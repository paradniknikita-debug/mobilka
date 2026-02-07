"""
Модель для BaseVoltage согласно CIM стандарту IEC 61970-301
BaseVoltage - базовый уровень напряжения
Соответствует CIM классу: cim:BaseVoltage
"""
from sqlalchemy import Column, Integer, String, Float, DateTime, Text
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base
from app.models.base import generate_mrid


class BaseVoltage(Base):
    """
    BaseVoltage - базовый уровень напряжения
    Соответствует CIM классу: cim:BaseVoltage
    
    BaseVoltage определяет номинальное напряжение, которое используется
    для классификации оборудования и линий электропередачи.
    Например: 0.4 кВ, 10 кВ, 35 кВ, 110 кВ, 220 кВ, 330 кВ, 500 кВ, 750 кВ
    """
    __tablename__ = "base_voltages"

    id = Column(Integer, primary_key=True, index=True)
    # mRID (Master Resource Identifier) по стандарту IEC 61970-552:2016
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    
    # Номинальное напряжение в киловольтах (кВ)
    nominal_voltage = Column(Float, nullable=False, unique=True)
    
    # Название уровня напряжения (например, "Низкое", "Среднее", "Высокое")
    name = Column(String(100), nullable=False)
    
    # Код уровня напряжения (например, "LV", "MV", "HV", "EHV")
    code = Column(String(20), unique=True, index=True, nullable=True)
    
    # Описание
    description = Column(Text, nullable=True)
    
    # Временные метки
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Связи - временно закомментировано до применения миграции
    # VoltageLevel использует BaseVoltage
    # voltage_levels = relationship("VoltageLevel", back_populates="base_voltage")
    
    # PowerLine может ссылаться на BaseVoltage (опционально, для обратной совместимости)
    # power_lines = relationship("PowerLine", back_populates="base_voltage")

