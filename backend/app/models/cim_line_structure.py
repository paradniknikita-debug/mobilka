"""
CIM-совместимая структура для линий электропередачи
Соответствует стандартам IEC 61970-301 (CIM Base) и IEC 61970-552

Иерархия:
Line (PowerLine) - cim:Line
  └── AClineSegment (сегменты линии) - cim:ACLineSegment
        └── LineSection (секции линии - группа пролётов с одинаковыми параметрами)
              └── Span (пролёты от опоры до опоры)
                    ├── FromConnectivityNode (опора) - cim:ConnectivityNode
                    └── ToConnectivityNode (опора) - cim:ConnectivityNode

Отпайки (Tap):
  └── AClineSegment (отдельный сегмент, начинающийся от ConnectivityNode основной линии)
        └── LineSection
              └── Span
                    └── Terminal (подключение к подстанции/КТП) - cim:Terminal
"""
from sqlalchemy import Column, Integer, String, Float, DateTime, Text, ForeignKey, Boolean
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship, remote
from app.database import Base
from app.models.base import generate_mrid
from app.models.cim_base import IdentifiedObject


class ConnectivityNode(Base, IdentifiedObject):
    """
    CIM ConnectivityNode - узел соединения
    Соответствует CIM классу: cim:ConnectivityNode
    
    Опоры являются ConnectivityNode - точками соединения сегментов линии.
    Одна опора может иметь несколько ConnectivityNode для:
    1. Основной линии (line_id = ID основной линии)
    2. Отпаек (line_id = ID линии отпайки, AClineSegment.is_tap = True)
    3. Совместного подвеса (несколько основных линий на одной опоре)
    
    Различение отпайки и совместного подвеса:
    - Отпайка: AClineSegment.is_tap = True, начинается от ConnectivityNode основной линии
    - Совместный подвес: несколько AClineSegment с is_tap = False разных линий используют ConnectivityNode на одной опоре
    """
    __tablename__ = "connectivity_node"
    
    id = Column(Integer, primary_key=True, index=True)
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    name = Column(String(100), nullable=False)
    
    # Связь с опорой (опора = физическое представление ConnectivityNode)
    # nullable=True для узлов на подстанциях (при link_line_to_substation)
    pole_id = Column(Integer, ForeignKey("pole.id"), nullable=True)
    
    # Связь с линией (для различения отпаек и совместного подвеса)
    # Если несколько ConnectivityNode на одной опоре принадлежат разным линиям с is_tap=False, это совместный подвес
    line_id = Column(Integer, ForeignKey("line.id"), nullable=False)
    
    # Координаты (CIM: x_position = долгота, y_position = широта)
    y_position = Column(Float, nullable=False)
    x_position = Column(Float, nullable=False)
    
    # description, created_at, updated_at - наследуются от IdentifiedObject
    
    # Связь с подстанцией (для ConnectivityNode в подстанциях)
    substation_id = Column(Integer, ForeignKey("substation.id"), nullable=True)
    
    # Связи (pole может быть None для узла на подстанции)
    pole = relationship("Pole", foreign_keys=[pole_id], back_populates="connectivity_nodes")
    line = relationship("PowerLine", foreign_keys=[line_id], back_populates="connectivity_nodes")
    substation = relationship("Substation", foreign_keys=[substation_id], back_populates="connectivity_nodes")
    
    # CIM-структура: ConnectivityNodeContainer содержит ConnectivityNode
    # ConnectivityNodeContainer.ConnectivityNodes - обратная связь
    # Терминалы, подключенные к этому узлу
    terminals = relationship("Terminal", back_populates="connectivity_node")
    # Сегменты, начинающиеся от этого узла
    from_segments = relationship("AClineSegment", primaryjoin="ConnectivityNode.id == remote(AClineSegment.from_connectivity_node_id)", back_populates="from_node")
    # Сегменты, заканчивающиеся в этом узле
    to_segments = relationship("AClineSegment", primaryjoin="ConnectivityNode.id == remote(AClineSegment.to_connectivity_node_id)", back_populates="to_node")
    # Пролёты, начинающиеся от этого узла
    from_spans = relationship("Span", primaryjoin="ConnectivityNode.id == remote(Span.from_connectivity_node_id)", back_populates="from_connectivity_node")
    # Пролёты, заканчивающиеся в этом узле
    to_spans = relationship("Span", primaryjoin="ConnectivityNode.id == remote(Span.to_connectivity_node_id)", back_populates="to_connectivity_node")


