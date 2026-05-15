"""
Абстракция хранилища медиа: локальный диск или S3-совместимое (MinIO).
Префиксы ключей: poles/{id}/..., equipment/{id}/...
Локально: uploads/pole_attachments/ и uploads/equipment_attachments/
"""
import logging
from pathlib import Path
from typing import Optional, Tuple
from urllib.parse import quote, unquote

from app.core.config import settings

logger = logging.getLogger(__name__)

UPLOAD_DIR_POLE = Path(__file__).resolve().parents[2] / "uploads" / "pole_attachments"
UPLOAD_DIR_EQUIPMENT = Path(__file__).resolve().parents[2] / "uploads" / "equipment_attachments"
# Обратная совместимость со старым именем
UPLOAD_DIR = UPLOAD_DIR_POLE

_s3_client = None
_bucket = None


def _use_s3() -> bool:
    return bool(
        settings.S3_ENDPOINT_URL
        and settings.S3_ACCESS_KEY
        and settings.S3_SECRET_KEY
        and settings.S3_BUCKET_MEDIA
    )


def log_media_storage_mode() -> None:
    """Вызвать при старте приложения: куда реально пишутся файлы вложений."""
    if _use_s3():
        logger.info(
            "Вложения (опоры/оборудование): MinIO/S3 (endpoint=%s, bucket=%s)",
            settings.S3_ENDPOINT_URL,
            settings.S3_BUCKET_MEDIA,
        )
        print(
            f"OK: Вложения — MinIO/S3 ({settings.S3_ENDPOINT_URL}, bucket={settings.S3_BUCKET_MEDIA})"
        )
    else:
        logger.warning(
            "Вложения: локальный диск опор=%s, оборудования=%s (S3 не настроен)",
            UPLOAD_DIR_POLE,
            UPLOAD_DIR_EQUIPMENT,
        )
        print(
            f"WARNING: Вложения — локально {UPLOAD_DIR_POLE} и {UPLOAD_DIR_EQUIPMENT} "
            "(задайте S3_* или в development уберите DISABLE_LOCAL_MINIO и поднимите MinIO на :9000)"
        )


def _get_s3_client():
    global _s3_client, _bucket
    if _s3_client is not None:
        return _s3_client, _bucket
    if not _use_s3():
        return None, None
    import boto3
    from botocore.config import Config
    from botocore.exceptions import ClientError

    client = boto3.client(
        "s3",
        endpoint_url=settings.S3_ENDPOINT_URL,
        aws_access_key_id=settings.S3_ACCESS_KEY,
        aws_secret_access_key=settings.S3_SECRET_KEY,
        region_name=settings.S3_REGION,
        config=Config(
            signature_version="s3v4",
            s3={"addressing_style": "path"},
        ),
    )
    _bucket = settings.S3_BUCKET_MEDIA
    try:
        client.head_bucket(Bucket=_bucket)
    except ClientError as e:
        code = (e.response or {}).get("Error", {}).get("Code", "") or ""
        http_status = (e.response or {}).get("ResponseMetadata", {}).get("HTTPStatusCode")
        if code in ("404", "NoSuchBucket", "NotFound") or http_status == 404:
            try:
                client.create_bucket(Bucket=_bucket)
                logger.info("Создан bucket S3/MinIO: %s", _bucket)
            except ClientError as e2:
                c2 = (e2.response or {}).get("Error", {}).get("Code", "") or ""
                if c2 in ("BucketAlreadyOwnedByYou", "BucketAlreadyExists"):
                    pass
                else:
                    logger.exception("Не удалось создать bucket %s: %s", _bucket, e2)
                    raise
        else:
            logger.exception("head_bucket %s: %s", _bucket, e)
            raise
    except Exception:
        logger.exception("Ошибка проверки bucket %s", _bucket)
        raise
    _s3_client = client
    logger.info(
        "Медиа: S3 endpoint=%s bucket=%s",
        settings.S3_ENDPOINT_URL,
        _bucket,
    )
    return _s3_client, _bucket


def _local_dir_for_prefix(prefix: str) -> Path:
    if prefix == "poles":
        return UPLOAD_DIR_POLE
    if prefix == "equipment":
        return UPLOAD_DIR_EQUIPMENT
    raise ValueError(f"Неизвестный префикс вложений: {prefix}")


def _original_sidecar_path(prefix: str, entity_id: int, storage_filename: str) -> Path:
    return _local_dir_for_prefix(prefix) / str(entity_id) / f"{storage_filename}.orig"


def _write_original_sidecar(prefix: str, entity_id: int, storage_filename: str, original: str) -> None:
    try:
        p = _original_sidecar_path(prefix, entity_id, storage_filename)
        p.write_text(original, encoding="utf-8")
    except OSError as e:
        logger.warning("Не удалось записать .orig для %s: %s", storage_filename, e)


