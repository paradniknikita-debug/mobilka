#!/usr/bin/env python3
"""
Создание пользователя admin (login: admin, password: admin_123456) в БД.
Использование: python scripts/create_admin_user.py
Или в Docker: docker compose exec backend python scripts/create_admin_user.py
"""
import asyncio
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import select
from app.database import AsyncSessionLocal, init_db
from app.core.security import get_password_hash
from app.models.user import User


async def create_admin_user():
    await init_db()
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
            print("Пользователь admin обновлён: пароль установлен на admin_123456")
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
            print("Создан пользователь: login=admin, password=admin_123456")


if __name__ == "__main__":
    asyncio.run(create_admin_user())
