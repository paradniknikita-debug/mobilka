"""
Абстракция хранилища медиа: локальный диск или S3-совместимое (MinIO).
Если заданы S3_ENDPOINT_URL и ключи — используем MinIO/S3, иначе — uploads/pole_attachments/.
"""
from pathlib import Path
from typing import Optional, Tuple

from app.core.config import settings

# Локальная директория (fallback)
UPLOAD_DIR = Path(__file__).resolve().parents[2] / "uploads" / "pole_attachments"

_s3_client = None
_bucket = None


def _use_s3() -> bool:
    return bool(
        settings.S3_ENDPOINT_URL
        and settings.S3_ACCESS_KEY
        and settings.S3_SECRET_KEY
        and settings.S3_BUCKET_MEDIA
    )


def _get_s3_client():
    global _s3_client, _bucket
    if _s3_client is not None:
        return _s3_client, _bucket
    if not _use_s3():
        return None, None
    import boto3
    from botocore.config import Config
    client = boto3.client(
        "s3",
        endpoint_url=settings.S3_ENDPOINT_URL,
        aws_access_key_id=settings.S3_ACCESS_KEY,
        aws_secret_access_key=settings.S3_SECRET_KEY,
        region_name=settings.S3_REGION,
        config=Config(signature_version="s3v4"),
    )
    _bucket = settings.S3_BUCKET_MEDIA
    try:
        client.head_bucket(Bucket=_bucket)
    except Exception:
        client.create_bucket(Bucket=_bucket)
    _s3_client = client
    return _s3_client, _bucket


def media_put(pole_id: int, filename: str, content: bytes, content_type: str) -> None:
    """Сохранить файл в выбранное хранилище."""
    key = f"poles/{pole_id}/{filename}"
    client, bucket = _get_s3_client()
    if client and bucket:
        client.put_object(
            Bucket=bucket,
            Key=key,
            Body=content,
            ContentType=content_type or "application/octet-stream",
        )
        return
    # Локальный диск
    d = UPLOAD_DIR / str(pole_id)
    d.mkdir(parents=True, exist_ok=True)
    (d / filename).write_bytes(content)


def media_get(pole_id: int, filename: str) -> Tuple[Optional[bytes], Optional[str]]:
    """
    Прочитать файл из хранилища.
    Возвращает (content, content_type) или (None, None) если не найден.
    """
    key = f"poles/{pole_id}/{filename}"
    client, bucket = _get_s3_client()
    if client and bucket:
        try:
            resp = client.get_object(Bucket=bucket, Key=key)
            body = resp["Body"].read()
            content_type = resp.get("ContentType") or "application/octet-stream"
            return body, content_type
        except Exception:
            return None, None
    # Локальный диск
    path = UPLOAD_DIR / str(pole_id) / filename
    if not path.is_file():
        return None, None
    content = path.read_bytes()
    content_type = "application/octet-stream"
    if filename.endswith((".jpg", ".jpeg")):
        content_type = "image/jpeg"
    elif filename.endswith(".png"):
        content_type = "image/png"
    elif filename.endswith((".m4a", ".mp4")):
        content_type = "audio/mp4"
    elif filename.endswith(".mp3"):
        content_type = "audio/mpeg"
    elif filename.endswith(".svg"):
        content_type = "image/svg+xml"
    elif filename.endswith(".pdf"):
        content_type = "application/pdf"
    elif filename.endswith(".webm"):
        content_type = "video/webm"
    elif filename.endswith(".mp4"):
        content_type = "video/mp4"
    return content, content_type


def media_exists(pole_id: int, filename: str) -> bool:
    """Проверить наличие файла."""
    client, bucket = _get_s3_client()
    if client and bucket:
        key = f"poles/{pole_id}/{filename}"
        try:
            client.head_object(Bucket=bucket, Key=key)
            return True
        except Exception:
            return False
    path = UPLOAD_DIR / str(pole_id) / filename
    return path.is_file()
