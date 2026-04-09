#!/usr/bin/env python3
"""
Быстрое создание пользователя без SQL/ручной работы с БД.

Примеры:
  python scripts/create_user.py --username ivan --password qwerty123 --role engineer
  python scripts/create_user.py --username disp1 --email disp1@company.local --role dispatcher --active
  python scripts/create_user.py --username admin2 --password secret --role admin --superuser

Если не передать часть аргументов, скрипт запросит их интерактивно.
"""

import argparse
import asyncio
import getpass
import os
import re
import sys

from sqlalchemy import or_, select

# Корень backend (чтобы "from app..." работал при запуске из scripts/)
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.security import get_password_hash
from app.database import AsyncSessionLocal, init_db
from app.models.user import User


ALLOWED_ROLES = ("engineer", "dispatcher", "admin")


def _non_empty(value: str | None) -> str | None:
    if value is None:
        return None
    text = value.strip()
    return text if text else None


def _is_valid_email(email: str) -> bool:
    return re.match(r"^[^@\s]+@[^@\s]+\.[^@\s]+$", email) is not None


def _prompt_required(prompt: str, default: str | None = None) -> str:
    while True:
        suffix = f" [{default}]" if default else ""
        value = input(f"{prompt}{suffix}: ").strip()
        if value:
            return value
        if default:
            return default
        print("Значение обязательно.")


def _prompt_password() -> str:
    while True:
        p1 = getpass.getpass("Пароль: ").strip()
        if len(p1) < 6:
            print("Пароль должен быть не короче 6 символов.")
            continue
        p2 = getpass.getpass("Повторите пароль: ").strip()
        if p1 != p2:
            print("Пароли не совпадают.")
            continue
        return p1


def _prompt_role(default: str = "engineer") -> str:
    while True:
        role = input(f"Роль [{default}] (engineer/dispatcher/admin): ").strip() or default
        if role in ALLOWED_ROLES:
            return role
        print(f"Недопустимая роль: {role}. Разрешено: {', '.join(ALLOWED_ROLES)}")


def _derive_email(username: str) -> str:
    return f"{username}@example.com"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Создать пользователя в БД (без SQL).",
    )
    parser.add_argument("--username", help="Логин пользователя")
    parser.add_argument("--email", help="Email пользователя")
    parser.add_argument("--full-name", dest="full_name", help="Полное имя")
    parser.add_argument("--password", help="Пароль (если не указан — будет интерактивный ввод)")
    parser.add_argument(
        "--role",
        choices=ALLOWED_ROLES,
        default=None,
        help="Роль пользователя",
    )
    parser.add_argument("--branch-id", dest="branch_id", type=int, default=None, help="ID филиала (опционально)")
    parser.add_argument("--active", dest="is_active", action="store_true", help="Сделать пользователя активным")
    parser.add_argument("--inactive", dest="is_active", action="store_false", help="Сделать пользователя неактивным")
    parser.set_defaults(is_active=True)
    parser.add_argument("--superuser", action="store_true", help="Выдать права superuser")
    parser.add_argument(
        "--update-if-exists",
        action="store_true",
        help="Если пользователь уже есть, обновить его поля вместо ошибки",
    )
    return parser.parse_args()


async def main() -> None:
    args = parse_args()

    username = _non_empty(args.username) or _prompt_required("Логин")
    email = _non_empty(args.email)
    if not email:
        suggested = _derive_email(username)
        email = _prompt_required("Email", suggested)
    if not _is_valid_email(email):
        raise ValueError(f"Некорректный email: {email}")

    full_name = _non_empty(args.full_name) or _prompt_required("ФИО", username)
    role = args.role or _prompt_role("engineer")
    password = _non_empty(args.password) or _prompt_password()
    if len(password) < 6:
        raise ValueError("Пароль должен быть не короче 6 символов.")

    await init_db()

    async with AsyncSessionLocal() as session:
        existing_result = await session.execute(
            select(User).where(or_(User.username == username, User.email == email))
        )
        existing = existing_result.scalars().first()

        if existing and not args.update_if_exists:
            if existing.username == username:
                raise ValueError(
                    f"Пользователь с логином '{username}' уже существует. "
                    f"Используйте --update-if-exists для обновления."
                )
            raise ValueError(
                f"Пользователь с email '{email}' уже существует. "
                f"Используйте другой email или --update-if-exists."
            )

        if existing and args.update_if_exists:
            existing.username = username
            existing.email = email
            existing.full_name = full_name
            existing.hashed_password = get_password_hash(password)
            existing.role = role
            existing.branch_id = args.branch_id
            existing.is_active = bool(args.is_active)
            existing.is_superuser = bool(args.superuser)
            await session.commit()
            print(
                f"Пользователь обновлён: id={existing.id}, username={existing.username}, "
                f"role={existing.role}, active={existing.is_active}, superuser={existing.is_superuser}"
            )
            return

        user = User(
            username=username,
            email=email,
            full_name=full_name,
            hashed_password=get_password_hash(password),
            is_active=bool(args.is_active),
            is_superuser=bool(args.superuser),
            role=role,
            branch_id=args.branch_id,
        )
        session.add(user)
        await session.commit()
        await session.refresh(user)
        print(
            f"Пользователь создан: id={user.id}, username={user.username}, "
            f"role={user.role}, active={user.is_active}, superuser={user.is_superuser}"
        )


if __name__ == "__main__":
    asyncio.run(main())
