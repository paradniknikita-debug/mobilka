from sqlalchemy import create_engine, MetaData, text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
import asyncio
import logging

from app.core.config import settings

logger = logging.getLogger(__name__)

# Создание движка базы данных
# Для asyncpg отключаем SSL для внутреннего Docker соединения
database_url = settings.DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://")
# Если URL не содержит параметров SSL, добавляем отключение SSL
if "?" not in database_url:
    database_url += "?ssl=disable"
elif "ssl=" not in database_url:
    database_url += "&ssl=disable"

# Отладочный вывод для диагностики
print(f"DEBUG: Database URL будет использован: {database_url.split('@')[0].split('://')[0]}://****@{database_url.split('@')[1] if '@' in database_url else 'unknown'}")

# Настройка движка с таймаутами и пулом соединений
# Адаптивные настройки в зависимости от окружения
import os
is_docker = os.path.exists("/.dockerenv")  # Проверка, запущены ли в Docker

if is_docker:
    # Настройки для Docker (более производительные)
    pool_size = 5
    max_overflow = 10
    pool_recycle = 3600  # 1 час
    timeout = 10
else:
    # Настройки для Windows (более консервативные)
    pool_size = 1
    max_overflow = 0
    pool_recycle = 300  # 5 минут
    timeout = 30

engine = create_async_engine(
    database_url,
    echo=False,  # Отключаем echo для уменьшения логов
    pool_size=pool_size,
    max_overflow=max_overflow,
    pool_pre_ping=True,  # Проверка соединений перед использованием
    pool_recycle=pool_recycle,
    # Используем минимальные параметры для asyncpg
    connect_args={
        "timeout": timeout,
    }
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
    """Инициализация базы данных с обработкой ошибок"""
    import asyncpg
    from urllib.parse import urlparse
    
    max_retries = 3
    retry_delay = 2  # секунды
    
    # Парсим URL для получения параметров подключения
    # Используем более надежный способ парсинга
    db_url = settings.DATABASE_URL
    parsed = urlparse(db_url)
    
    db_host = parsed.hostname or "localhost"
    # Важно: проверяем порт из URL, если не указан - используем 5433 (наш Docker порт)
    db_port = parsed.port if parsed.port else (5433 if "5433" in db_url else 5432)
    db_user = parsed.username or "postgres"
    db_password = parsed.password or ""
    db_name = parsed.path.lstrip("/") or "lepm_db"
    
    # Дополнительная проверка: если в URL явно указан 5433, используем его
    if ":5433" in db_url:
        db_port = 5433
    elif ":5432" in db_url:
        db_port = 5432
    
    # Маскируем пароль в URL для вывода
    safe_url = settings.DATABASE_URL
    if "@" in safe_url:
        parts = safe_url.split("@")
        if ":" in parts[0]:
            user_pass = parts[0].split(":")
            if len(user_pass) >= 2:
                safe_url = f"{user_pass[0]}:****@{parts[1]}"
    
    print(f"Попытка подключения к базе данных: {safe_url}")
    print(f"DEBUG: Параметры подключения - host={db_host}, port={db_port}, db={db_name}, user={db_user}")
    
    # Пробуем использовать прямое подключение через asyncpg для инициализации
    # Это обходит проблемы SQLAlchemy с asyncpg на Windows
    for attempt in range(max_retries):
        try:
            # Прямое подключение через asyncpg для проверки
            conn = await asyncpg.connect(
                host=db_host,
                port=db_port,
                user=db_user,
                password=db_password,
                database=db_name,
                timeout=10
            )
            
            # Проверяем подключение
            version = await conn.fetchval("SELECT version()")
            print(f"DEBUG: Подключение успешно, версия PostgreSQL: {version[:50]}...")
            
            # Закрываем прямое подключение
            await conn.close()
            
            # Теперь используем SQLAlchemy для создания таблиц
            # Используем более простой подход - синхронное создание через sync_engine
            async with engine.begin() as conn:
                await conn.run_sync(Base.metadata.create_all)
                # Обеспечиваем наличие колонки is_tap_pole в pole (на случай БД без миграций)
                await conn.execute(text("""
                    DO $$
                    BEGIN
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'pole')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'pole' AND column_name = 'is_tap_pole')
                        THEN
                            ALTER TABLE pole ADD COLUMN is_tap_pole BOOLEAN NOT NULL DEFAULT false;
                        END IF;
                    END $$;
                """))
            
            logger.info("База данных успешно инициализирована")
            print("OK: База данных успешно инициализирована")
            return
            
        except Exception as e:
            error_type = type(e).__name__
            error_message = str(e)
            
            if attempt < max_retries - 1:
                logger.warning(f"WARNING: Попытка подключения к БД {attempt + 1}/{max_retries} не удалась: {error_type}: {error_message}. Повтор через {retry_delay} сек...")
                print(f"WARNING: Попытка подключения к БД {attempt + 1}/{max_retries} не удалась: {error_type}: {error_message}. Повтор через {retry_delay} сек...")
                await asyncio.sleep(retry_delay)
            else:
                # Извлекаем информацию о хосте и порте из URL
                db_info = f"{db_host}:{db_port}/{db_name}"
                
                error_msg = (
                    f"\nERROR: Не удалось подключиться к базе данных после {max_retries} попыток.\n"
                    f"Тип ошибки: {error_type}\n"
                    f"Сообщение: {error_message}\n"
                    f"Адрес БД: {db_info}\n\n"
                    f"Проверьте:\n"
                    f"  1. Запущен ли PostgreSQL сервер\n"
                    f"  2. Правильность DATABASE_URL в настройках (app/core/config.py или .env файл)\n"
                    f"  3. Доступность базы данных по указанному адресу\n"
                    f"  4. Правильность имени базы данных, пользователя и пароля\n"
                    f"  5. Если используете Docker, проверьте, что контейнер PostgreSQL запущен\n"
                )
                logger.error(error_msg)
                print(error_msg)
                raise ConnectionError(f"Не удалось подключиться к базе данных: {error_message}") from e
