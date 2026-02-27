"""Схемы для журнала изменений."""
from pydantic import BaseModel
from typing import Optional, Any, List
from datetime import datetime


class ChangeLogCreate(BaseModel):
    source: str  # 'web' | 'flutter'
    action: str  # create | update | delete | session_start | session_end
    entity_type: str  # pole, power_line, span, substation, equipment, ...
    entity_id: Optional[int] = None
    payload: Optional[dict] = None  # название, старые/новые значения и т.д.
    session_id: Optional[str] = None  # для связки session_start / session_end (Flutter)


class ChangeLogResponse(BaseModel):
    id: int
    created_at: datetime
    user_id: Optional[int] = None
    source: str
    action: str
    entity_type: str
    entity_id: Optional[int] = None
    payload: Optional[dict] = None
    session_id: Optional[str] = None

    class Config:
        from_attributes = True


class ModelIssueResponse(BaseModel):
    """Одна запись журнала несоответствий (ошибки модели данных)."""
    issue_type: str
    entity_type: str
    entity_id: Optional[int] = None
    line_id: Optional[int] = None
    message: str
    details: Optional[dict] = None
    entity_uid: Optional[str] = None
    line_uid: Optional[str] = None

    class Config:
        from_attributes = True
