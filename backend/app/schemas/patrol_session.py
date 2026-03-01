from pydantic import BaseModel, Field, AliasChoices, field_validator
from typing import Optional
from datetime import datetime


class PatrolSessionCreate(BaseModel):
    """Создание сессии обхода. Принимаем line_id (наша схема) или power_line_id/powerLineId (для совместимости)."""
    line_id: int = Field(
        ...,
        validation_alias=AliasChoices("line_id", "power_line_id", "powerLineId"),
        description="ID линии (ЛЭП) на сервере",
    )
    note: Optional[str] = None

    @field_validator("line_id", mode="before")
    @classmethod
    def coerce_line_id(cls, v: object) -> int:
        if v is None:
            raise ValueError("line_id обязателен")
        if isinstance(v, int):
            return v
        if isinstance(v, str) and v.isdigit():
            return int(v)
        if isinstance(v, float) and v.is_integer():
            return int(v)
        raise ValueError("line_id должен быть целым числом (ID ЛЭП на сервере)")


class PatrolSessionUpdate(BaseModel):
    ended_at: Optional[datetime] = None


class PatrolSessionResponse(BaseModel):
    id: int
    user_id: int
    line_id: int  # id линии (ЛЭП)
    note: Optional[str]
    started_at: datetime
    ended_at: Optional[datetime]

    class Config:
        from_attributes = True


class PatrolSessionWithNamesResponse(PatrolSessionResponse):
    """Ответ с именами пользователя и ЛЭП для списка обходов."""
    user_name: str = ""
    power_line_name: str = ""

    class Config:
        from_attributes = True
