"""
API загрузки и отдачи вложений карточки опоры: фото, схемы, голосовые заметки, видео.
Хранилище: MinIO (S3) при заданных S3_* или локальный диск uploads/pole_attachments/.
Для фото создаётся миниатюра (до 150px) и возвращается thumbnail_url для хранения в истории комментариев.
"""
import io
import json
import os
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from fastapi.responses import Response

from app.core.security import get_current_active_user
from app.core.media_storage import media_put, media_get
from app.models.user import User
from app.database import get_db
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.power_line import Pole

router = APIRouter()

THUMBNAIL_MAX_SIZE = (150, 150)

ALLOWED_IMAGE = {"image/jpeg", "image/png", "image/gif", "image/webp"}
ALLOWED_VOICE = {"audio/mpeg", "audio/mp4", "audio/m4a", "audio/x-m4a", "audio/wav", "audio/webm"}
ALLOWED_SCHEMA = {"image/svg+xml", "image/png", "application/pdf"}
# Таблицы и документы как «схема/вложение карточки» (xlsx, csv и т.д.)
ALLOWED_SCHEMA_DOCUMENTS = {
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",  # .xlsx
    "application/vnd.ms-excel",  # .xls
    "text/csv",
    "text/csv; charset=utf-8",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",  # .docx
    "application/msword",  # .doc
    "application/vnd.openxmlformats-officedocument.presentationml.presentation",  # .pptx
    "application/vnd.ms-powerpoint",
    "application/vnd.oasis.opendocument.spreadsheet",  # .ods
    "application/vnd.oasis.opendocument.text",  # .odt
    "application/octet-stream",  # часто приходит с клиента; имя файла проверяем отдельно
}
ALLOWED_VIDEO = {"video/mp4", "video/webm", "video/quicktime"}
MAX_SIZE_MB = 25


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def _safe_original_filename(name: Optional[str]) -> str:
    """Имя файла от клиента для отображения и скачивания (без путей)."""
    if not name:
        return ""
    s = str(name).strip().replace("\x00", "")
    if not s:
        return ""
    base = os.path.basename(s.replace("\\", "/"))
    base = base.replace("..", "_").strip()
    if not base or base in (".", ".."):
        return ""
    return base[:240]


def _parse_card_attachment_items(raw: Optional[str]) -> List[Dict[str, Any]]:
    """Разбор JSON из pole.card_comment_attachment: массив или schema v2 с полем items."""
    if not raw or not str(raw).strip():
        return []
    try:
        data = json.loads(raw)
        if isinstance(data, list):
            return [x for x in data if isinstance(x, dict)]
        if isinstance(data, dict) and isinstance(data.get("items"), list):
            return [x for x in data["items"] if isinstance(x, dict)]
    except Exception:
        pass
    return []


def _catalog_item(item: Dict[str, Any], pole_id: int) -> Dict[str, Any]:
    url = (item.get("url") or item.get("p") or "").strip()
    fn = (item.get("filename") or "").strip()
    if not fn and url:
        fn = url.rstrip("/").split("/")[-1]
    ext = ""
    if fn and "." in fn:
        ext = "." + fn.rsplit(".", 1)[-1].lower()
    orig = (item.get("original_filename") or "").strip()
    display_name = orig or fn or "file"
    return {
        "t": item.get("t") or "photo",
        "url": url,
        "thumbnail_url": item.get("thumbnail_url") or item.get("thumbnail"),
        "filename": fn or "file",
        "original_filename": orig or None,
        "display_name": display_name,
        "extension": ext,
        "added_at": item.get("added_at"),
        "added_by_id": item.get("added_by_id") if item.get("added_by_id") is not None else item.get("added_by"),
        "added_by_name": item.get("added_by_name"),
    }


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
    if lower.endswith(".webm"):
        return "video/webm"
    if lower.endswith(".mp4"):
        return "video/mp4"
    if lower.endswith(".xlsx"):
        return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    if lower.endswith(".xls"):
        return "application/vnd.ms-excel"
    if lower.endswith(".csv"):
        return "text/csv"
    if lower.endswith(".docx"):
        return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    if lower.endswith(".doc"):
        return "application/msword"
    if lower.endswith(".pptx"):
        return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
    return ""


def _extension_for_any_file(filename: Optional[str], content_type: str) -> str:
    """Универсальное расширение для типа вложения «file» (любой файл)."""
    fe = _office_extension_from_filename(filename)
    if fe:
        return fe
    lower = (filename or "").lower()
    for suffix, ext in (
        (".mp3", ".mp3"),
        (".m4a", ".m4a"),
        (".wav", ".wav"),
        (".webm", ".webm"),
        (".ogg", ".ogg"),
        (".aac", ".aac"),
        (".mp4", ".mp4"),
        (".mov", ".mov"),
        (".mkv", ".mkv"),
        (".jpg", ".jpg"),
        (".jpeg", ".jpg"),
        (".png", ".png"),
        (".gif", ".gif"),
        (".webp", ".webp"),
        (".svg", ".svg"),
        (".pdf", ".pdf"),
        (".zip", ".zip"),
        (".txt", ".txt"),
    ):
        if lower.endswith(suffix):
            return ext
    ct = (content_type or "").lower()
    if ct.startswith("image/"):
        return ".jpg"
    if ct.startswith("audio/"):
        return ".m4a"
    if ct.startswith("video/"):
        return ".mp4"
    return ".bin"


