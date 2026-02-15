"""
API endpoints для CIM-совместимой структуры линий электропередачи
"""
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.core.security import get_current_active_user
from app.models.user import User
from app.models.cim_line_structure import ConnectivityNode, Terminal, LineSection
from app.models.acline_segment import AClineSegment
from app.models.power_line import Pole, Span, PowerLine
from app.schemas.cim_line_structure import (
    ConnectivityNodeCreate, ConnectivityNodeResponse,
    TerminalCreate, TerminalResponse,
    LineSectionCreate, LineSectionResponse,
    AClineSegmentCreate, AClineSegmentResponse,
    SpanCreate, SpanResponse
)

router = APIRouter()


# ==================== ConnectivityNode ====================

@router.post("/connectivity-nodes", response_model=ConnectivityNodeResponse)
async def create_connectivity_node(
    node_data: ConnectivityNodeCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Создание узла соединения (ConnectivityNode)"""
    from app.models.base import generate_mrid
    
    # Проверка существования опоры
    pole = await db.get(Pole, node_data.pole_id)
    if not pole:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Опора не найдена"
        )
    
    # Проверка, что у опоры ещё нет ConnectivityNode
    existing_node = await db.execute(
        select(ConnectivityNode).where(ConnectivityNode.pole_id == node_data.pole_id)
    )
    if existing_node.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="У этой опоры уже есть узел соединения"
        )
    
    mrid = node_data.mrid or generate_mrid()
    
    db_node = ConnectivityNode(
        mrid=mrid,
        name=node_data.name,
        pole_id=node_data.pole_id,
        latitude=node_data.latitude,
        longitude=node_data.longitude,
        description=node_data.description
    )
    
    db.add(db_node)
    await db.commit()
    await db.refresh(db_node)
    
    # Обновляем связь в опоре
    pole.connectivity_node_id = db_node.id
    await db.commit()
    
    return db_node


@router.get("/connectivity-nodes/{node_id}", response_model=ConnectivityNodeResponse)
async def get_connectivity_node(
    node_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение узла соединения по ID"""
    node = await db.get(ConnectivityNode, node_id)
    if not node:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Узел соединения не найден"
        )
    return node


@router.put("/connectivity-nodes/{node_id}", response_model=ConnectivityNodeResponse)
async def update_connectivity_node(
    node_id: int,
    node_data: ConnectivityNodeCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Обновление узла соединения"""
    node = await db.get(ConnectivityNode, node_id)
    if not node:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Узел соединения не найден"
        )
    
    # Обновляем поля
    node.name = node_data.name
    node.latitude = node_data.latitude
    node.longitude = node_data.longitude
    node.description = node_data.description
    
    await db.commit()
    await db.refresh(node)
    return node


@router.delete("/connectivity-nodes/{node_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_connectivity_node(
    node_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Удаление узла соединения"""
    node = await db.get(ConnectivityNode, node_id)
    if not node:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Узел соединения не найден"
        )
    
    # Проверяем, что узел не используется в сегментах
    from sqlalchemy import select
    from app.models.acline_segment import AClineSegment
    
    # Проверяем использование в сегментах
    segments_from = await db.execute(
        select(AClineSegment).where(AClineSegment.from_connectivity_node_id == node_id)
    )
    segments_to = await db.execute(
        select(AClineSegment).where(AClineSegment.to_connectivity_node_id == node_id)
    )
    
    if segments_from.scalar_one_or_none() or segments_to.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Невозможно удалить узел: он используется в сегментах линии"
        )
    
    # Отвязываем от опоры
    if node.pole_id:
        pole = await db.get(Pole, node.pole_id)
        if pole:
            pole.connectivity_node_id = None
    
    await db.delete(node)
    await db.commit()


