"""
Однократное пересоздание БД: удаление всех таблиц и создание по текущим моделям, затем создание пользователя admin.
Запуск: из каталога backend: python recreate_db.py
Требуется: PostgreSQL запущен, DATABASE_URL в .env или окружении.
Пользователь: admin / admin_123456
"""
import asyncio
import os

# Включаем пересоздание перед импортом app
os.environ["RECREATE_DB"] = "1"

# Импортируем после установки RECREATE_DB
from app.database import init_db, AsyncSessionLocal
from app.models.user import User
from app.core.security import get_password_hash
from sqlalchemy import select


async def main():
    await init_db()
    print("Таблицы пересозданы.")

    async with AsyncSessionLocal() as session:
        result = await session.execute(select(User).where(User.username == "admin"))
        user = result.scalar_one_or_none()
        if user:
            user.hashed_password = get_password_hash("admin_123456")
            user.email = "admin@example.com"
            user.full_name = user.full_name or "Администратор"
            user.is_active = True
            user.is_superuser = True
            user.role = "admin"
            await session.commit()
            print("Пользователь admin обновлён: пароль admin_123456")
        else:
            user = User(
                username="admin",
                email="admin@example.com",
                full_name="Администратор",
                hashed_password=get_password_hash("admin_123456"),
                is_active=True,
                is_superuser=True,
                role="admin",
                branch_id=None,
            )
            session.add(user)
            await session.commit()
            print("Создан пользователь: admin / admin_123456")

    print("Готово. После следующего запуска снимите RECREATE_DB (или не задавайте его), чтобы не пересоздавать БД при старте.")


if __name__ == "__main__":
    asyncio.run(main())
