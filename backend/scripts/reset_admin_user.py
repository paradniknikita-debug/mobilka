"""
Пересоздать пользователя admin: пароль admin_123456, роль admin.
БД не пересоздаётся, только обновление/создание пользователя.
Запуск из каталога backend: python scripts/reset_admin_user.py
"""
import asyncio
import sys
import os

# Корень приложения = родитель scripts
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import AsyncSessionLocal, engine
from app.models.user import User
from app.core.security import get_password_hash
from sqlalchemy import select


async def main():
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
    await engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
