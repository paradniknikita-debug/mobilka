from sqlalchemy import Column, Integer, String, Float, DateTime, Text, ForeignKey, Boolean
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship, remote
from app.database import Base
from app.models.base import generate_mrid
from app.models.cim_base import ConnectivityNodeContainer

class PowerLine(Base, ConnectivityNodeContainer):
    __tablename__ = "line"

    id = Column(Integer, primary_key=True, index=True)
    # mRID, name, description, created_at, updated_at - наследуются от ConnectivityNodeContainer
    # alias_name - наследуется от PowerSystemResource
    # Но оставляем явное определение для обратной совместимости
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    name = Column(String(100), nullable=False)

    # Связь с BaseVoltage (CIM стандарт) - временно закомментировано до применения миграции
    # base_voltage_id = Column(Integer, ForeignKey("base_voltage.id"), nullable=True)
    
    # Номинальное напряжение (дублируется из BaseVoltage для обратной совместимости)
    voltage_level = Column(Float, nullable=False)  # кВ
    length = Column(Float, nullable=True)  # км
    # Заменяем branch_id на region_id для географической иерархии
    region_id = Column(Integer, ForeignKey("geographic_regions.id"), nullable=True)
    # Оставляем branch_id для обратной совместимости (можно будет удалить позже)
    branch_id = Column(Integer, ForeignKey("branches.id"), nullable=True)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    status = Column(String(20), default="active")  # active, inactive, maintenance
    # description, created_at, updated_at - наследуются от IdentifiedObject

    # Подстанции в начале и конце линии (для автосборки пролётов ПС↔опора при пересборке топологии)
    substation_start_id = Column(Integer, ForeignKey("substation.id"), nullable=True)
    substation_end_id = Column(Integer, ForeignKey("substation.id"), nullable=True)

    # Связи
    region = relationship("GeographicRegion", back_populates="lines")
    branch = relationship("Branch", back_populates="lines")  # Для обратной совместимости
    creator = relationship("User", back_populates="created_lines")
    # base_voltage = relationship("BaseVoltage", back_populates="power_lines")
    
    # CIM-структура: Line (EquipmentContainer) содержит множество AClineSegment (Equipment)
    acline_segments = relationship("AClineSegment", foreign_keys="[AClineSegment.line_id]", back_populates="line", cascade="all, delete-orphan")
    
    # CIM-структура: ConnectivityNodeContainer содержит множество ConnectivityNode
    # ConnectivityNodeContainer.ConnectivityNodes - связь с ConnectivityNode
    connectivity_nodes = relationship("ConnectivityNode", foreign_keys="[ConnectivityNode.line_id]", back_populates="line")
    
    # Для обратной совместимости (можно будет удалить после миграции)
    poles = relationship("Pole", back_populates="line", cascade="all, delete-orphan")
    spans = relationship("Span", back_populates="line", cascade="all, delete-orphan")
    taps = relationship("Tap", back_populates="line", cascade="all, delete-orphan")
    connections = relationship("Connection", back_populates="line", cascade="all, delete-orphan")
    substation_start = relationship("Substation", foreign_keys=[substation_start_id])
    substation_end = relationship("Substation", foreign_keys=[substation_end_id])
    # Сессии обхода: без cascade и lazy='noload' — при удалении ЛЭП не трогаем patrol_sessions (удаление в API).
    patrol_sessions = relationship("PatrolSession", back_populates="power_line", lazy="noload", viewonly=True)

