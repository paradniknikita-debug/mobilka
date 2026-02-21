#!/usr/bin/env python3
"""
Скрипт пересоздания базы данных и заполнения тестовыми данными.

Выполняет:
1. Подключение к PostgreSQL и удаление всех объектов схемы public (DROP SCHEMA public CASCADE)
2. Создание пустой схемы public
3. Создание всех таблиц из текущих моделей (SQLAlchemy Base.metadata.create_all)
4. Заполнение тестовыми данными (seed_test_data)

Использование (из папки backend):
    python recreate_db.py

Требуется: PostgreSQL запущен, DATABASE_URL в .env или app/core/config.py.
"""
import asyncio
import os
import sys
from pathlib import Path

# Корень backend для импортов и запуска alembic
BACKEND_DIR = Path(__file__).resolve().parent
os.chdir(BACKEND_DIR)
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))


def get_sync_database_url():
    """Возвращает URL для синхронного драйвера (psycopg2)."""
    from app.core.config import settings
    url = settings.DATABASE_URL
    # Убираем async-драйвер, если указан
    if url.startswith("postgresql+asyncpg://"):
        return url.replace("postgresql+asyncpg://", "postgresql://", 1)
    if url.startswith("postgresql+psycopg2://"):
        return url
    if url.startswith("postgresql://"):
        return url
    return url


def drop_and_recreate_schema():
    """Удаляет все объекты в схеме public и создаёт пустую схему."""
    import psycopg2
    from urllib.parse import urlparse

    url = get_sync_database_url()
    parsed = urlparse(url)
    conn_params = {
        "host": parsed.hostname or "localhost",
        "port": parsed.port or 5432,
        "user": parsed.username or "postgres",
        "password": parsed.password or "",
        "dbname": parsed.path.lstrip("/") or "lepm_db",
    }
    # Убираем пустой пароль для localhost
    if not conn_params["password"]:
        conn_params.pop("password", None)

    print("Подключение к базе данных...")
    conn = psycopg2.connect(**conn_params)
    conn.autocommit = True
    cur = conn.cursor()

    try:
        print("Удаление схемы public (CASCADE)...")
        cur.execute("DROP SCHEMA IF EXISTS public CASCADE;")
        print("Создание схемы public...")
        cur.execute("CREATE SCHEMA public;")
        cur.execute("GRANT ALL ON SCHEMA public TO postgres;")
        cur.execute("GRANT ALL ON SCHEMA public TO public;")
        print("Схема пересоздана.")
    finally:
        cur.close()
        conn.close()


def create_tables_from_models():
    """Создаёт все таблицы из текущих моделей приложения."""
    from sqlalchemy import create_engine
    from app.database import Base
    import app.models  # регистрирует все модели в Base.metadata

    url = get_sync_database_url()
    print("\nСоздание таблиц из моделей...")
    engine = create_engine(url)
    Base.metadata.create_all(bind=engine)
    engine.dispose()
    print("Таблицы созданы.\n")


async def run_seed():
    """Запускает заполнение тестовыми данными."""
    from seed_test_data import create_test_data
    print("Заполнение тестовыми данными...")
    await create_test_data()
    print("\nГотово.")


def main():
    print("=" * 60)
    print("Пересоздание базы данных и тестовые данные")
    print("=" * 60)

    drop_and_recreate_schema()
    create_tables_from_models()
    asyncio.run(run_seed())

    print("=" * 60)
    print("База данных пересоздана и заполнена.")
    print("=" * 60)


if __name__ == "__main__":
    main()
