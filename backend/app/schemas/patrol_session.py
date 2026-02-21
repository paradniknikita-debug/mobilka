from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class PatrolSessionCreate(BaseModel):
    power_line_id: int
    note: Optional[str] = None


class PatrolSessionUpdate(BaseModel):
    ended_at: Optional[datetime] = None


class PatrolSessionResponse(BaseModel):
    id: int
    user_id: int
    power_line_id: int
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
