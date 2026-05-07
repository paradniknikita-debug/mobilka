from sqlalchemy import Column, Integer, String, Float, DateTime, Text, Boolean, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from app.database import Base


class EquipmentCatalogItem(Base):
    __tablename__ = "equipment_catalog"

    id = Column(Integer, primary_key=True, index=True)
    type_code = Column(String(50), nullable=False, index=True)  # disconnector, breaker, zn, arrester, recloser, ...
    brand = Column(String(100), nullable=False, index=True)  # РЛНД, ВВ/TEL, ОПН, ...
    model = Column(String(120), nullable=False, index=True)  # РЛНД-10/400, ...
    full_name = Column(String(255), nullable=True)
    voltage_kv = Column(Float, nullable=True)
    current_a = Column(Float, nullable=True)
    manufacturer = Column(String(120), nullable=True)
    country = Column(String(80), nullable=True)
    description = Column(Text, nullable=True)
    attrs_json = Column(Text, nullable=True)  # произвольные характеристики JSON-строкой
    is_active = Column(Boolean, nullable=False, default=True, server_default="true")
    created_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), onupdate=func.now(), nullable=True)

    equipment = relationship("Equipment", back_populates="catalog_item")