class Pole(Base):
    """
    Опора - физическое представление ConnectivityNode (узла соединения)
    Соответствует CIM концепции: опора = ConnectivityNode
    
    В CIM опора является узлом соединения (ConnectivityNode), к которому
    могут подключаться несколько сегментов (основная линия + отпайки).
    """
    __tablename__ = "pole"

    id = Column(Integer, primary_key=True, index=True)
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    
    # Связь с линией (для обратной совместимости)
    line_id = Column(Integer, ForeignKey("line.id"), nullable=False)
    
    # Связь с ConnectivityNode (один к одному)
    # ConnectivityNode создаётся автоматически при создании опоры
    # Примечание: foreign key находится в ConnectivityNode.pole_id, а не здесь
    # connectivity_node_id оставлен для обратной совместимости, но не используется в relationship
    connectivity_node_id = Column(Integer, ForeignKey("connectivity_node.id"), nullable=True, unique=True)
    
    pole_number = Column(String(20), nullable=False)
    sequence_number = Column(Integer, nullable=True)  # Порядковый номер опоры в линии (для контроля последовательности)
    
    # CIM Location - связь с Location для координат (координаты только в Location/PositionPoint по CIM)
    location_id = Column(Integer, ForeignKey("location.id"), nullable=True)
    # Координаты на опоре для обратной совместимости (основной источник — PositionPoint)
    y_position = Column(Float, nullable=True)  # широта (latitude)
    x_position = Column(Float, nullable=True)  # долгота (longitude)
    
    pole_type = Column(String(50), nullable=False)  # анкерная, промежуточная, угловая и т.д.
    height = Column(Float, nullable=True)  # м
    foundation_type = Column(String(50), nullable=True)
    material = Column(String(50), nullable=True)  # металл, железобетон, дерево
    year_installed = Column(Integer, nullable=True)
    condition = Column(String(20), default="good")  # good, satisfactory, poor
    notes = Column(Text, nullable=True)
    # Комментарий карточки опоры (как во Flutter)
    card_comment = Column(Text, nullable=True)
    # Вложения к комментарию: JSON [{"t":"voice"|"photo"|"schema","url":"/api/v1/attachments/..."}] или base64/data (для синка с Flutter)
    card_comment_attachment = Column(Text, nullable=True)
    # Марка провода для этой опоры (используется для определения марки провода пролёта от этой опоры)
    conductor_type = Column(String(50), nullable=True)  # AC-70, AC-95 и т.д.
    conductor_material = Column(String(50), nullable=True)  # алюминий, медь
    conductor_section = Column(String(20), nullable=True)  # 70, 95 и т.д. (сечение в мм²)
    # Отпаечная опора: на этой опоре заканчивается текущий ACLineSegment (участок от ПС/пред. отпайки)
    is_tap_pole = Column(Boolean, default=False, nullable=False)
    # Магистраль/отпайка: null — до первой отпаечной, 'main' — магистраль, 'tap' — отпайка
    branch_type = Column(String(10), nullable=True)
    # Для опор на отпайке: id отпаечной опоры, от которой идёт эта ветка
    tap_pole_id = Column(Integer, ForeignKey("pole.id"), nullable=True)
    # Номер ветки от одной отпаечной опоры (1 = первая отпайка 3/1, 2 = вторая 3/2 и т.д.)
    tap_branch_index = Column(Integer, nullable=True)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Связи
    # lazy='selectin' предотвращает ленивую загрузку в async контексте
    line = relationship("PowerLine", back_populates="poles", lazy='selectin')
    # Изменили на one-to-many: одна опора может иметь несколько ConnectivityNode (для совместного подвеса)
    connectivity_nodes = relationship("ConnectivityNode", primaryjoin="Pole.id == remote(ConnectivityNode.pole_id)", back_populates="pole", uselist=True, lazy='selectin')
    creator = relationship("User", lazy='selectin')
    equipment = relationship("Equipment", back_populates="pole", cascade="all, delete-orphan", lazy='selectin')
    location = relationship("Location", foreign_keys=[location_id], lazy='selectin')
    tap_pole = relationship("Pole", remote_side="Pole.id", foreign_keys=[tap_pole_id])
    
    def _get_connectivity_node_safe(self):
        """Безопасное получение первого ConnectivityNode без ленивой загрузки"""
        # Используем __dict__ для прямого доступа к загруженным данным
        # Это избегает ленивой загрузки
        try:
            # Проверяем, есть ли уже загруженные connectivity_nodes в состоянии объекта
            state = getattr(self, '__dict__', {})
            
            # Пытаемся получить из кэша, если он есть
            if '_connectivity_node_cache' in state:
                return state['_connectivity_node_cache']
            
            # Пытаемся получить из загруженных relationships
            connectivity_nodes = state.get('connectivity_nodes')
            if connectivity_nodes is None:
                # Если нет в __dict__, значит relationships не загружены
                # Возвращаем None, чтобы избежать ленивой загрузки
                return None
            
            # Если это коллекция SQLAlchemy, проверяем, загружена ли она
            if hasattr(connectivity_nodes, '_sa_instance_state'):
                # Это коллекция SQLAlchemy, проверяем, загружена ли она
                from sqlalchemy import inspect
                insp = inspect(self)
                if insp is not None:
                    attr_state = insp.attrs.get('connectivity_nodes')
                    if attr_state is not None:
                        # Проверяем, загружено ли значение
                        if not hasattr(attr_state, 'loaded_value') or attr_state.loaded_value is None:
                            return None
            
            # Безопасно получаем первый элемент
            if hasattr(connectivity_nodes, '__iter__'):
                try:
                    first_node = next(iter(connectivity_nodes), None)
                    # Кэшируем результат
                    state['_connectivity_node_cache'] = first_node
                    return first_node
                except (StopIteration, TypeError):
                    return None
            return None
        except Exception:
            return None
    
    @property
    def connectivity_node(self):
        """Получить первый ConnectivityNode для обратной совместимости со схемой"""
        return self._get_connectivity_node_safe()
    
    def get_connectivity_node_for_line(self, power_line_id: int):
        """Получить ConnectivityNode для конкретной линии"""
        if not self.connectivity_nodes:
            return None
        for cn in self.connectivity_nodes:
            if cn.line_id == power_line_id:
                return cn
        return None
    
    def get_latitude(self):
        """Получить широту по CIM: только из Location/PositionPoint или PositionPoint (pole_id), иначе из колонки."""
        pts = getattr(self, "position_points", None)
        if pts and len(pts) > 0:
            return getattr(pts[0], "y_position", None)
        loc = getattr(self, "location", None)
        if loc and getattr(loc, "position_points", None) and len(loc.position_points) > 0:
            return loc.position_points[0].y_position
        val = getattr(self, "y_position", None)
        return float(val) if val is not None else None

    def get_longitude(self):
        """Получить долготу по CIM: только из Location/PositionPoint или PositionPoint (pole_id), иначе из колонки."""
        pts = getattr(self, "position_points", None)
        if pts and len(pts) > 0:
            return getattr(pts[0], "x_position", None)
        loc = getattr(self, "location", None)
        if loc and getattr(loc, "position_points", None) and len(loc.position_points) > 0:
            return loc.position_points[0].x_position
        val = getattr(self, "x_position", None)
        return float(val) if val is not None else None

