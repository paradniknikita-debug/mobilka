from sqlalchemy import Column, Integer, String, Float, DateTime, Text, ForeignKey, Boolean
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship, remote
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
    
    # CIM-структура: Line содержит множество AClineSegment
    acline_segments = relationship("AClineSegment", foreign_keys="[AClineSegment.power_line_id]", back_populates="power_line", cascade="all, delete-orphan")
    # Many-to-many связь с сегментами (для обратной совместимости)
    segments = relationship("AClineSegment", secondary="line_segments", back_populates="power_lines")
    
    # Для обратной совместимости (можно будет удалить после миграции)
    poles = relationship("Pole", back_populates="power_line", cascade="all, delete-orphan")
    spans = relationship("Span", back_populates="power_line", cascade="all, delete-orphan")
    taps = relationship("Tap", back_populates="power_line", cascade="all, delete-orphan")
    connections = relationship("Connection", back_populates="power_line")

class Pole(Base):
    """
    Опора - физическое представление ConnectivityNode (узла соединения)
    Соответствует CIM концепции: опора = ConnectivityNode
    
    В CIM опора является узлом соединения (ConnectivityNode), к которому
    могут подключаться несколько сегментов (основная линия + отпайки).
    """
    __tablename__ = "poles"

    id = Column(Integer, primary_key=True, index=True)
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    
    # Связь с линией (для обратной совместимости)
    power_line_id = Column(Integer, ForeignKey("power_lines.id"), nullable=False)
    
    # Связь с ConnectivityNode (один к одному)
    # ConnectivityNode создаётся автоматически при создании опоры
    # Примечание: foreign key находится в ConnectivityNode.pole_id, а не здесь
    # connectivity_node_id оставлен для обратной совместимости, но не используется в relationship
    connectivity_node_id = Column(Integer, ForeignKey("connectivity_nodes.id"), nullable=True, unique=True)
    
    pole_number = Column(String(20), nullable=False)
    sequence_number = Column(Integer, nullable=True)  # Порядковый номер опоры в линии (для контроля последовательности)
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
    # Изменили на one-to-many: одна опора может иметь несколько ConnectivityNode (для совместного подвеса)
    connectivity_nodes = relationship("ConnectivityNode", primaryjoin="Pole.id == remote(ConnectivityNode.pole_id)", back_populates="pole", uselist=True)
    creator = relationship("User")
    equipment = relationship("Equipment", back_populates="pole", cascade="all, delete-orphan")
    
    def get_connectivity_node_for_line(self, power_line_id: int):
        """Получить ConnectivityNode для конкретной линии"""
        if not self.connectivity_nodes:
            return None
        for cn in self.connectivity_nodes:
            if cn.power_line_id == power_line_id:
                return cn
        return None

class Span(Base):
    """
    Пролёт - физическое соединение между двумя опорами
    Соответствует концепции CIM: пролёт между двумя ConnectivityNode
    
    Пролёт принадлежит LineSection (секции линии с одинаковыми параметрами провода).
    Параметры провода наследуются от LineSection.
    """
    __tablename__ = "spans"

    id = Column(Integer, primary_key=True, index=True)
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    
    # Связь с секцией линии (LineSection)
    # Пролёт наследует параметры провода от секции
    line_section_id = Column(Integer, ForeignKey("line_sections.id"), nullable=False)
    
    # Связь с узлами соединения (ConnectivityNode = опоры)
    from_connectivity_node_id = Column(Integer, ForeignKey("connectivity_nodes.id"), nullable=False)
    to_connectivity_node_id = Column(Integer, ForeignKey("connectivity_nodes.id"), nullable=False)
    
    # Для обратной совместимости (можно будет удалить после миграции)
    power_line_id = Column(Integer, ForeignKey("power_lines.id"), nullable=True)
    from_pole_id = Column(Integer, ForeignKey("poles.id"), nullable=True)
    to_pole_id = Column(Integer, ForeignKey("poles.id"), nullable=True)
    
    span_number = Column(String(100), nullable=False)  # Увеличено с 20 до 100 для поддержки полных наименований
    length = Column(Float, nullable=False)  # м
    
    # Параметры пролёта (могут переопределять параметры секции)
    # Если не указаны, используются параметры из LineSection
    conductor_type = Column(String(50), nullable=True)  # наследуется от LineSection
    conductor_material = Column(String(50), nullable=True)  # наследуется от LineSection
    conductor_section = Column(String(20), nullable=True)  # наследуется от LineSection
    
    # Механические параметры пролёта
    tension = Column(Float, nullable=True)  # Н - натяжение провода
    sag = Column(Float, nullable=True)  # м - провис провода
    
    # Порядок пролёта в секции
    sequence_number = Column(Integer, nullable=False, default=1)
    
    notes = Column(Text, nullable=True)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Связи
    line_section = relationship("LineSection", back_populates="spans")
    from_connectivity_node = relationship("ConnectivityNode", foreign_keys=[from_connectivity_node_id], back_populates="from_spans")
    to_connectivity_node = relationship("ConnectivityNode", foreign_keys=[to_connectivity_node_id], back_populates="to_spans")
    
    # Для обратной совместимости
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
