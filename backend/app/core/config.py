import os
from typing import List, Optional

from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    DATABASE_URL: str = "postgresql://postgres:dragon167@localhost:5433/lepm_db"
    SECRET_KEY: str = "CHANGE_ME_SECRET_KEY"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 480
    REDIS_URL: str = "redis://localhost:6379"
    UPLOAD_DIR: str = "uploads"
    MAX_FILE_SIZE: int = 10 * 1024 * 1024  # 10MB

    # MinIO / S3 — если endpoint и ключи заданы, вложения в объектном хранилище
    S3_ENDPOINT_URL: Optional[str] = None
    S3_ACCESS_KEY: str = ""
    S3_SECRET_KEY: str = ""
    S3_BUCKET_MEDIA: str = "lepm-media"
    S3_REGION: str = "us-east-1"

    TILE_CACHE_DIR: str = "tile_cache"
    TRUSTED_PROXIES: List[str] = ["127.0.0.1", "host.docker.internal", "nginx"]
    ALLOWED_HOSTS: List[str] = [
        "localhost",
        "127.0.0.1",
        "host.docker.internal",
        "0.0.0.0",
        "your-domain.com",
    ]
    ALLOWED_ORIGINS: List[str] = [
        "http://localhost",
        "http://127.0.0.1",
    ]
    CORS_ORIGINS: str = ""
    DEFAULT_ZOOM: int = 10
    MIN_ZOOM: int = 1
    MAX_ZOOM: int = 18
    SSL_KEYFILE: str = "/app/nginx/ssl/key.pem"
    SSL_CERTFILE: str = "/app/nginx/ssl/crt.pem"
    ENVIRONMENT: str = "development"
    RECREATE_DB: bool = False

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    @field_validator("S3_ENDPOINT_URL", mode="before")
    @classmethod
    def empty_endpoint_to_none(cls, v):
        if v == "":
            return None
        return v

    @field_validator("RECREATE_DB", mode="before")
    @classmethod
    def parse_recreate_db(cls, v):
        if isinstance(v, bool):
            return v
        if v is None:
            return False
        return str(v).lower() in ("1", "true", "yes")

    @model_validator(mode="after")
    def development_local_minio_defaults(self):
        """
        В development, если S3_ENDPOINT_URL не задан — подключаем локальный MinIO
        (docker compose: порт 9000 на хост). Отключить: DISABLE_LOCAL_MINIO=1
        """
        if self.ENVIRONMENT != "development":
            return self
        url = self.S3_ENDPOINT_URL
        if url is not None and str(url).strip() != "":
            return self
        if os.getenv("DISABLE_LOCAL_MINIO", "").lower() in ("1", "true", "yes"):
            return self
        return self.model_copy(
            update={
                "S3_ENDPOINT_URL": "http://127.0.0.1:9000",
                "S3_ACCESS_KEY": self.S3_ACCESS_KEY or "minioadmin",
                "S3_SECRET_KEY": self.S3_SECRET_KEY or "minioadmin",
            }
        )

    @model_validator(mode="after")
    def validate_production(self):
        if self.ENVIRONMENT != "production":
            return self
        if not self.DATABASE_URL:
            raise ValueError("DATABASE_URL обязателен для продакшена!")
        if not self.SECRET_KEY or self.SECRET_KEY == "CHANGE_ME_SECRET_KEY":
            raise ValueError("SECRET_KEY должен быть задан для продакшена!")
        if not self.CORS_ORIGINS:
            raise ValueError("CORS_ORIGINS должен быть задан для продакшена!")
        return self


settings = Settings()
