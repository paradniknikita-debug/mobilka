"""
API загрузки и отдачи вложений карточки опоры: фото, схемы, голосовые заметки, видео.
Хранилище: MinIO (S3) при заданных S3_* или локальный диск uploads/pole_attachments/ и uploads/equipment_attachments/.
Для фото создаётся миниатюра (до 150px) и возвращается thumbnail_url для хранения в истории комментариев.
На диске/S3 ключ остаётся уникальным (uuid); оригинальное имя — в S3 Metadata / файле .orig и в поле original_filename ответа API.
"""
import io
import os.path
import uuid
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from fastapi.responses import Response
from urllib.parse import quote

from app.core.security import get_current_active_user
from app.core.media_storage import media_put, media_get, media_put_for, media_get_for
from app.models.user import User
from app.database import get_db
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.power_line import Pole, Equipment

router = APIRouter()

THUMBNAIL_MAX_SIZE = (150, 150)

ALLOWED_IMAGE = {"image/jpeg", "image/png", "image/gif", "image/webp", "image/bmp", "image/x-ms-bmp"}
ALLOWED_VOICE = {
    "audio/mpeg",
    "audio/mp4",
    "audio/m4a",
    "audio/x-m4a",
    "audio/wav",
    "audio/x-wav",
    "audio/webm",
    "video/webm",
    "audio/ogg",
}
ALLOWED_SCHEMA = {"image/svg+xml", "image/png", "application/pdf"}
ALLOWED_VIDEO = {"video/mp4", "video/webm", "video/quicktime"}
MAX_SIZE_MB = 25


def _sanitize_original_filename(name: Optional[str]) -> Optional[str]:
    """Безопасное имя для отображения и метаданных (только basename, без path traversal)."""
    if not name or not str(name).strip():
        return None
    base = os.path.basename(str(name).strip())
    if not base or base in (".", ".."):
        return None
    base = base.replace("\x00", "").replace("\r", "").replace("\n", "")
    if ".." in base:
        base = os.path.basename(base.replace("\\", "/"))
    base = base.strip()
    if not base:
        return None
    if len(base) > 200:
        base = base[:200]
    return base


def _content_disposition_header(stored_url_name: str, original: Optional[str]) -> str:
    """Имя при скачивании: оригинал или ключ хранения; UTF-8 через filename* (RFC 5987)."""
    name = ((original or "").strip() or stored_url_name).replace('"', "'")
    ascii_fallback = (
        name.encode("ascii", "replace").decode("ascii").replace("?", "_").strip() or "file"
    )
    star = quote(name, safe="")
    return f'inline; filename="{ascii_fallback}"; filename*=UTF-8\'\'{star}'


def _guess_content_type_from_name(name: str) -> str:
    """Если клиент не прислал Content-Type (часто у multipart), определяем по имени файла."""
    lower = (name or "").lower()
    if lower.endswith((".jpg", ".jpeg")):
        return "image/jpeg"
    if lower.endswith(".png"):
        return "image/png"
    if lower.endswith(".gif"):
        return "image/gif"
    if lower.endswith(".webp"):
        return "image/webp"
    if lower.endswith(".bmp"):
        return "image/bmp"
    if lower.endswith(".svg"):
        return "image/svg+xml"
    if lower.endswith(".pdf"):
        return "application/pdf"
    if lower.endswith(".m4a"):
        return "audio/mp4"
    if lower.endswith(".mp3"):
        return "audio/mpeg"
    if lower.endswith(".wav"):
        return "audio/wav"
    if lower.endswith(".ogg"):
        return "audio/ogg"
    if lower.endswith(".webm"):
        return "video/webm"
    if lower.endswith(".mp4"):
        return "video/mp4"
    if lower.endswith(".doc"):
        return "application/msword"
    if lower.endswith(".docx"):
        return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    if lower.endswith(".xls"):
        return "application/vnd.ms-excel"
    if lower.endswith(".xlsx"):
        return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    if lower.endswith(".ppt"):
        return "application/vnd.ms-powerpoint"
    if lower.endswith(".pptx"):
        return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
    if lower.endswith(".txt"):
        return "text/plain"
    if lower.endswith(".zip"):
        return "application/zip"
    if lower.endswith(".rar"):
        return "application/vnd.rar"
    if lower.endswith(".7z"):
        return "application/x-7z-compressed"
    return ""


