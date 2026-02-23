"""
Однократное пересоздание БД: удаление всех таблиц и создание по текущим моделям.
Запуск: из каталога backend: python recreate_db.py
Требуется: PostgreSQL запущен, DATABASE_URL в .env или окружении.
"""
import asyncio
import os

# Включаем пересоздание перед импортом app
os.environ["RECREATE_DB"] = "1"

# Импортируем после установки RECREATE_DB
from app.database import init_db


async def main():
    await init_db()
    print("Готово. Таблицы пересозданы. Можно снять RECREATE_DB для следующих запусков.")


if __name__ == "__main__":
    asyncio.run(main())
