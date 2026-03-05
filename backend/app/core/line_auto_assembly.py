"""
Модуль автоматической сборки линии электропередачи

Логика работы:
1. При создании опоры автоматически создаётся пролёт до предыдущей опоры в последовательности (по sequence_number)
2. Марка провода для пролёта берётся из предыдущей опоры (начальной опоры пролёта)
3. Пролёты группируются в LineSection по марке кабеля (conductor_type)
   - Если марка провода отличается от последней секции - создаётся новая секция
   - Секция содержит последовательные пролёты с одинаковой маркой провода
4. LineSection группируются в AClineSegment от подстанции/ветвления до следующего ветвления/подстанции
5. Ветвление = опора с несколькими соединениями (> 1 пролёта, выходящего из неё)

Пример:
- 5 опор: 1(AC-50), 2(AC-50), 3(AC-70), 4(AC-70), 5(AC-50)
- Пролёты: 1-2(AC-50), 2-3(AC-50), 3-4(AC-70), 4-5(AC-70)
- Секции: 1-3(AC-50), 3-5(AC-70)
"""

import math
import re
from typing import Optional, List, Tuple
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, update, or_
from sqlalchemy.orm import selectinload

from app.models.power_line import Pole, Span
from app.models.cim_line_structure import ConnectivityNode, LineSection
from app.models.acline_segment import AClineSegment
from app.models.substation import Substation
from app.models.location import Location
from app.models.base import generate_mrid


async def get_or_create_connectivity_node_for_pole(
    db: AsyncSession,
    pole: Pole,
    power_line_id: int,
    force: bool = False,
) -> ConnectivityNode:
    """
    Получить или создать ConnectivityNode для опоры в данной линии.

    ВАЖНО: для корректной CIM‑топологии нам нужен ConnectivityNode на каждой опоре,
    которая участвует в пролётах/участках. Поэтому здесь мы больше НЕ ограничиваемся
    только отпаечными опорами: если узла нет — всегда создаём его.

    Параметр force оставлен для совместимости, но сейчас не влияет на логику.
    """
    result = await db.execute(
        select(ConnectivityNode).where(
            ConnectivityNode.pole_id == pole.id,
            ConnectivityNode.line_id == power_line_id,
        )
    )
    node = result.scalar_one_or_none()
    if node:
        return node
    # Обочные опоры — виртуальный CN (только для пролётов, не в CIM). Отпаечные опоры и ПС — реальный CN.
    is_virtual = not getattr(pole, "is_tap_pole", False)
    lat = pole.get_latitude()
    lon = pole.get_longitude()
    node = ConnectivityNode(
        mrid=generate_mrid(),
        name=f"Узел {pole.pole_number}",
        pole_id=pole.id,
        line_id=power_line_id,
        y_position=float(lat) if lat is not None else 0.0,
        x_position=float(lon) if lon is not None else 0.0,
        is_virtual=is_virtual,
    )
    db.add(node)
    await db.flush()
    return node


async def _connectivity_node_display_name(
    db: AsyncSession, connectivity_node_id: int
) -> str:
    """Имя для подписи: «ПС Название» для узла подстанции, иначе «оп. N» или «Опора 3/2»."""
    result = await db.execute(
        select(ConnectivityNode)
        .where(ConnectivityNode.id == connectivity_node_id)
        .options(
            selectinload(ConnectivityNode.substation),
            selectinload(ConnectivityNode.pole),
        )
    )
    node = result.scalar_one_or_none()
    if not node:
        return f"Узел {connectivity_node_id}"
    if getattr(node, "substation_id", None) and node.substation:
        return (node.substation.name or node.substation.dispatcher_name or "ПС")[:50]
    if node.pole:
        raw = (node.pole.pole_number or "").strip() or f"{node.pole.id}"
        # Единообразие с API: «3», «3/2», «3/2 а» -> «Опора 3», «Опора 3/2», «Опора 3/2 а»
        if re.match(r"^\d+$", raw):
            return f"Опора {raw}"
        if re.match(r"^\d+/\s*\d+", raw) or re.match(r"^\d+\s*/\s*\d+", raw):
            return f"Опора {raw}"
        if raw and not raw.lower().startswith(("опора", "оп.")):
            return f"Опора {raw}"
        return raw or f"Опора {node.pole.id}"
    return f"Узел {connectivity_node_id}"


def _short_label_for_span(display_name: str) -> str:
    """Подпись конца пролёта: «Опора 1» / «1» -> «оп.1», «Опора 3/2» -> «оп.3/2», подстанция — без изменения."""
    s = (display_name or "").strip()
    if not s:
        return s
    if s.lower().startswith("опора"):
        rest = s[5:].strip()
        num = rest if rest else ""
        return f"оп.{num}" if num else "оп."
    if re.match(r"^\d+$", s):
        return f"оп.{s}"
    if re.match(r"^\d+/\s*\d+", s) or re.match(r"^\d+\s*/\s*\d+", s):
        return f"оп.{s}"
    return s


