"""API сессий обхода ЛЭП. Администратор видит все обходы, инженер — только свои."""
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, status, Query
from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_

from app.database import get_db
from app.models.patrol_session import PatrolSession
from app.models.user import User
from app.models.power_line import PowerLine
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
        power_line_id=session.power_line_id,
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
    power_line_id: Optional[int] = Query(None, description="Фильтр по ЛЭП"),
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
    if power_line_id is not None:
        q = q.where(PatrolSession.power_line_id == power_line_id)
    q = q.order_by(PatrolSession.started_at.desc()).offset(offset).limit(limit)
    result = await db.execute(q)
    sessions = result.scalars().all()

    # Подгружаем имена пользователей и ЛЭП
    user_ids = {s.user_id for s in sessions}
    power_line_ids = {s.power_line_id for s in sessions}

    users_result = await db.execute(select(User).where(User.id.in_(user_ids)))
    users = {u.id: u.full_name or u.username for u in users_result.scalars().all()}
    pl_result = await db.execute(select(PowerLine).where(PowerLine.id.in_(power_line_ids)))
    power_lines = {pl.id: pl.name for pl in pl_result.scalars().all()}

    return [
        _session_to_response_with_names(
            s,
            users.get(s.user_id, ""),
            power_lines.get(s.power_line_id, ""),
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
    pl_result = await db.execute(select(PowerLine).where(PowerLine.id == body.power_line_id))
    if pl_result.scalar_one_or_none() is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"ЛЭП с id={body.power_line_id} не найдена. Возможно, она удалена на сервере или ещё не синхронизирована.",
        )
    session = PatrolSession(
        user_id=current_user.id,
        power_line_id=body.power_line_id,
        note=body.note,
    )
    db.add(session)
    await db.commit()
    await db.refresh(session)
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
    pl_result = await db.execute(select(PowerLine).where(PowerLine.id == session.power_line_id))
    pl = pl_result.scalar_one_or_none()
    return _session_to_response_with_names(
        session,
        (user.full_name or user.username) if user else "",
        pl.name if pl else "",
    )