def _office_extension_from_filename(filename: Optional[str]) -> str:
    """Расширение для таблиц/документов по имени файла (при octet-stream)."""
    lower = (filename or "").lower()
    for suffix, ext in (
        (".xlsx", ".xlsx"),
        (".xls", ".xls"),
        (".csv", ".csv"),
        (".docx", ".docx"),
        (".doc", ".doc"),
        (".pptx", ".pptx"),
        (".ppt", ".ppt"),
        (".ods", ".ods"),
        (".odt", ".odt"),
    ):
        if lower.endswith(suffix):
            return ext
    return ""


def _extension_for_content_type(content_type: str, attachment_type: str) -> str:
    if attachment_type == "voice":
        return ".m4a" if "m4a" in (content_type or "") or "mp4" in content_type else ".mp3"
    if attachment_type == "video":
        return ".mp4" if "mp4" in (content_type or "") or "quicktime" in (content_type or "") else ".webm"
    if attachment_type == "photo" or attachment_type == "schema":
        ct = (content_type or "").lower()
        if "spreadsheetml" in ct or "excel" in ct or ct == "application/vnd.ms-excel":
            return ".xlsx" if "spreadsheetml" in ct else ".xls"
        if "wordprocessingml" in ct or ct == "application/msword":
            return ".docx" if "wordprocessingml" in ct else ".doc"
        if "presentationml" in ct or "powerpoint" in ct:
            return ".pptx"
        if ct.startswith("text/csv"):
            return ".csv"
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
        if attachment_type == "schema":
            return ".jpg"
        return ".jpg"
    return ".bin"


@router.post("/poles/{pole_id}/attachments")
async def upload_pole_attachment(
    pole_id: int,
    attachment_type: str = Form(
        ...,
        description="file — любой файл; legacy: photo | voice | schema | video",
    ),
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    if attachment_type not in ("file", "photo", "voice", "schema", "video"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="attachment_type: file (рекомендуется) или photo, voice, schema, video",
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
            "file": "application/octet-stream",
            "photo": "image/jpeg",
            "voice": "audio/mp4",
            "schema": "image/jpeg",
            "video": "video/mp4",
        }.get(attachment_type, "application/octet-stream")
    if attachment_type == "file":
        pass  # любой MIME, ограничение только по размеру
    elif attachment_type == "photo" and content_type not in ALLOWED_IMAGE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Фото: допустимые типы {ALLOWED_IMAGE}",
        )
    if attachment_type == "voice" and content_type not in ALLOWED_VOICE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Голос: допустимые типы {ALLOWED_VOICE}",
        )
    if attachment_type == "schema":
        ct = (content_type or "").strip()
        schema_ok = (
            ct in ALLOWED_SCHEMA
            or ct.startswith("image/")
            or (ct in ALLOWED_SCHEMA_DOCUMENTS and ct != "application/octet-stream")
            or (ct == "application/octet-stream" and bool(_office_extension_from_filename(file.filename)))
        )
        if not schema_ok:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    "Схема/вложение: изображения, PDF, SVG или документы "
                    "(xlsx, xls, csv, docx, doc, pptx и др.)"
                ),
            )
    if attachment_type == "video" and content_type not in ALLOWED_VIDEO:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Видео: допустимые типы {ALLOWED_VIDEO}",
        )

    if attachment_type == "file":
        ext = _extension_for_any_file(file.filename, content_type)
    else:
        ext = _extension_for_content_type(content_type, attachment_type)
    if attachment_type == "schema":
        fe = _office_extension_from_filename(file.filename)
        ct_norm = (content_type or "").strip()
        if fe and (ct_norm == "application/octet-stream" or ext in (".jpg", ".bin")):
            ext = fe
    name = f"{uuid.uuid4().hex}{ext}"
    content = await file.read()
    if len(content) > MAX_SIZE_MB * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Размер файла не более {MAX_SIZE_MB} МБ",
        )

    try:
        media_put(pole_id, name, content, content_type or "application/octet-stream")
    except Exception as e:
        import logging
        logging.getLogger(__name__).exception("Ошибка сохранения вложения опоры")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Не удалось сохранить файл: {str(e)}",
        ) from e

    url = f"/api/v1/attachments/poles/{pole_id}/{name}"
    orig_safe = _safe_original_filename(file.filename)
    result = {
        "url": url,
        "type": attachment_type,
        "filename": name,
        "original_filename": orig_safe if orig_safe else name,
        "added_at": _utc_now_iso(),
        "added_by_id": current_user.id,
        "added_by_name": current_user.full_name or current_user.username,
    }

    # Для фото создаём миниатюру и возвращаем thumbnail_url для хранения в карточке опоры
    if (
        (attachment_type == "photo" or attachment_type == "file")
        and content_type in ALLOWED_IMAGE
    ):
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


@router.get("/poles/{pole_id}/catalog")
async def get_pole_attachment_catalog(
    pole_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Нормализованный список вложений карточки опоры (имя, расширение, дата, автор)."""
    result = await db.execute(select(Pole).where(Pole.id == pole_id))
    pole = result.scalar_one_or_none()
    if not pole:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Опора не найдена")
    raw = getattr(pole, "card_comment_attachment", None) or ""
    items = [_catalog_item(x, pole_id) for x in _parse_card_attachment_items(raw)]
    return {
        "items": items,
        "card_comment": getattr(pole, "card_comment", None),
    }


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
        content, media_type = media_get(pole_id, filename)
    except Exception as e:
        import logging
        logging.getLogger(__name__).exception("Ошибка чтения вложения")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Ошибка чтения файла: {str(e)}",
        ) from e
    if content is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Файл не найден")

    return Response(
        content=content,
        media_type=media_type or "application/octet-stream",
        headers={"Content-Disposition": f'inline; filename="{filename}"'},
    )
