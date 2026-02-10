"""
Схемы для BaseVoltage согласно CIM стандарту
"""
from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class BaseVoltageBase(BaseModel):
    """Базовая схема для BaseVoltage"""
    nominal_voltage: float  # кВ
    name: str
    code: Optional[str] = None
    description: Optional[str] = None


class BaseVoltageCreate(BaseVoltageBase):
    """Схема для создания BaseVoltage"""
    mrid: Optional[str] = None


class BaseVoltageResponse(BaseVoltageBase):
    """Схема ответа для BaseVoltage"""
    id: int
    mrid: str
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True

