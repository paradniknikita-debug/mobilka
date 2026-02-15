"""
Модель для географической иерархии регионов
Поддерживает рекурсивную структуру: Рабочие области → ФЭС → РЭС → ...
"""
from sqlalchemy import Column, Integer, String, DateTime, Text, Boolean, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base
from app.models.base import generate_mrid


class GeographicRegion(Base):
    __tablename__ = "geographic_regions"

    id = Column(Integer, primary_key=True, index=True)
    # mRID (Master Resource Identifier) по стандарту IEC 61970-552:2016
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    name = Column(String(100), nullable=False)
    code = Column(String(20), unique=True, index=True, nullable=False)
    region_type = Column(String(50), nullable=False)  # "рабочая_область", "ФЭС", "РЭС", и т.д.
    level = Column(Integer, nullable=False, default=0)  # 0=рабочая область, 1=ФЭС, 2=РЭС, ...
    parent_id = Column(Integer, ForeignKey("geographic_regions.id"), nullable=True)
    description = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Рекурсивная связь (самосвязь)
    parent = relationship("GeographicRegion", remote_side=[id], back_populates="children")
    children = relationship("GeographicRegion", back_populates="parent", cascade="all, delete-orphan")
    
    # Связи с объектами сети
    lines = relationship("PowerLine", back_populates="region")
    substations = relationship("Substation", back_populates="region")

