"""
API журнала изменений и журнала несоответствий.
События с веб- (Angular) и Flutter-клиентов: создание/редактирование/удаление объектов.
Отдельный эндпоинт — проверка модели на «забытые» объекты и обрывы линий.
"""
from typing import List, Optional, Dict, Set, Tuple
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc

from app.database import get_db
from app.core.security import get_current_active_user
from app.models.user import User
from app.models.change_log import ChangeLog
from app.models.power_line import PowerLine, Pole, Span
from app.models.acline_segment import AClineSegment
from app.models.cim_line_structure import ConnectivityNode, LineSection
from app.models.substation import Substation
from app.schemas.change_log import ChangeLogCreate, ChangeLogResponse, ModelIssueResponse

router = APIRouter()


async def _load_user_names(db: AsyncSession, user_ids: Set[int]) -> Dict[int, str]:
    """Вернуть словарь user_id -> full_name (или username)."""
    if not user_ids:
        return {}
    result = await db.execute(
        select(User.id, User.full_name, User.username).where(User.id.in_(user_ids))
    )
    return {r[0]: (r[1] or r[2] or str(r[0])) for r in result.fetchall()}


async def _load_entity_names(
    db: AsyncSession, entity_type: str, entity_ids: Set[int]
) -> Dict[int, str]:
    """Вернуть словарь entity_id -> отображаемое имя для заданного entity_type."""
    if not entity_ids:
        return {}
    name_col = None
    model = None
    if entity_type == "pole":
        model, name_col = Pole, Pole.pole_number
    elif entity_type == "power_line":
        model, name_col = PowerLine, PowerLine.name
    elif entity_type == "span":
        model, name_col = Span, Span.span_number
    elif entity_type == "substation":
        model, name_col = Substation, Substation.name
    elif entity_type == "acline_segment":
        model, name_col = AClineSegment, AClineSegment.name
    elif entity_type == "line_section":
        model, name_col = LineSection, LineSection.name
    else:
        return {}
    result = await db.execute(
        select(model.id, name_col).where(model.id.in_(entity_ids))
    )
    return {r[0]: (r[1] or f"id={r[0]}") for r in result.fetchall()}


