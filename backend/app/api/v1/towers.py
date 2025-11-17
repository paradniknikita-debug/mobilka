from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.core.security import get_current_active_user
from app.models.user import User
from app.models.power_line import Tower, Equipment
from app.schemas.power_line import EquipmentCreate, EquipmentResponse, TowerResponse

router = APIRouter()

@router.get("/", response_model=List[TowerResponse])
async def get_all_towers(
    skip: int = 0,
    limit: int = 100,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение всех опор"""
    result = await db.execute(
        select(Tower)
        .options(selectinload(Tower.equipment))
        .offset(skip)
        .limit(limit)
    )
    towers = result.scalars().all()
    return towers

@router.get("/{tower_id}", response_model=TowerResponse)
async def get_tower(
    tower_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение опоры по ID"""
    result = await db.execute(
        select(Tower)
        .options(selectinload(Tower.equipment))
        .where(Tower.id == tower_id)
    )
    tower = result.scalar_one_or_none()
    if not tower:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Tower not found"
        )
    return tower

@router.post("/{tower_id}/equipment", response_model=EquipmentResponse)
async def create_equipment(
    tower_id: int,
    equipment_data: EquipmentCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Добавление оборудования к опоре"""
    
    # Проверка существования опоры
    tower = await db.get(Tower, tower_id)
    if not tower:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Tower not found"
        )
    
    db_equipment = Equipment(
        **equipment_data.dict(),
        tower_id=tower_id,
        created_by=current_user.id
    )
    db.add(db_equipment)
    await db.commit()
    await db.refresh(db_equipment)
    return db_equipment

@router.get("/{tower_id}/equipment", response_model=List[EquipmentResponse])
async def get_tower_equipment(
    tower_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение оборудования опоры"""
    result = await db.execute(
        select(Equipment).where(Equipment.tower_id == tower_id)
    )
    equipment = result.scalars().all()
    return equipment
