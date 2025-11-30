"""
Скрипт для обновления пароля администратора
"""
import asyncio
import sys
import os

sys.path.insert(0, os.path.dirname(__file__))

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import AsyncSessionLocal, init_db
from app.models.user import User
from app.core.security import get_password_hash, verify_password


async def update_admin_password():
    """Обновление пароля администратора на admin_123456"""
    await init_db()
    
    async with AsyncSessionLocal() as session:
        try:
            result = await session.execute(
                select(User).where(User.username == "admin")
            )
            user = result.scalar_one_or_none()
            
            if user:
                # Обновляем пароль
                user.hashed_password = get_password_hash("admin_123456")
                await session.commit()
                
                # Проверяем пароль
                result2 = await session.execute(
                    select(User).where(User.username == "admin")
                )
                user2 = result2.scalar_one_or_none()
                if user2 and verify_password("admin_123456", user2.hashed_password):
                    print("✅ Пароль успешно обновлен и проверен!")
                    print(f"   Логин: admin")
                    print(f"   Пароль: admin_123456")
                else:
                    print("❌ Ошибка: пароль не прошел проверку")
            else:
                # Создаем пользователя
                user = User(
                    username="admin",
                    email="admin@lepm.local",
                    full_name="Администратор",
                    hashed_password=get_password_hash("admin_123456"),
                    is_active=True,
                    is_superuser=True,
                    role="admin"
                )
                session.add(user)
                await session.commit()
                print("✅ Создан новый пользователь admin/admin_123456")
            
        except Exception as e:
            await session.rollback()
            print(f"❌ Ошибка: {e}")
            raise


if __name__ == "__main__":
    asyncio.run(update_admin_password())

