"""
Скрипт для исправления пароля администратора
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


async def fix_admin_password():
    """Исправление пароля администратора"""
    await init_db()
    
    async with AsyncSessionLocal() as session:
        try:
            result = await session.execute(
                select(User).where(User.username == "admin")
            )
            user = result.scalar_one_or_none()
            
            if user:
                # Обновляем пароль с правильным хешем
                new_hash = get_password_hash("admin_123456")
                user.hashed_password = new_hash
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
                    print(f"   Хеш: {user2.hashed_password[:50]}...")
                else:
                    print("❌ Ошибка: пароль не прошел проверку")
                    print(f"   Хеш в БД: {user2.hashed_password[:50]}...")
            else:
                print("❌ Пользователь 'admin' не найден")
            
        except Exception as e:
            await session.rollback()
            print(f"❌ Ошибка: {e}")
            import traceback
            traceback.print_exc()
            raise


if __name__ == "__main__":
    print("🔧 Исправление пароля администратора...")
    asyncio.run(fix_admin_password())
    print("\n✅ Готово!")

