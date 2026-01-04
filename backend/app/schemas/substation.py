from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from datetime import datetime

class SubstationBase(BaseModel):
    name: str
    code: str
    voltage_level: float
    latitude: float
    longitude: float
    address: Optional[str] = None
    branch_id: int
    description: Optional[str] = None

class SubstationCreate(SubstationBase):
    pass

class SubstationResponse(SubstationBase):
    id: int
    is_active: bool
    created_at: datetime
    updated_at: Optional[datetime]

    class Config:
        from_attributes = True

class ConnectionBase(BaseModel):
    substation_id: int
    power_line_id: int
    connection_type: str
    voltage_level: float
    description: Optional[str] = None

class ConnectionCreate(ConnectionBase):
    pass

class ConnectionResponse(ConnectionBase):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True


# Схемы для VoltageLevel
class VoltageLevelBase(BaseModel):
    name: str
    code: str
    nominal_voltage: float  # кВ
    high_voltage_limit: Optional[float] = None  # кВ
    low_voltage_limit: Optional[float] = None  # кВ
    description: Optional[str] = None

class VoltageLevelCreate(VoltageLevelBase):
    mrid: Optional[str] = None

class VoltageLevelResponse(VoltageLevelBase):
    id: int
    mrid: str
    substation_id: int
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


# Схемы для Bay
class BayBase(BaseModel):
    name: str
    bay_number: str
    bay_type: str  # ввод, отходящая линия, секционный, трансформатор
    description: Optional[str] = None

class BayCreate(BayBase):
    mrid: Optional[str] = None

class BayResponse(BayBase):
    id: int
    mrid: str
    voltage_level_id: int
    created_at: datetime

    class Config:
        from_attributes = True


# Схемы для BusbarSection
class BusbarSectionBase(BaseModel):
    name: str
    section_number: int  # Номер секции (I, II, III)
    nominal_current: Optional[float] = None  # А
    description: Optional[str] = None

class BusbarSectionCreate(BusbarSectionBase):
    mrid: Optional[str] = None

class BusbarSectionResponse(BusbarSectionBase):
    id: int
    mrid: str
    bay_id: int
    created_at: datetime

    class Config:
        from_attributes = True


# Схемы для ConductingEquipment
class ConductingEquipmentBase(BaseModel):
    equipment_type: str  # CIM класс: PowerTransformer, Breaker, Disconnector и т.д.
    name: str
    manufacturer: Optional[str] = None
    model: Optional[str] = None
    serial_number: Optional[str] = None
    specifications: Optional[Dict[str, Any]] = None  # JSON с характеристиками
    installation_date: Optional[datetime] = None
    last_maintenance_date: Optional[datetime] = None
    next_maintenance_date: Optional[datetime] = None
    status: str = "active"  # active, maintenance, decommissioned
    notes: Optional[str] = None

class ConductingEquipmentCreate(ConductingEquipmentBase):
    mrid: Optional[str] = None

class ConductingEquipmentResponse(ConductingEquipmentBase):
    id: int
    mrid: str
    bay_id: int
    created_by: int
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


# Схемы для ProtectionEquipment
class ProtectionEquipmentBase(BaseModel):
    name: str
    protection_type: str  # реле, автомат защиты, УЗО
    manufacturer: Optional[str] = None
    model: Optional[str] = None
    serial_number: Optional[str] = None
    specifications: Optional[Dict[str, Any]] = None  # уставки, ток срабатывания и т.д.
    installation_date: Optional[datetime] = None
    status: str = "active"
    notes: Optional[str] = None

class ProtectionEquipmentCreate(ProtectionEquipmentBase):
    mrid: Optional[str] = None

class ProtectionEquipmentResponse(ProtectionEquipmentBase):
    id: int
    mrid: str
    bay_id: int
    created_by: int
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


# Обновленная схема SubstationResponse с voltage_levels
class SubstationResponseWithStructure(SubstationResponse):
    voltage_levels: List[VoltageLevelResponse] = []

    class Config:
        from_attributes = True