def _extension_for_content_type(content_type: str, attachment_type: str) -> str:
    if attachment_type == "voice":
        ct = (content_type or "").lower()
        if "ogg" in ct:
            return ".ogg"
        if "wav" in ct:
            return ".wav"
        if "webm" in ct:
            return ".webm"
        if "m4a" in ct or "mp4" in ct:
            return ".m4a"
        if "mpeg" in ct or "mp3" in ct:
            return ".mp3"
        # Консервативный fallback для неизвестных voice MIME.
        return ".m4a"
    if attachment_type == "video":
        return ".mp4" if "mp4" in (content_type or "") or "quicktime" in (content_type or "") else ".webm"
    if attachment_type == "photo" or attachment_type == "schema":
        if content_type and "png" in content_type:
            return ".png"
        if content_type and "gif" in content_type:
            return ".gif"
        if content_type and "webp" in content_type:
            return ".webp"
        if content_type and "svg" in content_type:
            return ".svg"
        if content_type and "pdf" in content_type:
            return ".pdf"
        return ".jpg"
    return ".bin"


@router.post("/poles/{pole_id}/attachments")
async def upload_pole_attachment(
    pole_id: int,
    attachment_type: str = Form(..., description="photo | voice | schema | video | file"),
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    if attachment_type not in ("photo", "voice", "schema", "video", "file"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="attachment_type: photo, voice, schema, video или file",
        )
    result = await db.execute(select(Pole).where(Pole.id == pole_id))
    pole = result.scalar_one_or_none()
    if not pole:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Опора не найдена")

    content_type = (file.content_type or "").strip()
    if not content_type and file.filename:
        content_type = _guess_content_type_from_name(file.filename)
    if not content_type:
        # Последний fallback (клиент не прислал ни типа, ни осмысленного имени)
        content_type = {
            "photo": "image/jpeg",
            "voice": "audio/mp4",
            "schema": "image/jpeg",
            "video": "video/mp4",
        }.get(attachment_type, "application/octet-stream")
    if attachment_type == "photo" and content_type not in ALLOWED_IMAGE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Фото: допустимые типы {ALLOWED_IMAGE}",
        )
    if attachment_type == "voice" and content_type not in ALLOWED_VOICE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Голос: допустимые типы {ALLOWED_VOICE}",
        )
    if attachment_type == "schema" and content_type not in ALLOWED_SCHEMA and not content_type.startswith("image/"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Схема: допустимые типы {ALLOWED_SCHEMA}",
        )
    if attachment_type == "video" and content_type not in ALLOWED_VIDEO:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Видео: допустимые типы {ALLOWED_VIDEO}",
        )
    # file — универсальный тип вложения: проверка только по максимальному размеру.

    ext = _extension_for_content_type(content_type, attachment_type)
    if attachment_type == "file" and file.filename:
        fn = file.filename.strip().lower()
        dot = fn.rfind(".")
        if dot > 0 and dot < len(fn) - 1:
            ext = fn[dot:]
    name = f"{uuid.uuid4().hex}{ext}"
    content = await file.read()
    if len(content) > MAX_SIZE_MB * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Размер файла не более {MAX_SIZE_MB} МБ",
        )

    original_display = _sanitize_original_filename(file.filename)

    try:
        media_put(
            pole_id,
            name,
            content,
            content_type or "application/octet-stream",
            original_filename=original_display,
        )
    except Exception as e:
        import logging
        logging.getLogger(__name__).exception("Ошибка сохранения вложения опоры")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Не удалось сохранить файл: {str(e)}",
        ) from e

    url = f"/api/v1/attachments/poles/{pole_id}/{name}"
    result = {
        "url": url,
        "type": attachment_type,
        "filename": name,
        "original_filename": original_display,
        "added_at": datetime.utcnow().isoformat() + "Z",
        "added_by_id": current_user.id,
        "added_by_name": (getattr(current_user, "full_name", None) or getattr(current_user, "username", None) or "").strip() or None,
    }

    # Для фото создаём миниатюру и возвращаем thumbnail_url для хранения в карточке опоры
    if attachment_type == "photo" and content_type in ALLOWED_IMAGE:
        try:
            from PIL import Image
            img = Image.open(io.BytesIO(content))
            if img.mode in ("RGBA", "P"):
                img = img.convert("RGB")
            img.thumbnail(THUMBNAIL_MAX_SIZE, Image.Resampling.LANCZOS)
            buf = io.BytesIO()
            img.save(buf, format="JPEG", quality=85)
            thumb_name = f"thumb_{uuid.uuid4().hex}.jpg"
            media_put(pole_id, thumb_name, buf.getvalue(), "image/jpeg")
            result["thumbnail_url"] = f"/api/v1/attachments/poles/{pole_id}/{thumb_name}"
        except Exception:
            pass  # миниатюра опциональна, не ломаем ответ

    return result


