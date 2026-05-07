"""
Журнал изменений: действия пользователей с веб- и Flutter-клиентов.
Используется для отображения истории и в перспективе для отката (назад/вперёд).
"""
from sqlalchemy import Column, Integer, String, DateTime, Text, ForeignKey, Enum as SQLEnum
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.sql import func
from app.database import Base
import enum


class ChangeLogSource(str, enum.Enum):
    web = "web"
    flutter = "flutter"


class ChangeLogAction(str, enum.Enum):
    create = "create"
    update = "update"
    delete = "delete"
    session_start = "session_start"
    session_end = "session_end"


class ChangeLog(Base):
    __tablename__ = "change_log"

    id = Column(Integer, primary_key=True, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    # Кто выполнил (может быть NULL для session_* от Flutter до авторизации)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)

    # Источник события: веб или Flutter
    source = Column(String(20), nullable=False)  # 'web' | 'flutter'

    # Тип действия
    action = Column(String(30), nullable=False)  # create | update | delete | session_start | session_end

    # Тип сущности: pole, power_line, span, substation, equipment, acline_segment, line_section, ...
    entity_type = Column(String(50), nullable=False)

    # ID сущности (для session_* может быть NULL)
    entity_id = Column(Integer, nullable=True)

    # Дополнительные данные (название, старые/новые значения и т.д.)
    payload = Column(JSONB, nullable=True)

    # Идентификатор сессии Flutter (для связки session_start / session_end)
    session_id = Column(String(100), nullable=True)
