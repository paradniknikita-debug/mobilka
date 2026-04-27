"""
API endpoints для CIM-совместимой структуры линий электропередачи
"""
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete, func
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.core.security import get_current_active_user
from app.models.user import User
from app.models.cim_line_structure import ConnectivityNode, Terminal, LineSection
from app.models.acline_segment import AClineSegment
from app.models.power_line import Pole, Span, PowerLine
from app.models.wire_info import WireInfo
from app.schemas.cim_line_structure import (
    ConnectivityNodeCreate, ConnectivityNodeResponse,
    TerminalCreate, TerminalResponse,
    LineSectionCreate, LineSectionResponse,
    AClineSegmentCreate, AClineSegmentResponse,
    SpanCreate, SpanResponse
)

router = APIRouter()


async def _find_wire_info(db: AsyncSession, marker: Optional[str]) -> Optional[WireInfo]:
    marker_norm = (marker or "").strip()
    if not marker_norm:
        return None
    result = await db.execute(
        select(WireInfo).where(
            func.lower(WireInfo.name) == marker_norm.lower()
        )
    )
    wi = result.scalar_one_or_none()
    if wi is not None:
        return wi
    result = await db.execute(
        select(WireInfo).where(
            func.lower(WireInfo.code) == marker_norm.lower()
        )
    )
    return result.scalar_one_or_none()


def _fill_segment_defaults_from_wire_info(data: dict, wire_info: Optional[WireInfo]) -> dict:
    if wire_info is None:
        return data
    # User-entered values have priority. Fill only missing fields.
    if not data.get("conductor_material") and getattr(wire_info, "material", None):
        data["conductor_material"] = wire_info.material
    if not data.get("conductor_section") and getattr(wire_info, "section", None) is not None:
        data["conductor_section"] = str(wire_info.section)
    if data.get("r") is None and getattr(wire_info, "r", None) is not None:
        data["r"] = wire_info.r
    if data.get("x") is None and getattr(wire_info, "x", None) is not None:
        data["x"] = wire_info.x
    if data.get("b") is None and getattr(wire_info, "b", None) is not None:
        data["b"] = wire_info.b
    if data.get("g") is None and getattr(wire_info, "g", None) is not None:
        data["g"] = wire_info.g
    if data.get("r0") is None and data.get("r") is not None:
        data["r0"] = data["r"]
    if data.get("x0") is None and data.get("x") is not None:
        data["x0"] = data["x"]
    if data.get("bch") is None and data.get("b") is not None:
        data["bch"] = data["b"]
    if data.get("gch") is None and data.get("g") is not None:
        data["gch"] = data["g"]
    if data.get("b0ch") is None and data.get("bch") is not None:
        data["b0ch"] = 0.0
    if data.get("g0ch") is None and data.get("gch") is not None:
        data["g0ch"] = 0.0
    if data.get("i_th") is None and getattr(wire_info, "nominal_current", None) is not None:
        data["i_th"] = wire_info.nominal_current
    if data.get("t_th") is None and getattr(wire_info, "max_operating_temperature", None) is not None:
        data["t_th"] = wire_info.max_operating_temperature
    return data


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
    
    payload = segment_data.model_dump() if hasattr(segment_data, "model_dump") else segment_data.dict()
    wire_info = await _find_wire_info(db, payload.get("conductor_type"))
    payload = _fill_segment_defaults_from_wire_info(payload, wire_info)

    db_segment = AClineSegment(
        mrid=mrid,
        name=payload["name"],
        code=code,
        line_id=payload["line_id"],
        voltage_level=payload["voltage_level"],
        length=payload["length"],
        is_tap=payload.get("is_tap", False),
        tap_number=payload.get("tap_number"),
        branch_type=payload.get("branch_type"),
        tap_pole_id=payload.get("tap_pole_id"),
        from_connectivity_node_id=payload["from_connectivity_node_id"],
        to_connectivity_node_id=payload.get("to_connectivity_node_id"),
        to_terminal_id=payload.get("to_terminal_id"),
        sequence_number=payload.get("sequence_number", 1),
        conductor_type=payload.get("conductor_type"),
        conductor_material=payload.get("conductor_material"),
        conductor_section=payload.get("conductor_section"),
        r=payload.get("r"),
        x=payload.get("x"),
        b=payload.get("b"),
        g=payload.get("g"),
        r0=payload.get("r0"),
        x0=payload.get("x0"),
        bch=payload.get("bch"),
        b0ch=payload.get("b0ch"),
        gch=payload.get("gch"),
        g0ch=payload.get("g0ch"),
        i_th=payload.get("i_th"),
        t_th=payload.get("t_th"),
        sections=payload.get("sections"),
        short_circuit_end_temperature=payload.get("short_circuit_end_temperature"),
        is_jumper=payload.get("is_jumper"),
        description=payload.get("description"),
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
            .selectinload(Span.to_connectivity_node)
            .selectinload(ConnectivityNode.pole),
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
    should_autofill = "conductor_type" in segment_dict
    if should_autofill:
        marker = segment_dict.get("conductor_type", getattr(segment, "conductor_type", None))
        wire_info = await _find_wire_info(db, marker)
        segment_dict = _fill_segment_defaults_from_wire_info(segment_dict, wire_info)
    
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

