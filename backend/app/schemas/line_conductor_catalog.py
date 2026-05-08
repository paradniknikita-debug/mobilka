from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class LineConductorCatalogCreate(BaseModel):
    mark: str
    voltage_kv: float
    is_active: bool = True


class LineConductorCatalogResponse(BaseModel):
    id: int
    mark: str
    voltage_kv: float
    is_active: bool
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True
