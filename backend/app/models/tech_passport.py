"""Сохранённые технические паспорта объектов (ЛЭП, опора, ПС) для паспортизации по СТП."""

from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import relationship

from app.database import Base
from app.models.base import generate_mrid


class TechPassport(Base):
    __tablename__ = "tech_passport"

    id = Column(Integer, primary_key=True, index=True)
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    title = Column(String(500), nullable=False)
    object_type = Column(String(40), nullable=False, index=True)  # power_line | pole | substation
    object_mrid = Column(String(36), nullable=False, index=True)
    object_id = Column(Integer, nullable=True, index=True)
    # Полный снимок данных на момент формирования (JSON)
    snapshot_json = Column(JSONB, nullable=False)
    # Дополнения вручную: произвольные поля / текстовые блоки
    manual_sections = Column(JSONB, nullable=True)
    stp_reference = Column(String(500), nullable=True)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    creator = relationship("User", lazy="selectin")
