# Архитектура системы учета подстанций на основе CIM (IEC 61970-301)

## Концепция CIM-совместимой архитектуры

Система учета подстанций и оборудования строится на основе стандарта **Common Information Model (CIM)** IEC 61970-301 и IEC 61968-11. Это обеспечивает совместимость с другими энергетическими системами и возможность обмена данными в стандартизированном формате.

## CIM иерархия подстанций

### Стандартная CIM структура

В CIM подстанция имеет следующую иерархию:

```
Substation (Подстанция)
  └── VoltageLevel (Уровень напряжения)
      └── Bay (Ячейка)
          ├── BusbarSection (Секция шин) - опционально
          └── ConductingEquipment (Проводящее оборудование)
              ├── PowerTransformer (Трансформатор)
              ├── Breaker (Выключатель)
              ├── Disconnector (Разъединитель)
              ├── GroundDisconnector (Заземлитель)
              └── ... (другие типы)
```

### Упрощенная CIM-совместимая структура

Для практической реализации предлагается упрощенная, но CIM-совместимая структура:

```
Substation (Подстанция)
  └── VoltageLevel (Уровень напряжения) - заменяет Switchyard
      └── Bay (Ячейка)
          ├── BusbarSection (Секция шин) - опционально, может быть в Bay
          └── ConductingEquipment (Оборудование)
              ├── PowerTransformer
              ├── Breaker
              ├── Disconnector
              └── ProtectionEquipment (Защита)
```

## Модели данных (Backend) - CIM совместимые

### Модель VoltageLevel (Уровень напряжения)

В CIM `VoltageLevel` представляет уровень напряжения в подстанции (например, 10 кВ, 0.4 кВ). Это более точное соответствие CIM, чем `Switchyard`.

```python
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
```

### Модель Bay (Ячейка)

В CIM `Bay` представляет ячейку распределительного устройства.

```python
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
```

### Модель BusbarSection (Секция шин)

В CIM `BusbarSection` представляет секцию шин.

```python
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
```

### Модель ConductingEquipment (Базовое оборудование)

В CIM все проводящее оборудование наследуется от `ConductingEquipment`. Для упрощения создаем единую таблицу с полиморфизмом через `equipment_type`.

```python
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
    specifications = Column(JSON, nullable=True)
    
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
    creator = relationship("User")
```

### Модель ProtectionEquipment (Оборудование защиты)

В CIM защитное оборудование выделено отдельно.

```python
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
    specifications = Column(JSON, nullable=True)  # уставки, ток срабатывания и т.д.
    installation_date = Column(DateTime, nullable=True)
    status = Column(String(20), default="active")
    notes = Column(Text, nullable=True)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Связи
    bay = relationship("Bay", back_populates="protection_equipment")
    creator = relationship("User")
```

### Обновление модели Substation

```python
class Substation(Base):
    """
    Substation - подстанция
    Соответствует CIM классу: cim:Substation
    """
    # ... существующие поля ...
    
    # Новые связи (CIM совместимые)
    voltage_levels = relationship("VoltageLevel", back_populates="substation", cascade="all, delete-orphan")
```

### Обновление модели Bay

```python
class Bay(Base):
    # ... поля из предыдущего определения ...
    
    # Добавляем связь с защитным оборудованием
    protection_equipment = relationship("ProtectionEquipment", back_populates="bay", cascade="all, delete-orphan")
```

## CIM типы оборудования

### Поддерживаемые CIM классы ConductingEquipment

1. **PowerTransformer** - силовой трансформатор
   - Характеристики: мощность (кВА), коэффициент трансформации, группа соединения обмоток

2. **Breaker** - выключатель
   - Характеристики: номинальный ток (А), напряжение отключения (кВ), тип привода

3. **Disconnector** - разъединитель
   - Характеристики: номинальный ток (А), напряжение (кВ)

4. **GroundDisconnector** - заземлитель
   - Характеристики: аналогично Disconnector

5. **LoadBreakSwitch** - выключатель нагрузки
   - Характеристики: номинальный ток, напряжение

6. **Fuse** - предохранитель
   - Характеристики: номинальный ток, тип

### Дополнительные CIM классы

- **ProtectionEquipment** - защитное оборудование (реле, автоматы)
- **Measurement** - измерительное оборудование (счетчики, трансформаторы тока/напряжения)

## API Endpoints (CIM-ориентированные)

### Подстанции

```
GET    /api/v1/substations                    # Список подстанций
GET    /api/v1/substations/{id}               # Детальная информация
GET    /api/v1/substations/{id}/cim           # CIM представление подстанции
GET    /api/v1/substations/{id}/structure     # Полная иерархическая структура
POST   /api/v1/substations                    # Создание подстанции
PUT    /api/v1/substations/{id}               # Обновление подстанции
DELETE /api/v1/substations/{id}               # Удаление подстанции
```

### Уровни напряжения

```
GET    /api/v1/substations/{id}/voltage-levels           # Список уровней напряжения
GET    /api/v1/voltage-levels/{vl_id}                     # Детали уровня напряжения
POST   /api/v1/substations/{id}/voltage-levels            # Создание уровня напряжения
PUT    /api/v1/voltage-levels/{vl_id}                     # Обновление уровня напряжения
DELETE /api/v1/voltage-levels/{vl_id}                     # Удаление уровня напряжения
```

