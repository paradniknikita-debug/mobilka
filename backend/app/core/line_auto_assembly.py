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
from typing import Optional, List, Tuple
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload

from app.models.power_line import Pole, Span
from app.models.cim_line_structure import ConnectivityNode, LineSection
from app.models.acline_segment import AClineSegment
from app.models.substation import Substation, Connection
from app.models.base import generate_mrid


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
    exclude_pole_id: Optional[int] = None
) -> Optional[Pole]:
    """
    Найти предыдущую опору в линии по sequence_number
    Используется для автоматического создания пролёта к предыдущей опоре в последовательности
    
    Если sequence_number не указан, использует поиск по ближайшему расстоянию (для обратной совместимости)
    """
    # Если sequence_number указан, ищем предыдущую опору по последовательности
    if current_sequence_number is not None:
        # Находим опору с максимальным sequence_number, который меньше текущего
        query = select(Pole).where(
            Pole.power_line_id == power_line_id,
            Pole.sequence_number.isnot(None),
            Pole.sequence_number < current_sequence_number
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
    query = select(Pole).where(Pole.power_line_id == power_line_id)
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
                    current_pole.latitude, current_pole.longitude,
                    pole.latitude, pole.longitude
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
    # Получаем ConnectivityNode для опоры в данной линии
    result = await db.execute(
        select(ConnectivityNode).where(
            ConnectivityNode.pole_id == pole_id,
            ConnectivityNode.power_line_id == power_line_id
        )
    )
    connectivity_node = result.scalar_one_or_none()
    
    if not connectivity_node:
        return False
    
    # Подсчитываем количество пролётов, выходящих из этого узла
    result = await db.execute(
        select(func.count(Span.id)).where(Span.from_connectivity_node_id == connectivity_node.id)
    )
    outgoing_spans_count = result.scalar_one()
    
    # Ветвление = более одного выходящего пролёта
    return outgoing_spans_count > 1


async def find_or_create_acline_segment(
    db: AsyncSession,
    power_line_id: int,
    from_connectivity_node_id: int,
    voltage_level: float,
    current_user_id: int
) -> AClineSegment:
    """
    Найти или создать AClineSegment от данной опоры
    
    Логика:
    - Если опора является ветвлением, создаётся новый AClineSegment от неё
    - Если опора не является ветвлением, ищем существующий незавершённый AClineSegment
    - AClineSegment создаётся от подстанции/ветвления до следующего ветвления/подстанции
    """
    from app.models.power_line import PowerLine
    
    # Получаем информацию о линии
    power_line = await db.get(PowerLine, power_line_id)
    if not power_line:
        raise ValueError(f"Power line {power_line_id} not found")
    
    # Проверяем, является ли опора ветвлением
    # Получаем ConnectivityNode
    result = await db.execute(
        select(ConnectivityNode).where(ConnectivityNode.id == from_connectivity_node_id)
    )
    from_node = result.scalar_one_or_none()
    if not from_node:
        raise ValueError(f"ConnectivityNode {from_connectivity_node_id} not found")
    
    is_branching = await is_branching_pole(db, from_node.pole_id, power_line_id)
    
    # Если опора является ветвлением или начало линии (подстанция), создаём новый сегмент
    # Ищем подключение к подстанции
    is_substation_start = False
    result = await db.execute(
        select(Connection).where(Connection.power_line_id == power_line_id)
    )
    connections = result.scalars().all()
    
    # Проверяем, подключена ли линия к подстанции через эту опору
    # (упрощённо: если это первая опора в линии или опора с sequence_number = 1)
    result = await db.execute(
        select(func.min(Pole.sequence_number)).where(Pole.power_line_id == power_line_id)
    )
    min_sequence = result.scalar_one()
    
    result = await db.execute(
        select(Pole).where(
            Pole.id == from_node.pole_id,
            Pole.power_line_id == power_line_id
        )
    )
    pole = result.scalar_one_or_none()
    if pole and pole.sequence_number == min_sequence:
        is_substation_start = True
    
    # Если начало или ветвление - создаём новый сегмент
    if is_substation_start or is_branching:
        # Генерируем код для сегмента
        result = await db.execute(
            select(func.count(AClineSegment.id)).where(AClineSegment.power_line_id == power_line_id)
        )
        segment_count = result.scalar_one() or 0
        code = f"{power_line.code}-SEG-{segment_count + 1}"
        
        # Создаём новый AClineSegment
        segment = AClineSegment(
            mrid=generate_mrid(),
            name=f"Сегмент {segment_count + 1} линии {power_line.name}",
            code=code,
            power_line_id=power_line_id,
            is_tap=False,
            from_connectivity_node_id=from_connectivity_node_id,
            to_connectivity_node_id=None,  # Будет установлено при завершении сегмента
            voltage_level=voltage_level,
            length=0.0,  # Будет обновлено при добавлении пролётов
            sequence_number=segment_count + 1,
            created_by=current_user_id
        )
        db.add(segment)
        await db.flush()
        return segment
    
    # Иначе ищем незавершённый сегмент (to_connectivity_node_id == None)
    result = await db.execute(
        select(AClineSegment).where(
            AClineSegment.power_line_id == power_line_id,
            AClineSegment.to_connectivity_node_id.is_(None),
            AClineSegment.is_tap == False
        ).order_by(AClineSegment.sequence_number.desc())
    )
    existing_segment = result.scalar_one_or_none()
    
    if existing_segment:
        return existing_segment
    
    # Если незавершённого сегмента нет, создаём новый (на случай первой опоры)
    result = await db.execute(
        select(func.count(AClineSegment.id)).where(AClineSegment.power_line_id == power_line_id)
    )
    segment_count = result.scalar_one() or 0
    code = f"{power_line.code}-SEG-{segment_count + 1}"
    
    segment = AClineSegment(
        mrid=generate_mrid(),
        name=f"Сегмент {segment_count + 1} линии {power_line.name}",
        code=code,
        power_line_id=power_line_id,
        is_tap=False,
        from_connectivity_node_id=from_connectivity_node_id,
        to_connectivity_node_id=None,
        voltage_level=voltage_level,
        length=0.0,
        sequence_number=segment_count + 1,
        created_by=current_user_id
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
    new_connectivity_node: ConnectivityNode,
    conductor_type: Optional[str] = None,
    conductor_material: Optional[str] = None,
    conductor_section: Optional[str] = None,
    is_tap: bool = False,
    current_user_id: int = 1
) -> Optional[Span]:
    """
    Автоматически создать пролёт от предыдущей опоры к новой опоре
    
    Логика:
    1. Находит предыдущую опору в линии по sequence_number (или ближайшую, если sequence_number не указан)
    2. Берёт марку провода из предыдущей опоры (если не указана явно)
    3. Создаёт Span между опорами
    4. Группирует в LineSection по марке кабеля (создаёт новую секцию, если марка провода изменилась)
    5. Добавляет в AClineSegment от подстанции/ветвления до следующего ветвления/подстанции
    """
    from app.models.power_line import PowerLine
    
    # Находим предыдущую опору по sequence_number (или ближайшую для обратной совместимости)
    previous_pole = await find_previous_pole(
        db, power_line_id, new_pole.sequence_number, exclude_pole_id=new_pole.id
    )
    
    if not previous_pole:
        # Первая опора в линии - пролёта нет
        return None
    
    # Получаем ConnectivityNode для предыдущей опоры
    previous_cn = previous_pole.get_connectivity_node_for_line(power_line_id)
    if not previous_cn:
        # Если ConnectivityNode нет, пропускаем создание пролёта
        return None
    
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
        previous_pole.latitude, previous_pole.longitude,
        new_pole.latitude, new_pole.longitude
    )
    
    # Получаем информацию о линии для voltage_level
    power_line = await db.get(PowerLine, power_line_id)
    voltage_level = power_line.voltage_level if power_line else 10.0
    
    # Находим или создаём AClineSegment
    acline_segment = await find_or_create_acline_segment(
        db, power_line_id, previous_cn.id, voltage_level, current_user_id
    )
    
    # Обновляем to_connectivity_node_id текущего сегмента на новую опору
    # (если это не ветвление и не отпаечная опора)
    is_new_pole_branching = await is_branching_pole(db, new_pole.id, power_line_id)
    if not is_new_pole_branching and not is_tap:
        acline_segment.to_connectivity_node_id = new_connectivity_node.id
    
    # Если это отпаечная опора, завершаем текущий сегмент
    if is_tap:
        acline_segment.to_connectivity_node_id = new_connectivity_node.id
        # Помечаем сегмент как завершённый (to_connectivity_node_id установлен)
    
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
    
    # Создаём пролёт
    span = Span(
        mrid=generate_mrid(),
        span_number=f"{previous_pole.pole_number}-{new_pole.pole_number}",
        power_line_id=power_line_id,
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

