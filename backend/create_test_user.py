"""
Скрипт для создания тестового пользователя
Использование: python create_test_user.py
"""
import asyncio
import sys
import os

# Добавляем путь к проекту
sys.path.insert(0, os.path.dirname(__file__))

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import AsyncSessionLocal, init_db
from app.models.user import User
from app.core.security import get_password_hash


async def create_test_user():
    """Создание тестового пользователя admin/admin_123456"""
    await init_db()
    
    async with AsyncSessionLocal() as session:
        try:
            # Проверяем, существует ли пользователь
            result = await session.execute(
                select(User).where(User.username == "admin")
            )
            user = result.scalar_one_or_none()
            
            if user:
                print("ℹ️  Пользователь 'admin' уже существует")
                print(f"   ID: {user.id}")
                print(f"   Email: {user.email}")
                print(f"   Роль: {user.role}")
                # Обновляем пароль на случай, если он был изменен
                user.hashed_password = get_password_hash("admin_123456")
                await session.commit()
                print("✅ Пароль обновлен на 'admin_123456'")
            else:
                # Создаем нового пользователя
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
                print("✅ Создан тестовый пользователь:")
                print("   Логин: admin")
                print("   Пароль: admin_123456")
                print("   Email: admin@lepm.local")
                print("   Роль: admin (суперпользователь)")
            
        except Exception as e:
            await session.rollback()
            print(f"❌ Ошибка при создании пользователя: {e}")
            raise


if __name__ == "__main__":
    print("🔧 Создание тестового пользователя...")
    asyncio.run(create_test_user())
    print("\n✅ Готово!")

