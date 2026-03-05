from typing import List, Optional, Tuple
import re
import uuid
from pydantic import BaseModel
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete, update, text
from sqlalchemy.orm import selectinload
from sqlalchemy.exc import ProgrammingError

from app.database import get_db
from app.core.security import get_current_active_user
from app.models.user import User
from app.models.power_line import PowerLine, Pole, Span, Tap, Equipment
from app.models.location import Location, PositionPoint
from app.models.acline_segment import AClineSegment
from app.models.cim_line_structure import ConnectivityNode, LineSection, Terminal
from app.models.change_log import ChangeLog
from app.schemas.power_line import (
    PowerLineCreate,
    PowerLineUpdate,
    PowerLineResponse,
    PoleCreate,
    PoleResponse,
    SpanCreate,
    SpanUpdate,
    SpanResponse,
    TapCreate,
    TapResponse,
    EquipmentCreate,
    EquipmentResponse,
)
from app.schemas.cim_line_structure import (
    ConnectivityNodeResponse,
    AClineSegmentResponse,
    LineSectionResponse,
    SpanResponse,
    TerminalResponse,
)

router = APIRouter()


def normalize_pole_number(s: Optional[str]) -> str:
    """
    Нормализация наименования опоры: «1» -> «Опора 1»; «3/2», «3/2 а» -> «Опора 3/2», «Опора 3/2 а»;
    опечатки «опооа», «опрора», «опра», «оп.» и т.п. -> «Опора»/«Опора N».
    """
    if not s or not isinstance(s, str):
        return (s or "").strip()
    s = s.strip()
    if not s:
        return s
    low = s.lower()
    # Уже есть префикс «опора» или «оп.» — нормализуем только опечатки
    if low.startswith("оп.") or low == "оп.":
        rest = re.sub(r"^оп\.\s*", "", low, flags=re.I).strip()
        if not rest:
            return "Опора"
        return f"Опора {rest}"
    for prefix in ("опрора", "опра", "опора", "опооа", "опораа", "опорра", "опоро"):
        if low.startswith(prefix) or low == prefix:
            rest = s[len(prefix):].strip()
            if not rest:
                return "Опора"
            return f"Опора {rest}"
    # Число или номер вида 3/2, 3/2 а, 44/1 — подтягиваем «Опора »
    if re.match(r"^\d+$", s):
        return f"Опора {s}"
    if re.match(r"^\d+/\s*\d+", s) or re.match(r"^\d+\s*/\s*\d+", s):
        return f"Опора {s}"
    return s


def fill_pole_coordinates(pole) -> None:
    """Заполняет на объекте опоры x_position, y_position для PoleResponse (из PositionPoint/Location)."""
    lon = getattr(pole, "get_longitude", None) and pole.get_longitude()
    lat = getattr(pole, "get_latitude", None) and pole.get_latitude()
    if lon is None:
        lon = 0.0
    if lat is None:
        lat = 0.0
    object.__setattr__(pole, "x_position", float(lon))
    object.__setattr__(pole, "y_position", float(lat))


def _get_attr_safe(obj, key: str, default=None):
    """Читает атрибут из __dict__ ORM-объекта, не вызывая дескрипторы SQLAlchemy (избегаем MissingGreenlet)."""
    if obj is None:
        return default
    d = getattr(obj, "__dict__", {})
    return d.get(key, default)


def _pole_orm_to_dict(pole) -> dict:
    """Собирает dict для PoleResponse из ORM, читая только из __dict__."""
    out = {
        "id": _get_attr_safe(pole, "id"),
        "mrid": _get_attr_safe(pole, "mrid", ""),
        "line_id": _get_attr_safe(pole, "line_id"),
        "connectivity_node_id": _get_attr_safe(pole, "connectivity_node_id"),
        "pole_number": _get_attr_safe(pole, "pole_number", ""),
        "x_position": _get_attr_safe(pole, "x_position") if _get_attr_safe(pole, "x_position") is not None else 0.0,
        "y_position": _get_attr_safe(pole, "y_position") if _get_attr_safe(pole, "y_position") is not None else 0.0,
        "pole_type": _get_attr_safe(pole, "pole_type", ""),
        "height": _get_attr_safe(pole, "height"),
        "foundation_type": _get_attr_safe(pole, "foundation_type"),
        "material": _get_attr_safe(pole, "material"),
        "year_installed": _get_attr_safe(pole, "year_installed"),
        "condition": _get_attr_safe(pole, "condition", "good"),
        "notes": _get_attr_safe(pole, "notes"),
        "sequence_number": _get_attr_safe(pole, "sequence_number"),
        "conductor_type": _get_attr_safe(pole, "conductor_type"),
        "conductor_material": _get_attr_safe(pole, "conductor_material"),
        "conductor_section": _get_attr_safe(pole, "conductor_section"),
        "is_tap_pole": bool(_get_attr_safe(pole, "is_tap_pole", False)),
        "branch_type": _get_attr_safe(pole, "branch_type"),
        "tap_pole_id": _get_attr_safe(pole, "tap_pole_id"),
        "tap_branch_index": _get_attr_safe(pole, "tap_branch_index"),
        "created_by": _get_attr_safe(pole, "created_by", 0),
        "created_at": _get_attr_safe(pole, "created_at"),
        "updated_at": _get_attr_safe(pole, "updated_at"),
        "connectivity_node": None,
    }
    return out


def _terminal_orm_to_dict(t) -> dict:
    """Собирает dict для TerminalResponse из ORM через __dict__."""
    if t is None:
        return None
    return {
        "id": _get_attr_safe(t, "id"),
        "mrid": _get_attr_safe(t, "mrid", ""),
        "name": _get_attr_safe(t, "name"),
        "sequence_number": _get_attr_safe(t, "sequence_number", 1),
        "connection_direction": _get_attr_safe(t, "connection_direction", "both"),
        "description": _get_attr_safe(t, "description"),
        "connectivity_node_id": _get_attr_safe(t, "connectivity_node_id"),
        "acline_segment_id": _get_attr_safe(t, "acline_segment_id"),
        "conducting_equipment_id": _get_attr_safe(t, "conducting_equipment_id"),
        "bay_id": _get_attr_safe(t, "bay_id"),
        "created_at": _get_attr_safe(t, "created_at"),
    }


def _equipment_pole_count(equipment: Equipment) -> int:
    """
    Определяет количество полюсов (терминалов), которое нужно создать для оборудования на опоре.
    По умолчанию: 2 полюса для разъединителя/выключателя/реклозера, 1 полюс для ЗН и разрядников,
    иначе 1 полюс.
    """
    etype = (_get_attr_safe(equipment, "equipment_type", "") or "").lower()
    if any(key in etype for key in ("разъедин", "disconnector", "выключат", "breaker", "реклозер", "recloser")):
        return 2
    if any(key in etype for key in ("зн", "земл", "разряд", "arrester")):
        return 1
    return 1


def _is_main_switching_equipment(equipment_type: str) -> bool:
    """
    Главное коммутационное оборудование (разъединитель, выключатель, реклозер) — граница участка (AClineSegment).
    ЗН и разрядник — вторичное, не создают границу участка.
    """
    if not equipment_type:
        return False
    etype = (equipment_type or "").lower()
    return bool(
        any(k in etype for k in ("разъедин", "disconnector", "выключат", "breaker", "реклозер", "recloser"))
    )


async def _sync_equipment_terminals_for_line(db: AsyncSession, power_line_id: int) -> None:
    """
    Синхронизирует терминалы оборудования на опорах линии с ConnectivityNode.

    Правила:
    - Для каждого оборудования на опорах линии создаются терминалы T1/T2:
      * разъединитель, выключатель, реклозер: два терминала (T1, T2);
      * ЗН, разрядник: один терминал (T1);
      * прочее оборудование: один терминал (T1).
    - Терминалы привязываются к ConnectivityNode соответствующей опоры и линии.
    - Перед созданием удаляются ранее созданные терминалы оборудования для этой линии:
      все терминалы без acline_segment_id и без conducting_equipment_id для узлов connectivity_node этой линии.
    """
    # Все connectivity node для этой линии
    cn_result = await db.execute(
        select(ConnectivityNode.id).where(ConnectivityNode.line_id == power_line_id)
    )
    cn_ids = [row[0] for row in cn_result.all()]

    if not cn_ids:
        return

    # Загружаем оборудование на опорах этой линии вместе с ConnectivityNode.
    # Учитываем только отпаечные опоры (is_tap_pole=True) — CN и терминалы оборудования
    # создаются только для отпаек, как оговаривалось в задаче.
    eq_query = (
        select(Equipment, Pole, ConnectivityNode)
        .join(Pole, Equipment.pole_id == Pole.id)
        .join(
            ConnectivityNode,
            (ConnectivityNode.pole_id == Pole.id)
            & (ConnectivityNode.line_id == power_line_id),
        )
        .where(
            Pole.line_id == power_line_id,
            Pole.is_tap_pole.is_(True),
        )
    )
    eq_result = await db.execute(eq_query)
    rows = eq_result.all()

    # Загружаем уже существующие терминалы по CN, сгруппованные по (cn_id, equipment_id, sequence_number)
    existing_terms_result = await db.execute(
        select(Terminal).where(
            Terminal.connectivity_node_id.in_(cn_ids),
            Terminal.acline_segment_id.is_(None),
        )
    )
    existing_terms = existing_terms_result.scalars().all()
    index: dict[tuple[int, Optional[int], int], Terminal] = {}
    for t in existing_terms:
        cn_id = _get_attr_safe(t, "connectivity_node_id")
        seq = int(_get_attr_safe(t, "sequence_number", 1) or 1)
        desc = (_get_attr_safe(t, "description", "") or "").lower()
        # Пытаемся вытащить equipment_id из description формата "equipment_id=123"
        eq_id: Optional[int] = None
        if "equipment_id=" in desc:
            try:
                part = desc.split("equipment_id=", 1)[1]
                num_str = ""
                for ch in part:
                    if ch.isdigit():
                        num_str += ch
                    else:
                        break
                if num_str:
                    eq_id = int(num_str)
            except Exception:
                eq_id = None
        key = (int(cn_id) if cn_id is not None else 0, eq_id, seq)
        # Не перезаписываем первый найденный терминал
        if key not in index:
            index[key] = t

    # Добавляем только отсутствующие терминалы для каждого оборудования
    for equipment, pole, cn in rows:
        pole_count = _equipment_pole_count(equipment)
        for seq in range(1, pole_count + 1):
            key = (int(cn.id), int(equipment.id), seq)
            if key in index:
                # Уже есть терминал для этого оборудования/узла/позиции — не пересоздаём, сохраняем mrid
                continue
            term = Terminal(
                name=f"T{seq}",
                connectivity_node_id=cn.id,
                sequence_number=seq,
                connection_direction="both",
            )
            setattr(term, "description", f"equipment_id={equipment.id}")
            db.add(term)

    await db.flush()