@router.post("/poles/{pole_id}/connectivity-node", response_model=ConnectivityNodeResponse)
async def create_connectivity_node_for_pole(
    pole_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Создание узла соединения для опоры вручную"""
    from app.models.base import generate_mrid
    
    pole = await db.get(Pole, pole_id)
    if not pole:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Опора не найдена"
        )
    
    # Проверяем, что у опоры ещё нет узла
    if pole.connectivity_node_id:
        existing_node = await db.get(ConnectivityNode, pole.connectivity_node_id)
        if existing_node:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="У этой опоры уже есть узел соединения"
            )
    
    node = ConnectivityNode(
        mrid=generate_mrid(),
        name=f"Узел {pole.pole_number}",
        pole_id=pole_id,
        latitude=pole.latitude,
        longitude=pole.longitude,
        description=f"Узел для опоры {pole.pole_number}"
    )
    
    db.add(node)
    await db.flush()
    
    pole.connectivity_node_id = node.id
    await db.commit()
    await db.refresh(node)
    return node


@router.delete("/poles/{pole_id}/connectivity-node", status_code=status.HTTP_204_NO_CONTENT)
async def delete_connectivity_node_from_pole(
    pole_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Удаление узла соединения от опоры"""
    pole = await db.get(Pole, pole_id)
    if not pole:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Опора не найдена"
        )
    
    if not pole.connectivity_node_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="У этой опоры нет узла соединения"
        )
    
    node = await db.get(ConnectivityNode, pole.connectivity_node_id)
    if node:
        # Проверяем использование в сегментах
        from sqlalchemy import select
        from app.models.acline_segment import AClineSegment
        
        segments_from = await db.execute(
            select(AClineSegment).where(AClineSegment.from_connectivity_node_id == node.id)
        )
        segments_to = await db.execute(
            select(AClineSegment).where(AClineSegment.to_connectivity_node_id == node.id)
        )
        
        if segments_from.scalar_one_or_none() or segments_to.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Невозможно удалить узел: он используется в сегментах линии"
            )
        
        pole.connectivity_node_id = None
        await db.delete(node)
        await db.commit()


# ==================== AClineSegment ====================

@router.post("/acline-segments", response_model=AClineSegmentResponse)
async def create_acline_segment(
    segment_data: AClineSegmentCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Создание сегмента линии (AClineSegment)"""
    from app.models.base import generate_mrid
    
    # Проверка существования линии
    power_line = await db.get(PowerLine, segment_data.line_id)
    if not power_line:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Линия не найдена"
        )
    
    # Проверка существования узлов соединения
    from_node = await db.get(ConnectivityNode, segment_data.from_connectivity_node_id)
    if not from_node:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Начальный узел соединения не найден"
        )
    
    if segment_data.to_connectivity_node_id:
        to_node = await db.get(ConnectivityNode, segment_data.to_connectivity_node_id)
        if not to_node:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Конечный узел соединения не найден"
            )
    
    mrid = segment_data.mrid or generate_mrid()
    
    # Генерируем код автоматически, если не указан
    code = segment_data.code or f"SEG-{mrid[:8].upper()}"
    
    db_segment = AClineSegment(
        mrid=mrid,
        name=segment_data.name,
        code=code,
        line_id=segment_data.line_id,
        voltage_level=segment_data.voltage_level,
        length=segment_data.length,
        is_tap=segment_data.is_tap,
        tap_number=segment_data.tap_number,
        from_connectivity_node_id=segment_data.from_connectivity_node_id,
        to_connectivity_node_id=segment_data.to_connectivity_node_id,
        to_terminal_id=segment_data.to_terminal_id,
        sequence_number=segment_data.sequence_number,
        conductor_type=segment_data.conductor_type,
        conductor_material=segment_data.conductor_material,
        conductor_section=segment_data.conductor_section,
        r=segment_data.r,
        x=segment_data.x,
        b=segment_data.b,
        g=segment_data.g,
        description=segment_data.description,
        created_by=current_user.id
    )
    
    db.add(db_segment)
    await db.commit()
    await db.refresh(db_segment)
    return db_segment


@router.get("/acline-segments/{segment_id}", response_model=AClineSegmentResponse)
async def get_acline_segment(
    segment_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение сегмента линии по ID"""
    result = await db.execute(
        select(AClineSegment)
        .options(selectinload(AClineSegment.line_sections))
        .where(AClineSegment.id == segment_id)
    )
    segment = result.scalar_one_or_none()
    if not segment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Сегмент линии не найден"
        )
    return segment


