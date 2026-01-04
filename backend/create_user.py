"""
Утилита для создания пользователя через командную строку
Использование: python create_user.py <username> <email> <password> <full_name> [role] [branch_id]
"""
import asyncio
import sys
from app.database import AsyncSessionLocal
from app.models.user import User
from app.core.security import get_password_hash
from sqlalchemy import select

async def create_user(username: str, email: str, password: str, full_name: str, role: str = "engineer", branch_id: int = None):
    """Создание пользователя"""
    async with AsyncSessionLocal() as db:
        try:
            # Проверка на существование пользователя
            existing_user = await db.execute(select(User).where(User.username == username))
            if existing_user.scalar_one_or_none():
                print(f"❌ Пользователь с именем '{username}' уже существует")
                return False
            
            existing_email = await db.execute(select(User).where(User.email == email))
            if existing_email.scalar_one_or_none():
                print(f"❌ Пользователь с email '{email}' уже существует")
                return False
            
            # Создание нового пользователя
            hashed_password = get_password_hash(password)
            db_user = User(
                username=username,
                email=email,
                last_name=full_name,
                hashed_password=hashed_password,
                role=role,
                branch_id=branch_id
            )
            
            db.add(db_user)
            await db.commit()
            await db.refresh(db_user)
            
            print(f"✅ Пользователь '{username}' успешно создан!")
            print(f"   ID: {db_user.id}")
            print(f"   Email: {db_user.email}")
            print(f"   Роль: {db_user.role}")
            return True
            
        except Exception as e:
            print(f"❌ Ошибка при создании пользователя: {e}")
            await db.rollback()
            return False

async def main():
    if len(sys.argv) < 5:
        print("Использование: python create_user.py <username> <email> <password> <full_name> [role] [branch_id]")
        print("Пример: python create_user.py admin admin@example.com password123 'Администратор' admin")
        sys.exit(1)
    
    username = sys.argv[1]
    email = sys.argv[2]
    password = sys.argv[3]
    full_name = sys.argv[4]
    role = sys.argv[5] if len(sys.argv) > 5 else "engineer"
    branch_id = int(sys.argv[6]) if len(sys.argv) > 6 and sys.argv[6].isdigit() else None
    
    success = await create_user(username, email, password, full_name, role, branch_id)
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    asyncio.run(main())