def _span_orm_to_dict(span) -> dict:
    """Собирает dict для SpanResponse (cim) из ORM через __dict__."""
    if span is None:
        return None
    return {
        "id": _get_attr_safe(span, "id"),
        "mrid": _get_attr_safe(span, "mrid", ""),
        "span_number": _get_attr_safe(span, "span_number", ""),
        "length": _get_attr_safe(span, "length", 0.0),
        "sequence_number": _get_attr_safe(span, "sequence_number", 1),
        "conductor_type": _get_attr_safe(span, "conductor_type"),
        "conductor_material": _get_attr_safe(span, "conductor_material"),
        "conductor_section": _get_attr_safe(span, "conductor_section"),
        "tension": _get_attr_safe(span, "tension"),
        "sag": _get_attr_safe(span, "sag"),
        "notes": _get_attr_safe(span, "notes"),
        "line_section_id": _get_attr_safe(span, "line_section_id"),
        "from_connectivity_node_id": _get_attr_safe(span, "from_connectivity_node_id"),
        "to_connectivity_node_id": _get_attr_safe(span, "to_connectivity_node_id"),
        "created_by": _get_attr_safe(span, "created_by"),
        "created_at": _get_attr_safe(span, "created_at"),
        "line_id": _get_attr_safe(span, "line_id"),
        "from_pole_id": _get_attr_safe(span, "from_pole_id"),
        "to_pole_id": _get_attr_safe(span, "to_pole_id"),
        "from_connectivity_node": None,
        "to_connectivity_node": None,
    }


def _line_section_orm_to_dict(ls) -> dict:
    """Собирает dict для LineSectionResponse из ORM через __dict__."""
    if ls is None:
        return None
    spans = _get_attr_safe(ls, "spans") or []
    return {
        "id": _get_attr_safe(ls, "id"),
        "mrid": _get_attr_safe(ls, "mrid", ""),
        "name": _get_attr_safe(ls, "name", ""),
        "acline_segment_id": _get_attr_safe(ls, "acline_segment_id"),
        "conductor_type": _get_attr_safe(ls, "conductor_type") or "",
        "conductor_material": _get_attr_safe(ls, "conductor_material"),
        "conductor_section": _get_attr_safe(ls, "conductor_section") or "",
        "r": _get_attr_safe(ls, "r"),
        "x": _get_attr_safe(ls, "x"),
        "b": _get_attr_safe(ls, "b"),
        "g": _get_attr_safe(ls, "g"),
        "sequence_number": _get_attr_safe(ls, "sequence_number", 1),
        "total_length": _get_attr_safe(ls, "total_length"),
        "description": _get_attr_safe(ls, "description"),
        "created_by": _get_attr_safe(ls, "created_by"),
        "created_at": _get_attr_safe(ls, "created_at"),
        "updated_at": _get_attr_safe(ls, "updated_at"),
        "spans": [_span_orm_to_dict(s) for s in spans] if spans else [],
    }


def _to_pole_display_name(seg) -> Optional[str]:
    """Для сегмента с to_node возвращает отображаемое имя конечной опоры (для выбора «подстанция в конце отпайки»)."""
    to_node = _get_attr_safe(seg, "to_node")
    if not to_node:
        return None
    pole = _get_attr_safe(to_node, "pole")
    if not pole:
        return None
    num = _get_attr_safe(pole, "pole_number")
    if num:
        return str(num).strip()
    seq = _get_attr_safe(pole, "sequence_number")
    if seq is not None:
        return f"Опора {seq}"
    return None


def _acline_segment_orm_to_dict(seg) -> dict:
    """Собирает dict для AClineSegmentResponse из ORM через __dict__."""
    if seg is None:
        return None
    line_sections = _get_attr_safe(seg, "line_sections") or []
    terminals = _get_attr_safe(seg, "terminals") or []

    # Для старых данных tap_pole_id в сегменте может быть пустым.
    # Тогда используем опору from_node как отпаечную опору.
    tap_pole_id = _get_attr_safe(seg, "tap_pole_id")
    if tap_pole_id is None:
        from_node = _get_attr_safe(seg, "from_node")
        if from_node is not None:
            tap_pole_id = _get_attr_safe(from_node, "pole_id")

    return {
        "id": _get_attr_safe(seg, "id"),
        "mrid": _get_attr_safe(seg, "mrid", ""),
        "name": _get_attr_safe(seg, "name", ""),
        "code": _get_attr_safe(seg, "code"),
        "line_id": _get_attr_safe(seg, "line_id"),
        "voltage_level": _get_attr_safe(seg, "voltage_level", 0.0),
        "length": _get_attr_safe(seg, "length", 0.0),
        "is_tap": bool(_get_attr_safe(seg, "is_tap", False)),
        "tap_number": _get_attr_safe(seg, "tap_number"),
        "branch_type": _get_attr_safe(seg, "branch_type"),
        "tap_pole_id": tap_pole_id,
        "sequence_number": _get_attr_safe(seg, "sequence_number", 1),
        "conductor_type": _get_attr_safe(seg, "conductor_type"),
        "conductor_material": _get_attr_safe(seg, "conductor_material"),
        "conductor_section": _get_attr_safe(seg, "conductor_section"),
        "r": _get_attr_safe(seg, "r"),
        "x": _get_attr_safe(seg, "x"),
        "b": _get_attr_safe(seg, "b"),
        "g": _get_attr_safe(seg, "g"),
        "description": _get_attr_safe(seg, "description"),
        "from_connectivity_node_id": _get_attr_safe(seg, "from_connectivity_node_id"),
        "to_connectivity_node_id": _get_attr_safe(seg, "to_connectivity_node_id"),
        "to_terminal_id": _get_attr_safe(seg, "to_terminal_id"),
        "to_substation_id": _get_attr_safe(seg, "to_substation_id"),
        "to_pole_id": _get_attr_safe(_get_attr_safe(seg, "to_node"), "pole_id"),
        "to_pole_display_name": _to_pole_display_name(seg),
        "created_by": _get_attr_safe(seg, "created_by"),
        "created_at": _get_attr_safe(seg, "created_at"),
        "updated_at": _get_attr_safe(seg, "updated_at"),
        "line_sections": [_line_section_orm_to_dict(sec) for sec in line_sections],
        "terminals": [_terminal_orm_to_dict(tr) for tr in terminals],
    }


def _power_line_orm_to_dict(pl) -> dict:
    """Собирает dict для PowerLineResponse из ORM через __dict__ (без дескрипторов SQLAlchemy)."""
    poles = _get_attr_safe(pl, "poles") or []
    acline_segments = _get_attr_safe(pl, "acline_segments") or []
    # Сегменты в порядке sequence_number (первый — от подстанции до первой опоры)
    acline_segments_sorted = sorted(acline_segments, key=lambda s: (_get_attr_safe(s, "sequence_number") or 0))
    return {
        "id": _get_attr_safe(pl, "id"),
        "mrid": _get_attr_safe(pl, "mrid", ""),
        "name": _get_attr_safe(pl, "name", ""),
        "base_voltage_id": _get_attr_safe(pl, "base_voltage_id"),
        "voltage_level": _get_attr_safe(pl, "voltage_level"),
        "length": _get_attr_safe(pl, "length"),
        "branch_name": _get_attr_safe(pl, "branch_name"),
        "region_name": _get_attr_safe(pl, "region_name"),
        "status": _get_attr_safe(pl, "status", "active"),
        "description": _get_attr_safe(pl, "description"),
        "created_by": _get_attr_safe(pl, "created_by"),
        "created_at": _get_attr_safe(pl, "created_at"),
        "updated_at": _get_attr_safe(pl, "updated_at"),
        "substation_start_id": _get_attr_safe(pl, "substation_start_id"),
        "substation_end_id": _get_attr_safe(pl, "substation_end_id"),
        "poles": [_pole_orm_to_dict(p) for p in poles],
        "acline_segments": [_acline_segment_orm_to_dict(s) for s in acline_segments_sorted],
    }


async def _recompute_power_line_length(db: AsyncSession, power_line_id: int) -> float:
    """Сумма длин всех пролётов линии (м) -> длина в км. Используется для авторасчёта."""
    from sqlalchemy import func as sql_func
    r = await db.execute(
        select(sql_func.coalesce(sql_func.sum(Span.length), 0)).where(Span.line_id == power_line_id)
    )
    total_m = r.scalar() or 0
    return round(float(total_m) / 1000.0, 6)


def _fill_pole_coordinates(pole: Pole) -> None:
    """
    Гарантирует, что у ORM-объекта опоры атрибуты x_position/y_position заданы числом (не None),
    используя CIM-координаты из PositionPoint/Location.
    Нужно для корректной сериализации в PoleResponse, где поля x_position/y_position — float.
    """
    try:
        lon = pole.get_longitude()
        lat = pole.get_latitude()
    except Exception:
        lon = None
        lat = None

    if lon is None:
        lon = 0.0
    if lat is None:
        lat = 0.0

    # object.__setattr__ позволяет не трогать ORM-состояние (не помечать поле изменённым в сессии)
    object.__setattr__(pole, "x_position", float(lon))
    object.__setattr__(pole, "y_position", float(lat))


class LinkLineToSubstationBody(BaseModel):
    """Тело запроса привязки первой опоры линии к подстанции."""
    first_pole_id: int
    substation_id: int