@router.put("/acline-segments/{segment_id}", response_model=AClineSegmentResponse)
async def update_acline_segment(
    segment_id: int,
    segment_data: AClineSegmentCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Обновление сегмента линии"""
    # Получаем существующий сегмент
    result = await db.execute(
        select(AClineSegment)
        .options(selectinload(AClineSegment.line_sections))
        .where(AClineSegment.id == segment_id)
    )
    segment = result.scalar_one_or_none()
    if not segment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Сегмент линии не найден"
        )
    
    # Проверяем принадлежность к той же линии
    if segment_data.line_id != segment.line_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Нельзя изменить принадлежность сегмента к линии"
        )
    
    # Проверяем существование узлов соединения если они изменились
    if segment_data.from_connectivity_node_id != segment.from_connectivity_node_id:
        from_node = await db.get(ConnectivityNode, segment_data.from_connectivity_node_id)
        if not from_node:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Начальный узел соединения не найден"
            )
    
    if segment_data.to_connectivity_node_id and segment_data.to_connectivity_node_id != segment.to_connectivity_node_id:
        to_node = await db.get(ConnectivityNode, segment_data.to_connectivity_node_id)
        if not to_node:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Конечный узел соединения не найден"
            )
    
    # Обновляем поля сегмента (исключаем mrid, line_id, created_by)
    segment_dict = segment_data.dict(exclude_unset=True, exclude={'mrid', 'line_id'})
    
    for key, value in segment_dict.items():
        if hasattr(segment, key):
            setattr(segment, key, value)
    
    await db.commit()
    await db.refresh(segment)
    
    # Загружаем сегмент с relationships для корректной сериализации ответа
    result = await db.execute(
        select(AClineSegment)
        .options(selectinload(AClineSegment.line_sections))
        .where(AClineSegment.id == segment_id)
    )
    segment = result.scalar_one()
    
    return segment


# ==================== LineSection ====================

@router.post("/line-sections", response_model=LineSectionResponse)
async def create_line_section(
    section_data: LineSectionCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Создание секции линии (LineSection)"""
    from app.models.base import generate_mrid
    
    # Проверка существования сегмента
    segment = await db.get(AClineSegment, section_data.acline_segment_id)
    if not segment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Сегмент линии не найден"
        )
    
    mrid = section_data.mrid or generate_mrid()
    
    db_section = LineSection(
        mrid=mrid,
        name=section_data.name,
        acline_segment_id=section_data.acline_segment_id,
        conductor_type=section_data.conductor_type,
        conductor_material=section_data.conductor_material,
        conductor_section=section_data.conductor_section,
        r=section_data.r,
        x=section_data.x,
        b=section_data.b,
        g=section_data.g,
        sequence_number=section_data.sequence_number,
        total_length=section_data.total_length,
        description=section_data.description,
        created_by=current_user.id
    )
    
    db.add(db_section)
    await db.commit()
    await db.refresh(db_section)
    return db_section


@router.get("/line-sections/{section_id}", response_model=LineSectionResponse)
async def get_line_section(
    section_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение секции линии по ID"""
    result = await db.execute(
        select(LineSection)
        .options(selectinload(LineSection.spans))
        .where(LineSection.id == section_id)
    )
    section = result.scalar_one_or_none()
    if not section:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Секция линии не найдена"
        )
    return section


# ==================== Span (обновлённый) ====================

@router.post("/spans", response_model=SpanResponse)
async def create_span_cim(
    span_data: SpanCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Создание пролёта (Span) с поддержкой CIM структуры"""
    from app.models.base import generate_mrid
    
    # Проверка существования секции линии
    line_section = await db.get(LineSection, span_data.line_section_id)
    if not line_section:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Секция линии не найдена"
        )
    
    # Проверка существования узлов соединения
    from_node = await db.get(ConnectivityNode, span_data.from_connectivity_node_id)
    if not from_node:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Начальный узел соединения не найден"
        )
    
    to_node = await db.get(ConnectivityNode, span_data.to_connectivity_node_id)
    if not to_node:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Конечный узел соединения не найден"
        )
    
    mrid = span_data.mrid or generate_mrid()
    
    db_span = Span(
        mrid=mrid,
        line_section_id=span_data.line_section_id,
        from_connectivity_node_id=span_data.from_connectivity_node_id,
        to_connectivity_node_id=span_data.to_connectivity_node_id,
        span_number=span_data.span_number,
        length=span_data.length,
        sequence_number=span_data.sequence_number,
        conductor_type=span_data.conductor_type,
        conductor_material=span_data.conductor_material,
        conductor_section=span_data.conductor_section,
        tension=span_data.tension,
        sag=span_data.sag,
        notes=span_data.notes,
        created_by=current_user.id
    )
    
    db.add(db_span)
    await db.commit()
    await db.refresh(db_span)
    return db_span

