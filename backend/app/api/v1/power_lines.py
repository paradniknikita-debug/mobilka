from typing import List, Optional
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.core.security import get_current_active_user
from app.models.user import User
from app.models.power_line import PowerLine, Pole, Span, Tap, Equipment
from app.models.acline_segment import AClineSegment
from app.models.cim_line_structure import ConnectivityNode, LineSection
from app.schemas.power_line import (
    PowerLineCreate, PowerLineResponse, PoleCreate, PoleResponse,
    SpanCreate, SpanResponse, TapCreate, TapResponse, EquipmentCreate, EquipmentResponse
)

router = APIRouter()

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
    
    # Генерируем код автоматически на основе mrid
    code = f"LEP-{mrid[:8].upper()}"
    
    # Проверяем уникальность code
    existing = await db.execute(
        select(PowerLine).where(PowerLine.code == code)
    )
    if existing.scalar_one_or_none():
        # Если код уже существует, добавляем суффикс
        counter = 1
        while True:
            new_code = f"{code}-{counter}"
            existing = await db.execute(
                select(PowerLine).where(PowerLine.code == new_code)
            )
            if not existing.scalar_one_or_none():
                code = new_code
                break
            counter += 1
    
    # Формируем описание из branch_name и region_name
    description_parts = []
    if branch_name:
        description_parts.append(f"Административная принадлежность: {branch_name}")
    if region_name:
        description_parts.append(f"Географический регион: {region_name}")
    if power_line_dict.get('description'):
        description_parts.append(power_line_dict.get('description'))
    
    final_description = '\n'.join(description_parts) if description_parts else None
    
    # Валидация напряжения (стандартные значения)
    voltage_level = power_line_dict.get('voltage_level')
    if voltage_level is not None:
        if voltage_level != 0:
            standard_voltages = [0.4, 6, 10, 35, 110, 220, 330, 500, 750]
            # Проверяем с учетом возможных погрешностей float (округляем до 1 знака)
            voltage_rounded = round(float(voltage_level), 1)
            if voltage_rounded not in standard_voltages:
                raise HTTPException(
                    status_code=400, 
                    detail=f"Номинальное напряжение должно быть одним из стандартных значений: {', '.join(map(str, standard_voltages))} кВ"
                )
        if voltage_level < 0:
            raise HTTPException(status_code=400, detail="Напряжение не может быть отрицательным")
    
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
    power_line_dict.pop('code', None)  # code генерируется автоматически
    
    # Логируем данные перед созданием
    print(f"DEBUG: Создание ЛЭП с данными:")
    print(f"  mrid: {mrid}")
    print(f"  code: {code}")
    print(f"  name: {power_line_dict.get('name')}")
    print(f"  voltage_level: {power_line_dict.get('voltage_level')}")
    print(f"  length: {power_line_dict.get('length')}")
    print(f"  status: {power_line_dict.get('status')}")
    print(f"  description: {final_description}")
    print(f"  created_by: {current_user.id}")
    print(f"  Все поля power_line_dict: {power_line_dict}")
    
    try:
        db_power_line = PowerLine(
            mrid=mrid,
            code=code,
            description=final_description,
            **power_line_dict,
            created_by=current_user.id
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
        return db_power_line
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
            selectinload(PowerLine.acline_segments).selectinload(AClineSegment.line_sections),
            selectinload(PowerLine.acline_segments).selectinload(AClineSegment.terminals)
        )
        .offset(skip)
        .limit(limit)
    )
    power_lines = result.scalars().all()
    return power_lines