@router.post("", response_model=PowerLineResponse)
async def create_power_line(
    power_line_data: PowerLineCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Создание новой ЛЭП"""
    from app.models.base import generate_mrid
    
    print(f"DEBUG: Получен запрос на создание ЛЭП от пользователя {current_user.id}")
    print(f"DEBUG: Данные запроса: {power_line_data}")
    
    power_line_dict = power_line_data.dict(exclude_unset=True)
    mrid = power_line_dict.pop('mrid', None)
    branch_name = power_line_dict.pop('branch_name', None)
    region_name = power_line_dict.pop('region_name', None)
    
    # Проверяем уникальность mrid, если он указан
    if mrid:
        existing = await db.execute(
            select(PowerLine).where(PowerLine.mrid == mrid)
        )
        if existing.scalar_one_or_none():
            raise HTTPException(status_code=400, detail=f"ЛЭП с UID '{mrid}' уже существует")
    else:
        mrid = generate_mrid()

    # Формируем описание из branch_name и region_name
    description_parts = []
    if branch_name:
        description_parts.append(f"Административная принадлежность: {branch_name}")
    if region_name:
        description_parts.append(f"Географический регион: {region_name}")
    if power_line_dict.get('description'):
        description_parts.append(power_line_dict.get('description'))
    
    final_description = '\n'.join(description_parts) if description_parts else None
    
    # Допустимые стандартные напряжения (кВ), отсортированы
    STANDARD_VOLTAGES_KV = [
        0.23, 0.4, 0.66, 3, 6, 6.3, 6.6, 10, 10.5, 11, 13.8, 15, 15.75, 18, 20, 21, 22, 24,
        27.5, 35, 60, 87, 110, 150, 220, 330, 400, 500, 750, 1150,
    ]
    # Валидация напряжения (диапазон и стандартные значения)
    voltage_level = power_line_dict.get('voltage_level')
    if voltage_level is not None:
        try:
            v = float(voltage_level)
        except (ValueError, TypeError):
            raise HTTPException(
                status_code=400,
                detail="Номинальное напряжение должно быть числом (например: 10, 35, 110).",
            )
        if v < 0:
            raise HTTPException(status_code=400, detail="Напряжение не может быть отрицательным.")
        if v > 1200:
            raise HTTPException(
                status_code=400,
                detail="Номинальное напряжение не должно превышать 1200 кВ. Укажите одно из стандартных значений (см. подсказку в форме).",
            )
        if v != 0:
            voltage_rounded = round(v, 2)
            allowed_set = {round(x, 2) for x in STANDARD_VOLTAGES_KV}
            if voltage_rounded not in allowed_set:
                str_values = ", ".join(str(x) for x in STANDARD_VOLTAGES_KV)
                raise HTTPException(
                    status_code=400,
                    detail=f"Номинальное напряжение должно быть одним из стандартных значений (кВ): {str_values}. Вы ввели: {voltage_rounded} кВ.",
                )
    
    # Если напряжение не указано, устанавливаем значение по умолчанию (0)
    # Это требуется, так как поле voltage_level в модели не nullable
    if 'voltage_level' not in power_line_dict or power_line_dict.get('voltage_level') is None:
        power_line_dict['voltage_level'] = 0.0
    else:
        # Убеждаемся, что voltage_level - это число
        try:
            power_line_dict['voltage_level'] = float(power_line_dict['voltage_level'])
        except (ValueError, TypeError):
            power_line_dict['voltage_level'] = 0.0
    
    # Валидация длины
    length = power_line_dict.get('length')
    if length is not None:
        if length < 0:
            raise HTTPException(status_code=400, detail="Длина не может быть отрицательной")
    
    # Удаляем поля, которые не должны передаваться в модель
    power_line_dict.pop('branch_id', None)
    power_line_dict.pop('region_id', None)
    power_line_dict.pop('base_voltage_id', None)  # в модели нет (зарезервировано под CIM)
    # ВАЖНО: description удаляем в последний момент перед созданием объекта
    # чтобы избежать конфликта с явно передаваемым description=final_description
    
    # Логируем данные перед созданием
    print(f"DEBUG: Создание ЛЭП с данными:")
    print(f"  mrid: {mrid}")
    print(f"  name: {power_line_dict.get('name')}")
    print(f"  voltage_level: {power_line_dict.get('voltage_level')}")
    print(f"  length: {power_line_dict.get('length')}")
    print(f"  status: {power_line_dict.get('status')}")
    print(f"  description: {final_description}")
    print(f"  created_by: {current_user.id}")
    print(f"  Все поля power_line_dict (до удаления description): {power_line_dict}")
    
    # Создаем новый словарь без description, чтобы избежать дублирования
    # Это безопаснее, чем pop(), так как гарантирует отсутствие description
    power_line_dict_clean = {k: v for k, v in power_line_dict.items() if k != 'description'}
    print(f"  Все поля power_line_dict (после удаления description): {power_line_dict_clean}")
    
    try:
        db_power_line = PowerLine(
            mrid=mrid,
            description=final_description,
            created_by=current_user.id,
            **power_line_dict_clean
        )
        db.add(db_power_line)
        await db.commit()
        await db.refresh(db_power_line)
        
        # Загружаем relationships для корректной сериализации ответа
        result = await db.execute(
            select(PowerLine)
            .options(
                selectinload(PowerLine.poles).selectinload(Pole.connectivity_nodes),
                selectinload(PowerLine.acline_segments)
            )
            .where(PowerLine.id == db_power_line.id)
        )
        db_power_line = result.scalar_one()
        for p in getattr(db_power_line, "poles", []) or []:
            fill_pole_coordinates(p)
        object.__setattr__(db_power_line, "length", await _recompute_power_line_length(db, db_power_line.id))
        return PowerLineResponse.model_validate(_power_line_orm_to_dict(db_power_line))
    except Exception as e:
        await db.rollback()
        import traceback
        error_details = traceback.format_exc()
        print(f"Ошибка создания ЛЭП: {e}")
        print(f"Детали ошибки:\n{error_details}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Ошибка создания ЛЭП: {str(e)}"
        )

@router.get("", response_model=List[PowerLineResponse])
async def get_power_lines(
    skip: int = 0,
    limit: int = 100,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение списка ЛЭП"""
    result = await db.execute(
        select(PowerLine)
        .options(
            selectinload(PowerLine.poles).selectinload(Pole.connectivity_nodes),
            selectinload(PowerLine.poles).selectinload(Pole.position_points),
            selectinload(PowerLine.poles).selectinload(Pole.location).selectinload(Location.position_points),
            selectinload(PowerLine.acline_segments).selectinload(AClineSegment.to_node).selectinload(ConnectivityNode.pole),
            selectinload(PowerLine.acline_segments).selectinload(AClineSegment.line_sections).selectinload(LineSection.spans),
            selectinload(PowerLine.acline_segments).selectinload(AClineSegment.terminals),
            selectinload(PowerLine.acline_segments).selectinload(AClineSegment.line)
        )
        .offset(skip)
        .limit(limit)
    )
    power_lines = result.scalars().all()
    
    # Заполняем x_position, y_position у каждой опоры для PoleResponse (иначе валидация падает на None)
    for power_line in power_lines:
        for pole in power_line.poles:
            fill_pole_coordinates(pole)
            if hasattr(pole, '_get_connectivity_node_safe'):
                _ = pole._get_connectivity_node_safe()
            _fill_pole_coordinates(pole)
        # Длина линии — всегда по сумме пролётов (авторасчёт по Span.length)
        computed_length = await _recompute_power_line_length(db, power_line.id)
        object.__setattr__(power_line, "length", computed_length)

    # Сериализуем через dict (чтение только из __dict__), чтобы не вызывать MissingGreenlet при доступе к ORM
    return [PowerLineResponse.model_validate(_power_line_orm_to_dict(pl)) for pl in power_lines]

@router.get("/{power_line_id}", response_model=PowerLineResponse)
async def get_power_line(
    power_line_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение ЛЭП по ID. Возвращает линию с пустыми списками опор/сегментов, если их нет."""
    # Сначала проверяем существование по PK — так линия без опор всегда найдётся
    power_line = await db.get(PowerLine, power_line_id)
    if not power_line:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Power line not found"
        )
    # Подгружаем связи (для линий без опор получим пустые списки)
    try:
        result = await db.execute(
            select(PowerLine)
            .options(
                selectinload(PowerLine.poles).selectinload(Pole.connectivity_nodes),
                selectinload(PowerLine.poles).selectinload(Pole.position_points),
                selectinload(PowerLine.poles).selectinload(Pole.location).selectinload(Location.position_points),
                selectinload(PowerLine.acline_segments).selectinload(AClineSegment.to_node).selectinload(ConnectivityNode.pole),
                selectinload(PowerLine.acline_segments).selectinload(AClineSegment.line_sections).selectinload(LineSection.spans),
                selectinload(PowerLine.acline_segments).selectinload(AClineSegment.terminals),
                selectinload(PowerLine.acline_segments).selectinload(AClineSegment.line)
            )
            .where(PowerLine.id == power_line_id)
        )
        loaded = result.scalar_one_or_none()
        if loaded is not None:
            power_line = loaded
    except Exception:
        # При любой ошибке загрузки связей возвращаем линию с пустыми списками
        await db.refresh(power_line)
    # Чтобы сериализация не падала на None: пустые списки для линий без опор/сегментов
    if getattr(power_line, "poles", None) is None:
        object.__setattr__(power_line, "poles", [])
    if getattr(power_line, "acline_segments", None) is None:
        object.__setattr__(power_line, "acline_segments", [])
    for pole in power_line.poles:
        if hasattr(pole, '_get_connectivity_node_safe'):
            _ = pole._get_connectivity_node_safe()
        _fill_pole_coordinates(pole)
        fill_pole_coordinates(pole)
    # Длина линии — всегда по сумме пролётов (авторасчёт)
    computed_length = await _recompute_power_line_length(db, power_line_id)
    object.__setattr__(power_line, "length", computed_length)
    # Сериализуем через dict (избегаем MissingGreenlet)
    return PowerLineResponse.model_validate(_power_line_orm_to_dict(power_line))


@router.put("/{power_line_id}", response_model=PowerLineResponse)
async def update_power_line(
    power_line_id: int,
    body: PowerLineUpdate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Обновление ЛЭП по ID (название, напряжение, длина, описание и т.д.)."""
    power_line = await db.get(PowerLine, power_line_id)
    if not power_line:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Power line not found",
        )
    data = body.model_dump(exclude_unset=True) if hasattr(body, "model_dump") else body.dict(exclude_unset=True)
    if not data:
        await db.refresh(power_line)
        # Сессия открыта — сериализуем в Pydantic, чтобы не было MissingGreenlet при отдаче
        pl_loaded = await db.execute(
            select(PowerLine)
            .options(
                selectinload(PowerLine.poles).selectinload(Pole.connectivity_nodes),
                selectinload(PowerLine.poles).selectinload(Pole.position_points),
                selectinload(PowerLine.poles).selectinload(Pole.location).selectinload(Location.position_points),
                selectinload(PowerLine.acline_segments).selectinload(AClineSegment.line_sections).selectinload(LineSection.spans),
                selectinload(PowerLine.acline_segments).selectinload(AClineSegment.terminals),
                selectinload(PowerLine.acline_segments).selectinload(AClineSegment.line),
            )
            .where(PowerLine.id == power_line_id),
        )
        pl = pl_loaded.scalar_one()
        for p in getattr(pl, "poles", []) or []:
            fill_pole_coordinates(p)
        object.__setattr__(pl, "length", await _recompute_power_line_length(db, power_line_id))
        return PowerLineResponse.model_validate(_power_line_orm_to_dict(pl))

    STANDARD_VOLTAGES_KV = [
        0.23, 0.4, 0.66, 3, 6, 6.3, 6.6, 10, 10.5, 11, 13.8, 15, 15.75, 18, 20, 21, 22, 24,
        27.5, 35, 60, 87, 110, 150, 220, 330, 400, 500, 750, 1150,
    ]
    if "voltage_level" in data and data["voltage_level"] is not None:
        try:
            v = float(data["voltage_level"])
        except (ValueError, TypeError):
            raise HTTPException(
                status_code=400,
                detail="Номинальное напряжение должно быть числом (например: 10, 35, 110).",
            )
        if v < 0:
            raise HTTPException(status_code=400, detail="Напряжение не может быть отрицательным.")
        if v > 1200:
            raise HTTPException(
                status_code=400,
                detail="Номинальное напряжение не должно превышать 1200 кВ.",
            )
        if v != 0:
            voltage_rounded = round(v, 2)
            allowed_set = {round(x, 2) for x in STANDARD_VOLTAGES_KV}
            if voltage_rounded not in allowed_set:
                str_values = ", ".join(str(x) for x in STANDARD_VOLTAGES_KV)
                raise HTTPException(
                    status_code=400,
                    detail=f"Номинальное напряжение должно быть одним из стандартных значений (кВ): {str_values}. Вы ввели: {voltage_rounded} кВ.",
                )
        data["voltage_level"] = v
    if "length" in data and data["length"] is not None and data["length"] < 0:
        raise HTTPException(status_code=400, detail="Длина не может быть отрицательной")

    for key, value in data.items():
        if hasattr(power_line, key):
            setattr(power_line, key, value)
    await db.commit()
    await db.refresh(power_line)

    # Если привязали подстанцию как начало/конец ЛЭП — создаём пролёт подстанция–опора, если его ещё нет
    if "substation_start_id" in data or "substation_end_id" in data:
        from app.core.line_auto_assembly import link_line_to_substation, add_substation_span_from_last_pole
        # Перечитываем ЛЭП из БД, чтобы гарантированно иметь актуальные substation_*_id
        await db.refresh(power_line)
        sub_start = getattr(power_line, "substation_start_id", None)
        sub_end = getattr(power_line, "substation_end_id", None)
        if sub_start is not None:
            sub_start = int(sub_start)
        if sub_end is not None:
            sub_end = int(sub_end)
        poles_res = await db.execute(
            select(Pole)
            .where(Pole.line_id == power_line_id, Pole.sequence_number.isnot(None), Pole.tap_pole_id.is_(None))
            .order_by(Pole.sequence_number)
            .options(selectinload(Pole.connectivity_nodes), selectinload(Pole.location).selectinload(Location.position_points))
        )
        main_poles = list(poles_res.scalars().all())
        if main_poles:
            if sub_start:
                try:
                    await link_line_to_substation(
                        db, power_line_id, main_poles[0].id, sub_start, current_user.id
                    )
                    await db.commit()
                except ValueError:
                    # Участок подстанция–опора уже есть
                    await db.rollback()
            if sub_end:
                try:
                    await add_substation_span_from_last_pole(
                        db, power_line_id, main_poles[-1], sub_end, current_user.id
                    )
                    await db.commit()
                except Exception:
                    await db.rollback()
        if main_poles and (sub_start or sub_end):
            await db.refresh(power_line)

    result = await db.execute(
        select(PowerLine)
        .options(
            selectinload(PowerLine.poles).selectinload(Pole.connectivity_nodes),
            selectinload(PowerLine.poles).selectinload(Pole.position_points),
            selectinload(PowerLine.poles).selectinload(Pole.location).selectinload(Location.position_points),
            selectinload(PowerLine.acline_segments).selectinload(AClineSegment.line_sections).selectinload(LineSection.spans),
            selectinload(PowerLine.acline_segments).selectinload(AClineSegment.terminals),
            selectinload(PowerLine.acline_segments).selectinload(AClineSegment.line),
        )
        .where(PowerLine.id == power_line_id),
    )
    pl = result.scalar_one()
    for p in getattr(pl, "poles", []) or []:
        fill_pole_coordinates(p)
    object.__setattr__(pl, "length", await _recompute_power_line_length(db, power_line_id))
    return PowerLineResponse.model_validate(_power_line_orm_to_dict(pl))


@router.post("/{power_line_id}/poles", response_model=PoleResponse)
async def create_pole(
    power_line_id: int,
    pole_data: PoleCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Добавление опоры к ЛЭП"""
    
    # Проверка существования ЛЭП
    power_line = await db.get(PowerLine, power_line_id)
    if not power_line:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Power line not found"
        )
    
    # Проверка уникальности mrid, если он передан
    if pole_data.mrid:
        existing_pole = await db.execute(
            select(Pole).where(Pole.mrid == pole_data.mrid)
        )
        if existing_pole.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Pole with mrid '{pole_data.mrid}' already exists"
            )
    
    # CIM: координаты только в PositionPoint, не в таблице pole
    pole_dict = pole_data.dict(exclude={'mrid', 'is_tap', 'x_position', 'y_position', 'id'})
    if pole_data.mrid:
        pole_dict['mrid'] = pole_data.mrid
    pole_dict.pop('id', None)
    if pole_dict.get('pole_number') is not None:
        pole_dict['pole_number'] = normalize_pole_number(pole_dict['pole_number'])
    if getattr(pole_data, 'branch_type', None) is not None:
        pole_dict['branch_type'] = pole_data.branch_type
    if getattr(pole_data, 'tap_pole_id', None) is not None:
        pole_dict['tap_pole_id'] = pole_data.tap_pole_id
    pole_dict.pop('start_new_tap', None)  # не поле БД, только флаг для логики

    lon_val = getattr(pole_data, 'x_position', None)
    lat_val = getattr(pole_data, 'y_position', None)

    def _is_schema_mismatch(err: Exception) -> bool:
        s = str(getattr(err, "orig", err)).lower()
        return "column" in s and ("does not exist" in s or "power_line_id" in s or "latitude" in s or "longitude" in s)

    try:
        db_pole = Pole(
            **pole_dict,
            line_id=power_line_id,
            created_by=current_user.id
        )
        db_pole.is_tap_pole = getattr(pole_data, "is_tap", False)
        db.add(db_pole)
        await db.flush()  # Получаем ID опоры

        # Порядок опоры: если не передан — для отпайки считаем в рамках ветки (tap_branch_index) или новую ветку (start_new_tap)
        if db_pole.sequence_number is None:
            tap_pole_id_val = getattr(db_pole, "tap_pole_id", None)
            if tap_pole_id_val is not None:
                from sqlalchemy import func as sql_func
                start_new_tap = getattr(pole_data, "start_new_tap", False)
                tap_branch_from_request = getattr(pole_data, "tap_branch_index", None)
                if start_new_tap:
                    max_branch = await db.execute(
                        select(sql_func.coalesce(sql_func.max(Pole.tap_branch_index), 0)).where(
                            Pole.line_id == power_line_id, Pole.tap_pole_id == tap_pole_id_val
                        )
                    )
                    max_branch_val = (max_branch.scalar() or 0)
                    db_pole.tap_branch_index = max_branch_val + 1
                    db_pole.sequence_number = 1
                else:
                    if tap_branch_from_request is not None:
                        db_pole.tap_branch_index = tap_branch_from_request
                    else:
                        max_branch = await db.execute(
                            select(sql_func.coalesce(sql_func.max(Pole.tap_branch_index), 0)).where(
                                Pole.line_id == power_line_id, Pole.tap_pole_id == tap_pole_id_val
                            )
                        )
                        max_branch_val = (max_branch.scalar() or 0)
                        db_pole.tap_branch_index = max_branch_val if max_branch_val > 0 else 1
                    # Макс sequence в этой ветке (для обратной совместимости: tap_branch_index NULL считаем как ветка 1)
                    max_seq_q = select(sql_func.coalesce(sql_func.max(Pole.sequence_number), 0)).where(
                        Pole.line_id == power_line_id,
                        Pole.tap_pole_id == tap_pole_id_val,
                    )
                    if db_pole.tap_branch_index == 1:
                        max_seq_q = max_seq_q.where(
                            (Pole.tap_branch_index == 1) | (Pole.tap_branch_index.is_(None))
                        )
                    else:
                        max_seq_q = max_seq_q.where(Pole.tap_branch_index == db_pole.tap_branch_index)
                    max_seq = await db.execute(max_seq_q)
                    db_pole.sequence_number = (max_seq.scalar() or 0) + 1
            else:
                from sqlalchemy import func as sql_func
                max_seq = await db.execute(
                    select(sql_func.coalesce(sql_func.max(Pole.sequence_number), 0)).where(
                        Pole.line_id == power_line_id, Pole.tap_pole_id.is_(None)
                    )
                )
                db_pole.sequence_number = (max_seq.scalar() or 0) + 1
            await db.flush()

        # CIM: координаты только в PositionPoint
        if lon_val is not None and lat_val is not None:
            from app.models.base import generate_mrid
            position_point = PositionPoint(
                mrid=generate_mrid(),
                x_position=float(lon_val),
                y_position=float(lat_val),
                pole_id=db_pole.id
            )
            db.add(position_point)
            await db.flush()

        from app.models.cim_line_structure import ConnectivityNode
        from app.models.base import generate_mrid

        connectivity_node = None
        if pole_data.is_tap:
            connectivity_node = ConnectivityNode(
                mrid=generate_mrid(),
                name=f"Узел {pole_data.pole_number}",
                pole_id=db_pole.id,
                line_id=power_line_id,
                y_position=float(lat_val) if lat_val is not None else 0.0,
                x_position=float(lon_val) if lon_val is not None else 0.0,
                description=f"Узел отпаечной опоры {pole_data.pole_number} линии {power_line_id}",
            )
            db.add(connectivity_node)
            await db.flush()
            db_pole.connectivity_node_id = connectivity_node.id

        # Автоматическое создание пролёта от предыдущей опоры к новой (узлы создаются по требованию)
        try:
            from app.core.line_auto_assembly import auto_create_span

            await auto_create_span(
                db=db,
                power_line_id=power_line_id,
                new_pole=db_pole,
                new_connectivity_node=connectivity_node,
                conductor_type=pole_data.conductor_type,
                conductor_material=pole_data.conductor_material,
                conductor_section=pole_data.conductor_section,
                is_tap=pole_data.is_tap,
                current_user_id=current_user.id
            )
        except Exception as e:
            import traceback
            print(f"Ошибка автоматического создания пролёта: {e}")
            print(traceback.format_exc())

        await db.commit()
    except ProgrammingError as e:
        await db.rollback()
        if _is_schema_mismatch(e):
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=(
                    "Схема БД не совпадает с приложением. Выполните на сервере один раз: "
                    "backend/scripts/align_schema_to_git.sql (см. backend/docs/ALEMBIC_HEADS.md)."
                ),
            ) from e
        raise
    
    # Загружаем опору с relationships для корректной сериализации ответа
    result = await db.execute(
        select(Pole)
        .options(
            selectinload(Pole.connectivity_nodes),
            selectinload(Pole.position_points),
            selectinload(Pole.location).selectinload(Location.position_points),
            selectinload(Pole.line)
        )
        .where(Pole.id == db_pole.id)
    )
    db_pole = result.scalar_one()
    # Для совместимости со схемой и GeoJSON: гарантируем числовые координаты x_position/y_position
    _fill_pole_coordinates(db_pole)
    fill_pole_coordinates(db_pole)
    return db_pole

@router.get("/{power_line_id}/poles", response_model=List[PoleResponse])
async def get_poles(
    power_line_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение опор ЛЭП"""
    result = await db.execute(
        select(Pole)
        .where(Pole.line_id == power_line_id)
        .options(
            selectinload(Pole.connectivity_nodes),
            selectinload(Pole.position_points),
            selectinload(Pole.location).selectinload(Location.position_points),
            selectinload(Pole.line)
        )
    )
    poles = result.scalars().all()
    
    for pole in poles:
        _fill_pole_coordinates(pole)
        fill_pole_coordinates(pole)
    return poles


@router.get("/{power_line_id}/poles/sequence")
async def get_poles_sequence(
    power_line_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Опоры линии в порядке sequence_number (для диалога редактирования пролёта). Маршрут задан явно, чтобы не перехватывался .../poles/{pole_id}."""
    from datetime import datetime, timezone
    from pydantic import ValidationError

    result = await db.execute(
        select(Pole)
        .options(
            selectinload(Pole.connectivity_nodes),
            selectinload(Pole.position_points),
            selectinload(Pole.location).selectinload(Location.position_points),
        )
        .where(Pole.line_id == power_line_id)
        .order_by(Pole.sequence_number.asc().nulls_last(), Pole.pole_number.asc())
    )
    poles = result.scalars().all()
    out = []
    for pole in poles:
        mrid = getattr(pole, "mrid", None) or ""
        pole_number = getattr(pole, "pole_number", None) or ""
        pole_type = getattr(pole, "pole_type", None) or ""
        created_by = getattr(pole, "created_by", None) or 0
        _created_at = getattr(pole, "created_at", None)
        created_at = _created_at.isoformat() if hasattr(_created_at, "isoformat") else datetime.now(timezone.utc).isoformat()
        x_pos = getattr(pole, "x_position", None)
        y_pos = getattr(pole, "y_position", None)
        x_pos = 0.0 if x_pos is None else float(x_pos)
        y_pos = 0.0 if y_pos is None else float(y_pos)
        cn = pole.get_connectivity_node_for_line(power_line_id)
        cn_out = None
        cn_id = None
        if cn is not None and getattr(cn, "pole_id", None) is not None:
            try:
                cn_out = ConnectivityNodeResponse.model_validate(cn).model_dump()
                cn_id = cn.id
            except (ValidationError, TypeError):
                pass
        _updated_at = getattr(pole, "updated_at", None)
        updated_at = _updated_at.isoformat() if _updated_at and hasattr(_updated_at, "isoformat") else None
        out.append({
            "id": pole.id,
            "mrid": mrid,
            "line_id": pole.line_id,
            "connectivity_node_id": cn_id,
            "pole_number": pole_number,
            "pole_type": pole_type,
            "x_position": x_pos,
            "y_position": y_pos,
            "sequence_number": getattr(pole, "sequence_number", None),
            "height": getattr(pole, "height", None),
            "foundation_type": getattr(pole, "foundation_type", None),
            "material": getattr(pole, "material", None),
            "year_installed": getattr(pole, "year_installed", None),
            "condition": getattr(pole, "condition", None) or "good",
            "notes": getattr(pole, "notes", None),
            "conductor_type": getattr(pole, "conductor_type", None),
            "conductor_material": getattr(pole, "conductor_material", None),
            "conductor_section": getattr(pole, "conductor_section", None),
            "is_tap_pole": bool(getattr(pole, "is_tap_pole", False)),
            "branch_type": getattr(pole, "branch_type", None),
            "tap_pole_id": getattr(pole, "tap_pole_id", None),
            "created_by": created_by,
            "created_at": created_at,
            "updated_at": updated_at,
            "connectivity_node": cn_out,
        })
    return out


@router.get("/{power_line_id}/poles/{pole_id}", response_model=PoleResponse)
async def get_pole(
    power_line_id: int,
    pole_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение опоры по ID"""
    result = await db.execute(
        select(Pole)
        .options(
            selectinload(Pole.connectivity_nodes),
            selectinload(Pole.position_points),
            selectinload(Pole.location).selectinload(Location.position_points),
            selectinload(Pole.line)
        )
        .where(Pole.id == pole_id, Pole.line_id == power_line_id)
    )
    pole = result.scalar_one_or_none()
    if not pole:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pole not found"
        )
    _fill_pole_coordinates(pole)
    fill_pole_coordinates(pole)
    return pole


@router.post("/{power_line_id}/link-substation")
async def link_line_to_substation(
    power_line_id: int,
    body: LinkLineToSubstationBody,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Привязка первой опоры ЛЭП к подстанции (по «перетаскиванию» от опоры до ПС на карте).
    Создаёт участок (ACLineSegment) от подстанции до опоры и первый пролёт.
    """
    try:
        from app.core.line_auto_assembly import link_line_to_substation as do_link
        segment = await do_link(
            db=db,
            power_line_id=power_line_id,
            first_pole_id=body.first_pole_id,
            substation_id=body.substation_id,
            current_user_id=current_user.id,
        )
        await db.commit()
        await db.refresh(segment)
        return {"acline_segment_id": segment.id, "name": segment.name}
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


class SegmentSubstationUpdate(BaseModel):
    """Тело запроса: назначить ТП в конце участка (отпайки)."""
    to_substation_id: Optional[int] = None


@router.patch("/{power_line_id}/segments/{segment_id}/substation", status_code=status.HTTP_200_OK)
async def set_segment_end_substation(
    power_line_id: int,
    segment_id: int,
    body: SegmentSubstationUpdate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Назначить или снять подстанцию (ТП) в конце участка линии (отпайки)."""
    power_line = await db.get(PowerLine, power_line_id)
    if not power_line:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Power line not found")
    result = await db.execute(
        select(AClineSegment)
        .where(
            AClineSegment.id == segment_id,
            AClineSegment.line_id == power_line_id,
        )
        .options(
            selectinload(AClineSegment.to_node),
            selectinload(AClineSegment.from_node).selectinload(ConnectivityNode.pole),
            selectinload(AClineSegment.line_sections).selectinload(LineSection.spans),
        )
    )
    segment = result.scalar_one_or_none()
    if not segment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Segment not found")
    segment.to_substation_id = body.to_substation_id
    if body.to_substation_id is not None:
        from app.core.line_auto_assembly import add_substation_span_from_last_pole, extend_tap_segment_to_substation

        last_pole = None

        is_tap_segment = bool(
            getattr(segment, "is_tap", False)
            and ((getattr(segment, "branch_type", None) or "") == "tap" or getattr(segment, "tap_pole_id", None) is not None)
        )

        # Если это отпаечный сегмент, последнюю опору определяем по ветке отпайки,
        # а не по общему списку пролётов (чтобы не получить магистральный пролёт 2–3).
        if is_tap_segment:
            tap_pole_id = getattr(segment, "tap_pole_id", None)
            # Для старых сегментов tap_pole_id может быть пустым — берём отпаечную опору из from_node
            if tap_pole_id is None and getattr(segment, "from_node", None) is not None:
                tap_pole_id = getattr(segment.from_node, "pole_id", None)
            tap_number = (getattr(segment, "tap_number", None) or "").strip()
            tap_branch_index = None
            if tap_number and "/" in tap_number:
                # Форматы вида "3/1", "3/2 а" → берём число после слэша
                try:
                    right = tap_number.split("/", 1)[1].strip()
                    num_str = ""
                    for ch in right:
                        if ch.isdigit():
                            num_str += ch
                        else:
                            break
                    if num_str:
                        tap_branch_index = int(num_str)
                except Exception:
                    tap_branch_index = None

            if tap_pole_id is not None:
                q = select(Pole).where(
                    Pole.line_id == power_line_id,
                    Pole.branch_type == "tap",
                    Pole.tap_pole_id == tap_pole_id,
                )
                if tap_branch_index is not None:
                    q = q.where(Pole.tap_branch_index == tap_branch_index)
                # Последняя опора ветки — с максимальным sequence_number
                q = q.order_by(Pole.sequence_number.desc()).limit(1)
                res_last = await db.execute(q)
                last_pole = res_last.scalar_one_or_none()

        # Общий резервный вариант: если явно не нашли по ветке, пытаемся взять по пролётам сегмента
        if last_pole is None:
            spans = []
            for sec in getattr(segment, "line_sections", []) or []:
                for sp in getattr(sec, "spans", []) or []:
                    spans.append(sp)
            if spans:
                spans_sorted = sorted(spans, key=lambda s: (getattr(s, "sequence_number", 0) or 0))
                last_span = spans_sorted[-1]
                last_pole_id = getattr(last_span, "to_pole_id", None) or getattr(last_span, "from_pole_id", None)
                if last_pole_id:
                    last_pole = await db.get(Pole, last_pole_id)

        # Финальный резерв: если пролётов нет, используем опору, к которой сейчас привязан конец сегмента
        if last_pole is None and segment.to_node and getattr(segment.to_node, "pole_id", None) is not None:
            last_pole = await db.get(Pole, segment.to_node.pole_id)

        if last_pole is not None:
            if is_tap_segment:
                await extend_tap_segment_to_substation(
                    db, power_line_id, segment, last_pole, body.to_substation_id, current_user.id
                )
            else:
                await add_substation_span_from_last_pole(
                    db, power_line_id, last_pole, body.to_substation_id, current_user.id
                )
    await db.commit()
    return {"segment_id": segment_id, "to_substation_id": body.to_substation_id}


@router.put("/{power_line_id}/poles/{pole_id}", response_model=PoleResponse)
async def update_pole(
    power_line_id: int,
    pole_id: int,
    pole_data: PoleCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Обновление опоры"""
    # Базовый лог для отладки обновления опор
    try:
        print(
            f"DEBUG update_pole: power_line_id={power_line_id}, pole_id={pole_id}, "
            f"payload={pole_data.dict(exclude_unset=False)}"
        )
    except Exception:
        # Лог не должен ломать обработчик даже при проблемах сериализации
        pass
    # Проверяем существование ЛЭП
    power_line = await db.get(PowerLine, power_line_id)
    if not power_line:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Power line not found"
        )
    
    # Получаем существующую опору
    result = await db.execute(
        select(Pole)
        .options(
            selectinload(Pole.connectivity_nodes),
            selectinload(Pole.position_points),
            selectinload(Pole.location).selectinload(Location.position_points),
            selectinload(Pole.line)
        )
        .where(Pole.id == pole_id, Pole.line_id == power_line_id)
    )
    pole = result.scalar_one_or_none()
    if not pole:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pole not found"
        )
    
    # Обновляем поля опоры (исключаем mrid, power_line_id, created_by, x_position, y_position)
    # x_position и y_position будут обновлены в PositionPoint
    # CIM: координаты только в PositionPoint, не в pole
    pole_dict = pole_data.dict(exclude_unset=True, exclude={'mrid', 'x_position', 'y_position'})
    # Координаты: приходят в теле, но в соответствии с CIM храним их в PositionPoint и ConnectivityNode,
    # а также дублируем в полях x_position/y_position опоры для быстрого доступа и карты.
    x_position = getattr(pole_data, 'x_position', None) if 'x_position' in pole_data.dict(exclude_unset=True) else None
    y_position = getattr(pole_data, 'y_position', None) if 'y_position' in pole_data.dict(exclude_unset=True) else None
    if "is_tap" in pole_data.dict(exclude_unset=True):
        pole.is_tap_pole = pole_data.is_tap
        # Если опору переводят обратно в магистральную, сбрасываем привязку к отпайке
        if not pole_data.is_tap:
            pole.tap_pole_id = None
            pole.tap_branch_index = None
            pole.branch_type = None
    # Прочие поля ветки/отпайки обновляем только если они есть в payload
    if "branch_type" in pole_dict and pole_data.is_tap:
        pole.branch_type = pole_dict.get("branch_type")
    if "tap_pole_id" in pole_dict and pole_data.is_tap:
        pole.tap_pole_id = pole_dict.get("tap_pole_id")
    if "pole_number" in pole_dict and pole_dict["pole_number"] is not None:
        pole_dict["pole_number"] = normalize_pole_number(pole_dict["pole_number"])
    for key, value in pole_dict.items():
        if hasattr(pole, key) and key != "is_tap" and value is not None:
            setattr(pole, key, value)

    # Обновляем или создаем PositionPoint для координат опоры
    if x_position is not None or y_position is not None:
        from app.models.base import generate_mrid
        
        # Ищем существующий PositionPoint для этой опоры
        existing_point = await db.execute(
            select(PositionPoint).where(PositionPoint.pole_id == pole.id).limit(1)
        )
        position_point = existing_point.scalar_one_or_none()
        
        if position_point:
            # Обновляем существующий
            if x_position is not None:
                position_point.x_position = x_position
            if y_position is not None:
                position_point.y_position = y_position
        else:
            # Создаем новый, если координаты указаны
            if x_position is not None and y_position is not None:
                position_point = PositionPoint(
                    mrid=generate_mrid(),
                    x_position=x_position,
                    y_position=y_position,
                    pole_id=pole.id
                )
                db.add(position_point)
    
    # Обновляем координаты в ConnectivityNode если они изменились
    if x_position is not None or y_position is not None:
        cn = pole.get_connectivity_node_for_line(power_line_id)
        if cn:
            if x_position is not None:
                cn.x_position = x_position
            if y_position is not None:
                cn.y_position = y_position
    
    await db.commit()
    await db.refresh(pole)
    
    # Загружаем опору с relationships для корректной сериализации ответа
    result = await db.execute(
        select(Pole)
        .options(
            selectinload(Pole.connectivity_nodes),
            selectinload(Pole.position_points),
            selectinload(Pole.location).selectinload(Location.position_points),
            selectinload(Pole.line)
        )
        .where(Pole.id == pole_id)
    )
    pole = result.scalar_one()
    
    fill_pole_coordinates(pole)
    # Для обратной совместимости: connectivity_node доступен через @property
    # Не нужно устанавливать через setattr, так как это property
    # Pydantic получит его автоматически через from_attributes=True
    
    return pole

@router.post("/{power_line_id}/spans", response_model=SpanResponse)
async def create_span(
    power_line_id: int,
    span_data: SpanCreate,
    segment_id: Optional[int] = Query(None, description="ID участка (AClineSegment) для создания пролёта"),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Создание пролёта"""
    from app.models.cim_line_structure import ConnectivityNode
    
    # Проверка существования ЛЭП
    power_line = await db.get(PowerLine, power_line_id)
    if not power_line:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Power line not found"
        )
    
    # Получаем опоры с координатами (CIM: position_points)
    r_from = await db.execute(
        select(Pole)
        .options(
            selectinload(Pole.position_points),
            selectinload(Pole.location).selectinload(Location.position_points),
        )
        .where(Pole.id == span_data.from_pole_id)
    )
    r_to = await db.execute(
        select(Pole)
        .options(
            selectinload(Pole.position_points),
            selectinload(Pole.location).selectinload(Location.position_points),
        )
        .where(Pole.id == span_data.to_pole_id)
    )
    from_pole = r_from.scalar_one_or_none()
    to_pole = r_to.scalar_one_or_none()

    if not from_pole or not to_pole:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="One or both poles not found"
        )
    
    # Проверяем, что опоры принадлежат этой линии (или разрешаем совместный подвес)
    if from_pole.line_id != power_line_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"From pole belongs to different power line (line {from_pole.line_id})"
        )
    if to_pole.line_id != power_line_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"To pole belongs to different power line (line {to_pole.line_id})"
        )
    
    # Находим или создаём ConnectivityNode для опор и этой линии
    result_from_node = await db.execute(
        select(ConnectivityNode).where(
            ConnectivityNode.pole_id == from_pole.id,
            ConnectivityNode.line_id == power_line_id
        )
    )
    from_connectivity_node = result_from_node.scalar_one_or_none()
    
    if not from_connectivity_node:
        # Создаём ConnectivityNode для начальной опоры
        from app.models.base import generate_mrid
        from_connectivity_node = ConnectivityNode(
            mrid=generate_mrid(),
            name=f"Узел {from_pole.pole_number}",
            pole_id=from_pole.id,
            line_id=power_line_id,
            y_position=from_pole.get_latitude() or 0.0,
            x_position=from_pole.get_longitude() or 0.0,
            description=f"Узел для опоры {from_pole.pole_number} линии {power_line_id}"
        )
        db.add(from_connectivity_node)
        await db.flush()
    
    result_to_node = await db.execute(
        select(ConnectivityNode).where(
            ConnectivityNode.pole_id == to_pole.id,
            ConnectivityNode.line_id == power_line_id
        )
    )
    to_connectivity_node = result_to_node.scalar_one_or_none()
    
    if not to_connectivity_node:
        # Создаём ConnectivityNode для конечной опоры
        from app.models.base import generate_mrid
        to_connectivity_node = ConnectivityNode(
            mrid=generate_mrid(),
            name=f"Узел {to_pole.pole_number}",
            pole_id=to_pole.id,
            line_id=power_line_id,
            y_position=to_pole.get_latitude() or 0.0,
            x_position=to_pole.get_longitude() or 0.0,
            description=f"Узел для опоры {to_pole.pole_number} линии {power_line_id}"
        )
        db.add(to_connectivity_node)
        await db.flush()
    
    # Создаём или находим LineSection для этого пролёта
    from app.models.cim_line_structure import LineSection
    from app.models.acline_segment import AClineSegment
    
    # Если segment_id передан, используем его; иначе ищем существующий AClineSegment
    if segment_id:
        # Проверяем существование и принадлежность сегмента
        target_segment = await db.get(AClineSegment, segment_id)
        if not target_segment:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Segment not found"
            )
        if target_segment.line_id != power_line_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Segment belongs to different power line"
            )
        use_segment_id = segment_id
    else:
        # Ищем существующий AClineSegment для этой линии
        result_segment = await db.execute(
            select(AClineSegment).where(AClineSegment.line_id == power_line_id).limit(1)
        )
        existing_segment = result_segment.scalar_one_or_none()
        
        if not existing_segment:
            # Создаём временный AClineSegment (единый UID = mrid)
            from app.models.base import generate_mrid
            seg_mrid = generate_mrid()
            temp_segment = AClineSegment(
                mrid=seg_mrid,
                name=f"Сегмент {power_line.name}",
                code=seg_mrid,
                voltage_level=power_line.voltage_level or 0.0,
                length=0.0,
                line_id=power_line_id,
                from_connectivity_node_id=from_connectivity_node.id,
                to_connectivity_node_id=to_connectivity_node.id,
                sequence_number=1,
                created_by=current_user.id
            )
            db.add(temp_segment)
            await db.flush()
            use_segment_id = temp_segment.id
        else:
            use_segment_id = existing_segment.id
    
    # Ищем существующую LineSection для этого сегмента
    result_section = await db.execute(
        select(LineSection).where(LineSection.acline_segment_id == use_segment_id).limit(1)
    )
    existing_section = result_section.scalar_one_or_none()
    
    if not existing_section:
        # Создаём LineSection
        from app.models.base import generate_mrid
        temp_line_section = LineSection(
            mrid=generate_mrid(),
            name=f"Секция линии {power_line.name}",
            acline_segment_id=use_segment_id,
            sequence_number=1,
            conductor_type=span_data.conductor_type or "AC-70",
            conductor_section=span_data.conductor_section or "70",
            created_by=current_user.id,
            description="Автоматически созданная секция для пролётов"
        )
        db.add(temp_line_section)
        await db.flush()
        line_section_id = temp_line_section.id
    else:
        line_section_id = existing_section.id
    
    # Создаём пролёт
    span_dict = span_data.dict()
    span_dict['line_section_id'] = line_section_id
    span_dict['from_connectivity_node_id'] = from_connectivity_node.id
    span_dict['to_connectivity_node_id'] = to_connectivity_node.id
    span_dict['line_id'] = power_line_id
    span_dict['created_by'] = current_user.id
    
    db_span = Span(**span_dict)
    db.add(db_span)
    await db.commit()
    await db.refresh(db_span)
    return db_span

