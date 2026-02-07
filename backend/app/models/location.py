"""
Модели для Location и PositionPoint согласно CIM стандарту IEC 61970-301
Location - абстрактный класс для географического местоположения
PositionPoint - точка с координатами (xPosition, yPosition, zPosition)
"""
from sqlalchemy import Column, Integer, String, Float, DateTime, Text, ForeignKey, Enum as SQLEnum
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base
from app.models.base import generate_mrid
import enum


class LocationType(str, enum.Enum):
    """Тип местоположения согласно CIM"""
    POINT = "point"  # Точечное местоположение (опора, подстанция)
    LINE = "line"  # Линейное местоположение (ЛЭП)
    AREA = "area"  # Площадное местоположение


class Location(Base):
    """
    Location - географическое местоположение объекта
    Соответствует CIM классу: cim:Location
    
    В CIM Location является абстрактным классом, который может быть связан
    с любым PowerSystemResource через атрибут location.
    """
    __tablename__ = "locations"

    id = Column(Integer, primary_key=True, index=True)
    # mRID (Master Resource Identifier) по стандарту IEC 61970-552:2016
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    
    # Тип местоположения
    location_type = Column(SQLEnum(LocationType), nullable=False, default=LocationType.POINT)
    
    # Адрес (опционально)
    address = Column(Text, nullable=True)
    
    # Описание
    description = Column(Text, nullable=True)
    
    # Временные метки
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Связи с PositionPoint (один Location может иметь несколько точек)
    # Для точечных объектов (опоры, подстанции) обычно одна точка
    # Для линейных объектов (ЛЭП) - множество точек
    position_points = relationship("PositionPoint", back_populates="location", cascade="all, delete-orphan")
    
    # Полиморфные связи с объектами через location_id
    # Эти связи определяются в соответствующих моделях (Pole, Substation, etc.)


class PositionPoint(Base):
    """
    PositionPoint - точка с координатами
    Соответствует CIM классу: cim:PositionPoint
    
    В CIM PositionPoint содержит координаты xPosition, yPosition, zPosition
    и связан с Location.
    """
    __tablename__ = "position_points"

    id = Column(Integer, primary_key=True, index=True)
    # mRID (Master Resource Identifier) по стандарту IEC 61970-552:2016
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    
    # Связь с Location
    location_id = Column(Integer, ForeignKey("locations.id"), nullable=False)
    
    # Координаты согласно CIM стандарту
    # xPosition - долгота (longitude) в десятичных градусах
    # yPosition - широта (latitude) в десятичных градусах
    # zPosition - высота над уровнем моря в метрах (опционально)
    x_position = Column(Float, nullable=False)  # Долгота (longitude)
    y_position = Column(Float, nullable=False)  # Широта (latitude)
    z_position = Column(Float, nullable=True)   # Высота (altitude)
    
    # Порядковый номер точки (для линейных объектов)
    sequence_number = Column(Integer, nullable=True, default=1)
    
    # Описание точки
    description = Column(Text, nullable=True)
    
    # Временные метки
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Связи
    location = relationship("Location", back_populates="position_points")

