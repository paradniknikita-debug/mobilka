#!/usr/bin/env python3
"""
Скрипт для создания SQL запроса для добавления пользователя в БД
Использование: python create_user.py

Требования:
    pip install passlib[argon2]
    или
    pip install -r requirements.txt
"""

import sys
import os

# Добавляем путь к backend для импорта
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from passlib.context import CryptContext
except ImportError:
    print("Ошибка: модуль passlib не установлен!")
    print("Установите его командой: pip install passlib[argon2]")
    print("Или установите все зависимости: pip install -r requirements.txt")
    sys.exit(1)

# Настройка хеширования паролей (должно совпадать с backend/app/core/security.py)
pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")

def get_password_hash(password: str) -> str:
    """Хеширование пароля"""
    return pwd_context.hash(password)

def generate_user_sql(username: str, email: str, password: str, 
                     full_name: str = None, role: str = "admin", 
                     branch_id: int = None, is_superuser: bool = True):
    """
    Генерирует SQL запрос для создания пользователя
    
    Args:
        username: Имя пользователя
        email: Email пользователя
        password: Пароль (будет захеширован)
        full_name: Полное имя (если None, будет равно username)
        role: Роль (engineer, dispatcher, admin)
        branch_id: ID филиала (может быть NULL)
        is_superuser: Является ли суперпользователем
    """
    hashed_password = get_password_hash(password)
    
    if full_name is None:
        full_name = username
    
    # SQL запрос
    sql = f"""
-- Создание пользователя: {username}
INSERT INTO users (username, email, full_name, hashed_password, role, is_active, is_superuser, branch_id, created_at, updated_at)
VALUES (
    '{username}',
    '{email}',
    '{full_name}',
    '{hashed_password}',
    '{role}',
    true,
    {str(is_superuser).lower()},
    {f'{branch_id}' if branch_id is not None else 'NULL'},
    NOW(),
    NOW()
);
"""
    
    return sql

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Генератор SQL запроса для создания пользователя')
    parser.add_argument('--username', '-u', default=None, help='Имя пользователя (по умолчанию: admin)')
    parser.add_argument('--email', '-e', default=None, help='Email (по умолчанию: admin@example.com)')
    parser.add_argument('--password', '-p', default=None, help='Пароль (если не указан, будет интерактивный режим)')
    parser.add_argument('--full-name', '-n', default=None, help='Полное имя (по умолчанию: равно username)')
    parser.add_argument('--role', '-r', default='admin', choices=['engineer', 'dispatcher', 'admin'], 
                       help='Роль (по умолчанию: admin)')
    parser.add_argument('--branch-id', '-b', type=int, default=None, help='ID филиала (по умолчанию: NULL)')
    parser.add_argument('--superuser', '-s', action='store_true', default=True, help='Суперпользователь (по умолчанию: да)')
    parser.add_argument('--no-superuser', action='store_false', dest='superuser', help='Не суперпользователь')
    parser.add_argument('--interactive', '-i', action='store_true', help='Интерактивный режим')
    
    args = parser.parse_args()
    
    # Если пароль не указан, автоматически переходим в интерактивный режим
    # Или если явно указан флаг --interactive
    if args.interactive or args.password is None:
        print("=" * 60)
        print("Генератор SQL запроса для создания пользователя")
        print("=" * 60)
        print()
        
        try:
            username = input("Введите имя пользователя (или нажмите Enter для 'admin'): ").strip() or "admin"
            email = input("Введите email (или нажмите Enter для 'admin@example.com'): ").strip() or "admin@example.com"
            password = input("Введите пароль: ").strip()
            
            if not password:
                print("Ошибка: пароль не может быть пустым!")
                exit(1)
            
            full_name = input("Введите полное имя (или нажмите Enter для использования username): ").strip() or None
            role = input("Введите роль (engineer/dispatcher/admin, по умолчанию 'admin'): ").strip() or "admin"
            branch_id_input = input("Введите ID филиала (или нажмите Enter для NULL): ").strip()
            branch_id = int(branch_id_input) if branch_id_input else None
            is_superuser_input = input("Суперпользователь? (y/n, по умолчанию 'y'): ").strip().lower()
            is_superuser = is_superuser_input != 'n'
        except (EOFError, KeyboardInterrupt):
            print("\nОтменено пользователем")
            exit(0)
    else:
        # Режим с аргументами
        username = args.username or "admin"
        email = args.email or "admin@example.com"
        password = args.password
        full_name = args.full_name
        role = args.role
        branch_id = args.branch_id
        is_superuser = args.superuser
        
        if not password:
            print("Ошибка: пароль не может быть пустым!")
            print("Используйте --password или запустите в интерактивном режиме (--interactive)")
            exit(1)
    
    print()
    print("=" * 60)
    print("SQL запрос:")
    print("=" * 60)
    print()
    
    sql = generate_user_sql(
        username=username,
        email=email,
        password=password,
        full_name=full_name,
        role=role,
        branch_id=branch_id,
        is_superuser=is_superuser
    )
    
    print(sql)
    print()
    print("=" * 60)
    print("Инструкция:")
    print("=" * 60)
    print("1. Скопируйте SQL запрос выше")
    print("2. Подключитесь к базе данных PostgreSQL:")
    print("   docker exec -it lepm_postgres psql -U <ваш_пользователь> -d <ваша_база>")
    print("3. Вставьте и выполните SQL запрос")
    print()
    print("Или выполните напрямую:")
    print(f"docker exec -i lepm_postgres psql -U <ваш_пользователь> -d <ваша_база> << 'EOF'")
    print(sql.strip())
    print("EOF")