@router.get("/{power_line_id}/spans/{span_id}", response_model=SpanResponse)
async def get_span(
    power_line_id: int,
    span_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение пролёта по ID"""
    # Загружаем пролёт с связанными объектами; pole нужен для pole_number в ConnectivityNodeResponse (избегаем MissingGreenlet)
    result = await db.execute(
        select(Span)
        .options(
            selectinload(Span.from_connectivity_node).selectinload(ConnectivityNode.pole),
            selectinload(Span.to_connectivity_node).selectinload(ConnectivityNode.pole),
            selectinload(Span.line_section).selectinload(LineSection.acline_segment)
        )
        .where(Span.id == span_id)
    )
    span = result.scalar_one_or_none()
    if not span:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Span not found"
        )
    
    # Проверяем, что пролёт принадлежит указанной ЛЭП
    # Проверяем через line_id (если есть) или через line_section -> acline_segment -> line_id
    if span.line_id and span.line_id != power_line_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Span not found in this power line"
        )
    
    # Если line_id не задан, проверяем через line_section
    if not span.line_id and span.line_section and span.line_section.acline_segment:
        if span.line_section.acline_segment.line_id != power_line_id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Span not found in this power line"
            )
    
    # Устанавливаем from_pole_id и to_pole_id для обратной совместимости
    if span.from_connectivity_node:
        span.from_pole_id = span.from_connectivity_node.pole_id
    if span.to_connectivity_node:
        span.to_pole_id = span.to_connectivity_node.pole_id
    
    return span

@router.put("/{power_line_id}/spans/{span_id}", response_model=SpanResponse)
async def update_span(
    power_line_id: int,
    span_id: int,
    span_data: SpanUpdate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Обновление пролёта"""
    # Проверяем существование ЛЭП
    power_line = await db.get(PowerLine, power_line_id)
    if not power_line:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Power line not found"
        )
    
    # Получаем существующий пролёт (с pole для pole_number в ответе)
    result = await db.execute(
        select(Span)
        .options(
            selectinload(Span.from_connectivity_node).selectinload(ConnectivityNode.pole),
            selectinload(Span.to_connectivity_node).selectinload(ConnectivityNode.pole),
            selectinload(Span.line_section)
        )
        .where(Span.id == span_id)
    )
    span = result.scalar_one_or_none()
    if not span:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Span not found"
        )
    
    # Проверяем принадлежность пролёта к ЛЭП
    if span.line_id and span.line_id != power_line_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Span not found in this power line"
        )
    
    # Если power_line_id не задан, проверяем через line_section
    if not span.line_id and span.line_section and span.line_section.acline_segment:
        if span.line_section.acline_segment.line_id != power_line_id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Span not found in this power line"
            )
    
    # Если переданы from_pole_id и to_pole_id, обновляем connectivity_node
    from app.models.cim_line_structure import ConnectivityNode
    
    if span_data.from_pole_id:
        r_f = await db.execute(
            select(Pole)
            .options(
                selectinload(Pole.position_points),
                selectinload(Pole.location).selectinload(Location.position_points),
            )
            .where(Pole.id == span_data.from_pole_id)
        )
        from_pole = r_f.scalar_one_or_none()
        if not from_pole:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="From pole not found"
            )
        
        # Находим или создаём ConnectivityNode для начальной опоры
        result_from_node = await db.execute(
            select(ConnectivityNode).where(
                ConnectivityNode.pole_id == from_pole.id,
                ConnectivityNode.line_id == power_line_id
            )
        )
        from_connectivity_node = result_from_node.scalar_one_or_none()
        
        if not from_connectivity_node:
            from app.models.base import generate_mrid
            from_connectivity_node = ConnectivityNode(
                mrid=generate_mrid(),
                name=f"Узел {from_pole.pole_number}",
                pole_id=from_pole.id,
                line_id=power_line_id,
                y_position=from_pole.get_latitude() or 0.0,
                x_position=from_pole.get_longitude() or 0.0,
                description=f"Узел для опоры {from_pole.pole_number} линии {power_line_id}"
            )
            db.add(from_connectivity_node)
            await db.flush()
        
        span.from_connectivity_node_id = from_connectivity_node.id
        span.from_pole_id = from_pole.id
    
    if span_data.to_pole_id:
        r_t = await db.execute(
            select(Pole)
            .options(
                selectinload(Pole.position_points),
                selectinload(Pole.location).selectinload(Location.position_points),
            )
            .where(Pole.id == span_data.to_pole_id)
        )
        to_pole = r_t.scalar_one_or_none()
        if not to_pole:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="To pole not found"
            )
        
        # Находим или создаём ConnectivityNode для конечной опоры
        result_to_node = await db.execute(
            select(ConnectivityNode).where(
                ConnectivityNode.pole_id == to_pole.id,
                ConnectivityNode.line_id == power_line_id
            )
        )
        to_connectivity_node = result_to_node.scalar_one_or_none()
        
        if not to_connectivity_node:
            from app.models.base import generate_mrid
            to_connectivity_node = ConnectivityNode(
                mrid=generate_mrid(),
                name=f"Узел {to_pole.pole_number}",
                pole_id=to_pole.id,
                line_id=power_line_id,
                y_position=to_pole.get_latitude() or 0.0,
                x_position=to_pole.get_longitude() or 0.0,
                description=f"Узел для опоры {to_pole.pole_number} линии {power_line_id}"
            )
            db.add(to_connectivity_node)
            await db.flush()
        
        span.to_connectivity_node_id = to_connectivity_node.id
        span.to_pole_id = to_pole.id
    
    # Обновляем остальные поля пролёта
    span_dict = span_data.dict(exclude_unset=True, exclude={'from_pole_id', 'to_pole_id', 'line_id'})
    
    for key, value in span_dict.items():
        if hasattr(span, key) and value is not None:
            setattr(span, key, value)
    
    # Обновляем line_id если он был передан
    if span_data.line_id:
        span.line_id = span_data.line_id
    
    await db.commit()
    # Перезагружаем пролёт с pole для сериализации (избегаем MissingGreenlet)
    result = await db.execute(
        select(Span)
        .options(
            selectinload(Span.from_connectivity_node).selectinload(ConnectivityNode.pole),
            selectinload(Span.to_connectivity_node).selectinload(ConnectivityNode.pole),
            selectinload(Span.line_section).selectinload(LineSection.acline_segment)
        )
        .where(Span.id == span_id)
    )
    span = result.scalar_one()
    if span.from_connectivity_node:
        span.from_pole_id = span.from_connectivity_node.pole_id
    if span.to_connectivity_node:
        span.to_pole_id = span.to_connectivity_node.pole_id
    
    return span

