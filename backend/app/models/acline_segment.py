"""
Модель AClineSegment (сегмент линии передачи)
Соответствует стандарту IEC 61970-301 CIM: cim:ACLineSegment

Структура:
- Line (PowerLine) содержит множество AClineSegment
- AClineSegment может быть основным сегментом линии или отпайкой (Tap)
- AClineSegment соединяет два ConnectivityNode (опоры)
- AClineSegment содержит множество LineSection (секций с одинаковыми параметрами провода)
- LineSection содержит множество Span (пролётов от опоры до опоры)
"""
from sqlalchemy import Column, Integer, String, Float, DateTime, Text, ForeignKey, Table, Boolean
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
    """
    CIM ACLineSegment - сегмент линии переменного тока
    Соответствует CIM классу: cim:ACLineSegment
    
    Сегмент может быть:
    1. Основным сегментом линии (от подстанции до подстанции)
    2. Отпайкой (Tap) - начинается от ConnectivityNode основной линии
    """
    __tablename__ = "acline_segments"

    id = Column(Integer, primary_key=True, index=True)
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    name = Column(String(100), nullable=False)
    code = Column(String(20), unique=True, index=True, nullable=False)
    
    # Связь с линией (PowerLine)
    power_line_id = Column(Integer, ForeignKey("power_lines.id"), nullable=False)
    
    # Тип сегмента: основной или отпайка
    is_tap = Column(Boolean, default=False, nullable=False)  # True = отпайка, False = основной сегмент
    tap_number = Column(String(20), nullable=True)  # Номер отпайки (44/1, 44/2 и т.д.)
    
    # Связь с узлами соединения (ConnectivityNode = опоры)
    # Для основного сегмента: начало и конец линии
    # Для отпайки: начало от опоры основной линии, конец - опора или подстанция
    from_connectivity_node_id = Column(Integer, ForeignKey("connectivity_nodes.id"), nullable=False)
    to_connectivity_node_id = Column(Integer, ForeignKey("connectivity_nodes.id"), nullable=True)
    
    # Для отпаек, заканчивающихся на подстанции/КТП
    to_terminal_id = Column(Integer, ForeignKey("terminals.id"), nullable=True)
    
    # Уровень напряжения
    voltage_level = Column(Float, nullable=False)  # кВ
    
    # Общая длина сегмента (сумма длин всех секций)
    length = Column(Float, nullable=False)  # км
    
    # Параметры по умолчанию (могут переопределяться в LineSection)
    # Эти параметры используются, если сегмент не имеет секций
    conductor_type = Column(String(50), nullable=True)
    conductor_material = Column(String(50), nullable=True)
    conductor_section = Column(String(20), nullable=True)
    r = Column(Float, nullable=True)  # активное сопротивление, Ом/км
    x = Column(Float, nullable=True)  # реактивное сопротивление, Ом/км
    b = Column(Float, nullable=True)  # проводимость, См/км
    g = Column(Float, nullable=True)  # активная проводимость, См/км
    
    # Порядок сегмента в линии
    sequence_number = Column(Integer, nullable=False, default=1)
    
    description = Column(Text, nullable=True)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Связи
    # Связь с линией (для обратной совместимости - many-to-many)
    power_lines = relationship("PowerLine", secondary=line_segments, back_populates="segments")
    # Прямая связь с линией (для отпаек)
    power_line = relationship("PowerLine", foreign_keys=[power_line_id], back_populates="acline_segments")
    
    # Связь с узлами соединения (ConnectivityNode)
    from_node = relationship("ConnectivityNode", foreign_keys=[from_connectivity_node_id], back_populates="from_segments")
    to_node = relationship("ConnectivityNode", foreign_keys=[to_connectivity_node_id], back_populates="to_segments")
    
    # Терминалы подключения (множество терминалов, связанных с сегментом через acline_segment_id)
    terminals = relationship("Terminal", primaryjoin="AClineSegment.id == Terminal.acline_segment_id", back_populates="acline_segment")
    # Терминал, к которому подключается сегмент (для отпаек, заканчивающихся на подстанции)
    to_terminal = relationship("Terminal", primaryjoin="AClineSegment.to_terminal_id == Terminal.id", foreign_keys=[to_terminal_id])
    
    # Секции линии (LineSection)
    line_sections = relationship("LineSection", back_populates="acline_segment", cascade="all, delete-orphan", order_by="LineSection.sequence_number")
    
    creator = relationship("User")

