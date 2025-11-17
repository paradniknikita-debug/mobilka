from pydantic_settings import BaseSettings
from typing import Optional, List
import os

class Settings(BaseSettings):
    # База данных
    # Используйте .env или переменные окружения для задания реальной строки подключения
    # Для Docker: postgresql://postgres:postgres@postgres:5432/lepm_db
    # Для локального запуска: postgresql://postgres:password@localhost:5432/lepm_db
    DATABASE_URL: str = "postgresql://postgres:dragon167@localhost:5432/lepm_db"
    
    # JWT настройки
    SECRET_KEY: str = "CHANGE_ME_SECRET_KEY"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    
    # Redis для кэширования
    REDIS_URL: str = "redis://localhost:6379"
    
    # Настройки файлов
    UPLOAD_DIR: str = "uploads"
    MAX_FILE_SIZE: int = 10 * 1024 * 1024  # 10MB
    
    # Tile server настройки
    TILE_CACHE_DIR: str = "tile_cache"
    #Nginx
    TRUSTED_PROXIES: List[str] = ["127.0.0.1", "host.docker.internal", "nginx"]
    ALLOWED_HOSTS: List[str] = [
        "localhost",
        "127.0.0.1",
        "host.docker.internal",
        "0.0.0.0",
        "your-domain.com"
    ]
    ALLOWED_ORIGINS: List[str] = [
        "http://localhost",
        "http://127.0.0.1",
        "https://your-domain.com",
        # для Flutter Web dev-сервера (случайные порты)
        # при необходимости ограничьте конкретными origin позже
    ]



    # Настройки карты
    DEFAULT_ZOOM: int = 10
    MIN_ZOOM: int = 1
    MAX_ZOOM: int = 18
    SSL_KEYFILE: str = "/app/nginx/ssl/key.pem"
    SSL_CERTFILE: str = "/app/nginx/ssl/crt.pem"
    class Config:
        env_file = ".env"

settings = Settings()