@router.delete("/{power_line_id}/spans/{span_id}")
async def delete_span(
    power_line_id: int,
    span_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Удаление пролёта"""
    # Проверяем существование ЛЭП
    power_line = await db.get(PowerLine, power_line_id)
    if not power_line:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Power line not found"
        )
    
    # Получаем существующий пролёт
    result = await db.execute(
        select(Span)
        .options(
            selectinload(Span.from_connectivity_node),
            selectinload(Span.to_connectivity_node),
            selectinload(Span.line_section)
        )
        .where(Span.id == span_id)
    )
    span = result.scalar_one_or_none()
    if not span:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Span not found"
        )
    
    # Проверяем принадлежность пролёта к ЛЭП
    if span.line_id and span.line_id != power_line_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Span not found in this power line"
        )
    
    # Если power_line_id не задан, проверяем через line_section
    if not span.line_id and span.line_section and span.line_section.acline_segment:
        if span.line_section.acline_segment.line_id != power_line_id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Span not found in this power line"
            )
    
    # Удаляем пролёт используя правильный синтаксис SQLAlchemy 2.0 async
    from sqlalchemy import delete
    stmt = delete(Span).where(Span.id == span_id)
    await db.execute(stmt)
    await db.commit()
    
    return {"message": "Span deleted successfully"}

@router.post("/{power_line_id}/spans/auto-create")
async def auto_create_spans(
    power_line_id: int,
    mode: str = Query("preserve", description="full — пересобрать с нуля (удалить существующие); preserve — добавить только недостающие"),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Автоматическое создание пролётов на основе последовательности опор.
    - mode=preserve (по умолчанию): существующие пролёты сохраняются, добавляются только недостающие.
    - mode=full: существующие пролёты и участки линии удаляются, топология строится с нуля.
    Создаёт пролёты между соседними опорами, участки линии (AClineSegment) и секции линии (LineSection).
    """
    from app.models.base import generate_mrid

    # Проверка существования ЛЭП
    power_line = await db.get(PowerLine, power_line_id)
    if not power_line:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Power line not found"
        )
    
    if mode == "full":
        # Сохраняем ТП в конце отпаек (to_substation_id), чтобы восстановить после пересборки
        segs_with_tp = await db.execute(
            select(AClineSegment.tap_pole_id, AClineSegment.tap_number, AClineSegment.to_substation_id).where(
                AClineSegment.line_id == power_line_id,
                AClineSegment.to_substation_id.isnot(None),
            )
        )
        tap_substation_restore = [(r[0], r[1], r[2]) for r in segs_with_tp.all()]
        # Удаляем все пролёты и участки линии для пересборки с нуля
        from app.models.cim_line_structure import LineSection
        segment_ids_subq = select(AClineSegment.id).where(AClineSegment.line_id == power_line_id)
        line_section_ids_subq = select(LineSection.id).where(LineSection.acline_segment_id.in_(segment_ids_subq))
        await db.execute(delete(Span).where(Span.line_section_id.in_(line_section_ids_subq)))
        await db.execute(delete(LineSection).where(LineSection.acline_segment_id.in_(segment_ids_subq)))
        await db.execute(delete(AClineSegment).where(AClineSegment.line_id == power_line_id))
        await db.flush()
    else:
        tap_substation_restore = []
    
    # Получаем опоры с sequence_number (все ветки); подгружаем location/position_points для get_latitude (пересборка с подстанцией)
    result = await db.execute(
        select(Pole)
        .where(Pole.line_id == power_line_id)
        .where(Pole.sequence_number.isnot(None))
        .options(
            selectinload(Pole.connectivity_nodes),
            selectinload(Pole.location).selectinload(Location.position_points),
            selectinload(Pole.position_points),
        )
    )
    all_poles = result.scalars().all()

    # Строим пролёты по ветвям: магистраль (tap_pole_id is None) + каждая отпайка (tap_pole_id = id отпаечной опоры)
    # Магистраль: сортировка по sequence_number
    main_poles = sorted(
        [p for p in all_poles if getattr(p, "tap_pole_id", None) is None],
        key=lambda p: (p.sequence_number or 0),
    )
    # Пары (from_pole, to_pole) для магистрали
    span_pairs: List[Tuple[Pole, Pole]] = []
    for i in range(1, len(main_poles)):
        span_pairs.append((main_poles[i - 1], main_poles[i]))

    # Отпайки: для каждой отпаечной опоры — цепочка от неё к опорам с tap_pole_id = её id
    tap_pole_ids = {getattr(p, "tap_pole_id", None) for p in all_poles if getattr(p, "tap_pole_id", None) is not None}
    poles_by_id = {p.id: p for p in all_poles}
    for tpid in tap_pole_ids:
        tap_pole = poles_by_id.get(tpid)
        if not tap_pole:
            continue
        branch_poles = sorted(
            [p for p in all_poles if getattr(p, "tap_pole_id", None) == tpid],
            key=lambda p: (p.sequence_number or 0),
        )
        if not branch_poles:
            continue
        # Пролёт от отпаечной опоры к первой опоре отпайки
        span_pairs.append((tap_pole, branch_poles[0]))
        for i in range(1, len(branch_poles)):
            span_pairs.append((branch_poles[i - 1], branch_poles[i]))

    poles = all_poles  # для создания узлов ниже
    
    line_name = power_line.name
    if len(span_pairs) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Для создания пролётов необходимо минимум 2 опоры с заданной последовательностью (магистраль или отпайка)"
        )
    
    # Проверяем, что у всех опор есть ConnectivityNode для этой линии
    from app.models.cim_line_structure import ConnectivityNode
    
    for pole in poles:
        # Ищем ConnectivityNode для этой опоры и этой линии
        result_node = await db.execute(
            select(ConnectivityNode).where(
                ConnectivityNode.pole_id == pole.id,
                ConnectivityNode.line_id == power_line_id
            )
        )
        connectivity_node = result_node.scalar_one_or_none()
        
        if not connectivity_node:
            # Если ConnectivityNode нет, создаём его
            connectivity_node = ConnectivityNode(
                mrid=generate_mrid(),
                name=f"Узел {pole.pole_number}",
                pole_id=pole.id,
                line_id=power_line_id,
                y_position=pole.get_latitude(),
                x_position=pole.get_longitude(),
                description=f"Автоматически созданный узел для опоры {pole.pole_number} линии {power_line_id}",
                is_virtual=not getattr(pole, "is_tap_pole", False),
            )
            db.add(connectivity_node)
            await db.flush()
            
            # Обновляем connectivity_node_id в опоре (для обратной совместимости)
            pole.connectivity_node_id = connectivity_node.id
        
        # Сохраняем ConnectivityNode в опоре для использования ниже
        pole._connectivity_node = connectivity_node
    
    # Перечитываем ЛЭП из БД, чтобы гарантированно иметь актуальные substation_start_id/substation_end_id
    await db.refresh(power_line)
    # Пролёты от/до подстанций (если заданы начало и/или конец линии)
    from app.core.line_auto_assembly import link_line_to_substation, add_substation_span_from_last_pole
    substation_start_id = getattr(power_line, "substation_start_id", None)
    substation_end_id = getattr(power_line, "substation_end_id", None)
    if main_poles:
        if substation_start_id:
            try:
                await link_line_to_substation(
                    db, power_line_id, main_poles[0].id, substation_start_id, current_user.id
                )
            except ValueError:
                pass  # участок уже есть
        if substation_end_id and len(main_poles) > 0:
            await add_substation_span_from_last_pole(
                db, power_line_id, main_poles[-1], substation_end_id, current_user.id
            )
    await db.flush()
    
    # Используем ту же логику, что и при пошаговом добавлении опор: создаются
    # участки линии (AClineSegment) по ветвлениям/подстанциям и секции линии
    # (LineSection) по марке провода — через auto_create_span из line_auto_assembly
    from app.core.line_auto_assembly import auto_create_span

    created_spans = []
    for from_pole, to_pole in span_pairs:
        existing_span = await db.execute(
            select(Span).where(
                Span.from_pole_id == from_pole.id,
                Span.to_pole_id == to_pole.id,
                Span.line_id == power_line_id
            )
        )
        if existing_span.scalar_one_or_none():
            continue
        new_cn = getattr(to_pole, "_connectivity_node", None)
        # is_tap: первый пролёт отпайки (от отпаечной опоры к первой опоре ветки 3/1),
        # как при пошаговом создании (pole_data.is_tap=True только для первой опоры отпайки).
        # Признак: у новой опоры задан tap_pole_id (она на отпайке) и sequence_number == 1 в этой ветке.
        is_tap = bool(getattr(to_pole, "tap_pole_id", None) is not None and (to_pole.sequence_number or 0) == 1)
        span = await auto_create_span(
            db,
            power_line_id,
            to_pole,
            new_connectivity_node=new_cn,
            conductor_type=getattr(from_pole, "conductor_type", None),
            conductor_material=getattr(from_pole, "conductor_material", None),
            conductor_section=getattr(from_pole, "conductor_section", None),
            is_tap=is_tap,
            current_user_id=current_user.id,
        )
        if span:
            created_spans.append(span)

    # После построения пролётов и участков создаём/обновляем терминалы оборудования на опорах этой линии.
    # Терминалы T1/T2 автоматически привязываются к ConnectivityNode соответствующих опор.
    await _sync_equipment_terminals_for_line(db, power_line_id)

    # Восстанавливаем ТП в конце отпаек (после полной пересборки)
    for (tap_pid, tap_num, sub_id) in tap_substation_restore:
        if sub_id is None:
            continue
        q = select(AClineSegment).where(
            AClineSegment.line_id == power_line_id,
            AClineSegment.tap_pole_id == tap_pid,
            AClineSegment.to_substation_id.is_(None),
        )
        if tap_num is not None:
            q = q.where(AClineSegment.tap_number == tap_num)
        else:
            q = q.where(AClineSegment.tap_number.is_(None))
        # На всякий случай берём только один "самый поздний" сегмент по sequence_number,
        # чтобы избежать MultipleResultsFound при наличии нескольких подходящих записей.
        q = q.order_by(AClineSegment.sequence_number.desc()).limit(1)

        seg_result = await db.execute(
            q.options(
                selectinload(AClineSegment.to_node).selectinload(ConnectivityNode.pole),
            )
        )
        seg = seg_result.scalar_one_or_none()
        if not seg or not seg.to_node:
            continue
        to_node = seg.to_node
        if getattr(to_node, "pole_id", None) is None:
            continue
        seg.to_substation_id = sub_id
        await db.flush()
        last_pole = await db.get(Pole, to_node.pole_id)
        if last_pole:
            # Для настоящих отпаек (is_tap=True, branch_type='tap' или есть tap_pole_id)
            # расширяем существующий сегмент до подстанции, а не создаём новый.
            is_tap_segment = bool(
                getattr(seg, "is_tap", False)
                and ((getattr(seg, "branch_type", None) or "") == "tap" or getattr(seg, "tap_pole_id", None) is not None)
            )
            if is_tap_segment:
                from app.core.line_auto_assembly import extend_tap_segment_to_substation

                await extend_tap_segment_to_substation(
                    db, power_line_id, seg, last_pole, sub_id, current_user.id
                )
            else:
                await add_substation_span_from_last_pole(
                    db, power_line_id, last_pole, sub_id, current_user.id
                )

    await db.commit()

    # Запись в журнал изменений об автосборке топологии (созданные пролёты/участки)
    if created_spans:
        log_entry = ChangeLog(
            user_id=current_user.id,
            source="web",
            action="create",
            entity_type="power_line",
            entity_id=power_line_id,
            payload={
                "topology_rebuild": True,
                "message": "Автосборка топологии",
                "created_spans": len(created_spans),
                "line_name": line_name,
            },
        )
        db.add(log_entry)
        await db.commit()

    # Обновляем длину ЛЭП по сумме пролётов (авторасчёт)
    power_line = await db.get(PowerLine, power_line_id)
    if power_line:
        power_line.length = await _recompute_power_line_length(db, power_line_id)
        await db.commit()
    
    # Обновляем объекты для возврата
    for span in created_spans:
        await db.refresh(span)
    
    return {
        "message": f"Создано пролётов: {len(created_spans)}",
        "created_count": len(created_spans),
        "spans": created_spans
    }

