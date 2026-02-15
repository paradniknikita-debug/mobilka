"""
Базовые CIM классы для моделей БД
Соответствует стандарту IEC 61970-301 (CIM Base)
"""
from sqlalchemy import Column, String, Text, DateTime, ForeignKey, Integer, Boolean
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship, declared_attr
from app.database import Base
from app.models.base import generate_mrid


class IdentifiedObject:
    """
    Базовый класс IdentifiedObject (IEC 61970-301)
    Все CIM объекты наследуются от этого класса
    """
    # mRID (Master Resource Identifier) - обязательное поле по IEC 61970-552:2016
    mrid = Column(String(36), unique=True, index=True, nullable=False, default=generate_mrid)
    
    # Имя объекта
    name = Column(String(100), nullable=True)
    
    # Описание
    description = Column(Text, nullable=True)
    
    # Время создания и обновления
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())


class PowerSystemResource(IdentifiedObject):
    """
    Класс PowerSystemResource (IEC 61970-301)
    Базовый класс для всех ресурсов энергосистемы
    """
    # Alias name (альтернативное имя)
    alias_name = Column(String(100), nullable=True)
    
    # Связь с родительским объектом (для иерархии)
    parent_id = Column(Integer, nullable=True)  # Будет переопределено в конкретных классах


class Equipment(PowerSystemResource):
    """
    Класс Equipment (IEC 61970-301)
    Базовый класс для всего оборудования
    """
    # Оборудование в нормальной эксплуатации
    normally_in_service = Column(Boolean, default=True, nullable=True)  # true/false
    
    # Связь с контейнером оборудования
    equipment_container_id = Column(Integer, nullable=True)  # Будет переопределено


class ConductingEquipment(Equipment):
    """
    Класс ConductingEquipment (IEC 61970-301)
    Базовый класс для проводящего оборудования
    """
    # Фазы (A, B, C, ABC и т.д.)
    phases = Column(String(10), nullable=True)


class EquipmentContainer(PowerSystemResource):
    """
    Класс EquipmentContainer (IEC 61970-301)
    Контейнер для оборудования (Substation, Line и т.д.)
    """
    pass  # Дополнительные поля будут в конкретных классах


class ConnectivityNodeContainer(EquipmentContainer):
    """
    Класс ConnectivityNodeContainer (IEC 61970-301)
    Контейнер для узлов соединения
    """
    pass  # Дополнительные поля будут в конкретных классах

