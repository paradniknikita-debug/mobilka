from sqlalchemy import Boolean, Column, DateTime, Float, Integer, String
from sqlalchemy.sql import func

from app.database import Base


class LineConductorCatalogItem(Base):
    __tablename__ = "line_conductor_catalog"

    id = Column(Integer, primary_key=True, index=True)
    mark = Column(String(120), nullable=False, index=True)
    voltage_kv = Column(Float, nullable=False, index=True)
    is_active = Column(Boolean, nullable=False, default=True, server_default="true")
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), onupdate=func.now(), nullable=True)