@router.post("/{power_line_id}/taps", response_model=TapResponse)
async def create_tap(
    power_line_id: int,
    tap_data: TapCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Создание отпайки"""
    
    # Проверка существования ЛЭП
    power_line = await db.get(PowerLine, power_line_id)
    if not power_line:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Power line not found"
        )
    
    tap_dict = tap_data.dict()
    tap_dict["line_id"] = power_line_id
    tap_dict["created_by"] = current_user.id
    db_tap = Tap(**tap_dict)
    db.add(db_tap)
    await db.commit()
    await db.refresh(db_tap)
    return db_tap

@router.delete("/{power_line_id}", status_code=status.HTTP_200_OK)
async def delete_power_line(
    power_line_id: int,
    cascade: bool = Query(True, description="При True удалить ЛЭП и все дочерние объекты; при False — только саму ЛЭП, если дочерних нет"),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Удаление ЛЭП"""
    import traceback
    
    try:
        print(f"DEBUG: Попытка удаления ЛЭП {power_line_id} пользователем {current_user.id}")
        
        # Проверяем существование ЛЭП
        result = await db.execute(
            select(PowerLine).where(PowerLine.id == power_line_id)
        )
        power_line = result.scalar_one_or_none()
        
        if not power_line:
            print(f"DEBUG: ЛЭП {power_line_id} не найдена")
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Power line not found"
            )
        
        print(f"DEBUG: ЛЭП {power_line_id} найдена: {power_line.name}")
        
        # Проверяем связанные объекты перед удалением
        # Загружаем связанные данные для проверки
        from sqlalchemy import func
        from app.models.power_line import Pole, Span, Tap
        from app.models.acline_segment import AClineSegment
        from app.models.cim_line_structure import ConnectivityNode, LineSection
        
        # Подсчитываем связанные объекты
        poles_count = await db.execute(
            select(func.count(Pole.id)).where(Pole.line_id == power_line_id)
        )
        spans_count = await db.execute(
            select(func.count(Span.id)).where(Span.line_id == power_line_id)
        )
        segments_count = await db.execute(
            select(func.count(AClineSegment.id)).where(AClineSegment.line_id == power_line_id)
        )
        
        poles_n = poles_count.scalar() or 0
        spans_n = spans_count.scalar() or 0
        segments_n = segments_count.scalar() or 0
        
        line_name = power_line.name
        print(f"DEBUG: Связанные объекты - Опоры: {poles_n}, Пролёты: {spans_n}, Сегменты: {segments_n}")
        # Удаляем связанные Connection вручную (если они есть)
        from app.models.substation import Connection
        connections_result = await db.execute(
            select(Connection).where(Connection.line_id == power_line_id)
        )
        connections = connections_result.scalars().all()
        for conn in connections:
            await db.delete(conn)
            print(f"DEBUG: Удалено соединение {conn.id}")
        
        if not cascade and (poles_n > 0 or spans_n > 0 or segments_n > 0):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Невозможно удалить только ЛЭП: есть дочерние элементы (опоры, пролёты). Удалите их отдельно или выберите каскадное удаление."
            )
        
        if not cascade and poles_n == 0 and spans_n == 0 and segments_n == 0:
            from app.models.substation import Substation
            patrol_sessions_stmt = delete(PatrolSession).where(PatrolSession.line_id == power_line_id)
            await db.execute(patrol_sessions_stmt)
            substations_result = await db.execute(select(Substation).where(Substation.connected_line_ids.isnot(None)))
            for substation in substations_result.scalars().all():
                if substation.connected_line_ids and power_line_id in substation.connected_line_ids:
                    substation.connected_line_ids = [lid for lid in substation.connected_line_ids if lid != power_line_id]
            await db.delete(power_line)
            await db.commit()
            print(f"DEBUG: ЛЭП {power_line_id} удалена (без дочерних)")
            return {"message": "Power line deleted successfully"}
        
        # Каскадное удаление
        connectivity_nodes_result = await db.execute(
            select(ConnectivityNode).where(ConnectivityNode.line_id == power_line_id)
        )
        connectivity_nodes = connectivity_nodes_result.scalars().all()
        
        # Сначала удаляем ВСЕ пролёты (Span), ссылающиеся на LineSection этой линии,
        # иначе при удалении LineSection получим нарушение FK span_line_section_id_fkey
        segment_ids_subq = select(AClineSegment.id).where(AClineSegment.line_id == power_line_id)
        line_section_ids_subq = select(LineSection.id).where(LineSection.acline_segment_id.in_(segment_ids_subq))
        await db.execute(delete(Span).where(Span.line_section_id.in_(line_section_ids_subq)))
        
        # Для каждого ConnectivityNode нужно удалить связанные объекты
        for cn in connectivity_nodes:
            connectivity_node_id = cn.id
            
            # Удаляем Span, связанные с этим ConnectivityNode
            span_from_stmt = delete(Span).where(Span.from_connectivity_node_id == connectivity_node_id)
            span_to_stmt = delete(Span).where(Span.to_connectivity_node_id == connectivity_node_id)
            await db.execute(span_from_stmt)
            await db.execute(span_to_stmt)
            
            # Получаем AClineSegment, которые начинаются с этого ConnectivityNode
            acline_segments_from = await db.execute(
                select(AClineSegment).where(AClineSegment.from_connectivity_node_id == connectivity_node_id)
            )
            acline_segments_to_delete = list(acline_segments_from.scalars().all())
            
            # Удаляем LineSection для AClineSegment
            for acline_seg in acline_segments_to_delete:
                line_sections_stmt = delete(LineSection).where(LineSection.acline_segment_id == acline_seg.id)
                await db.execute(line_sections_stmt)
            
            # Удаляем AClineSegment, которые начинаются с этого ConnectivityNode
            acline_from_stmt = delete(AClineSegment).where(AClineSegment.from_connectivity_node_id == connectivity_node_id)
            await db.execute(acline_from_stmt)
            
            # Обнуляем to_connectivity_node_id в AClineSegment
            acline_to_update = update(AClineSegment).where(AClineSegment.to_connectivity_node_id == connectivity_node_id).values(to_connectivity_node_id=None)
            await db.execute(acline_to_update)
        
        # Обнуляем connectivity_node_id в опорах перед удалением ConnectivityNode
        for cn in connectivity_nodes:
            connectivity_node_id = cn.id
            pole_update_stmt = update(Pole).where(Pole.connectivity_node_id == connectivity_node_id).values(connectivity_node_id=None)
            await db.execute(pole_update_stmt)
        
        # Удаляем ConnectivityNode
        connectivity_node_stmt = delete(ConnectivityNode).where(ConnectivityNode.line_id == power_line_id)
        await db.execute(connectivity_node_stmt)
        print(f"DEBUG: Удалены ConnectivityNode для ЛЭП {power_line_id}")
        
        # Удаляем сессии обхода, привязанные к этой ЛЭП.
        # В БД колонка могла называться power_line_id (старые версии) или line_id (новые) —
        # поддерживаем оба варианта через сырой SQL и nested-транзакцию.
        try:
            async with db.begin_nested():
                try:
                    await db.execute(
                        text("DELETE FROM patrol_sessions WHERE power_line_id = :id"),
                        {"id": power_line_id},
                    )
                except Exception as e1:
                    err_str = str(e1).lower()
                    if "power_line_id" in err_str and ("does not exist" in err_str or "undefinedcolumn" in err_str):
                        await db.execute(
                            text("DELETE FROM patrol_sessions WHERE line_id = :id"),
                            {"id": power_line_id},
                        )
                    else:
                        raise
            print(f"DEBUG: Удалены сессии обхода для ЛЭП {power_line_id}")
        except Exception as patrol_err:
            err_str = str(patrol_err).lower()
            if "does not exist" in err_str or "undefinedcolumn" in err_str:
                print(f"DEBUG: Не удалось удалить сессии обхода (колонка не найдена), продолжаем")
            else:
                raise
        
        # Убираем эту линию из connected_line_ids у всех подстанций (связь хранится в таблице подстанции)
        from app.models.substation import Substation
        substations_result = await db.execute(select(Substation).where(Substation.connected_line_ids.isnot(None)))
        for substation in substations_result.scalars().all():
            if substation.connected_line_ids and power_line_id in substation.connected_line_ids:
                substation.connected_line_ids = [lid for lid in substation.connected_line_ids if lid != power_line_id]
        
        # Обнуляем самоссылки и ссылки на опоры, чтобы каскадное удаление не упало на FK:
        # Pole.tap_pole_id -> Pole.id и AClineSegment.tap_pole_id -> Pole.id
        await db.execute(update(Pole).where(Pole.line_id == power_line_id).values(tap_pole_id=None))
        await db.execute(update(AClineSegment).where(AClineSegment.line_id == power_line_id).values(tap_pole_id=None))
        
        # Удаляем ЛЭП (каскадное удаление опор, пролётов, отпаек и сегментов настроено в модели)
        # Используем delete через сессию для правильной работы каскадов
        await db.delete(power_line)
        await db.commit()
        
        # Запись в журнал изменений о каскадном удалении (линия + опоры, пролёты, участки)
        if cascade and (poles_n > 0 or spans_n > 0 or segments_n > 0):
            log_entry = ChangeLog(
                user_id=current_user.id,
                source="web",
                action="delete",
                entity_type="power_line",
                entity_id=power_line_id,
                payload={
                    "name": line_name,
                    "cascade": True,
                    "deleted_poles": poles_n,
                    "deleted_spans": spans_n,
                    "deleted_segments": segments_n,
                },
            )
            db.add(log_entry)
            await db.commit()
        
        print(f"DEBUG: ЛЭП {power_line_id} успешно удалена")
        return {"message": "Power line deleted successfully"}
        
    except HTTPException:
        # Пробрасываем HTTP исключения как есть
        raise
    except Exception as e:
        # Логируем полную ошибку для отладки
        error_trace = traceback.format_exc()
        print(f"ERROR: Ошибка при удалении ЛЭП {power_line_id}: {e}")
        print(f"ERROR: Traceback:\n{error_trace}")
        
        # Откатываем транзакцию
        await db.rollback()
        
        # Возвращаем понятное сообщение об ошибке
        error_message = str(e)
        if "foreign key constraint" in error_message.lower() or "violates foreign key" in error_message.lower():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Не удалось удалить ЛЭП: существуют связанные объекты, которые не могут быть удалены автоматически"
            )
        else:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Ошибка при удалении ЛЭП: {error_message}"
            )
