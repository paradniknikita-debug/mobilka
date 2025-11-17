from pydantic import BaseModel
from typing import Optional
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
