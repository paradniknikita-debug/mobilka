from sqlalchemy import Column, Integer, String, Float, DateTime, Text, ForeignKey, Boolean
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base
from app.models.base import generate_mrid

class PowerLine(Base):
    __tablename__ = "power_lines"

    id = Column(Integer, primary_key=True, index=True)
    # mRID (Master Resource Identifier) по стандарту IEC 61970-552:2016
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    name = Column(String(100), nullable=False)
    code = Column(String(20), unique=True, index=True, nullable=False)
    voltage_level = Column(Float, nullable=False)  # кВ
    length = Column(Float, nullable=True)  # км
    # Заменяем branch_id на region_id для географической иерархии
    region_id = Column(Integer, ForeignKey("geographic_regions.id"), nullable=True)
    # Оставляем branch_id для обратной совместимости (можно будет удалить позже)
    branch_id = Column(Integer, ForeignKey("branches.id"), nullable=True)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    status = Column(String(20), default="active")  # active, inactive, maintenance
    description = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Связи
    region = relationship("GeographicRegion", back_populates="power_lines")
    branch = relationship("Branch", back_populates="power_lines")  # Для обратной совместимости
    creator = relationship("User", back_populates="created_power_lines")
    poles = relationship("Pole", back_populates="power_line", cascade="all, delete-orphan")
    spans = relationship("Span", back_populates="power_line", cascade="all, delete-orphan")
    taps = relationship("Tap", back_populates="power_line", cascade="all, delete-orphan")
    connections = relationship("Connection", back_populates="power_line")
    # Many-to-many связь с сегментами
    segments = relationship("AClineSegment", secondary="line_segments", back_populates="power_lines")

class Pole(Base):
    __tablename__ = "poles"

    id = Column(Integer, primary_key=True, index=True)
    # mRID (Master Resource Identifier) по стандарту IEC 61970-552:2016
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    power_line_id = Column(Integer, ForeignKey("power_lines.id"), nullable=False)
    # Опциональная связь с сегментом (для паспортизации)
    segment_id = Column(Integer, ForeignKey("acline_segments.id"), nullable=True)
    pole_number = Column(String(20), nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    pole_type = Column(String(50), nullable=False)  # анкерная, промежуточная, угловая и т.д.
    height = Column(Float, nullable=True)  # м
    foundation_type = Column(String(50), nullable=True)
    material = Column(String(50), nullable=True)  # металл, железобетон, дерево
    year_installed = Column(Integer, nullable=True)
    condition = Column(String(20), default="good")  # good, satisfactory, poor
    notes = Column(Text, nullable=True)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Связи
    power_line = relationship("PowerLine", back_populates="poles")
    segment = relationship("AClineSegment", foreign_keys=[segment_id])
    creator = relationship("User")
    equipment = relationship("Equipment", back_populates="pole", cascade="all, delete-orphan")

class Span(Base):
    __tablename__ = "spans"

    id = Column(Integer, primary_key=True, index=True)
    # mRID (Master Resource Identifier) по стандарту IEC 61970-552:2016
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    power_line_id = Column(Integer, ForeignKey("power_lines.id"), nullable=False)
    from_pole_id = Column(Integer, ForeignKey("poles.id"), nullable=False)
    to_pole_id = Column(Integer, ForeignKey("poles.id"), nullable=False)
    span_number = Column(String(20), nullable=False)
    length = Column(Float, nullable=False)  # м
    conductor_type = Column(String(50), nullable=True)
    conductor_material = Column(String(50), nullable=True)
    conductor_section = Column(String(20), nullable=True)  # мм²
    tension = Column(Float, nullable=True)  # Н
    sag = Column(Float, nullable=True)  # м
    notes = Column(Text, nullable=True)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Связи
    power_line = relationship("PowerLine", back_populates="spans")
    from_pole = relationship("Pole", foreign_keys=[from_pole_id])
    to_pole = relationship("Pole", foreign_keys=[to_pole_id])
    creator = relationship("User")

class Tap(Base):
    __tablename__ = "taps"

    id = Column(Integer, primary_key=True, index=True)
    # mRID (Master Resource Identifier) по стандарту IEC 61970-552:2016
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    power_line_id = Column(Integer, ForeignKey("power_lines.id"), nullable=False)
    pole_id = Column(Integer, ForeignKey("poles.id"), nullable=False)
    tap_number = Column(String(20), nullable=False)
    tap_type = Column(String(50), nullable=False)  # трансформаторная подстанция, потребитель и т.д.
    voltage_level = Column(Float, nullable=False)  # кВ
    power_rating = Column(Float, nullable=True)  # кВА
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    description = Column(Text, nullable=True)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Связи
    power_line = relationship("PowerLine", back_populates="taps")
    pole = relationship("Pole")
    creator = relationship("User")

class Equipment(Base):
    __tablename__ = "equipment"

    id = Column(Integer, primary_key=True, index=True)
    # mRID (Master Resource Identifier) по стандарту IEC 61970-552:2016
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    pole_id = Column(Integer, ForeignKey("poles.id"), nullable=False)
    equipment_type = Column(String(50), nullable=False)  # изолятор, разрядник, грозозащитный трос и т.д.
    name = Column(String(100), nullable=False)
    manufacturer = Column(String(100), nullable=True)
    model = Column(String(100), nullable=True)
    serial_number = Column(String(100), nullable=True)
    year_manufactured = Column(Integer, nullable=True)
    installation_date = Column(DateTime, nullable=True)
    condition = Column(String(20), default="good")  # good, satisfactory, poor
    notes = Column(Text, nullable=True)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Связи
    pole = relationship("Pole", back_populates="equipment")
    creator = relationship("User")
