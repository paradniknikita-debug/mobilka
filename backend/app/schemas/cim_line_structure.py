"""
Pydantic схемы для CIM-совместимой структуры линий электропередачи
"""
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


# ==================== ConnectivityNode ====================

class ConnectivityNodeBase(BaseModel):
    name: str
    x_position: float  # долгота (longitude)
    y_position: float  # широта (latitude)
    description: Optional[str] = None


class ConnectivityNodeCreate(ConnectivityNodeBase):
    pole_id: int
    mrid: Optional[str] = None


class ConnectivityNodeResponse(ConnectivityNodeBase):
    id: int
    mrid: str
    pole_id: int
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


# ==================== Terminal ====================

class TerminalBase(BaseModel):
    name: Optional[str] = None
    sequence_number: int = 1
    connection_direction: str  # 'from', 'to', 'both'
    description: Optional[str] = None


class TerminalCreate(TerminalBase):
    connectivity_node_id: Optional[int] = None
    acline_segment_id: Optional[int] = None
    conducting_equipment_id: Optional[int] = None
    bay_id: Optional[int] = None
    mrid: Optional[str] = None


class TerminalResponse(TerminalBase):
    id: int
    mrid: str
    connectivity_node_id: Optional[int] = None
    acline_segment_id: Optional[int] = None
    conducting_equipment_id: Optional[int] = None
    bay_id: Optional[int] = None
    created_at: datetime

    class Config:
        from_attributes = True


# ==================== LineSection ====================

class LineSectionBase(BaseModel):
    name: str
    conductor_type: str  # марка провода (AC-70, AC-95 и т.д.)
    conductor_material: Optional[str] = None  # материал (алюминий, медь)
    conductor_section: str  # сечение, мм²
    r: Optional[float] = None  # активное сопротивление, Ом/км
    x: Optional[float] = None  # реактивное сопротивление, Ом/км
    b: Optional[float] = None  # проводимость, См/км
    g: Optional[float] = None  # активная проводимость, См/км
    sequence_number: int = 1
    total_length: Optional[float] = None  # м
    description: Optional[str] = None


class LineSectionCreate(LineSectionBase):
    acline_segment_id: int
    mrid: Optional[str] = None


class LineSectionResponse(LineSectionBase):
    id: int
    mrid: str
    acline_segment_id: int
    created_by: int
    created_at: datetime
    updated_at: Optional[datetime] = None
    spans: List['SpanResponse'] = []  # Forward reference

    class Config:
        from_attributes = True


# ==================== AClineSegment (обновлённая) ====================

class AClineSegmentBase(BaseModel):
    name: str
    code: Optional[str] = None  # Генерируется автоматически, если не указан
    voltage_level: float  # кВ
    length: float  # км
    is_tap: bool = False
    tap_number: Optional[str] = None
    sequence_number: int = 1
    # Параметры по умолчанию (могут переопределяться в LineSection)
    conductor_type: Optional[str] = None
    conductor_material: Optional[str] = None
    conductor_section: Optional[str] = None
    r: Optional[float] = None
    x: Optional[float] = None
    b: Optional[float] = None
    g: Optional[float] = None
    description: Optional[str] = None


class AClineSegmentCreate(AClineSegmentBase):
    line_id: int
    from_connectivity_node_id: int
    to_connectivity_node_id: Optional[int] = None
    to_terminal_id: Optional[int] = None
    mrid: Optional[str] = None


class AClineSegmentResponse(AClineSegmentBase):
    id: int
    mrid: str
    line_id: int
    from_connectivity_node_id: int
    to_connectivity_node_id: Optional[int] = None
    to_terminal_id: Optional[int] = None
    created_by: int
    created_at: datetime
    updated_at: Optional[datetime] = None
    line_sections: List[LineSectionResponse] = []
    terminals: List[TerminalResponse] = []

    class Config:
        from_attributes = True


# ==================== Span (обновлённая) ====================

class SpanBase(BaseModel):
    span_number: str
    length: float  # м
    sequence_number: int = 1
    # Параметры пролёта (могут переопределять параметры секции)
    conductor_type: Optional[str] = None
    conductor_material: Optional[str] = None
    conductor_section: Optional[str] = None
    tension: Optional[float] = None  # Н
    sag: Optional[float] = None  # м
    notes: Optional[str] = None


class SpanCreate(SpanBase):
    line_section_id: int
    from_connectivity_node_id: int
    to_connectivity_node_id: int
    mrid: Optional[str] = None
    # Для обратной совместимости
    line_id: Optional[int] = None
    from_pole_id: Optional[int] = None
    to_pole_id: Optional[int] = None


class SpanResponse(SpanBase):
    id: int
    mrid: str
    line_section_id: int
    from_connectivity_node_id: int
    to_connectivity_node_id: int
    created_by: int
    created_at: datetime
    # Для обратной совместимости
    line_id: Optional[int] = None
    from_pole_id: Optional[int] = None
    to_pole_id: Optional[int] = None
    # Связанные объекты
    from_connectivity_node: Optional[ConnectivityNodeResponse] = None
    to_connectivity_node: Optional[ConnectivityNodeResponse] = None

    class Config:
        from_attributes = True

