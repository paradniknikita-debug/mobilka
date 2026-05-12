"""
Роли пользователей: администратор, паспортист, инженер-обходчик.

Строки в БД: admin, passport_clerk, field_engineer.
Поддерживаются устаревшие значения engineer / dispatcher для обратной совместимости.
"""

from __future__ import annotations

from fastapi import Depends, HTTPException, status

from app.core.security import get_current_active_user
from app.models.user import User

ROLE_ADMIN = "admin"
ROLE_PASSPORT_CLERK = "passport_clerk"
ROLE_FIELD_ENGINEER = "field_engineer"

CANONICAL_ROLES = frozenset({ROLE_ADMIN, ROLE_PASSPORT_CLERK, ROLE_FIELD_ENGINEER})

LEGACY_ROLE_MAP = {
    "admin": ROLE_ADMIN,
    "dispatcher": ROLE_PASSPORT_CLERK,
    "passport_clerk": ROLE_PASSPORT_CLERK,
    "engineer": ROLE_FIELD_ENGINEER,
    "field_engineer": ROLE_FIELD_ENGINEER,
}


def normalize_role(role: str | None) -> str:
    if role is None or not str(role).strip():
        return ROLE_FIELD_ENGINEER
    key = str(role).strip().lower()
    if key in LEGACY_ROLE_MAP:
        return LEGACY_ROLE_MAP[key]
    if key in CANONICAL_ROLES:
        return key
    return ROLE_FIELD_ENGINEER


def is_admin(user: User) -> bool:
    return bool(user.is_superuser) or normalize_role(user.role) == ROLE_ADMIN


def can_export(user: User) -> bool:
    if user.is_superuser:
        return True
    return normalize_role(user.role) in (ROLE_ADMIN, ROLE_PASSPORT_CLERK)


def can_manage_equipment_catalog(user: User) -> bool:
    """Создание/изменение марок в справочнике оборудования и марок проводов."""
    return can_export(user)


async def require_admin_user(current_user: User = Depends(get_current_active_user)) -> User:
    if is_admin(current_user):
        return current_user
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Требуется роль администратора",
    )


async def require_user_can_export(current_user: User = Depends(get_current_active_user)) -> User:
    if can_export(current_user):
        return current_user
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Недостаточно прав для выгрузок и отчётов",
    )


async def require_catalog_manager(current_user: User = Depends(get_current_active_user)) -> User:
    if can_manage_equipment_catalog(current_user):
        return current_user
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Недостаточно прав для изменения справочников",
    )
