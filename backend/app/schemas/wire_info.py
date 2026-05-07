"""
Схемы для WireInfo согласно CIM стандарту
"""
from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class WireInfoBase(BaseModel):
    """Базовая схема для WireInfo"""
    name: str  # Марка провода (AC-70, AC-95 и т.д.)
    code: Optional[str] = None
    material: str  # алюминий, медь, сталь
    section: float  # мм²
    number_of_strands: Optional[int] = 1
    diameter: Optional[float] = None  # мм
    # Электрические параметры
    r: Optional[float] = None  # Ом/км
    x: Optional[float] = None  # Ом/км
    b: Optional[float] = None  # См/км
    g: Optional[float] = None  # См/км
    # Механические характеристики
    breaking_load: Optional[float] = None  # Н
    weight_per_length: Optional[float] = None  # кг/км
    max_operating_temperature: Optional[float] = 70.0  # °C
    nominal_current: Optional[float] = None  # А
    description: Optional[str] = None
    is_active: bool = True


class WireInfoCreate(WireInfoBase):
    """Схема для создания WireInfo"""
    mrid: Optional[str] = None


class WireInfoResponse(WireInfoBase):
    """Схема ответа для WireInfo"""
    id: int
    mrid: str
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True

