"""
API endpoints для CIM-совместимой структуры линий электропередачи
"""
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.core.security import get_current_active_user
from app.models.user import User
from app.models.cim_line_structure import ConnectivityNode, Terminal, LineSection
from app.models.acline_segment import AClineSegment
from app.models.power_line import Pole, Span, PowerLine
from app.models.substation import Substation
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
        x_position=node_data.x_position,
        y_position=node_data.y_position,
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
    node.x_position = node_data.x_position
    node.y_position = node_data.y_position
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
        y_position=pole.y_position,
        x_position=pole.x_position,
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


@router.get("/poles/{pole_id}/terminals", response_model=List[TerminalResponse])
async def get_pole_terminals(
    pole_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Получить все терминалы, связанные с узлом(ами) соединения опоры.
    Возвращаются терминалы, у которых connectivity_node_id указывает на ConnectivityNode с pole_id = pole_id.
    """
    # Ищем все узлы соединения для указанной опоры
    nodes_result = await db.execute(
        select(ConnectivityNode.id).where(ConnectivityNode.pole_id == pole_id)
    )
    node_ids = [row[0] for row in nodes_result.all()]
    if not node_ids:
        return []

    result = await db.execute(
        select(Terminal).where(Terminal.connectivity_node_id.in_(node_ids))
    )
    terminals = result.scalars().all()
    return terminals


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
    
    # Единый UID: code = mrid (без SEG-xxx и т.п.)
    code = segment_data.code or mrid
    
    db_segment = AClineSegment(
        mrid=mrid,
        name=segment_data.name,
        code=code,
        line_id=segment_data.line_id,
        voltage_level=segment_data.voltage_level,
        length=segment_data.length,
        is_tap=segment_data.is_tap,
        tap_number=segment_data.tap_number,
        branch_type=getattr(segment_data, 'branch_type', None),
        tap_pole_id=getattr(segment_data, 'tap_pole_id', None),
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
    """Получение сегмента линии по ID (с секциями, пролётами и номерами опор для карточки участка)."""
    result = await db.execute(
        select(AClineSegment)
        .options(
            selectinload(AClineSegment.line_sections)
            .selectinload(LineSection.spans)
            .selectinload(Span.from_connectivity_node)
            .selectinload(ConnectivityNode.pole),
            selectinload(AClineSegment.line_sections)
            .selectinload(LineSection.spans)
            .selectinload(Span.from_connectivity_node)
            .selectinload(ConnectivityNode.substation),
            selectinload(AClineSegment.line_sections)
            .selectinload(LineSection.spans)
            .selectinload(Span.to_connectivity_node)
            .selectinload(ConnectivityNode.pole),
            selectinload(AClineSegment.line_sections)
            .selectinload(LineSection.spans)
            .selectinload(Span.to_connectivity_node)
            .selectinload(ConnectivityNode.substation),
            selectinload(AClineSegment.terminals),
        )
        .where(AClineSegment.id == segment_id)
    )
    segment = result.scalar_one_or_none()
    if not segment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Сегмент линии не найден"
        )
    # Чтобы «Длина (по пролётам)» совпадала с суммой длин секций в карточке — пересчитываем из секций
    if segment.line_sections:
        from sqlalchemy import func as sqlfunc
        seg_len = (await db.execute(
            select(sqlfunc.coalesce(sqlfunc.sum(LineSection.total_length), 0)).where(
                LineSection.acline_segment_id == segment_id
            )
        )).scalar_one() or 0.0
        object.__setattr__(segment, "length", seg_len)

    # Имя участка в БД может устаревать (например, если меняли номера опор).
    # Для карточки пересчитываем имя по фактическим пролётам (первый/последний).
    try:
        all_spans: List[Span] = []
        for ls in (segment.line_sections or []):
            for sp in (ls.spans or []):
                all_spans.append(sp)
        all_spans = sorted(all_spans, key=lambda s: (getattr(s, "sequence_number", 0) or 0))
        if all_spans:
            first = all_spans[0].from_connectivity_node
            last = all_spans[-1].to_connectivity_node

            def _cn_label(cn: Optional[ConnectivityNode]) -> str:
                if cn is None:
                    return "—"
                if getattr(cn, "substation_id", None):
                    sub = getattr(cn, "substation", None)
                    if sub is not None:
                        return (getattr(sub, "name", None) or getattr(sub, "dispatcher_name", None) or getattr(cn, "name", None) or "ПС").strip()
                    return (getattr(cn, "name", None) or "ПС").strip()
                pn = getattr(cn, "pole_number", None)
                if pn:
                    s = str(pn).strip()
                    if s.lower().startswith(("опора", "оп.")):
                        return s
                    return f"Опора {s}"
                return (getattr(cn, "name", None) or f"Узел {getattr(cn, 'id', '')}").strip()

            from_name = _cn_label(first)
            to_name = _cn_label(last)
            if from_name != "—" and to_name != "—":
                object.__setattr__(segment, "name", f"{from_name} - {to_name}")
    except Exception:
        pass
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


@router.delete("/acline-segments/{segment_id}", status_code=status.HTTP_200_OK)
async def delete_acline_segment(
    segment_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Удаление участка линии (AClineSegment): удаляются секции и пролёты участка."""
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
    # Удаляем пролёты (Span) всех секций участка, затем секции (LineSection), затем участок
    for ls in segment.line_sections:
        await db.execute(delete(Span).where(Span.line_section_id == ls.id))
    await db.execute(delete(LineSection).where(LineSection.acline_segment_id == segment_id))
    await db.execute(delete(AClineSegment).where(AClineSegment.id == segment_id))
    await db.commit()
    return {"message": "AClineSegment deleted", "details": "Участок линии и связанные секции и пролёты удалены."}


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

