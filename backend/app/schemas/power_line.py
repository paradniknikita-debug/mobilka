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
    branch_type: Optional[str] = None  # 'main' — магистраль, 'tap' — отпайка (для опор после отпаечной)
    tap_pole_id: Optional[int] = None   # id отпаечной опоры, от которой идёт эта ветка (для отпайки)
    tap_branch_index: Optional[int] = None  # Номер ветки от одной отпаечной (1, 2, …); при продолжении существующей отпайки
    start_new_tap: bool = False  # True = начать новую отпайку от tap_pole_id (вторая/третья ветка), False = продолжить текущую
    conductor_type: Optional[str] = None
    conductor_material: Optional[str] = None
    conductor_section: Optional[str] = None

class PoleResponse(PoleBase):
    id: int
    mrid: str
    line_id: int
    connectivity_node_id: Optional[int] = None
    sequence_number: Optional[int] = None
    is_tap_pole: bool = False
    branch_type: Optional[str] = None
    tap_pole_id: Optional[int] = None
    tap_branch_index: Optional[int] = None
    conductor_type: Optional[str] = None
    conductor_material: Optional[str] = None
    conductor_section: Optional[str] = None
    created_by: int
    created_at: datetime
    updated_at: Optional[datetime]
    connectivity_node: Optional[ConnectivityNodeResponse] = None
    # Оборудование, установленное на опоре
    equipment: List['EquipmentResponse'] = []
    # Переопределяем координаты - всегда должны быть заполнены (не None) для Flutter
    x_position: float = 0.0  # Долгота (longitude) - значение по умолчанию
    y_position: float = 0.0  # Широта (latitude) - значение по умолчанию
    equipment: List["EquipmentResponse"] = []

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
    substation_start_id: Optional[int] = None  # Подстанция в начале линии (пролёт ПС→первая опора)
    substation_end_id: Optional[int] = None    # Подстанция в конце линии (пролёт последняя опора→ПС)


class PowerLineResponse(PowerLineBase):
    id: int
    mrid: str
    created_by: int
    created_at: datetime
    updated_at: Optional[datetime]
    substation_start_id: Optional[int] = None
    substation_end_id: Optional[int] = None
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

class SpanUpdate(BaseModel):
    """Тело PUT для обновления пролёта — все поля опциональны."""
    span_number: Optional[str] = None
    length: Optional[float] = None
    conductor_type: Optional[str] = None
    conductor_material: Optional[str] = None
    conductor_section: Optional[str] = None
    tension: Optional[float] = None
    sag: Optional[float] = None
    sequence_number: Optional[int] = None
    notes: Optional[str] = None
    line_id: Optional[int] = None
    from_pole_id: Optional[int] = None
    to_pole_id: Optional[int] = None

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
    x_position: Optional[float] = None  # Долгота (CIM)
    y_position: Optional[float] = None  # Широта (CIM)
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
    x_position: Optional[float] = None
    y_position: Optional[float] = None

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

    # Координаты оборудования как отдельного объекта на карте
    # (CIM: x_position = longitude, y_position = latitude)
    x_position: Optional[float] = None  # Долгота
    y_position: Optional[float] = None  # Широта
    # Направление от опоры для отрисовки (градусы 0–360); задаёт, в какую сторону от опоры ставится участок до оборудования
    direction_angle: Optional[float] = None

class EquipmentCreate(EquipmentBase):
    # pole_id оставляем опциональным:
    # - для маршрута /poles/{pole_id}/equipment он берётся из URL и из тела игнорируется;
    # - для маршрута /equipment клиент может передавать pole_id в теле.
    pole_id: Optional[int] = None

class EquipmentResponse(EquipmentBase):
    id: int
    pole_id: int
    created_by: int
    created_at: datetime
    updated_at: Optional[datetime]

    class Config:
        from_attributes = True