@router.post("", response_model=ChangeLogResponse)
async def create_change_log_entry(
    data: ChangeLogCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Добавить запись в журнал изменений (вызывают веб- и Flutter-клиенты)."""
    entry = ChangeLog(
        user_id=current_user.id,
        source=data.source,
        action=data.action,
        entity_type=data.entity_type,
        entity_id=data.entity_id,
        payload=data.payload,
        session_id=data.session_id,
    )
    db.add(entry)
    await db.commit()
    await db.refresh(entry)
    user_name = current_user.full_name or current_user.username
    entity_name = None
    if entry.entity_id and entry.entity_type:
        names = await _load_entity_names(db, entry.entity_type, {entry.entity_id})
        entity_name = names.get(entry.entity_id)
    return ChangeLogResponse(
        id=entry.id,
        created_at=entry.created_at,
        user_id=entry.user_id,
        user_name=user_name,
        source=entry.source,
        action=entry.action,
        entity_type=entry.entity_type,
        entity_id=entry.entity_id,
        entity_name=entity_name,
        payload=entry.payload,
        session_id=entry.session_id,
    )


@router.get("", response_model=List[ChangeLogResponse])
async def get_change_log(
    source: Optional[str] = Query(None, description="Фильтр: web | flutter"),
    action: Optional[str] = Query(None, description="Фильтр: create | update | delete | session_start | session_end"),
    entity_type: Optional[str] = Query(None, description="Фильтр по типу сущности"),
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Список записей журнала изменений"""
    q = select(ChangeLog).order_by(desc(ChangeLog.created_at)).limit(limit).offset(offset)
    if source:
        q = q.where(ChangeLog.source == source)
    if action:
        q = q.where(ChangeLog.action == action)
    if entity_type:
        q = q.where(ChangeLog.entity_type == entity_type)
    result = await db.execute(q)
    rows = result.scalars().all()

    user_ids: Set[int] = {r.user_id for r in rows if r.user_id is not None}
    by_entity: Dict[str, Set[int]] = {}
    for r in rows:
        if r.entity_id is not None:
            by_entity.setdefault(r.entity_type, set()).add(r.entity_id)

    user_names = await _load_user_names(db, user_ids)
    entity_names: Dict[str, Dict[int, str]] = {}
    for et, ids in by_entity.items():
        entity_names[et] = await _load_entity_names(db, et, ids)

    out: List[ChangeLogResponse] = []
    for r in rows:
        d = {
            "id": r.id,
            "created_at": r.created_at,
            "user_id": r.user_id,
            "user_name": user_names.get(r.user_id) if r.user_id else None,
            "source": r.source,
            "action": r.action,
            "entity_type": r.entity_type,
            "entity_id": r.entity_id,
            "entity_name": entity_names.get(r.entity_type, {}).get(r.entity_id) if r.entity_id else None,
            "payload": r.payload,
            "session_id": r.session_id,
        }
        out.append(ChangeLogResponse.model_validate(d))
    return out


@router.get("/errors", response_model=List[ModelIssueResponse])
async def get_model_issues(
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Журнал несоответствий: опоры/пролёты без линии, отпаечные опоры без отпаек, обрывы линий.
    Данные вычисляются при запросе, не хранятся в БД.
    """
    issues: List[ModelIssueResponse] = []
    line_ids_needed: set = set()

    # 1) Опоры, у которых line_id указывает на несуществующую ЛЭП
    line_ids_result = await db.execute(select(PowerLine.id))
    existing_line_ids = {r[0] for r in line_ids_result.fetchall()}
    poles_orphan = await db.execute(
        select(Pole.id, Pole.line_id, Pole.pole_number, Pole.mrid).where(Pole.line_id.isnot(None))
    )
    for row in poles_orphan.fetchall():
        pid, lid, pnum, pmrid = row
        if lid is not None and lid not in existing_line_ids:
            issues.append(ModelIssueResponse(
                issue_type="orphan_pole",
                entity_type="pole",
                entity_id=pid,
                line_id=lid,
                message=f"Опора «{pnum or pid}» привязана к несуществующей ЛЭП (id={lid})",
                details={"pole_number": pnum},
                entity_uid=pmrid,
                line_uid=None
            ))

    # 2) Отпаечные опоры, от которых ещё не построена ни одна отпайка (нет опор с tap_pole_id = эта опора)
    tap_poles_result = await db.execute(
        select(Pole.id, Pole.pole_number, Pole.line_id, Pole.mrid).where(Pole.is_tap_pole == True)
    )
    tap_pole_ids = set()
    tap_rows = []
    for row in tap_poles_result.fetchall():
        tap_pole_ids.add(row[0])
        tap_rows.append(row)
    if tap_pole_ids:
        has_tap_result = await db.execute(
            select(Pole.tap_pole_id).where(Pole.tap_pole_id.isnot(None)).distinct()
        )
        tap_poles_with_children = {r[0] for r in has_tap_result.fetchall()}
        for row in tap_rows:
            pid, pnum, lid, pmrid = row
            if pid not in tap_poles_with_children:
                if lid is not None:
                    line_ids_needed.add(lid)
                issues.append(ModelIssueResponse(
                    issue_type="tap_pole_without_tap",
                    entity_type="pole",
                    entity_id=pid,
                    line_id=lid,
                    message=f"Отпаечная опора «{pnum or pid}» без построенной отпайки",
                    details={"pole_number": pnum},
                    entity_uid=pmrid,
                    line_uid=None
                ))

    # 3) Сегменты линии без конечного узла (обрыв: to_connectivity_node_id и to_terminal_id пусты)
    segments_result = await db.execute(
        select(AClineSegment.id, AClineSegment.name, AClineSegment.line_id, AClineSegment.mrid).where(
            AClineSegment.to_connectivity_node_id.is_(None),
            AClineSegment.to_terminal_id.is_(None)
        )
    )
    for row in segments_result.fetchall():
        seg_id, name, line_id, seg_mrid = row
        if line_id is not None:
            line_ids_needed.add(line_id)
        issues.append(ModelIssueResponse(
            issue_type="line_break",
            entity_type="acline_segment",
            entity_id=seg_id,
            line_id=line_id,
            message=f"Участок «{name or seg_id}» без конечного узла (обрыв линии)",
            details={"segment_name": name},
            entity_uid=seg_mrid,
            line_uid=None
        ))

    # 4) ConnectivityNode с line_id несуществующей ЛЭП
    cn_result = await db.execute(
        select(ConnectivityNode.id, ConnectivityNode.line_id, ConnectivityNode.mrid).where(ConnectivityNode.line_id.isnot(None))
    )
    for row in cn_result.fetchall():
        cn_id, lid, cn_mrid = row
        if lid not in existing_line_ids:
            issues.append(ModelIssueResponse(
                issue_type="orphan_connectivity_node",
                entity_type="connectivity_node",
                entity_id=cn_id,
                line_id=lid,
                message=f"Узел соединения (id={cn_id}) привязан к несуществующей ЛЭП (id={lid})",
                details={},
                entity_uid=cn_mrid,
                line_uid=None
            ))

    # 5) LineSection с acline_segment_id несуществующего сегмента
    seg_ids_result = await db.execute(select(AClineSegment.id))
    existing_segment_ids = {r[0] for r in seg_ids_result.fetchall()}
    ls_result = await db.execute(select(LineSection.id, LineSection.acline_segment_id, LineSection.name, LineSection.mrid))
    for row in ls_result.fetchall():
        ls_id, aseg_id, name, ls_mrid = row
        if aseg_id is not None and aseg_id not in existing_segment_ids:
            issues.append(ModelIssueResponse(
                issue_type="orphan_line_section",
                entity_type="line_section",
                entity_id=ls_id,
                message=f"Секция линии «{name or ls_id}» привязана к несуществующему участку (id={aseg_id})",
                details={"acline_segment_id": aseg_id},
                entity_uid=ls_mrid,
                line_uid=None
            ))

    # 6) Пролёты (Span) с line_section_id несуществующей секции
    ls_ids_result = await db.execute(select(LineSection.id))
    existing_ls_ids = {r[0] for r in ls_ids_result.fetchall()}
    span_result = await db.execute(select(Span.id, Span.line_section_id, Span.span_number, Span.mrid))
    for row in span_result.fetchall():
        span_id, ls_id, snum, span_mrid = row
        if ls_id is not None and ls_id not in existing_ls_ids:
            issues.append(ModelIssueResponse(
                issue_type="orphan_span",
                entity_type="span",
                entity_id=span_id,
                message=f"Пролёт «{snum or span_id}» привязан к несуществующей секции линии (id={ls_id})",
                details={"line_section_id": ls_id, "span_number": snum},
                entity_uid=span_mrid,
                line_uid=None
            ))

    # Заполняем line_uid для записей, где line_id есть и ЛЭП существует
    line_ids_needed |= {i.line_id for i in issues if i.line_id is not None}
    line_uid_map = {}
    if line_ids_needed:
        pl_mrid_result = await db.execute(select(PowerLine.id, PowerLine.mrid).where(PowerLine.id.in_(line_ids_needed)))
        line_uid_map = {r[0]: r[1] for r in pl_mrid_result.fetchall()}
    for issue in issues:
        if issue.line_id is not None and issue.line_uid is None:
            issue.line_uid = line_uid_map.get(issue.line_id)

    return issues
