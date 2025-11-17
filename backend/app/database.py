from sqlalchemy import create_engine, MetaData
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
import asyncio

from app.core.config import settings

# Создание движка базы данных
# Для asyncpg отключаем SSL для внутреннего Docker соединения
database_url = settings.DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://")
# Если URL не содержит параметров SSL, добавляем отключение SSL
if "?" not in database_url:
    database_url += "?ssl=disable"
elif "ssl=" not in database_url:
    database_url += "&ssl=disable"

engine = create_async_engine(
    database_url,
    echo=True
)

# Создание сессии
AsyncSessionLocal = sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False
)

# Базовый класс для моделей
Base = declarative_base()

# Метаданные
metadata = MetaData()

async def get_db():
    """Получение сессии базы данных"""
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()

async def init_db():
    """Инициализация базы данных"""
    async with engine.begin() as conn:
        # Создание всех таблиц
        await conn.run_sync(Base.metadata.create_all)