def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Вычисление расстояния между двумя GPS координатами по формуле гаверсинуса (Haversine)
    Возвращает расстояние в метрах
    """
    # Радиус Земли в метрах
    R = 6371000
    
    # Преобразование в радианы
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    
    # Формула гаверсинуса
    a = math.sin(delta_phi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    
    distance = R * c
    return distance


async def find_previous_pole(
    db: AsyncSession,
    power_line_id: int,
    current_sequence_number: Optional[int],
    exclude_pole_id: Optional[int] = None,
    tap_pole_id: Optional[int] = None,
    tap_branch_index: Optional[int] = None
) -> Optional[Pole]:
    """
    Найти предыдущую опору в линии по sequence_number или по отпайке.
    Для опоры отпайки (tap_pole_id задан): если tap_branch_index задан — цепочка в рамках одной ветки (3/1 или 3/2);
    при sequence_number==1 предыдущая — отпаечная опора; иначе — опора с тем же tap_pole_id, tap_branch_index и sequence_number-1.
    Если tap_branch_index не задан (обратная совместимость) — одна цепочка по tap_pole_id и sequence_number.
    """
    if tap_pole_id is not None:
        if current_sequence_number == 1:
            result = await db.execute(
                select(Pole)
                .where(Pole.id == tap_pole_id, Pole.line_id == power_line_id)
                .options(selectinload(Pole.connectivity_nodes))
            )
            return result.scalar_one_or_none()
        # Второй и далее по отпайке: предыдущая — опора с тем же tap_pole_id, (tap_branch_index при наличии) и sequence_number = current - 1
        if current_sequence_number is not None and current_sequence_number > 1:
            q = select(Pole).where(
                Pole.line_id == power_line_id,
                Pole.tap_pole_id == tap_pole_id,
                Pole.sequence_number == current_sequence_number - 1
            )
            if tap_branch_index is not None:
                q = q.where(Pole.tap_branch_index == tap_branch_index)
            q = q.options(selectinload(Pole.connectivity_nodes))
            result = await db.execute(q)
            return result.scalar_one_or_none()
        return None

    # Если sequence_number указан, ищем предыдущую опору по последовательности (только та же ветка: магистраль)
    if current_sequence_number is not None:
        # Находим опору с максимальным sequence_number, который меньше текущего (только магистраль — tap_pole_id is None)
        query = select(Pole).where(
            Pole.line_id == power_line_id,
            Pole.sequence_number.isnot(None),
            Pole.sequence_number < current_sequence_number,
            Pole.tap_pole_id.is_(None)
        )
        if exclude_pole_id:
            query = query.where(Pole.id != exclude_pole_id)
        
        query = query.order_by(Pole.sequence_number.desc()).limit(1)
        result = await db.execute(query.options(selectinload(Pole.connectivity_nodes)))
        previous_pole = result.scalar_one_or_none()
        
        if previous_pole:
            return previous_pole
    
    # Если не нашли по sequence_number, используем поиск по ближайшему расстоянию (обратная совместимость)
    # Это нужно для опор, у которых sequence_number не установлен
    query = select(Pole).where(Pole.line_id == power_line_id)
    if exclude_pole_id:
        query = query.where(Pole.id != exclude_pole_id)
    
    result = await db.execute(query.options(selectinload(Pole.connectivity_nodes)))
    poles = result.scalars().all()
    
    if not poles:
        return None
    
    # Находим ближайшую опору (для обратной совместимости)
    # В будущем это можно убрать, когда все опоры будут иметь sequence_number
    nearest_pole = None
    min_distance = float('inf')
    
    # Получаем координаты текущей опоры для поиска ближайшей
    if exclude_pole_id:
        current_pole_result = await db.execute(
            select(Pole).where(Pole.id == exclude_pole_id)
        )
        current_pole = current_pole_result.scalar_one_or_none()
        if current_pole:
            for pole in poles:
                distance = calculate_distance(
                    current_pole.get_latitude(), current_pole.get_longitude(),
                    pole.get_latitude(), pole.get_longitude(),
                )
                if distance < min_distance:
                    min_distance = distance
                    nearest_pole = pole
    
    return nearest_pole


async def is_branching_pole(db: AsyncSession, pole_id: int, power_line_id: int) -> bool:
    """
    Определить, является ли опора точкой ветвления
    Ветвление = опора с несколькими соединениями (> 1 пролёта, выходящего из неё)
    """
    # Получаем все ConnectivityNode для этой опоры в данной линии.
    # После миграции allow_multiple_connectivity_nodes_per_pole таких узлов может быть несколько
    # (виртуальные CN для разных сегментов/отпаек), поэтому scalar_one_or_none здесь использовать нельзя.
    result = await db.execute(
        select(ConnectivityNode.id).where(
            ConnectivityNode.pole_id == pole_id,
            ConnectivityNode.line_id == power_line_id
        )
    )
    cn_ids = [row[0] for row in result.all()]
    if not cn_ids:
        return False

    # Подсчитываем количество пролётов, выходящих из любых CN этой опоры в этой линии.
    # Ветвление = более одного исходящего пролёта.
    result = await db.execute(
        select(func.count(Span.id)).where(Span.from_connectivity_node_id.in_(cn_ids))
    )
    outgoing_spans_count = result.scalar_one() or 0
    return outgoing_spans_count > 1


async def find_or_create_acline_segment(
    db: AsyncSession,
    power_line_id: int,
    from_connectivity_node_id: int,
    voltage_level: float,
    current_user_id: int,
    to_connectivity_node_id_if_tap: Optional[int] = None,
    branch_type: Optional[str] = None,
    tap_pole_id: Optional[int] = None,
) -> AClineSegment:
    """
    Найти или создать AClineSegment от данной опоры.
    
    Если to_connectivity_node_id_if_tap задан (новая опора — первая в отпайке):
    - Не продлеваем основной сегмент до новой опоры.
    - Ищем незавершённый сегмент, начинающийся от from_connectivity_node_id (отпаечная опора); если есть — закрываем его на новой опоре.
    - Иначе создаём новый сегмент отпайки (is_tap=True) от отпаечной опоры до новой.
    Так от одной отпаечной опоры может быть несколько отпаек (3/1, 3/2, 3/3).
    """
    from app.models.power_line import PowerLine

    # Первая опора отпайки: сегмент от отпаечной опоры до новой
    if to_connectivity_node_id_if_tap is not None:
        # Есть ли уже незавершённый сегмент, начинающийся от этой отпаечной опоры? (продолжаем текущую отпайку)
        result = await db.execute(
            select(AClineSegment).where(
                AClineSegment.line_id == power_line_id,
                AClineSegment.from_connectivity_node_id == from_connectivity_node_id,
                AClineSegment.to_connectivity_node_id.is_(None),
                AClineSegment.is_tap == True
            ).order_by(AClineSegment.sequence_number.desc()).limit(1)
        )
        open_tap_segment = result.scalar_one_or_none()
        if open_tap_segment:
            open_tap_segment.to_connectivity_node_id = to_connectivity_node_id_if_tap
            from_name = await _connectivity_node_display_name(db, open_tap_segment.from_connectivity_node_id)
            to_name = await _connectivity_node_display_name(db, to_connectivity_node_id_if_tap)
            open_tap_segment.name = f"{from_name} - {to_name}"
            await db.flush()
            return open_tap_segment
        # Новая отпайка от этой опоры: создаём новый сегмент (is_tap=True)
        power_line = await db.get(PowerLine, power_line_id)
        if not power_line:
            raise ValueError(f"Power line {power_line_id} not found")
        # Номер отпайки: "3/1", "3/2", "3/3" — от номера отпаечной опоры и порядкового номера отпайки
        tap_number_str = None
        if tap_pole_id is not None:
            tap_pole = await db.get(Pole, tap_pole_id)
            if tap_pole:
                result_count = await db.execute(
                    select(func.count(AClineSegment.id)).where(
                        AClineSegment.line_id == power_line_id,
                        AClineSegment.tap_pole_id == tap_pole_id,
                    )
                )
                existing_taps = result_count.scalar_one() or 0
                base = (tap_pole.pole_number or str(tap_pole.sequence_number or 0)).strip()
                tap_number_str = f"{base}/{existing_taps + 1}"
        result = await db.execute(
            select(func.count(AClineSegment.id)).where(AClineSegment.line_id == power_line_id)
        )
        segment_count = result.scalar_one() or 0
        mrid = generate_mrid()
        tap_segment = AClineSegment(
            mrid=mrid,
            name="",
            code=mrid,
            line_id=power_line_id,
            is_tap=True,
            tap_number=tap_number_str,
            from_connectivity_node_id=from_connectivity_node_id,
            to_connectivity_node_id=to_connectivity_node_id_if_tap,
            voltage_level=voltage_level,
            length=0.0,
            sequence_number=segment_count + 1,
            created_by=current_user_id,
            branch_type=branch_type or "tap",
            tap_pole_id=tap_pole_id,
        )
        from_name = await _connectivity_node_display_name(db, from_connectivity_node_id)
        to_name = await _connectivity_node_display_name(db, to_connectivity_node_id_if_tap)
        tap_segment.name = f"{from_name} - {to_name}"
        db.add(tap_segment)
        await db.flush()
        return tap_segment
    
    # Получаем информацию о линии
    power_line = await db.get(PowerLine, power_line_id)
    if not power_line:
        raise ValueError(f"Power line {power_line_id} not found")
    
    # Получаем ConnectivityNode и опору, от которой идём
    result = await db.execute(
        select(ConnectivityNode).where(ConnectivityNode.id == from_connectivity_node_id)
    )
    from_node = result.scalar_one_or_none()
    if not from_node:
        raise ValueError(f"ConnectivityNode {from_connectivity_node_id} not found")
    
    # Определяем структурное ветвление по флагу is_tap_pole на опоре,
    # а не по количеству исходящих пролётов (Span), чтобы магистральный
    # сегмент не обрывался раньше времени (как ПС–оп.2 вместо ПС–оп.3).
    result = await db.execute(
        select(Pole).where(
            Pole.id == from_node.pole_id,
            Pole.line_id == power_line_id
        )
    )
    pole = result.scalar_one_or_none()
    is_branching = bool(getattr(pole, "is_tap_pole", False)) if pole is not None else False
    
    # Проверяем, является ли опора «стартом» магистрали только один раз,
    # когда ещё нет ни одного сегмента в линии.
    is_substation_start = False
    result = await db.execute(
        select(func.count(AClineSegment.id)).where(AClineSegment.line_id == power_line_id)
    )
    total_segments_for_line = result.scalar_one() or 0
    
    result = await db.execute(
        select(func.min(Pole.sequence_number)).where(Pole.line_id == power_line_id)
    )
    min_sequence = result.scalar_one()
    
    if pole and pole.sequence_number == min_sequence and total_segments_for_line == 0:
        # Первая опора первой ЛЭП без сегментов: создаём первый сегмент магистрали
        is_substation_start = True
    
    # Если начало или ветвление - создаём новый сегмент
    if is_substation_start or is_branching:
        result = await db.execute(
            select(func.count(AClineSegment.id)).where(AClineSegment.line_id == power_line_id)
        )
        segment_count = result.scalar_one() or 0
        mrid = generate_mrid()
        segment = AClineSegment(
            mrid=mrid,
            name=f"Сегмент {segment_count + 1} линии {power_line.name}",
            code=mrid,
            line_id=power_line_id,
            is_tap=False,
            from_connectivity_node_id=from_connectivity_node_id,
            to_connectivity_node_id=None,  # Будет установлено при завершении сегмента
            voltage_level=voltage_level,
            length=0.0,  # Будет обновлено при добавлении пролётов
            sequence_number=segment_count + 1,
            created_by=current_user_id,
            branch_type=branch_type,
            tap_pole_id=tap_pole_id,
        )
        db.add(segment)
        await db.flush()
        return segment
    
    # Иначе ищем незавершённый сегмент (to_connectivity_node_id == None) — берём один последний по sequence
    # Сначала: сегмент, который заканчивается на этой опоре (продлеваем его до следующей) — важно для отпаек
    # На отпаечной опоре (ветвлении) НЕ продлеваем сегмент — создаём новый участок для каждой исходящей ветки
    segment_ending_here = None
    if not is_branching:
        result = await db.execute(
            select(AClineSegment).where(
                AClineSegment.line_id == power_line_id,
                AClineSegment.to_connectivity_node_id == from_connectivity_node_id,
            ).order_by(AClineSegment.sequence_number.desc()).limit(1)
        )
        segment_ending_here = result.scalar_one_or_none()
    if segment_ending_here:
        return segment_ending_here

    result = await db.execute(
        select(AClineSegment).where(
            AClineSegment.line_id == power_line_id,
            AClineSegment.to_connectivity_node_id.is_(None),
            AClineSegment.is_tap == False
        ).order_by(AClineSegment.sequence_number.desc()).limit(1)
    )
    existing_segment = result.scalar_one_or_none()
    
    if existing_segment:
        return existing_segment
    
    # Если незавершённого сегмента нет, создаём новый (на случай первой опоры)
    result = await db.execute(
        select(func.count(AClineSegment.id)).where(AClineSegment.line_id == power_line_id)
    )
    segment_count = result.scalar_one() or 0
    mrid = generate_mrid()
    segment = AClineSegment(
        mrid=mrid,
        name=f"Сегмент {segment_count + 1} линии {power_line.name}",
        code=mrid,
        line_id=power_line_id,
        is_tap=False,
        from_connectivity_node_id=from_connectivity_node_id,
        to_connectivity_node_id=None,
        voltage_level=voltage_level,
        length=0.0,
        sequence_number=segment_count + 1,
        created_by=current_user_id,
        branch_type=branch_type,
        tap_pole_id=tap_pole_id,
    )
    db.add(segment)
    await db.flush()
    return segment


async def find_or_create_line_section(
    db: AsyncSession,
    acline_segment_id: int,
    conductor_type: Optional[str],
    conductor_material: Optional[str],
    conductor_section: Optional[str],
    current_user_id: int,
    check_last_section: bool = True
) -> LineSection:
    """
    Найти или создать LineSection в AClineSegment с заданной маркой кабеля
    
    LineSection группирует пролёты с одинаковыми параметрами провода
    
    Если check_last_section=True, проверяет последнюю секцию в сегменте.
    Если марка провода отличается от последней секции, создаёт новую секцию.
    Если марка провода совпадает, возвращает существующую секцию.
    """
    # Если conductor_type не указан, используем значение по умолчанию
    if not conductor_type:
        conductor_type = "AC-70"  # Значение по умолчанию
    
    if not conductor_section:
        conductor_section = "70"  # Значение по умолчанию
    
    if not conductor_material:
        conductor_material = "алюминий"  # Значение по умолчанию
    
    # Получаем последнюю секцию в сегменте (если нужно проверить)
    if check_last_section:
        result = await db.execute(
            select(LineSection).where(
                LineSection.acline_segment_id == acline_segment_id
            ).order_by(LineSection.sequence_number.desc()).limit(1)
        )
        last_section = result.scalar_one_or_none()
        
        # Если последняя секция существует и марка провода совпадает - используем её
        if last_section and last_section.conductor_type == conductor_type and \
           (last_section.conductor_material or "") == (conductor_material or ""):
            return last_section
    
    # Иначе ищем существующую секцию с такими же параметрами в этом сегменте
    result = await db.execute(
        select(LineSection).where(
            LineSection.acline_segment_id == acline_segment_id,
            LineSection.conductor_type == conductor_type,
            LineSection.conductor_material == (conductor_material or "")
        ).order_by(LineSection.sequence_number.desc())
    )
    existing_section = result.scalar_one_or_none()
    
    if existing_section:
        return existing_section
    
    # Создаём новую секцию
    result = await db.execute(
        select(func.count(LineSection.id)).where(LineSection.acline_segment_id == acline_segment_id)
    )
    section_count = result.scalar_one() or 0
    
    section = LineSection(
        mrid=generate_mrid(),
        name=f"Секция {section_count + 1} (провод {conductor_type})",
        acline_segment_id=acline_segment_id,
        conductor_type=conductor_type,
        conductor_material=conductor_material or "алюминий",
        conductor_section=conductor_section,
        sequence_number=section_count + 1,
        total_length=0.0,  # Будет обновлено при добавлении пролётов
        created_by=current_user_id
    )
    db.add(section)
    await db.flush()
    return section


async def auto_create_span(
    db: AsyncSession,
    power_line_id: int,
    new_pole: Pole,
    new_connectivity_node: Optional[ConnectivityNode] = None,
    conductor_type: Optional[str] = None,
    conductor_material: Optional[str] = None,
    conductor_section: Optional[str] = None,
    is_tap: bool = False,
    current_user_id: int = 1
) -> Optional[Span]:
    """
    Автоматически создать пролёт от предыдущей опоры к новой опоре.
    ConnectivityNode для опор создаётся по требованию (только отпаечные получают узел при создании опоры).
    """
    from app.models.power_line import PowerLine

    # Узел новой опоры: передан или создаём по требованию для пролёта.
    if new_connectivity_node is None:
        new_connectivity_node = await get_or_create_connectivity_node_for_pole(
            db, new_pole, power_line_id
        )

    # Находим предыдущую опору по sequence_number (или отпаечную опору, если tap_pole_id задан)
    previous_pole = await find_previous_pole(
        db, power_line_id, new_pole.sequence_number, exclude_pole_id=new_pole.id,
        tap_pole_id=getattr(new_pole, "tap_pole_id", None),
        tap_branch_index=getattr(new_pole, "tap_branch_index", None)
    )

    if not previous_pole:
        return None

    # Узел предыдущей опоры: создаём по требованию, если его ещё нет
    previous_cn = previous_pole.get_connectivity_node_for_line(power_line_id)
    if previous_cn is None:
        previous_cn = await get_or_create_connectivity_node_for_pole(
            db, previous_pole, power_line_id
        )
    
    # Берём марку провода из предыдущей опоры (если не указана явно)
    # Марка провода пролёта определяется по марке провода начальной опоры пролёта
    # Используем getattr для безопасного доступа (на случай, если миграция ещё не применена)
    if not conductor_type:
        conductor_type = getattr(previous_pole, 'conductor_type', None)
    if not conductor_material:
        conductor_material = getattr(previous_pole, 'conductor_material', None)
    if not conductor_section:
        conductor_section = getattr(previous_pole, 'conductor_section', None)
    
    # Вычисляем расстояние между опорами (в метрах)
    distance = calculate_distance(
        previous_pole.get_latitude(), previous_pole.get_longitude(),
        new_pole.get_latitude(), new_pole.get_longitude(),
    )
    
    # Получаем информацию о линии для voltage_level
    power_line = await db.get(PowerLine, power_line_id)
    voltage_level = power_line.voltage_level if power_line else 10.0
    
    # Находим или создаём AClineSegment (если новая опора отпаечная — закрываем текущий участок на ней)
    acline_segment = await find_or_create_acline_segment(
        db, power_line_id, previous_cn.id, voltage_level, current_user_id,
        to_connectivity_node_id_if_tap=new_connectivity_node.id if is_tap else None,
        branch_type=getattr(new_pole, 'branch_type', None),
        tap_pole_id=getattr(new_pole, 'tap_pole_id', None),
    )
    
    # Конец участка (to_connectivity_node) только на реальных CN: отпаечная опора, ПС или оборудование.
    # На обочных опорах CN виртуальный — участок не закрываем, только добавляем пролёт.
    is_real_cn = not getattr(new_connectivity_node, "is_virtual", False)
    if is_real_cn:
        acline_segment.to_connectivity_node_id = new_connectivity_node.id
        from_name = await _connectivity_node_display_name(db, acline_segment.from_connectivity_node_id)
        to_name = await _connectivity_node_display_name(db, new_connectivity_node.id)
        acline_segment.name = f"{from_name} - {to_name}"

    # Находим или создаём LineSection с нужной маркой кабеля
    # check_last_section=True означает, что нужно проверить последнюю секцию
    # и создать новую, если марка провода отличается
    line_section = await find_or_create_line_section(
        db, acline_segment.id, conductor_type, conductor_material, conductor_section, 
        current_user_id, check_last_section=True
    )
    
    # Подсчитываем порядковый номер пролёта в секции
    result = await db.execute(
        select(func.count(Span.id)).where(Span.line_section_id == line_section.id)
    )
    span_count = result.scalar_one() or 0
    
    # Наименование пролёта: «оп.1 - оп.2» или «ПС Название - оп.1»
    from_display = await _connectivity_node_display_name(db, previous_cn.id)
    to_display = await _connectivity_node_display_name(db, new_connectivity_node.id)
    from_short = _short_label_for_span(from_display)
    to_short = _short_label_for_span(to_display)
    span_number = f"{from_short} - {to_short}"

    # Создаём пролёт
    span = Span(
        mrid=generate_mrid(),
        span_number=span_number,
        line_id=power_line_id,
        from_pole_id=previous_pole.id,
        to_pole_id=new_pole.id,
        from_connectivity_node_id=previous_cn.id,
        to_connectivity_node_id=new_connectivity_node.id,
        line_section_id=line_section.id,
        length=distance,  # в метрах
        conductor_type=conductor_type or "AC-70",
        conductor_material=conductor_material or "алюминий",
        sequence_number=span_count + 1,
        created_by=current_user_id
    )
    db.add(span)
    await db.flush()
    
    # Обновляем общую длину секции
    result = await db.execute(
        select(func.sum(Span.length)).where(Span.line_section_id == line_section.id)
    )
    total_length = result.scalar_one() or 0.0
    line_section.total_length = total_length / 1000.0  # Переводим в километры
    
    # Обновляем общую длину сегмента
    result = await db.execute(
        select(func.sum(LineSection.total_length)).where(LineSection.acline_segment_id == acline_segment.id)
    )
    segment_length = result.scalar_one() or 0.0
    acline_segment.length = segment_length
    
    await db.flush()
    
    return span


async def link_line_to_substation(
    db: AsyncSession,
    power_line_id: int,
    first_pole_id: int,
    substation_id: int,
    current_user_id: int,
) -> AClineSegment:
    """
    Привязка первой опоры линии к подстанции (по «перетаскиванию» на карте).
    Создаёт ACLineSegment от подстанции до первой опоры и первый пролёт.
    """
    from app.models.power_line import PowerLine

    power_line = await db.get(PowerLine, power_line_id)
    if not power_line:
        raise ValueError(f"ЛЭП {power_line_id} не найдена")
    # Подгружаем location/position_points, чтобы get_latitude/get_longitude не вызывали lazy load (greenlet)
    substation_result = await db.execute(
        select(Substation)
        .where(Substation.id == substation_id)
        .options(selectinload(Substation.location).selectinload(Location.position_points))
    )
    substation = substation_result.scalar_one_or_none()
    if not substation:
        raise ValueError(f"Подстанция {substation_id} не найдена")
    pole_result = await db.execute(
        select(Pole)
        .where(Pole.id == first_pole_id, Pole.line_id == power_line_id)
        .options(
            selectinload(Pole.connectivity_nodes),
            selectinload(Pole.location).selectinload(Location.position_points),
            selectinload(Pole.position_points),
        )
    )
    first_pole = pole_result.scalar_one_or_none()
    if not first_pole:
        raise ValueError(f"Опора {first_pole_id} не найдена или не принадлежит ЛЭП {power_line_id}")

    first_cn = first_pole.get_connectivity_node_for_line(power_line_id)
    if first_cn is None:
        # Для опоры, к которой привязываем подстанцию, CN создаём принудительно
        first_cn = await get_or_create_connectivity_node_for_pole(
            db, first_pole, power_line_id, force=True
        )

    sub_lat = substation.get_latitude()
    sub_lon = substation.get_longitude()
    if sub_lat == 0 and sub_lon == 0:
        sub_lat = first_cn.y_position
        sub_lon = first_cn.x_position

    # Узел подстанции для этой линии (один на пару линия–подстанция)
    result = await db.execute(
        select(ConnectivityNode).where(
            ConnectivityNode.substation_id == substation_id,
            ConnectivityNode.line_id == power_line_id,
        )
    )
    substation_cn = result.scalar_one_or_none()
    if not substation_cn:
        substation_cn = ConnectivityNode(
            mrid=generate_mrid(),
            name=substation.name or substation.dispatcher_name or "ПС",
            pole_id=None,
            line_id=power_line_id,
            y_position=float(sub_lat),
            x_position=float(sub_lon),
            substation_id=substation_id,
        )
        db.add(substation_cn)
        await db.flush()

    # Есть ли уже сегмент от этой подстанции до этой опоры (или открытый сегмент от ПС)
    result = await db.execute(
        select(AClineSegment).where(
            AClineSegment.line_id == power_line_id,
            AClineSegment.from_connectivity_node_id == substation_cn.id,
            or_(
                AClineSegment.to_connectivity_node_id == first_cn.id,
                AClineSegment.to_connectivity_node_id.is_(None),
            ),
        )
    )
    if result.scalars().first():
        raise ValueError("Участок от этой подстанции до этой опоры уже создан")

    mrid_seg = generate_mrid()
    segment_count_result = await db.execute(
        select(func.count(AClineSegment.id)).where(AClineSegment.line_id == power_line_id)
    )
    segment_count = segment_count_result.scalar_one() or 0

    # Сегмент от подстанции до первой опоры всегда первый по порядку (sequence_number=1)
    from app.models.acline_segment import AClineSegment as ACS
    await db.execute(
        update(ACS).where(ACS.line_id == power_line_id).values(sequence_number=ACS.sequence_number + 1)
    )
    await db.flush()

    from_name = await _connectivity_node_display_name(db, substation_cn.id)
    to_name = await _connectivity_node_display_name(db, first_cn.id)
    # Конец участка только на реальном CN (отпаечная опора/оборудование); обочная опора — виртуальный CN, участок остаётся открытым
    first_cn_real = not getattr(first_cn, "is_virtual", False)
    to_cn_id = first_cn.id if first_cn_real else None
    segment_name = f"{from_name} - {to_name}" if to_cn_id else f"{from_name} - ..."

    segment = AClineSegment(
        mrid=mrid_seg,
        name=segment_name,
        code=mrid_seg,
        line_id=power_line_id,
        is_tap=False,
        from_connectivity_node_id=substation_cn.id,
        to_connectivity_node_id=to_cn_id,
        voltage_level=power_line.voltage_level or 10.0,
        length=0.0,
        sequence_number=1,
        created_by=current_user_id,
    )
    db.add(segment)
    await db.flush()

    conductor_type = getattr(first_pole, "conductor_type", None) or "AC-70"
    conductor_material = getattr(first_pole, "conductor_material", None) or "алюминий"
    conductor_section = getattr(first_pole, "conductor_section", None) or "70"

    line_section = await find_or_create_line_section(
        db, segment.id, conductor_type, conductor_material, conductor_section,
        current_user_id, check_last_section=False
    )
    line_section.name = f"{from_name} - {to_name} ({conductor_type})"
    await db.flush()

    distance = calculate_distance(
        float(sub_lat), float(sub_lon),
        first_pole.get_latitude() or 0, first_pole.get_longitude() or 0,
    )
    span_number = f"{_short_label_for_span(from_name)} - {_short_label_for_span(to_name)}"

    span = Span(
        mrid=generate_mrid(),
        span_number=span_number,
        line_id=power_line_id,
        from_pole_id=None,
        to_pole_id=first_pole.id,
        from_connectivity_node_id=substation_cn.id,
        to_connectivity_node_id=first_cn.id,
        line_section_id=line_section.id,
        length=distance,
        conductor_type=conductor_type,
        conductor_material=conductor_material,
        conductor_section=conductor_section,
        sequence_number=1,
        created_by=current_user_id,
    )
    db.add(span)
    await db.flush()

    line_section.total_length = distance / 1000.0
    segment.length = distance / 1000.0
    await db.flush()

    # Связь линии с подстанцией (Connection) для второго разработчика
    from app.models.substation import Connection
    conn_result = await db.execute(
        select(Connection).where(
            Connection.line_id == power_line_id,
            Connection.substation_id == substation_id,
        )
    )
    if conn_result.scalar_one_or_none() is None:
        conn = Connection(
            mrid=generate_mrid(),
            substation_id=substation_id,
            line_id=power_line_id,
            connection_type="output",
            voltage_level=power_line.voltage_level or 10.0,
        )
        db.add(conn)

    return segment


async def add_substation_span_from_last_pole(
    db: AsyncSession,
    power_line_id: int,
    last_pole: Pole,
    substation_id: int,
    current_user_id: int,
) -> Optional[AClineSegment]:
    """
    Создать участок и пролёт от последней опоры линии до подстанции (конец линии).
    Используется при пересборке топологии, если у линии задана подстанция в конце.
    """
    from app.models.power_line import PowerLine

    power_line = await db.get(PowerLine, power_line_id)
    if not power_line:
        return None
    substation_result = await db.execute(
        select(Substation)
        .where(Substation.id == substation_id)
        .options(selectinload(Substation.location).selectinload(Location.position_points))
    )
    substation = substation_result.scalar_one_or_none()
    if not substation:
        return None

    last_cn = last_pole.get_connectivity_node_for_line(power_line_id)
    if last_cn is None:
        # Для последней опоры перед подстанцией CN создаём принудительно
        last_cn = await get_or_create_connectivity_node_for_pole(
            db, last_pole, power_line_id, force=True
        )

    sub_lat = substation.get_latitude()
    sub_lon = substation.get_longitude()
    if sub_lat == 0 and sub_lon == 0:
        sub_lat = last_cn.y_position
        sub_lon = last_cn.x_position

    result = await db.execute(
        select(ConnectivityNode).where(
            ConnectivityNode.substation_id == substation_id,
            ConnectivityNode.line_id == power_line_id,
        )
    )
    substation_cn = result.scalar_one_or_none()
    if not substation_cn:
        substation_cn = ConnectivityNode(
            mrid=generate_mrid(),
            name=substation.name or substation.dispatcher_name or "ПС",
            pole_id=None,
            line_id=power_line_id,
            y_position=float(sub_lat),
            x_position=float(sub_lon),
            substation_id=substation_id,
        )
        db.add(substation_cn)
        await db.flush()

    existing = await db.execute(
        select(AClineSegment).where(
            AClineSegment.line_id == power_line_id,
            AClineSegment.from_connectivity_node_id == last_cn.id,
            AClineSegment.to_connectivity_node_id == substation_cn.id,
        )
    )
    if existing.scalar_one_or_none():
        return None

    segment_count_result = await db.execute(
        select(func.count(AClineSegment.id)).where(AClineSegment.line_id == power_line_id)
    )
    segment_count = segment_count_result.scalar_one() or 0
    from_name = await _connectivity_node_display_name(db, last_cn.id)
    to_name = await _connectivity_node_display_name(db, substation_cn.id)
    mrid_seg = generate_mrid()
    segment = AClineSegment(
        mrid=mrid_seg,
        name=f"{from_name} - {to_name}",
        code=mrid_seg,
        line_id=power_line_id,
        is_tap=False,
        from_connectivity_node_id=last_cn.id,
        to_connectivity_node_id=substation_cn.id,
        voltage_level=power_line.voltage_level or 10.0,
        length=0.0,
        sequence_number=segment_count + 1,
        created_by=current_user_id,
    )
    db.add(segment)
    await db.flush()

    conductor_type = getattr(last_pole, "conductor_type", None) or "AC-70"
    conductor_material = getattr(last_pole, "conductor_material", None) or "алюминий"
    conductor_section = getattr(last_pole, "conductor_section", None) or "70"
    line_section = await find_or_create_line_section(
        db, segment.id, conductor_type, conductor_material, conductor_section,
        current_user_id, check_last_section=False
    )
    line_section.name = f"{from_name} - {to_name} ({conductor_type})"
    await db.flush()

    distance = calculate_distance(
        last_pole.get_latitude() or 0, last_pole.get_longitude() or 0,
        float(sub_lat), float(sub_lon),
    )
    span = Span(
        mrid=generate_mrid(),
        span_number=f"{_short_label_for_span(from_name)} - {_short_label_for_span(to_name)}",
        line_id=power_line_id,
        from_pole_id=last_pole.id,
        to_pole_id=None,
        from_connectivity_node_id=last_cn.id,
        to_connectivity_node_id=substation_cn.id,
        line_section_id=line_section.id,
        length=distance,
        conductor_type=conductor_type,
        conductor_material=conductor_material,
        conductor_section=conductor_section,
        sequence_number=1,
        created_by=current_user_id,
    )
    db.add(span)
    await db.flush()
    line_section.total_length = distance / 1000.0
    segment.length = distance / 1000.0
    await db.flush()
    return segment


async def extend_tap_segment_to_substation(
    db: AsyncSession,
    power_line_id: int,
    segment: AClineSegment,
    last_pole: Pole,
    substation_id: int,
    current_user_id: int,
) -> Optional[AClineSegment]:
    """
    Расширить уже существующий отпаечный участок (AClineSegment.is_tap=True) до подстанции.

    В отличие от add_substation_span_from_last_pole НЕ создаёт новый AClineSegment, а:
    - находит/создаёт ConnectivityNode подстанции для этой линии;
    - добавляет пролёт last_pole -> ПС внутрь переданного сегмента;
    - обновляет to_connectivity_node_id и to_substation_id у этого сегмента.
    """
    from app.models.power_line import PowerLine

    power_line = await db.get(PowerLine, power_line_id)
    if not power_line:
        return None

    substation_result = await db.execute(
        select(Substation)
        .where(Substation.id == substation_id)
        .options(selectinload(Substation.location).selectinload(Location.position_points))
    )
    substation = substation_result.scalar_one_or_none()
    if not substation:
        return None

    last_cn = last_pole.get_connectivity_node_for_line(power_line_id)
    if last_cn is None:
        last_cn = await get_or_create_connectivity_node_for_pole(
            db, last_pole, power_line_id, force=True
        )

    sub_lat = substation.get_latitude()
    sub_lon = substation.get_longitude()
    if sub_lat == 0 and sub_lon == 0:
        sub_lat = last_cn.y_position
        sub_lon = last_cn.x_position

    # CN подстанции для этой линии
    result = await db.execute(
        select(ConnectivityNode).where(
            ConnectivityNode.substation_id == substation_id,
            ConnectivityNode.line_id == power_line_id,
        )
    )
    substation_cn = result.scalar_one_or_none()
    if not substation_cn:
        substation_cn = ConnectivityNode(
            mrid=generate_mrid(),
            name=substation.name or substation.dispatcher_name or "ПС",
            pole_id=None,
            line_id=power_line_id,
            y_position=float(sub_lat),
            x_position=float(sub_lon),
            substation_id=substation_id,
        )
        db.add(substation_cn)
        await db.flush()

    # Если сегмент уже заканчивается на этой подстанции и пролёт ПС уже есть — ничего не делаем.
    if (
        getattr(segment, "to_connectivity_node_id", None) == substation_cn.id
        and any(
            getattr(sp, "to_connectivity_node_id", None) == substation_cn.id
            for sec in getattr(segment, "line_sections", []) or []
            for sp in getattr(sec, "spans", []) or []
        )
    ):
        return segment

    conductor_type = getattr(last_pole, "conductor_type", None) or "AC-70"
    conductor_material = getattr(last_pole, "conductor_material", None) or "алюминий"
    conductor_section = getattr(last_pole, "conductor_section", None) or "70"

    line_section = await find_or_create_line_section(
        db, segment.id, conductor_type, conductor_material, conductor_section,
        current_user_id, check_last_section=False
    )

    # Имя для пролёта берём от последней опоры ветки (last_pole),
    # а имя участка — от начала сегмента (segment.from_connectivity_node_id).
    from_name_span = await _connectivity_node_display_name(db, last_cn.id)
    to_name = await _connectivity_node_display_name(db, substation_cn.id)

    distance = calculate_distance(
        last_pole.get_latitude() or 0, last_pole.get_longitude() or 0,
        float(sub_lat), float(sub_lon),
    )

    # Следующий sequence_number внутри секции
    result = await db.execute(
        select(func.count(Span.id)).where(Span.line_section_id == line_section.id)
    )
    span_count = result.scalar_one() or 0

    span = Span(
        mrid=generate_mrid(),
        span_number=f"{_short_label_for_span(from_name_span)} - {_short_label_for_span(to_name)}",
        line_id=power_line_id,
        from_pole_id=last_pole.id,
        to_pole_id=None,
        from_connectivity_node_id=last_cn.id,
        to_connectivity_node_id=substation_cn.id,
        line_section_id=line_section.id,
        length=distance,
        conductor_type=conductor_type,
        conductor_material=conductor_material,
        conductor_section=conductor_section,
        sequence_number=span_count + 1,
        created_by=current_user_id,
    )
    db.add(span)
    await db.flush()

    # Обновляем длину секции/сегмента и конец сегмента на ПС
    result = await db.execute(
        select(func.sum(Span.length)).where(Span.line_section_id == line_section.id)
    )
    total_length = result.scalar_one() or 0.0
    line_section.total_length = total_length / 1000.0

    result = await db.execute(
        select(func.sum(LineSection.total_length)).where(LineSection.acline_segment_id == segment.id)
    )
    segment.length = result.scalar_one() or 0.0
    # Обновляем имя участка, чтобы оно отражало привязку от начала сегмента до подстанции
    seg_from_cn_id = getattr(segment, "from_connectivity_node_id", None)
    if seg_from_cn_id:
        from_name_segment = await _connectivity_node_display_name(db, seg_from_cn_id)
    else:
        from_name_segment = from_name_span
    segment.name = f"{from_name_segment} - {to_name}"
    segment.to_connectivity_node_id = substation_cn.id

    await db.flush()
    return segment