class Span(Base):
    """
    Пролёт - физическое соединение между двумя опорами
    Соответствует концепции CIM: пролёт между двумя ConnectivityNode
    
    Пролёт принадлежит LineSection (секции линии с одинаковыми параметрами провода).
    Параметры провода наследуются от LineSection.
    """
    __tablename__ = "span"

    id = Column(Integer, primary_key=True, index=True)
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    
    # Связь с секцией линии (LineSection)
    # Пролёт наследует параметры провода от секции
    line_section_id = Column(Integer, ForeignKey("line_section.id"), nullable=False)
    
    # Связь с узлами соединения (ConnectivityNode = опоры)
    from_connectivity_node_id = Column(Integer, ForeignKey("connectivity_node.id"), nullable=False)
    to_connectivity_node_id = Column(Integer, ForeignKey("connectivity_node.id"), nullable=False)
    
    # Для обратной совместимости (можно будет удалить после миграции)
    line_id = Column(Integer, ForeignKey("line.id"), nullable=True)
    from_pole_id = Column(Integer, ForeignKey("pole.id"), nullable=True)
    to_pole_id = Column(Integer, ForeignKey("pole.id"), nullable=True)
    
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
    line = relationship("PowerLine", back_populates="spans")
    from_pole = relationship("Pole", foreign_keys=[from_pole_id])
    to_pole = relationship("Pole", foreign_keys=[to_pole_id])
    creator = relationship("User")

class Tap(Base):
    __tablename__ = "tap"

    id = Column(Integer, primary_key=True, index=True)
    # mRID (Master Resource Identifier) по стандарту IEC 61970-552:2016
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    line_id = Column(Integer, ForeignKey("line.id"), nullable=False)
    pole_id = Column(Integer, ForeignKey("pole.id"), nullable=False)
    tap_number = Column(String(20), nullable=False)
    tap_type = Column(String(50), nullable=False)  # трансформаторная подстанция, потребитель и т.д.
    voltage_level = Column(Float, nullable=False)  # кВ
    power_rating = Column(Float, nullable=True)  # кВА
    
    # CIM Location - связь с Location для координат
    location_id = Column(Integer, ForeignKey("location.id"), nullable=True)
    
    # Координаты (CIM: x_position = долгота, y_position = широта)
    y_position = Column(Float, nullable=True)
    x_position = Column(Float, nullable=True)
    
    description = Column(Text, nullable=True)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Связи
    line = relationship("PowerLine", back_populates="taps")
    pole = relationship("Pole")
    creator = relationship("User")
    location = relationship("Location", foreign_keys=[location_id])
    
    def get_latitude(self) -> float:
        """Получить широту из Location/PositionPoint или из колонки"""
        if self.location and self.location.position_points:
            return self.location.position_points[0].y_position
        return self.__dict__.get('y_position')
    
    def get_longitude(self) -> float:
        """Получить долготу из Location/PositionPoint или из колонки"""
        if self.location and self.location.position_points:
            return self.location.position_points[0].x_position
        return self.__dict__.get('x_position')

    @property
    def x_position(self) -> float:
        """Долгота (CIM x_position)."""
        val = self.get_longitude()
        return float(val) if val is not None else 0.0

    @property
    def y_position(self) -> float:
        """Широта (CIM y_position)."""
        val = self.get_latitude()
        return float(val) if val is not None else 0.0