class Terminal(Base, IdentifiedObject):
    """
    CIM Terminal - точка подключения оборудования
    Соответствует CIM классу: cim:Terminal
    
    Terminal связывает ConductingEquipment (AClineSegment) с ConnectivityNode.
    Для отпаек, подключенных к подстанциям/КТП, Terminal связывает сегмент с оборудованием подстанции.
    """
    __tablename__ = "terminal"
    
    id = Column(Integer, primary_key=True, index=True)
    # mRID, name, description, created_at, updated_at - наследуются от IdentifiedObject
    # Но оставляем явное определение для обратной совместимости
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    name = Column(String(100), nullable=True)
    
    # Связь с узлом соединения (опорой)
    connectivity_node_id = Column(Integer, ForeignKey("connectivity_node.id"), nullable=True)
    
    # Связь с сегментом линии
    acline_segment_id = Column(Integer, ForeignKey("acline_segment.id"), nullable=True)
    
    # Для подключения к подстанции/КТП
    conducting_equipment_id = Column(Integer, ForeignKey("conducting_equipment.id"), nullable=True)
    bay_id = Column(Integer, ForeignKey("bay.id"), nullable=True)
    
    # Номер терминала (1, 2, 3... для многофазных линий)
    sequence_number = Column(Integer, nullable=True, default=1)
    
    # Направление подключения (from/to)
    connection_direction = Column(String(20), nullable=False)  # 'from', 'to', 'both'
    
    # description, created_at, updated_at - наследуются от IdentifiedObject
    
    # Связи
    connectivity_node = relationship("ConnectivityNode", back_populates="terminals")
    acline_segment = relationship("AClineSegment", foreign_keys=[acline_segment_id], back_populates="terminals")
    conducting_equipment = relationship("ConductingEquipment", back_populates="terminals")
    bay = relationship("Bay", back_populates="terminals")


class LineSection(Base):
    """
    Секция линии - группа пролётов с одинаковыми параметрами провода
    Не является прямым CIM классом, но логически группирует пролёты
    
    Секция линии объединяет пролёты с одинаковыми:
    - Маркой провода
    - Сечением
    - Материалом
    - Параметрами (R, X, B, G)
    """
    __tablename__ = "line_section"
    
    id = Column(Integer, primary_key=True, index=True)
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    name = Column(String(100), nullable=False)
    
    # Связь с сегментом линии
    acline_segment_id = Column(Integer, ForeignKey("acline_segment.id"), nullable=False)
    
    # Связь с WireInfo (CIM стандарт) - временно закомментировано до применения миграции
    # wire_info_id = Column(Integer, ForeignKey("wire_infos.id"), nullable=True)
    
    # Параметры провода (дублируются из WireInfo для обратной совместимости)
    conductor_type = Column(String(50), nullable=True)  # марка провода (AC-70, AC-95 и т.д.)
    conductor_material = Column(String(50), nullable=True)  # материал (алюминий, медь)
    conductor_section = Column(String(20), nullable=True)  # сечение, мм²
    
    # Электрические параметры (на единицу длины) - дублируются из WireInfo
    r = Column(Float, nullable=True)  # активное сопротивление, Ом/км
    x = Column(Float, nullable=True)  # реактивное сопротивление, Ом/км
    b = Column(Float, nullable=True)  # проводимость, См/км
    g = Column(Float, nullable=True)  # активная проводимость, См/км
    
    # Порядок секции в сегменте
    sequence_number = Column(Integer, nullable=False, default=1)
    
    # Общая длина секции (сумма длин всех пролётов)
    total_length = Column(Float, nullable=True)  # м
    
    description = Column(Text, nullable=True)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Связи
    acline_segment = relationship("AClineSegment", back_populates="line_sections")
    # wire_info = relationship("WireInfo", back_populates="line_sections")
    spans = relationship("Span", back_populates="line_section", cascade="all, delete-orphan", order_by="Span.sequence_number")
    creator = relationship("User")


# Обновляем модель Span для связи с LineSection
# Span теперь должен быть связан с LineSection, а не напрямую с PowerLine

