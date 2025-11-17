from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.core.security import get_current_active_user
from app.models.user import User
from app.models.power_line import PowerLine, Tower, Span, Tap, Equipment
from app.schemas.power_line import (
    PowerLineCreate, PowerLineResponse, TowerCreate, TowerResponse,
    SpanCreate, SpanResponse, TapCreate, TapResponse, EquipmentCreate, EquipmentResponse
)

router = APIRouter()

@router.post("/", response_model=PowerLineResponse)
async def create_power_line(
    power_line_data: PowerLineCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Создание новой ЛЭП"""
    db_power_line = PowerLine(
        **power_line_data.dict(),
        created_by=current_user.id
    )
    db.add(db_power_line)
    await db.commit()
    await db.refresh(db_power_line)
    return db_power_line

@router.get("/", response_model=List[PowerLineResponse])
async def get_power_lines(
    skip: int = 0,
    limit: int = 100,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение списка ЛЭП"""
    result = await db.execute(
        select(PowerLine)
        .options(selectinload(PowerLine.towers))
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
        .options(selectinload(PowerLine.towers))
        .where(PowerLine.id == power_line_id)
    )
    power_line = result.scalar_one_or_none()
    if not power_line:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Power line not found"
        )
    return power_line

@router.post("/{power_line_id}/towers", response_model=TowerResponse)
async def create_tower(
    power_line_id: int,
    tower_data: TowerCreate,
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
    
    db_tower = Tower(
        **tower_data.dict(),
        power_line_id=power_line_id,
        created_by=current_user.id
    )
    db.add(db_tower)
    await db.commit()
    await db.refresh(db_tower)
    return db_tower

@router.get("/{power_line_id}/towers", response_model=List[TowerResponse])
async def get_towers(
    power_line_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение опор ЛЭП"""
    result = await db.execute(
        select(Tower).where(Tower.power_line_id == power_line_id)
    )
    towers = result.scalars().all()
    return towers

@router.post("/{power_line_id}/spans", response_model=SpanResponse)
async def create_span(
    power_line_id: int,
    span_data: SpanCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Создание пролёта"""
    
    # Проверка существования ЛЭП
    power_line = await db.get(PowerLine, power_line_id)
    if not power_line:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Power line not found"
        )
    
    db_span = Span(
        **span_data.dict(),
        power_line_id=power_line_id,
        created_by=current_user.id
    )
    db.add(db_span)
    await db.commit()
    await db.refresh(db_span)
    return db_span

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
