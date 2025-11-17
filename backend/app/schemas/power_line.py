from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime

class TowerBase(BaseModel):
    tower_number: str
    latitude: float
    longitude: float
    tower_type: str
    height: Optional[float] = None
    foundation_type: Optional[str] = None
    material: Optional[str] = None
    year_installed: Optional[int] = None
    condition: str = "good"
    notes: Optional[str] = None

class TowerCreate(TowerBase):
    pass

class TowerResponse(TowerBase):
    id: int
    power_line_id: int
    created_by: int
    created_at: datetime
    updated_at: Optional[datetime]

    class Config:
        from_attributes = True

class PowerLineBase(BaseModel):
    name: str
    code: str
    voltage_level: float
    length: Optional[float] = None
    branch_id: int
    status: str = "active"
    description: Optional[str] = None

class PowerLineCreate(PowerLineBase):
    pass

class PowerLineResponse(PowerLineBase):
    id: int
    created_by: int
    created_at: datetime
    updated_at: Optional[datetime]
    towers: List[TowerResponse] = []

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
    notes: Optional[str] = None

class SpanCreate(SpanBase):
    power_line_id: int
    from_tower_id: int
    to_tower_id: int

class SpanResponse(SpanBase):
    id: int
    power_line_id: int
    from_tower_id: int
    to_tower_id: int
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
    power_line_id: int
    tower_id: int

class TapResponse(TapBase):
    id: int
    power_line_id: int
    tower_id: int
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
    tower_id: int

class EquipmentResponse(EquipmentBase):
    id: int
    tower_id: int
    created_by: int
    created_at: datetime
    updated_at: Optional[datetime]

    class Config:
        from_attributes = True
