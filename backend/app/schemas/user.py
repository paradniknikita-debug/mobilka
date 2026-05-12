from pydantic import BaseModel, EmailStr, field_validator
from typing import Optional
from datetime import datetime

from app.core.roles import CANONICAL_ROLES, LEGACY_ROLE_MAP, ROLE_FIELD_ENGINEER


class UserBase(BaseModel):
    username: str
    email: EmailStr
    full_name: str
    role: str = "field_engineer"

    @field_validator("role", mode="before")
    @classmethod
    def _coerce_role(cls, v: object) -> str:
        """Нормализует роль; неизвестные значения на входе — ошибка валидации."""
        if v is None or (isinstance(v, str) and not str(v).strip()):
            return ROLE_FIELD_ENGINEER
        key = str(v).strip().lower()
        if key in LEGACY_ROLE_MAP:
            return LEGACY_ROLE_MAP[key]
        if key in CANONICAL_ROLES:
            return key
        raise ValueError(
            f"Неизвестная роль. Допустимо: {', '.join(sorted(CANONICAL_ROLES))} "
            f"или устаревшие: {', '.join(sorted(LEGACY_ROLE_MAP.keys()))}"
        )

class UserCreate(UserBase):
    password: str
    branch_id: Optional[int] = None

class UserLogin(BaseModel):
    username: str
    password: str

class UserResponse(UserBase):
    id: int
    is_active: bool
    is_superuser: bool
    branch_id: Optional[int]
    created_at: datetime
    updated_at: Optional[datetime]

    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    token_type: str


