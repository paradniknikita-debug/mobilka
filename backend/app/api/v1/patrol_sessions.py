"""API сессий обхода ЛЭП. Администратор видит все обходы, инженер — только свои. События обходов пишутся в журнал изменений."""
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, status, Query
from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, func

from app.database import get_db
from app.models.patrol_session import PatrolSession
from app.models.user import User
from app.models.power_line import PowerLine
from app.models.change_log import ChangeLog
from app.core.security import get_current_active_user
from app.schemas.patrol_session import (
    PatrolSessionCreate,
    PatrolSessionResponse,
    PatrolSessionWithNamesResponse,
)

router = APIRouter()


def _session_to_response_with_names(
    session: PatrolSession,
    user_name: str,
    power_line_name: str,
) -> PatrolSessionWithNamesResponse:
    return PatrolSessionWithNamesResponse(
        id=session.id,
        user_id=session.user_id,
        line_id=session.line_id,
        note=session.note,
        started_at=session.started_at,
        ended_at=session.ended_at,
        user_name=user_name,
        power_line_name=power_line_name,
    )


@router.get("", response_model=List[PatrolSessionWithNamesResponse])
async def list_patrol_sessions(
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
    user_id: Optional[int] = Query(None, description="Фильтр по пользователю (только для admin)"),
    line_id: Optional[int] = Query(None, description="Фильтр по ЛЭП (id линии)"),
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
):
    """
    Список сессий обхода.
    Администратор видит все сессии, остальные — только свои.
    """
    q = select(PatrolSession)
    if current_user.role != "admin":
        q = q.where(PatrolSession.user_id == current_user.id)
    elif user_id is not None:
        q = q.where(PatrolSession.user_id == user_id)
    if line_id is not None:
        q = q.where(PatrolSession.line_id == line_id)
    q = q.order_by(PatrolSession.started_at.desc()).offset(offset).limit(limit)
    result = await db.execute(q)
    sessions = result.scalars().all()

    # Подгружаем имена пользователей и ЛЭП
    user_ids = {s.user_id for s in sessions}
    line_ids = {s.line_id for s in sessions}

    users_result = await db.execute(select(User).where(User.id.in_(user_ids)))
    users = {u.id: u.full_name or u.username for u in users_result.scalars().all()}
    pl_result = await db.execute(select(PowerLine).where(PowerLine.id.in_(line_ids)))
    power_lines = {pl.id: pl.name for pl in pl_result.scalars().all()}

    return [
        _session_to_response_with_names(
            s,
            users.get(s.user_id, ""),
            power_lines.get(s.line_id, ""),
        )
        for s in sessions
    ]


