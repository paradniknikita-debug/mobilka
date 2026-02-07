"""
Схемы для Location и PositionPoint согласно CIM стандарту
"""
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from app.models.location import LocationType


class PositionPointBase(BaseModel):
    """Базовая схема для PositionPoint"""
    x_position: float  # Долгота (longitude)
    y_position: float  # Широта (latitude)
    z_position: Optional[float] = None  # Высота (altitude)
    sequence_number: Optional[int] = 1
    description: Optional[str] = None


class PositionPointCreate(PositionPointBase):
    """Схема для создания PositionPoint"""
    pass


class PositionPointResponse(PositionPointBase):
    """Схема ответа для PositionPoint"""
    id: int
    mrid: str
    location_id: int
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class LocationBase(BaseModel):
    """Базовая схема для Location"""
    location_type: LocationType = LocationType.POINT
    address: Optional[str] = None
    description: Optional[str] = None


class LocationCreate(LocationBase):
    """Схема для создания Location"""
    # Координаты для автоматического создания PositionPoint
    latitude: Optional[float] = None  # Широта (будет сохранена как y_position)
    longitude: Optional[float] = None  # Долгота (будет сохранена как x_position)
    altitude: Optional[float] = None  # Высота (будет сохранена как z_position)
    position_points: Optional[List[PositionPointCreate]] = None  # Для множественных точек


class LocationResponse(LocationBase):
    """Схема ответа для Location"""
    id: int
    mrid: str
    position_points: List[PositionPointResponse] = []
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True

