from pydantic_settings import BaseSettings
from typing import Optional, List
import os

class Settings(BaseSettings):
    # База данных
    # ОБЯЗАТЕЛЬНО задайте через .env или переменные окружения для продакшена!
    # Для Docker: postgresql://postgres:postgres@postgres:5432/lepm_db
    # Для локального запуска: postgresql://postgres:password@localhost:5432/lepm_db
    # Дефолтное значение только для development
    DATABASE_URL: str = os.getenv("DATABASE_URL", "postgresql://postgres:dragon167@localhost:5433/lepm_db")
    
    # JWT настройки
    # ОБЯЗАТЕЛЬНО задайте через .env для продакшена! Сгенерируйте через: python3 -c "import secrets; print(secrets.token_urlsafe(32))"
    # Дефолтное значение только для development
    SECRET_KEY: str = os.getenv("SECRET_KEY", "CHANGE_ME_SECRET_KEY")
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
    
    # CORS настройки для продакшена
    # Задайте через переменную окружения CORS_ORIGINS (через запятую)
    CORS_ORIGINS: str = os.getenv("CORS_ORIGINS", "")



    # Настройки карты
    DEFAULT_ZOOM: int = 10
    MIN_ZOOM: int = 1
    MAX_ZOOM: int = 18
    SSL_KEYFILE: str = "/app/nginx/ssl/key.pem"
    SSL_CERTFILE: str = "/app/nginx/ssl/crt.pem"
    
    # Окружение (development/production)
    ENVIRONMENT: str = os.getenv("ENVIRONMENT", "development")
    
    class Config:
        env_file = ".env"
        
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        # Проверка обязательных переменных для продакшена
        if self.ENVIRONMENT == "production":
            if not self.DATABASE_URL:
                raise ValueError("DATABASE_URL обязателен для продакшена!")
            if not self.SECRET_KEY or self.SECRET_KEY == "CHANGE_ME_SECRET_KEY":
                raise ValueError("SECRET_KEY должен быть задан для продакшена!")
            if not self.CORS_ORIGINS:
                raise ValueError("CORS_ORIGINS должен быть задан для продакшена!")

settings = Settings()
