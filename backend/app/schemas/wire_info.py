"""
Схемы для WireInfo (справочник марок проводов).
"""
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class WireInfoBase(BaseModel):
    name: str = Field(..., description="Марка провода, напр. АС 70/11")
    code: Optional[str] = Field(None, description="Код / условное обозначение")
    material: str = Field("алюминий", description="Материал жилы")
    section: float = Field(..., description="Сечение, мм²")
    voltage_kv: Optional[float] = Field(None, description="Номинальное напряжение линии, кВ")
    number_of_strands: Optional[int] = 1
    diameter: Optional[float] = None
    r: Optional[float] = Field(None, description="Активное сопротивление, Ом/км")
    x: Optional[float] = Field(None, description="Реактивное сопротивление, Ом/км")
    b: Optional[float] = Field(None, description="Проводимость (ёмкостная), См/км")
    g: Optional[float] = Field(None, description="Активная проводимость, См/км")
    breaking_load: Optional[float] = None
    weight_per_length: Optional[float] = None
    max_operating_temperature: Optional[float] = 70.0
    nominal_current: Optional[float] = Field(None, description="Длительно допустимый ток, А")
    i_th: Optional[float] = Field(None, description="Ток термической стойкости, А")
    ip_max: Optional[float] = Field(None, description="Ударный ток, А")
    t_th: Optional[float] = Field(None, description="Время воздействия тока терм. стойкости, с")
    description: Optional[str] = None
    in_service: bool = True


class WireInfoCreate(WireInfoBase):
    mrid: Optional[str] = None


class WireInfoUpdate(BaseModel):
    name: Optional[str] = None
    code: Optional[str] = None
    material: Optional[str] = None
    section: Optional[float] = None
    voltage_kv: Optional[float] = None
    number_of_strands: Optional[int] = None
    diameter: Optional[float] = None
    r: Optional[float] = None
    x: Optional[float] = None
    b: Optional[float] = None
    g: Optional[float] = None
    breaking_load: Optional[float] = None
    weight_per_length: Optional[float] = None
    max_operating_temperature: Optional[float] = None
    nominal_current: Optional[float] = None
    i_th: Optional[float] = None
    ip_max: Optional[float] = None
    t_th: Optional[float] = None
    description: Optional[str] = None
    in_service: Optional[bool] = None


class WireInfoResponse(WireInfoBase):
    id: int
    mrid: str
    is_active: bool = True
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True
