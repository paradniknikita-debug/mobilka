from sqlalchemy import Column, Integer, String, Float, DateTime, Text, ForeignKey, Boolean
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base
from app.models.base import generate_mrid

class Substation(Base):
    __tablename__ = "substations"

    id = Column(Integer, primary_key=True, index=True)
    # mRID (Master Resource Identifier) по стандарту IEC 61970-552:2016
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    name = Column(String(100), nullable=False)
    dispatcher_name = Column(String(100), nullable=False)  # Диспетчерское наименование (заменяет code)
    voltage_level = Column(Float, nullable=False)  # кВ
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    address = Column(Text, nullable=True)
    # Заменяем branch_id на region_id для географической иерархии
    region_id = Column(Integer, ForeignKey("geographic_regions.id"), nullable=True)
    # Оставляем branch_id для обратной совместимости
    branch_id = Column(Integer, ForeignKey("branches.id"), nullable=True)
    description = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Связи
    region = relationship("GeographicRegion", back_populates="substations")
    branch = relationship("Branch", back_populates="substations")  # Для обратной совместимости
    connections = relationship("Connection", back_populates="substation")
    voltage_levels = relationship("VoltageLevel", back_populates="substation", cascade="all, delete-orphan")

class Connection(Base):
    __tablename__ = "connections"

    id = Column(Integer, primary_key=True, index=True)
    # mRID (Master Resource Identifier) по стандарту IEC 61970-552:2016
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    substation_id = Column(Integer, ForeignKey("substations.id"), nullable=False)
    power_line_id = Column(Integer, ForeignKey("power_lines.id"), nullable=False)
    connection_type = Column(String(20), nullable=False)  # input, output
    voltage_level = Column(Float, nullable=False)
    description = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Связи
    substation = relationship("Substation", back_populates="connections")
    power_line = relationship("PowerLine", back_populates="connections")


class VoltageLevel(Base):
    """
    VoltageLevel - уровень напряжения в подстанции
    Соответствует CIM классу: cim:VoltageLevel
    """
    __tablename__ = "voltage_levels"
    
    id = Column(Integer, primary_key=True, index=True)
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    substation_id = Column(Integer, ForeignKey("substations.id"), nullable=False)
    name = Column(String(100), nullable=False)
    code = Column(String(20), nullable=False)
    nominal_voltage = Column(Float, nullable=False)  # кВ - соответствует CIM BaseVoltage
    high_voltage_limit = Column(Float, nullable=True)  # кВ - верхний предел
    low_voltage_limit = Column(Float, nullable=True)  # кВ - нижний предел
    description = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Связи
    substation = relationship("Substation", back_populates="voltage_levels")
    bays = relationship("Bay", back_populates="voltage_level", cascade="all, delete-orphan")


class Bay(Base):
    """
    Bay - ячейка распределительного устройства
    Соответствует CIM классу: cim:Bay
    """
    __tablename__ = "bays"
    
    id = Column(Integer, primary_key=True, index=True)
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    voltage_level_id = Column(Integer, ForeignKey("voltage_levels.id"), nullable=False)
    name = Column(String(100), nullable=False)
    bay_number = Column(String(20), nullable=False)  # Номер ячейки
    bay_type = Column(String(50), nullable=False)  # ввод, отходящая линия, секционный, трансформатор
    description = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Связи
    voltage_level = relationship("VoltageLevel", back_populates="bays")
    busbar_sections = relationship("BusbarSection", back_populates="bay", cascade="all, delete-orphan")
    conducting_equipment = relationship("ConductingEquipment", back_populates="bay", cascade="all, delete-orphan")
    protection_equipment = relationship("ProtectionEquipment", back_populates="bay", cascade="all, delete-orphan")
    terminals = relationship("Terminal", back_populates="bay")


class BusbarSection(Base):
    """
    BusbarSection - секция шин
    Соответствует CIM классу: cim:BusbarSection
    """
    __tablename__ = "busbar_sections"
    
    id = Column(Integer, primary_key=True, index=True)
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    bay_id = Column(Integer, ForeignKey("bays.id"), nullable=False)
    name = Column(String(100), nullable=False)
    section_number = Column(Integer, nullable=False)  # Номер секции (I, II, III)
    nominal_current = Column(Float, nullable=True)  # А
    description = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Связи
    bay = relationship("Bay", back_populates="busbar_sections")


class ConductingEquipment(Base):
    """
    ConductingEquipment - проводящее оборудование
    Соответствует CIM классу: cim:ConductingEquipment
    Поддерживает полиморфизм для различных типов оборудования
    """
    __tablename__ = "conducting_equipment"
    
    id = Column(Integer, primary_key=True, index=True)
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    bay_id = Column(Integer, ForeignKey("bays.id"), nullable=False)
    
    # CIM тип оборудования (PowerTransformer, Breaker, Disconnector и т.д.)
    equipment_type = Column(String(50), nullable=False)  # CIM класс
    name = Column(String(100), nullable=False)
    
    # Производитель и модель
    manufacturer = Column(String(100), nullable=True)
    model = Column(String(100), nullable=True)
    serial_number = Column(String(100), nullable=True)
    
    # Технические характеристики (JSON для гибкости разных типов)
    # Для PowerTransformer: мощность, коэффициент трансформации
    # Для Breaker: номинальный ток, напряжение отключения
    # Для Disconnector: номинальный ток, напряжение
    specifications = Column(JSONB, nullable=True)
    
    # Даты обслуживания
    installation_date = Column(DateTime, nullable=True)
    last_maintenance_date = Column(DateTime, nullable=True)
    next_maintenance_date = Column(DateTime, nullable=True)
    
    # Статус (соответствует CIM OperationalLimitSet)
    status = Column(String(20), default="active")  # active, maintenance, decommissioned
    
    notes = Column(Text, nullable=True)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Связи
    bay = relationship("Bay", back_populates="conducting_equipment")
    terminals = relationship("Terminal", back_populates="conducting_equipment")
    creator = relationship("User")


class ProtectionEquipment(Base):
    """
    ProtectionEquipment - оборудование защиты
    Соответствует CIM классу: cim:ProtectionEquipment
    """
    __tablename__ = "protection_equipment"
    
    id = Column(Integer, primary_key=True, index=True)
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    bay_id = Column(Integer, ForeignKey("bays.id"), nullable=False)
    name = Column(String(100), nullable=False)
    protection_type = Column(String(50), nullable=False)  # реле, автомат защиты, УЗО
    manufacturer = Column(String(100), nullable=True)
    model = Column(String(100), nullable=True)
    serial_number = Column(String(100), nullable=True)
    specifications = Column(JSONB, nullable=True)  # уставки, ток срабатывания и т.д.
    installation_date = Column(DateTime, nullable=True)
    status = Column(String(20), default="active")
    notes = Column(Text, nullable=True)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Связи
    bay = relationship("Bay", back_populates="protection_equipment")
    creator = relationship("User")
