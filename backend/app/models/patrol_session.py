# Модель сессии обхода ЛЭП
from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base
from app.models.base import generate_mrid


class PatrolSession(Base):
    """Сессия обхода: пользователь, ЛЭП, время начала и окончания."""
    __tablename__ = "patrol_sessions"

    id = Column(Integer, primary_key=True, index=True)
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    line_id = Column(Integer, ForeignKey("line.id"), nullable=False)
    note = Column(Text, nullable=True)
    started_at = Column(DateTime(timezone=True), server_default=func.now())
    ended_at = Column(DateTime(timezone=True), nullable=True)

    user = relationship("User", backref="patrol_sessions")
    power_line = relationship("PowerLine", back_populates="patrol_sessions")
