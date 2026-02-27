"""
Модель для WireInfo согласно CIM стандарту IEC 61970-301
WireInfo - информация о проводе
Соответствует CIM классу: cim:WireInfo
"""
from sqlalchemy import Column, Integer, String, Float, DateTime, Text, Boolean
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base
from app.models.base import generate_mrid


class WireInfo(Base):
    """
    WireInfo - информация о проводе
    Соответствует CIM классу: cim:WireInfo
    
    WireInfo содержит характеристики провода:
    - Марка провода (AC-70, AC-95, AC-120 и т.д.)
    - Материал (алюминий, медь, сталь)
    - Сечение
    - Электрические параметры (R, X, B, G)
    - Механические характеристики
    """
    __tablename__ = "wire_info"

    id = Column(Integer, primary_key=True, index=True)
    # mRID (Master Resource Identifier) по стандарту IEC 61970-552:2016
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    
    # Название/марка провода (например, "AC-70", "AC-95", "AC-120")
    name = Column(String(100), nullable=False, unique=True)
    
    # Код марки провода
    code = Column(String(20), unique=True, index=True, nullable=True)
    
    # Материал провода
    material = Column(String(50), nullable=False)  # алюминий, медь, сталь, алюминиево-стальной
    
    # Сечение провода в квадратных миллиметрах (мм²)
    section = Column(Float, nullable=False)
    
    # Количество жил (для многожильных проводов)
    number_of_strands = Column(Integer, nullable=True, default=1)
    
    # Диаметр провода в миллиметрах
    diameter = Column(Float, nullable=True)
    
    # Электрические параметры на единицу длины (1 км)
    # Активное сопротивление, Ом/км
    r = Column(Float, nullable=True)
    
    # Реактивное сопротивление, Ом/км
    x = Column(Float, nullable=True)
    
    # Проводимость (емкостная), См/км
    b = Column(Float, nullable=True)
    
    # Активная проводимость, См/км
    g = Column(Float, nullable=True)
    
    # Механические характеристики
    # Разрывное усилие, Н
    breaking_load = Column(Float, nullable=True)
    
    # Масса провода, кг/км
    weight_per_length = Column(Float, nullable=True)
    
    # Максимальная рабочая температура, °C
    max_operating_temperature = Column(Float, nullable=True, default=70.0)
    
    # Номинальный ток, А
    nominal_current = Column(Float, nullable=True)
    
    # Описание
    description = Column(Text, nullable=True)
    
    # Активность (можно отключить устаревшие марки)
    is_active = Column(Boolean, default=True)
    
    # Временные метки
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Связи - временно закомментировано до применения миграции
    # LineSection использует WireInfo
    # line_sections = relationship("LineSection", back_populates="wire_info")
    
    # AClineSegment может ссылаться на WireInfo (опционально)
    # acline_segments = relationship("AClineSegment", back_populates="wire_info")