@router.post("", response_model=PatrolSessionResponse)
async def create_patrol_session(
    body: PatrolSessionCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Создать сессию обхода (начало обхода)."""
    # Проверяем, что ЛЭП существует (избегаем ForeignKeyViolation)
    pl_result = await db.execute(select(PowerLine).where(PowerLine.id == body.line_id))
    if pl_result.scalar_one_or_none() is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"ЛЭП с id={body.line_id} не найдена. Укажите line_id существующей линии на сервере (при синхронизации с мобильного приложения используйте серверный id линии, а не локальный).",
        )
    session = PatrolSession(
        user_id=current_user.id,
        line_id=body.line_id,
        note=body.note,
    )
    db.add(session)
    await db.commit()
    await db.refresh(session)

    # Запись в журнал изменений: начало обхода
    pl_result = await db.execute(select(PowerLine).where(PowerLine.id == body.line_id))
    pl = pl_result.scalar_one_or_none()
    change_entry = ChangeLog(
        user_id=current_user.id,
        source="flutter",
        action="session_start",
        entity_type="patrol_session",
        entity_id=session.id,
        payload={
            "line_id": body.line_id,
            "line_name": pl.name if pl else None,
            "started_at": session.started_at.isoformat() if session.started_at else None,
            "note": body.note,
        },
        session_id=str(session.id),
    )
    db.add(change_entry)
    await db.commit()

    return session


@router.patch("/{session_id}", response_model=PatrolSessionResponse)
async def end_patrol_session(
    session_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Завершить сессию обхода (установить ended_at)."""
    result = await db.execute(
        select(PatrolSession).where(
            and_(
                PatrolSession.id == session_id,
                PatrolSession.user_id == current_user.id,
            )
        )
    )
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Сессия не найдена или доступ запрещён",
        )
    session.ended_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(session)

    # Собираем сводку: что было сделано в рамках сессии (по журналу изменений).
    # Окно: started_at .. ended_at. Фильтруем по пользователю и ЛЭП, исключаем записи про саму patrol_session.
    summary_items = []
    action_counts: dict[str, int] = {}
    entity_counts: dict[str, int] = {}
    try:
        started = session.started_at
        ended = session.ended_at or datetime.now(timezone.utc)
        if started:
            q = (
                select(ChangeLog)
                .where(
                    and_(
                        ChangeLog.created_at >= started,
                        ChangeLog.created_at <= ended,
                        ChangeLog.user_id == current_user.id,
                    )
                )
                .order_by(ChangeLog.created_at.asc())
                .limit(500)
            )
            rows = (await db.execute(q)).scalars().all()
            for r in rows:
                if r.entity_type == "patrol_session" and r.entity_id == session.id:
                    continue
                # если запись относится к конкретной ЛЭП — учитываем; иначе не отбрасываем,
                # но помечаем (например, создание ЛЭП/пользовательские действия вне линии)
                line_id_in_payload = None
                try:
                    if isinstance(r.payload, dict):
                        line_id_in_payload = r.payload.get("line_id")
                except Exception:
                    line_id_in_payload = None
                if session.line_id is not None and line_id_in_payload is not None and int(line_id_in_payload) != int(session.line_id):
                    continue

                action_counts[r.action] = action_counts.get(r.action, 0) + 1
                entity_counts[r.entity_type] = entity_counts.get(r.entity_type, 0) + 1
                if len(summary_items) < 80:
                    summary_items.append(
                        {
                            "created_at": r.created_at.isoformat() if r.created_at else None,
                            "action": r.action,
                            "entity_type": r.entity_type,
                            "entity_id": r.entity_id,
                            "payload": r.payload,
                        }
                    )
    except Exception:
        pass

    # Запись в журнал изменений: завершение обхода
    pl_result = await db.execute(select(PowerLine).where(PowerLine.id == session.line_id))
    pl = pl_result.scalar_one_or_none()
    change_entry = ChangeLog(
        user_id=current_user.id,
        source="flutter",
        action="session_end",
        entity_type="patrol_session",
        entity_id=session.id,
        payload={
            "line_id": session.line_id,
            "line_name": pl.name if pl else None,
            "started_at": session.started_at.isoformat() if session.started_at else None,
            "ended_at": session.ended_at.isoformat() if session.ended_at else None,
            "note": session.note,
            "session_summary": {
                "by_action": action_counts,
                "by_entity": entity_counts,
                "items_preview": summary_items,
            },
        },
        session_id=str(session.id),
    )
    db.add(change_entry)
    await db.commit()
    await db.refresh(session)

    return session


@router.get("/{session_id}", response_model=PatrolSessionWithNamesResponse)
async def get_patrol_session(
    session_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Получить одну сессию по id. Админ — любую, иначе только свою."""
    result = await db.execute(select(PatrolSession).where(PatrolSession.id == session_id))
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Сессия не найдена")
    if current_user.role != "admin" and session.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Доступ запрещён")

    user_result = await db.execute(select(User).where(User.id == session.user_id))
    user = user_result.scalar_one_or_none()
    pl_result = await db.execute(select(PowerLine).where(PowerLine.id == session.line_id))
    pl = pl_result.scalar_one_or_none()
    return _session_to_response_with_names(
        session,
        (user.full_name or user.username) if user else "",
        pl.name if pl else "",
    )
