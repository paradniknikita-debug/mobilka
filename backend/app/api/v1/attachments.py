"""
API загрузки и отдачи вложений карточки опоры: фото, схемы, голосовые заметки, видео.
Хранилище: MinIO (S3) при заданных S3_* или локальный диск uploads/pole_attachments/.
Для фото создаётся миниатюра (до 150px) и возвращается thumbnail_url для хранения в истории комментариев.
"""
import io
import uuid
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
ALLOWED_VIDEO = {"video/mp4", "video/webm", "video/quicktime"}
MAX_SIZE_MB = 25


def _extension_for_content_type(content_type: str, attachment_type: str) -> str:
    if attachment_type == "voice":
        return ".m4a" if "m4a" in (content_type or "") or "mp4" in content_type else ".mp3"
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
    attachment_type: str = Form(..., description="photo | voice | schema | video"),
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Загрузить вложение к карточке опоры.
    attachment_type: photo, voice, schema, video.
    Хранилище: MinIO при настройке S3_* или локальный диск.
    """
    if attachment_type not in ("photo", "voice", "schema", "video"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="attachment_type: photo, voice, schema или video",
        )
    result = await db.execute(select(Pole).where(Pole.id == pole_id))
    pole = result.scalar_one_or_none()
    if not pole:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Опора не найдена")

    content_type = file.content_type or ""
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
    result = {"url": url, "type": attachment_type, "filename": name}

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
