from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class EquipmentCatalogBase(BaseModel):
    type_code: str = Field(..., description="Системный тип: disconnector, breaker, zn, arrester, recloser, ...")
    brand: str
    model: str
    full_name: Optional[str] = None
    voltage_kv: Optional[float] = None
    current_a: Optional[float] = None
    manufacturer: Optional[str] = None
    country: Optional[str] = None
    description: Optional[str] = None
    attrs_json: Optional[str] = None
    is_active: bool = True


class EquipmentCatalogCreate(EquipmentCatalogBase):
    pass


class EquipmentCatalogUpdate(BaseModel):
    type_code: Optional[str] = None
    brand: Optional[str] = None
    model: Optional[str] = None
    full_name: Optional[str] = None
    voltage_kv: Optional[float] = None
    current_a: Optional[float] = None
    manufacturer: Optional[str] = None
    country: Optional[str] = None
    description: Optional[str] = None
    attrs_json: Optional[str] = None
    is_active: Optional[bool] = None


class EquipmentCatalogResponse(EquipmentCatalogBase):
    id: int
    created_by: Optional[int] = None
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True