def _read_original_sidecar(prefix: str, entity_id: int, storage_filename: str) -> Optional[str]:
    p = _original_sidecar_path(prefix, entity_id, storage_filename)
    if not p.is_file():
        return None
    try:
        t = p.read_text(encoding="utf-8").strip()
        return t or None
    except OSError:
        return None


def _s3_metadata_original(original: str) -> dict:
    """S3 user metadata — только ASCII; имя кодируем percent-encoding."""
    return {"original-filename": quote(original.strip(), safe="")}


def _parse_s3_original_metadata(meta: dict) -> Optional[str]:
    if not meta:
        return None
    raw = meta.get("original-filename") or meta.get("original_filename")
    if not raw:
        return None
    try:
        return unquote(str(raw))
    except Exception:
        return None


def media_put_for(
    prefix: str,
    entity_id: int,
    filename: str,
    content: bytes,
    content_type: str,
    original_filename: Optional[str] = None,
) -> None:
    """Сохранить файл (S3 key: {prefix}/{entity_id}/{filename}). Опционально — оригинальное имя для скачивания."""
    key = f"{prefix}/{entity_id}/{filename}"
    orig = (original_filename or "").strip() or None
    try:
        client, bucket = _get_s3_client()
    except Exception as e:
        logger.warning("S3 недоступен, локальный диск: %s", e)
        client, bucket = None, None
    if client and bucket:
        put_kw = dict(
            Bucket=bucket,
            Key=key,
            Body=content,
            ContentType=content_type or "application/octet-stream",
        )
        if orig:
            put_kw["Metadata"] = _s3_metadata_original(orig)
        client.put_object(**put_kw)
        return
    d = _local_dir_for_prefix(prefix) / str(entity_id)
    try:
        d.mkdir(parents=True, exist_ok=True)
    except OSError as e:
        raise RuntimeError(f"Не удалось создать каталог {d}: {e}") from e
    target = d / filename
    try:
        target.write_bytes(content)
    except OSError as e:
        raise RuntimeError(f"Не удалось записать файл {target}: {e}") from e
    if orig:
        _write_original_sidecar(prefix, entity_id, filename, orig)


def media_put(
    pole_id: int,
    filename: str,
    content: bytes,
    content_type: str,
    original_filename: Optional[str] = None,
) -> None:
    """Сохранить вложение карточки опоры."""
    media_put_for("poles", pole_id, filename, content, content_type, original_filename)


def _read_local_prefixed(prefix: str, entity_id: int, filename: str) -> Tuple[Optional[bytes], Optional[str]]:
    path = _local_dir_for_prefix(prefix) / str(entity_id) / filename
    if not path.is_file():
        return None, None
    try:
        content = path.read_bytes()
    except OSError:
        return None, None
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


def _read_local(pole_id: int, filename: str) -> Tuple[Optional[bytes], Optional[str]]:
    return _read_local_prefixed("poles", pole_id, filename)


def media_get_for(
    prefix: str, entity_id: int, filename: str
) -> Tuple[Optional[bytes], Optional[str], Optional[str]]:
    """Тело, Content-Type, оригинальное имя файла (если было при загрузке)."""
    key = f"{prefix}/{entity_id}/{filename}"
    try:
        client, bucket = _get_s3_client()
    except Exception as e:
        logger.warning("S3 клиент недоступен, только локальный диск: %s", e)
        client, bucket = None, None
    if client and bucket:
        try:
            resp = client.get_object(Bucket=bucket, Key=key)
            body = resp["Body"].read()
            content_type = resp.get("ContentType") or "application/octet-stream"
            meta = resp.get("Metadata") or {}
            orig = _parse_s3_original_metadata(meta)
            return body, content_type, orig
        except Exception:
            pass
    content, ct = _read_local_prefixed(prefix, entity_id, filename)
    if content is not None:
        orig = _read_original_sidecar(prefix, entity_id, filename)
        return content, ct, orig
    return None, None, None


def media_get(pole_id: int, filename: str) -> Tuple[Optional[bytes], Optional[str], Optional[str]]:
    return media_get_for("poles", pole_id, filename)


def media_exists(pole_id: int, filename: str) -> bool:
    """Проверить наличие файла вложения опоры."""
    try:
        client, bucket = _get_s3_client()
    except Exception:
        client, bucket = None, None
    if client and bucket:
        key = f"poles/{pole_id}/{filename}"
        try:
            client.head_object(Bucket=bucket, Key=key)
            return True
        except Exception:
            pass
    path = UPLOAD_DIR_POLE / str(pole_id) / filename
    return path.is_file()
