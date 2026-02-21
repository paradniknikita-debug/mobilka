from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from .cim_line_structure import (
    ConnectivityNodeResponse, TerminalResponse, LineSectionResponse,
    AClineSegmentResponse, SpanResponse
)

class PoleBase(BaseModel):
    pole_number: str
    # Координаты согласно CIM стандарту (x_position = longitude, y_position = latitude)
    x_position: Optional[float] = None  # Долгота (longitude)
    y_position: Optional[float] = None  # Широта (latitude)
    pole_type: str
    height: Optional[float] = None
    foundation_type: Optional[str] = None
    material: Optional[str] = None
    year_installed: Optional[int] = None
    condition: str = "good"
    notes: Optional[str] = None
    sequence_number: Optional[int] = None
    conductor_type: Optional[str] = None
    conductor_material: Optional[str] = None
    conductor_section: Optional[str] = None

class PoleCreate(PoleBase):
    mrid: Optional[str] = None  # Опциональный UID, если не указан - генерируется автоматически
    is_tap: bool = False  # Является ли опора отпаечной (точкой отпайки)
    # Параметры кабеля для автоматического создания пролёта
    conductor_type: Optional[str] = None  # Марка провода (AC-70, AC-95 и т.д.)
    conductor_material: Optional[str] = None  # Материал (алюминий, медь)
    conductor_section: Optional[str] = None  # Сечение, мм²

class PoleResponse(PoleBase):
    id: int
    mrid: str
    line_id: int
    connectivity_node_id: Optional[int] = None
    sequence_number: Optional[int] = None
    is_tap_pole: bool = False
    conductor_type: Optional[str] = None
    conductor_material: Optional[str] = None
    conductor_section: Optional[str] = None
    created_by: int
    created_at: datetime
    updated_at: Optional[datetime]
    connectivity_node: Optional[ConnectivityNodeResponse] = None
    # Переопределяем координаты - всегда должны быть заполнены (не None) для Flutter
    x_position: float = 0.0  # Долгота (longitude) - значение по умолчанию
    y_position: float = 0.0  # Широта (latitude) - значение по умолчанию

    class Config:
        from_attributes = True
    

class PowerLineBase(BaseModel):
    name: str
    base_voltage_id: Optional[int] = None  # Связь с BaseVoltage (CIM)
    voltage_level: Optional[float] = None  # кВ (дублируется из BaseVoltage для обратной совместимости)
    length: Optional[float] = None
    branch_name: Optional[str] = None  # Административная принадлежность (текстовое поле)
    region_name: Optional[str] = None  # Географический регион (текстовое поле)
    status: str = "active"
    description: Optional[str] = None

class PowerLineCreate(PowerLineBase):
    mrid: Optional[str] = None  # Опциональный UID, если не указан - генерируется автоматически


class PowerLineUpdate(BaseModel):
    """Тело запроса на обновление ЛЭП (все поля опциональны)."""
    name: Optional[str] = None
    base_voltage_id: Optional[int] = None
    voltage_level: Optional[float] = None
    length: Optional[float] = None
    branch_name: Optional[str] = None
    region_name: Optional[str] = None
    status: Optional[str] = None
    description: Optional[str] = None


class PowerLineResponse(PowerLineBase):
    id: int
    code: str
    mrid: str
    created_by: int
    created_at: datetime
    updated_at: Optional[datetime]
    poles: List[PoleResponse] = []
    # CIM структура
    acline_segments: List[AClineSegmentResponse] = []

    class Config:
        from_attributes = True

class SpanBase(BaseModel):
    span_number: str
    length: float
    conductor_type: Optional[str] = None
    conductor_material: Optional[str] = None
    conductor_section: Optional[str] = None
    tension: Optional[float] = None
    sag: Optional[float] = None
    sequence_number: Optional[int] = None  # Порядковый номер пролёта в секции
    notes: Optional[str] = None

class SpanCreate(SpanBase):
    line_id: int
    from_pole_id: int
    to_pole_id: int

class SpanResponse(SpanBase):
    id: int
    line_id: int
    line_section_id: Optional[int] = None  # Связь с LineSection (CIM)
    from_pole_id: Optional[int] = None  # Для обратной совместимости
    to_pole_id: Optional[int] = None  # Для обратной совместимости
    from_connectivity_node_id: Optional[int] = None  # CIM структура
    to_connectivity_node_id: Optional[int] = None  # CIM структура
    created_by: int
    created_at: datetime

    class Config:
        from_attributes = True

class TapBase(BaseModel):
    tap_number: str
    tap_type: str
    voltage_level: float
    power_rating: Optional[float] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    description: Optional[str] = None

class TapCreate(TapBase):
    line_id: int
    pole_id: int

class TapResponse(TapBase):
    id: int
    line_id: int
    pole_id: int
    created_by: int
    created_at: datetime

    class Config:
        from_attributes = True

class EquipmentBase(BaseModel):
    equipment_type: str
    name: str
    manufacturer: Optional[str] = None
    model: Optional[str] = None
    serial_number: Optional[str] = None
    year_manufactured: Optional[int] = None
    installation_date: Optional[datetime] = None
    condition: str = "good"
    notes: Optional[str] = None

class EquipmentCreate(EquipmentBase):
    pole_id: int

class EquipmentResponse(EquipmentBase):
    id: int
    pole_id: int
    created_by: int
    created_at: datetime
    updated_at: Optional[datetime]

    class Config:
        from_attributes = True
