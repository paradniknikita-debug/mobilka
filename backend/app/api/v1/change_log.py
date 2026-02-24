"""
API журнала изменений.
События с веб- (Angular) и Flutter-клиентов: создание/редактирование/удаление объектов, начало/закрытие сессий.
"""
from typing import List, Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc

from app.database import get_db
from app.core.security import get_current_active_user
from app.models.user import User
from app.models.change_log import ChangeLog
from app.schemas.change_log import ChangeLogCreate, ChangeLogResponse

router = APIRouter()


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
    return entry


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
    """Список записей журнала изменений (для отображения в вебе и во Flutter)."""
    q = select(ChangeLog).order_by(desc(ChangeLog.created_at)).limit(limit).offset(offset)
    if source:
        q = q.where(ChangeLog.source == source)
    if action:
        q = q.where(ChangeLog.action == action)
    if entity_type:
        q = q.where(ChangeLog.entity_type == entity_type)
    result = await db.execute(q)
    return result.scalars().all()