@router.get("/{power_line_id}", response_model=PowerLineResponse)
async def get_power_line(
    power_line_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение ЛЭП по ID"""
    result = await db.execute(
        select(PowerLine)
        .options(
            selectinload(PowerLine.poles).selectinload(Pole.connectivity_nodes),
            selectinload(PowerLine.acline_segments).selectinload(AClineSegment.line_sections),
            selectinload(PowerLine.acline_segments).selectinload(AClineSegment.terminals)
        )
        .where(PowerLine.id == power_line_id)
    )
    power_line = result.scalar_one_or_none()
    if not power_line:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Power line not found"
        )
    return power_line

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
    
    # Создаем словарь данных, исключая mrid если он None
    pole_dict = pole_data.dict(exclude={'mrid'})
    if pole_data.mrid:
        pole_dict['mrid'] = pole_data.mrid
    
    db_pole = Pole(
        **pole_dict,
        power_line_id=power_line_id,
        created_by=current_user.id
    )
    db.add(db_pole)
    await db.flush()  # Получаем ID опоры
    
    # Автоматическое создание ConnectivityNode для опоры
    # Теперь один ConnectivityNode создаётся для линии опоры
    # Если нужно создать совместный подвес, можно создать дополнительный ConnectivityNode вручную
    from app.models.cim_line_structure import ConnectivityNode
    from app.models.base import generate_mrid
    
    connectivity_node = ConnectivityNode(
        mrid=generate_mrid(),
        name=f"Узел {pole_data.pole_number}",
        pole_id=db_pole.id,
        power_line_id=power_line_id,  # Связываем узел с линией
        latitude=pole_data.latitude,
        longitude=pole_data.longitude,
        description=f"Автоматически созданный узел для опоры {pole_data.pole_number} линии {power_line_id}"
    )
    db.add(connectivity_node)
    await db.flush()
    
    # Связываем опору с узлом (для обратной совместимости)
    db_pole.connectivity_node_id = connectivity_node.id
    await db.commit()
    
    # Загружаем опору с relationships для корректной сериализации ответа
    result = await db.execute(
        select(Pole)
        .options(selectinload(Pole.connectivity_nodes))
        .where(Pole.id == db_pole.id)
    )
    db_pole = result.scalar_one()
    
    # Для обратной совместимости добавляем connectivity_node
    cn = db_pole.get_connectivity_node_for_line(power_line_id)
    setattr(db_pole, 'connectivity_node', cn)
    setattr(db_pole, 'connectivity_node_id', cn.id if cn else None)
    
    return db_pole

@router.get("/{power_line_id}/poles", response_model=List[PoleResponse])
async def get_poles(
    power_line_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение опор ЛЭП"""
    result = await db.execute(
        select(Pole).where(Pole.power_line_id == power_line_id)
    )
    poles = result.scalars().all()
    return poles

@router.post("/{power_line_id}/spans", response_model=SpanResponse)
async def create_span(
    power_line_id: int,
    span_data: SpanCreate,
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
    
    # Получаем опоры
    from_pole = await db.get(Pole, span_data.from_pole_id)
    to_pole = await db.get(Pole, span_data.to_pole_id)
    
    if not from_pole or not to_pole:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="One or both poles not found"
        )
    
    # Проверяем, что опоры принадлежат этой линии (или разрешаем совместный подвес)
    if from_pole.power_line_id != power_line_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"From pole belongs to different power line (line {from_pole.power_line_id})"
        )
    if to_pole.power_line_id != power_line_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"To pole belongs to different power line (line {to_pole.power_line_id})"
        )
    
    # Находим или создаём ConnectivityNode для опор и этой линии
    result_from_node = await db.execute(
        select(ConnectivityNode).where(
            ConnectivityNode.pole_id == from_pole.id,
            ConnectivityNode.power_line_id == power_line_id
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
            power_line_id=power_line_id,
            latitude=from_pole.latitude,
            longitude=from_pole.longitude,
            description=f"Узел для опоры {from_pole.pole_number} линии {power_line_id}"
        )
        db.add(from_connectivity_node)
        await db.flush()
    
    result_to_node = await db.execute(
        select(ConnectivityNode).where(
            ConnectivityNode.pole_id == to_pole.id,
            ConnectivityNode.power_line_id == power_line_id
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
            power_line_id=power_line_id,
            latitude=to_pole.latitude,
            longitude=to_pole.longitude,
            description=f"Узел для опоры {to_pole.pole_number} линии {power_line_id}"
        )
        db.add(to_connectivity_node)
        await db.flush()
    
    # Создаём или находим LineSection для этого пролёта
    from app.models.cim_line_structure import LineSection
    from app.models.acline_segment import AClineSegment
    
    # Ищем существующий AClineSegment для этой линии
    result_segment = await db.execute(
        select(AClineSegment).where(AClineSegment.power_line_id == power_line_id).limit(1)
    )
    existing_segment = result_segment.scalar_one_or_none()
    
    if not existing_segment:
        # Создаём временный AClineSegment
        from app.models.base import generate_mrid
        # Генерируем короткий код (максимум 20 символов)
        # Формат: SEG-{короткий UUID} (например: SEG-A1B2C3D4)
        short_uuid = str(uuid.uuid4()).replace('-', '')[:8].upper()
        segment_code = f"SEG-{short_uuid}"  # Максимум 12 символов
        temp_segment = AClineSegment(
            mrid=generate_mrid(),
            name=f"Сегмент {power_line.name}",
            code=segment_code,
            voltage_level=power_line.voltage_level or 0.0,
            length=0.0,
            power_line_id=power_line_id,
            from_connectivity_node_id=from_connectivity_node.id,
            to_connectivity_node_id=to_connectivity_node.id,
            sequence_number=1,
            created_by=current_user.id
        )
        db.add(temp_segment)
        await db.flush()
        segment_id = temp_segment.id
    else:
        segment_id = existing_segment.id
    
    # Ищем существующую LineSection
    result_section = await db.execute(
        select(LineSection).where(LineSection.acline_segment_id == segment_id).limit(1)
    )
    existing_section = result_section.scalar_one_or_none()
    
    if not existing_section:
        # Создаём LineSection
        from app.models.base import generate_mrid
        temp_line_section = LineSection(
            mrid=generate_mrid(),
            name=f"Секция линии {power_line.name}",
            acline_segment_id=segment_id,
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
    span_dict['power_line_id'] = power_line_id
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
    # Загружаем пролёт с связанными объектами
    result = await db.execute(
        select(Span)
        .options(
            selectinload(Span.from_connectivity_node),
            selectinload(Span.to_connectivity_node),
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
    # Проверяем через power_line_id (если есть) или через line_section -> acline_segment -> power_line_id
    if span.power_line_id and span.power_line_id != power_line_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Span not found in this power line"
        )
    
    # Если power_line_id не задан, проверяем через line_section
    if not span.power_line_id and span.line_section and span.line_section.acline_segment:
        if span.line_section.acline_segment.power_line_id != power_line_id:
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
    span_data: SpanCreate,
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
    if span.power_line_id and span.power_line_id != power_line_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Span not found in this power line"
        )
    
    # Если power_line_id не задан, проверяем через line_section
    if not span.power_line_id and span.line_section and span.line_section.acline_segment:
        if span.line_section.acline_segment.power_line_id != power_line_id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Span not found in this power line"
            )
    
    # Если переданы from_pole_id и to_pole_id, обновляем connectivity_node
    from app.models.cim_line_structure import ConnectivityNode
    
    if span_data.from_pole_id:
        from_pole = await db.get(Pole, span_data.from_pole_id)
        if not from_pole:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="From pole not found"
            )
        
        # Находим или создаём ConnectivityNode для начальной опоры
        result_from_node = await db.execute(
            select(ConnectivityNode).where(
                ConnectivityNode.pole_id == from_pole.id,
                ConnectivityNode.power_line_id == power_line_id
            )
        )
        from_connectivity_node = result_from_node.scalar_one_or_none()
        
        if not from_connectivity_node:
            from app.models.base import generate_mrid
            from_connectivity_node = ConnectivityNode(
                mrid=generate_mrid(),
                name=f"Узел {from_pole.pole_number}",
                pole_id=from_pole.id,
                power_line_id=power_line_id,
                latitude=from_pole.latitude,
                longitude=from_pole.longitude,
                description=f"Узел для опоры {from_pole.pole_number} линии {power_line_id}"
            )
            db.add(from_connectivity_node)
            await db.flush()
        
        span.from_connectivity_node_id = from_connectivity_node.id
        span.from_pole_id = from_pole.id
    
    if span_data.to_pole_id:
        to_pole = await db.get(Pole, span_data.to_pole_id)
        if not to_pole:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="To pole not found"
            )
        
        # Находим или создаём ConnectivityNode для конечной опоры
        result_to_node = await db.execute(
            select(ConnectivityNode).where(
                ConnectivityNode.pole_id == to_pole.id,
                ConnectivityNode.power_line_id == power_line_id
            )
        )
        to_connectivity_node = result_to_node.scalar_one_or_none()
        
        if not to_connectivity_node:
            from app.models.base import generate_mrid
            to_connectivity_node = ConnectivityNode(
                mrid=generate_mrid(),
                name=f"Узел {to_pole.pole_number}",
                pole_id=to_pole.id,
                power_line_id=power_line_id,
                latitude=to_pole.latitude,
                longitude=to_pole.longitude,
                description=f"Узел для опоры {to_pole.pole_number} линии {power_line_id}"
            )
            db.add(to_connectivity_node)
            await db.flush()
        
        span.to_connectivity_node_id = to_connectivity_node.id
        span.to_pole_id = to_pole.id
    
    # Обновляем остальные поля пролёта
    span_dict = span_data.dict(exclude_unset=True, exclude={'from_pole_id', 'to_pole_id', 'power_line_id'})
    
    for key, value in span_dict.items():
        if hasattr(span, key) and value is not None:
            setattr(span, key, value)
    
    # Обновляем power_line_id если он был передан
    if span_data.power_line_id:
        span.power_line_id = span_data.power_line_id
    
    await db.commit()
    await db.refresh(span)
    
    # Загружаем связанные объекты для ответа
    await db.refresh(span, ['from_connectivity_node', 'to_connectivity_node', 'line_section'])
    
    # Устанавливаем from_pole_id и to_pole_id для обратной совместимости
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
    if span.power_line_id and span.power_line_id != power_line_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Span not found in this power line"
        )
    
    # Если power_line_id не задан, проверяем через line_section
    if not span.power_line_id and span.line_section and span.line_section.acline_segment:
        if span.line_section.acline_segment.power_line_id != power_line_id:
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
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Автоматическое создание пролётов на основе последовательности опор.
    Создаёт пролёты между соседними опорами в порядке их sequence_number.
    """
    import math
    from app.models.base import generate_mrid
    
    # Проверка существования ЛЭП
    power_line = await db.get(PowerLine, power_line_id)
    if not power_line:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Power line not found"
        )
    
    # Получаем опоры, отсортированные по sequence_number
    result = await db.execute(
        select(Pole)
        .where(Pole.power_line_id == power_line_id)
        .where(Pole.sequence_number.isnot(None))
        .order_by(Pole.sequence_number)
    )
    poles = result.scalars().all()
    
    if len(poles) < 2:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Для создания пролётов необходимо минимум 2 опоры с заданной последовательностью"
        )
    
    # Проверяем, что у всех опор есть ConnectivityNode для этой линии
    from app.models.cim_line_structure import ConnectivityNode
    
    for pole in poles:
        # Ищем ConnectivityNode для этой опоры и этой линии
        result_node = await db.execute(
            select(ConnectivityNode).where(
                ConnectivityNode.pole_id == pole.id,
                ConnectivityNode.power_line_id == power_line_id
            )
        )
        connectivity_node = result_node.scalar_one_or_none()
        
        if not connectivity_node:
            # Если ConnectivityNode нет, создаём его
            connectivity_node = ConnectivityNode(
                mrid=generate_mrid(),
                name=f"Узел {pole.pole_number}",
                pole_id=pole.id,
                power_line_id=power_line_id,
                latitude=pole.latitude,
                longitude=pole.longitude,
                description=f"Автоматически созданный узел для опоры {pole.pole_number} линии {power_line_id}"
            )
            db.add(connectivity_node)
            await db.flush()
            
            # Обновляем connectivity_node_id в опоре (для обратной совместимости)
            pole.connectivity_node_id = connectivity_node.id
        
        # Сохраняем ConnectivityNode в опоре для использования ниже
        pole._connectivity_node = connectivity_node
    
    # Функция для расчёта расстояния по формуле Гаверсинуса
    def haversine_distance(lat1, lon1, lat2, lon2):
        R = 6371000  # Радиус Земли в метрах
        phi1 = math.radians(lat1)
        phi2 = math.radians(lat2)
        delta_phi = math.radians(lat2 - lat1)
        delta_lambda = math.radians(lon2 - lon1)
        
        a = math.sin(delta_phi / 2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2)**2
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        return R * c
    
    # Создаём временную CIM структуру для всей линии
    # Это нужно для обратной совместимости, так как Span требует line_section_id
    from app.models.cim_line_structure import LineSection
    from app.models.acline_segment import AClineSegment
    
    # Проверяем, есть ли уже AClineSegment для этой линии
    result_segment = await db.execute(
        select(AClineSegment).where(AClineSegment.power_line_id == power_line_id).limit(1)
    )
    existing_segment = result_segment.scalar_one_or_none()
    
    if not existing_segment:
        # Создаём временный AClineSegment для всей линии
        first_pole = poles[0]
        last_pole = poles[-1]
        
        # Используем ConnectivityNode из опор (уже загружены выше)
        from_connectivity_node_id = first_pole._connectivity_node.id
        to_connectivity_node_id = last_pole._connectivity_node.id
        
        # Генерируем короткий код для сегмента (максимум 20 символов)
        short_uuid = str(uuid.uuid4()).replace('-', '')[:8].upper()
        segment_code = f"SEG-{short_uuid}"  # Максимум 12 символов
        
        temp_segment = AClineSegment(
            mrid=generate_mrid(),
            name=f"Сегмент {power_line.name}",
            code=segment_code,
            voltage_level=power_line.voltage_level or 0.0,
            length=0.0,  # Будет рассчитано позже
            power_line_id=power_line_id,
            from_connectivity_node_id=from_connectivity_node_id,
            to_connectivity_node_id=to_connectivity_node_id,
            sequence_number=1,
            created_by=current_user.id
        )
        db.add(temp_segment)
        await db.flush()  # Получаем ID сегмента
        segment_id = temp_segment.id
    else:
        segment_id = existing_segment.id
    
    # Создаём временную LineSection
    temp_line_section = LineSection(
        mrid=generate_mrid(),
        name=f"Секция линии {power_line.name}",
        acline_segment_id=segment_id,
        sequence_number=1,
        description="Автоматически созданная секция для пролётов"
    )
    db.add(temp_line_section)
    await db.flush()  # Получаем ID секции
    
    # Создаём пролёты между соседними опорами
    created_spans = []
    for i in range(len(poles) - 1):
        from_pole = poles[i]
        to_pole = poles[i + 1]
        
        # Проверяем, не существует ли уже такой пролёт
        existing_span = await db.execute(
            select(Span).where(
                Span.from_pole_id == from_pole.id,
                Span.to_pole_id == to_pole.id,
                Span.power_line_id == power_line_id
            )
        )
        if existing_span.scalar_one_or_none():
            continue  # Пропускаем, если пролёт уже существует
        
        # Рассчитываем расстояние
        distance = haversine_distance(
            from_pole.latitude, from_pole.longitude,
            to_pole.latitude, to_pole.longitude
        )
        
        # Создаём пролёт
        span_number = f"ПР-{from_pole.sequence_number}-{to_pole.sequence_number}"
        
        # Используем ConnectivityNode из опор (уже загружены выше)
        from_connectivity_node_id = from_pole._connectivity_node.id
        to_connectivity_node_id = to_pole._connectivity_node.id
        
        # Для обратной совместимости создаём пролёт со старыми полями
        db_span = Span(
            mrid=generate_mrid(),
            line_section_id=temp_line_section.id,  # Привязываем к временной секции
            power_line_id=power_line_id,
            from_pole_id=from_pole.id,
            to_pole_id=to_pole.id,
            from_connectivity_node_id=from_connectivity_node_id,
            to_connectivity_node_id=to_connectivity_node_id,
            span_number=span_number,
            length=distance,
            sequence_number=i + 1,
            created_by=current_user.id
        )
        db.add(db_span)
        created_spans.append(db_span)
    
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
    
    db_tap = Tap(
        **tap_data.dict(),
        power_line_id=power_line_id,
        created_by=current_user.id
    )
    db.add(db_tap)
    await db.commit()
    await db.refresh(db_tap)
    return db_tap

@router.delete("/{power_line_id}", status_code=status.HTTP_200_OK)
async def delete_power_line(
    power_line_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Удаление ЛЭП"""
    # Проверяем существование ЛЭП
    result = await db.execute(
        select(PowerLine).where(PowerLine.id == power_line_id)
    )
    power_line = result.scalar_one_or_none()
    
    if not power_line:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Power line not found"
        )
    
    # Удаляем ЛЭП (каскадное удаление опор, пролётов, отпаек и сегментов настроено в модели)
    await db.execute(delete(PowerLine).where(PowerLine.id == power_line_id))
    await db.commit()
    
    return {"message": "Power line deleted successfully"}