class Equipment(Base):
    __tablename__ = "equipment"

    id = Column(Integer, primary_key=True, index=True)
    # mRID (Master Resource Identifier) по стандарту IEC 61970-552:2016
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    pole_id = Column(Integer, ForeignKey("pole.id"), nullable=False)
    equipment_type = Column(String(50), nullable=False)  # изолятор, разрядник, грозозащитный трос и т.д.
    name = Column(String(100), nullable=False)
    manufacturer = Column(String(100), nullable=True)
    model = Column(String(100), nullable=True)
    serial_number = Column(String(100), nullable=True)
    year_manufactured = Column(Integer, nullable=True)
    installation_date = Column(DateTime, nullable=True)
    condition = Column(String(20), default="good")  # good, satisfactory, poor
    notes = Column(Text, nullable=True)
    # Дефект (описание), критичность (low | medium | high) — как во Flutter
    defect = Column(Text, nullable=True)
    criticality = Column(String(20), nullable=True)
    # Мультимедиа дефекта: JSON-список [{t, url|p, thumbnail_url?}]
    defect_attachment = Column(Text, nullable=True)

    # CIM Location - связь с Location для координат оборудования (как отдельного объекта на карте)
    location_id = Column(Integer, ForeignKey("location.id"), nullable=True)

    # Координаты (CIM: x_position = долгота, y_position = широта) для обратной совместимости.
    # Основным источником координат в перспективе должна быть Location/PositionPoint.
    y_position = Column(Float, nullable=True)
    x_position = Column(Float, nullable=True)

    created_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Направление от опоры для отрисовки на карте (градусы 0–360; если задано — участок до оборудования в этом направлении)
    direction_angle = Column(Float, nullable=True)
    
    # Связи
    pole = relationship("Pole", back_populates="equipment")
    creator = relationship("User")
    location = relationship("Location", foreign_keys=[location_id])
    connectivity_nodes = relationship("ConnectivityNode", back_populates="equipment")

    def get_latitude(self) -> float:
        """
        Получить широту оборудования:
        Используем только собственную колонку y_position, без загрузки связанных объектов,
        чтобы избежать MissingGreenlet при сериализации через Pydantic.
        """
        # Читаем напрямую из __dict__, чтобы не вызывать property и не триггерить lazy-load
        val = self.__dict__.get("y_position", None)
        if val is not None:
            try:
                return float(val)
            except (TypeError, ValueError):
                pass
        return 0.0

    def get_longitude(self) -> float:
        """
        Получить долготу оборудования:
        Используем только собственную колонку x_position, без загрузки связанных объектов,
        чтобы избежать MissingGreenlet при сериализации через Pydantic.
        """
        # Собственная колонка (из БД) — читаем напрямую из __dict__, чтобы не вызывать property
        val = self.__dict__.get("x_position", None)
        if val is not None:
            try:
                return float(val)
            except (TypeError, ValueError):
                pass
        return 0.0

    @property
    def x_position(self) -> float:
        """Долгота (CIM x_position) для оборудования."""
        val = self.get_longitude()
        return float(val) if val is not None else 0.0

    @x_position.setter
    def x_position(self, value: float) -> None:
        # Сеттер нужен для корректной работы ORM при записи в колонку
        self.__dict__["x_position"] = value

    @property
    def y_position(self) -> float:
        """Широта (CIM y_position) для оборудования."""
        val = self.get_latitude()
        return float(val) if val is not None else 0.0

    @y_position.setter
    def y_position(self, value: float) -> None:
        self.__dict__["y_position"] = value