### Ячейки

```
GET    /api/v1/voltage-levels/{vl_id}/bays                # Список ячеек
POST   /api/v1/voltage-levels/{vl_id}/bays                # Создание ячейки
PUT    /api/v1/bays/{bay_id}                              # Обновление ячейки
DELETE /api/v1/bays/{bay_id}                              # Удаление ячейки
```

### Секции шин

```
GET    /api/v1/bays/{bay_id}/busbar-sections              # Список секций
POST   /api/v1/bays/{bay_id}/busbar-sections              # Создание секции
PUT    /api/v1/busbar-sections/{bs_id}                    # Обновление секции
DELETE /api/v1/busbar-sections/{bs_id}                    # Удаление секции
```

### Проводящее оборудование

```
GET    /api/v1/bays/{bay_id}/equipment                    # Список оборудования ячейки
GET    /api/v1/substations/{id}/equipment                # Все оборудование подстанции
GET    /api/v1/equipment/{eq_id}                         # Детали оборудования
POST   /api/v1/bays/{bay_id}/equipment                    # Добавление оборудования
PUT    /api/v1/equipment/{eq_id}                          # Обновление оборудования
DELETE /api/v1/equipment/{eq_id}                          # Удаление оборудования
```

### Защитное оборудование

```
GET    /api/v1/bays/{bay_id}/protection                   # Список защиты
POST   /api/v1/bays/{bay_id}/protection                  # Добавление защиты
PUT    /api/v1/protection/{prot_id}                       # Обновление защиты
DELETE /api/v1/protection/{prot_id}                       # Удаление защиты
```

## CIM экспорт/импорт

### Интеграция с существующим CIM модулем

Использование существующего модуля `backend/app/core/cim/` для экспорта подстанций в CIM формат:

```python
# Пример экспорта подстанции в CIM JSON
from app.core.cim.cim_json import CIMJSONExporter
from app.core.cim.substation_cim import SubstationCIMObject

substation_cim = SubstationCIMObject.from_substation(substation)
exporter = CIMJSONExporter()
cim_json = exporter.export([substation_cim])
```

### CIM классы для подстанций

Создание CIM объектов для экспорта:

```python
class SubstationCIMObject(CIMObject):
    """CIM представление подстанции"""
    
    def get_cim_class(self) -> str:
        return "Substation"
    
    def to_cim_dict(self) -> Dict[str, Any]:
        return {
            "mRID": self.mrid,
            "name": self.name,
            "VoltageLevels": [vl.to_cim_dict() for vl in self.voltage_levels]
        }
```

## Преимущества CIM-совместимой архитектуры

1. **Стандартизация** - полное соответствие международным стандартам IEC 61970/61968
2. **Интеграция** - возможность обмена данными с другими CIM-совместимыми системами
3. **Расширяемость** - легко добавлять новые типы оборудования через CIM классы
4. **Совместимость** - использование стандартных терминов и структур
5. **Экспорт/импорт** - готовность к обмену данными в стандартизированном формате

## Сравнение с предыдущим предложением

| Аспект | Предыдущее предложение | CIM-совместимое предложение |
|--------|------------------------|----------------------------|
| Средний уровень | Switchyard (РУ) | VoltageLevel (Уровень напряжения) |
| Соответствие стандартам | Частичное (mRID) | Полное (CIM классы) |
| Экспорт данных | Не предусмотрен | CIM JSON/XML/RDF |
| Типы оборудования | Общий класс | CIM ConductingEquipment с полиморфизмом |
| Интеграция | Внутренняя | Межсистемная |

## Рекомендации по реализации

### Этап 1: Backend CIM модели
1. Создать модели VoltageLevel, Bay, BusbarSection, ConductingEquipment, ProtectionEquipment
2. Обновить модель Substation (добавить связь с voltage_levels)
3. Создать Pydantic схемы с CIM-ориентированными полями
4. Реализовать API endpoints
5. Создать миграцию базы данных

### Этап 2: CIM экспорт/импорт
1. Расширить `app/core/cim/` модуль классами для подстанций
2. Реализовать CIM объекты для всех уровней иерархии
3. Добавить экспорт в CIM JSON/XML/RDF
4. Реализовать импорт из CIM форматов

### Этап 3: Frontend структура
1. Создать модуль substations с компонентами
2. Реализовать компонент иерархического дерева (CIM-ориентированный)
3. Создать формы для создания/редактирования элементов
4. Интегрировать с картой (двойной клик, popup)

### Этап 4: Интеграция и тестирование
1. Протестировать создание полной структуры подстанции
2. Проверить CIM экспорт/импорт
3. Протестировать синхронизацию данных
4. Оптимизировать производительность

## Альтернативный вариант: Гибридный подход

Можно использовать гибридный подход, где:
- Внутренняя структура БД использует упрощенные названия (VoltageLevel вместо Switchyard)
- При экспорте в CIM происходит преобразование в стандартные CIM классы
- API использует понятные названия, но возвращает CIM-совместимые данные

Это упрощает разработку, сохраняя CIM совместимость на уровне экспорта.
