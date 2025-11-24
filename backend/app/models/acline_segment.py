"""
Модель AClineSegment (сегмент линии передачи)
Соответствует стандарту IEC 61970-301 CIM
Сегмент может быть общим для нескольких линий (many-to-many)
"""
from sqlalchemy import Column, Integer, String, Float, DateTime, Text, ForeignKey, Table
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base
from app.models.base import generate_mrid

# Промежуточная таблица для связи many-to-many между PowerLine и AClineSegment
line_segments = Table(
    'line_segments',
    Base.metadata,
    Column('power_line_id', Integer, ForeignKey('power_lines.id'), primary_key=True),
    Column('acline_segment_id', Integer, ForeignKey('acline_segments.id'), primary_key=True),
)


class AClineSegment(Base):
    __tablename__ = "acline_segments"

    id = Column(Integer, primary_key=True, index=True)
    # mRID (Master Resource Identifier) по стандарту IEC 61970-552:2016
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    name = Column(String(100), nullable=False)
    code = Column(String(20), unique=True, index=True, nullable=False)
    voltage_level = Column(Float, nullable=False)  # кВ
    length = Column(Float, nullable=False)  # км
    # Параметры проводника
    conductor_type = Column(String(50), nullable=True)  # тип проводника
    conductor_material = Column(String(50), nullable=True)  # материал (алюминий, медь и т.д.)
    conductor_section = Column(String(20), nullable=True)  # сечение, мм²
    # Связь с опорами (начало и конец сегмента)
    start_pole_id = Column(Integer, ForeignKey("poles.id"), nullable=True)
    end_pole_id = Column(Integer, ForeignKey("poles.id"), nullable=True)
    # Дополнительные параметры
    r = Column(Float, nullable=True)  # активное сопротивление, Ом/км
    x = Column(Float, nullable=True)  # реактивное сопротивление, Ом/км
    b = Column(Float, nullable=True)  # проводимость, См/км
    g = Column(Float, nullable=True)  # активная проводимость, См/км
    description = Column(Text, nullable=True)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Связи
    # Many-to-many с линиями (сегмент может быть общим для нескольких линий)
    power_lines = relationship("PowerLine", secondary=line_segments, back_populates="segments")
    # Связь с опорами
    start_pole = relationship("Pole", foreign_keys=[start_pole_id])
    end_pole = relationship("Pole", foreign_keys=[end_pole_id])
    creator = relationship("User")

