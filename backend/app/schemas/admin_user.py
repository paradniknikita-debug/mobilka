from __future__ import annotations

from typing import Optional

from pydantic import BaseModel, EmailStr, Field, field_validator

from app.core.roles import CANONICAL_ROLES, normalize_role
from app.schemas.user import UserResponse


class AdminUserResponse(UserResponse):
    """Ответ админ-API: включает учётную копию пароля (если задавалась при создании/смене)."""

    password_plain: Optional[str] = None

    class Config:
        from_attributes = True


class AdminUserUpdate(BaseModel):
    full_name: Optional[str] = None
    email: Optional[EmailStr] = None
    role: Optional[str] = None
    is_active: Optional[bool] = None
    password: Optional[str] = Field(default=None, min_length=6, max_length=128)

    @field_validator("role")
    @classmethod
    def _role_ok(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return None
        n = normalize_role(v)
        if n not in CANONICAL_ROLES:
            raise ValueError(f"role must be one of {sorted(CANONICAL_ROLES)}")
        return n