@router.get("/poles/{pole_id}/{filename}")
async def get_pole_attachment(
    pole_id: int,
    filename: str,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Отдать файл вложения опоры (фото, голос, схема, видео). Из MinIO или с диска."""
    if ".." in filename or "/" in filename:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Недопустимое имя файла")
    result = await db.execute(select(Pole).where(Pole.id == pole_id))
    pole = result.scalar_one_or_none()
    if not pole:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Опора не найдена")

    try:
        content, media_type, original_download = media_get(pole_id, filename)
    except Exception as e:
        import logging
        logging.getLogger(__name__).exception("Ошибка чтения вложения")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Ошибка чтения файла: {str(e)}",
        ) from e
    # Legacy fallback: у старых голосовых вложений расширение в URL могло
    # не совпасть с фактическим файлом (например, .mp3 vs .ogg/.m4a).
    # Пробуем соседние голосовые расширения до 404.
    if content is None:
        lower = filename.lower()
        dot = lower.rfind(".")
        if dot > 0:
            stem = filename[:dot]
            ext = lower[dot:]
            if ext in {".mp3", ".m4a", ".ogg", ".wav", ".webm"}:
                for alt_ext in (".ogg", ".m4a", ".mp3", ".wav", ".webm"):
                    if alt_ext == ext:
                        continue
                    alt_name = f"{stem}{alt_ext}"
                    try:
                        alt_content, alt_media_type, alt_orig = media_get(pole_id, alt_name)
                    except Exception:
                        alt_content, alt_media_type, alt_orig = None, None, None
                    if alt_content is not None:
                        content, media_type, original_download = alt_content, alt_media_type, alt_orig
                        filename = alt_name
                        break
    if content is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Файл не найден")

    disp = _content_disposition_header(filename, original_download)
    return Response(
        content=content,
        media_type=media_type or "application/octet-stream",
        headers={"Content-Disposition": disp},
    )


@router.post("/equipment/{equipment_id}/attachments")
async def upload_equipment_attachment(
    equipment_id: int,
    attachment_type: str = Form(..., description="photo | voice | schema | video | file"),
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    if attachment_type not in ("photo", "voice", "schema", "video", "file"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="attachment_type: photo, voice, schema, video или file",
        )
    result = await db.execute(select(Equipment).where(Equipment.id == equipment_id))
    row = result.scalar_one_or_none()
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Оборудование не найдено")

    content_type = (file.content_type or "").strip()
    if not content_type and file.filename:
        content_type = _guess_content_type_from_name(file.filename)
    if not content_type:
        content_type = {
            "photo": "image/jpeg",
            "voice": "audio/mp4",
            "schema": "image/jpeg",
            "video": "video/mp4",
        }.get(attachment_type, "application/octet-stream")
    if attachment_type == "photo" and content_type not in ALLOWED_IMAGE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Фото: допустимые типы {ALLOWED_IMAGE}",
        )
    if attachment_type == "voice" and content_type not in ALLOWED_VOICE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Голос: допустимые типы {ALLOWED_VOICE}",
        )
    if attachment_type == "schema" and content_type not in ALLOWED_SCHEMA and not content_type.startswith("image/"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Схема: допустимые типы {ALLOWED_SCHEMA}",
        )
    if attachment_type == "video" and content_type not in ALLOWED_VIDEO:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Видео: допустимые типы {ALLOWED_VIDEO}",
        )

    ext = _extension_for_content_type(content_type, attachment_type)
    if attachment_type == "file" and file.filename:
        fn = file.filename.strip().lower()
        dot = fn.rfind(".")
        if dot > 0 and dot < len(fn) - 1:
            ext = fn[dot:]
    name = f"{uuid.uuid4().hex}{ext}"
    content = await file.read()
    if len(content) > MAX_SIZE_MB * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Размер файла не более {MAX_SIZE_MB} МБ",
        )

    original_display = _sanitize_original_filename(file.filename)

    try:
        media_put_for(
            "equipment",
            equipment_id,
            name,
            content,
            content_type or "application/octet-stream",
            original_filename=original_display,
        )
    except Exception as e:
        import logging
        logging.getLogger(__name__).exception("Ошибка сохранения вложения оборудования")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Не удалось сохранить файл: {str(e)}",
        ) from e

    url = f"/api/v1/attachments/equipment/{equipment_id}/{name}"
    out = {
        "url": url,
        "type": attachment_type,
        "filename": name,
        "original_filename": original_display,
        "added_at": datetime.utcnow().isoformat() + "Z",
        "added_by_id": current_user.id,
        "added_by_name": (getattr(current_user, "full_name", None) or getattr(current_user, "username", None) or "").strip() or None,
    }

    if attachment_type == "photo" and content_type in ALLOWED_IMAGE:
        try:
            from PIL import Image
            img = Image.open(io.BytesIO(content))
            if img.mode in ("RGBA", "P"):
                img = img.convert("RGB")
            img.thumbnail(THUMBNAIL_MAX_SIZE, Image.Resampling.LANCZOS)
            buf = io.BytesIO()
            img.save(buf, format="JPEG", quality=85)
            thumb_name = f"thumb_{uuid.uuid4().hex}.jpg"
            media_put_for("equipment", equipment_id, thumb_name, buf.getvalue(), "image/jpeg")
            out["thumbnail_url"] = f"/api/v1/attachments/equipment/{equipment_id}/{thumb_name}"
        except Exception:
            pass

    return out


@router.get("/equipment/{equipment_id}/{filename}")
async def get_equipment_attachment(
    equipment_id: int,
    filename: str,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    if ".." in filename or "/" in filename:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Недопустимое имя файла")
    result = await db.execute(select(Equipment).where(Equipment.id == equipment_id))
    row = result.scalar_one_or_none()
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Оборудование не найдено")

    try:
        content, media_type, original_download = media_get_for("equipment", equipment_id, filename)
    except Exception as e:
        import logging
        logging.getLogger(__name__).exception("Ошибка чтения вложения оборудования")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Ошибка чтения файла: {str(e)}",
        ) from e
    if content is None:
        lower = filename.lower()
        dot = lower.rfind(".")
        if dot > 0:
            stem = filename[:dot]
            ext = lower[dot:]
            if ext in {".mp3", ".m4a", ".ogg", ".wav", ".webm"}:
                for alt_ext in (".ogg", ".m4a", ".mp3", ".wav", ".webm"):
                    if alt_ext == ext:
                        continue
                    alt_name = f"{stem}{alt_ext}"
                    try:
                        alt_content, alt_media_type, alt_orig = media_get_for(
                            "equipment", equipment_id, alt_name
                        )
                    except Exception:
                        alt_content, alt_media_type, alt_orig = None, None, None
                    if alt_content is not None:
                        content, media_type, original_download = alt_content, alt_media_type, alt_orig
                        filename = alt_name
                        break
    if content is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Файл не найден")

    disp = _content_disposition_header(filename, original_download)
    return Response(
        content=content,
        media_type=media_type or "application/octet-stream",
        headers={"Content-Disposition": disp},
    )
