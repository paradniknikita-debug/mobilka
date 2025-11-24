from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.core.security import get_current_active_user
from app.models.user import User
from app.models.power_line import Pole, Equipment
from app.schemas.power_line import EquipmentCreate, EquipmentResponse, PoleResponse

router = APIRouter()

@router.get("/", response_model=List[PoleResponse])
async def get_all_poles(
    skip: int = 0,
    limit: int = 100,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение всех опор"""
    result = await db.execute(
        select(Pole)
        .options(selectinload(Pole.equipment))
        .offset(skip)
        .limit(limit)
    )
    poles = result.scalars().all()
    return poles

@router.get("/{pole_id}", response_model=PoleResponse)
async def get_pole(
    pole_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение опоры по ID"""
    result = await db.execute(
        select(Pole)
        .options(selectinload(Pole.equipment))
        .where(Pole.id == pole_id)
    )
    pole = result.scalar_one_or_none()
    if not pole:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pole not found"
        )
    return pole

@router.post("/{pole_id}/equipment", response_model=EquipmentResponse)
async def create_equipment(
    pole_id: int,
    equipment_data: EquipmentCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Добавление оборудования к опоре"""
    
    # Проверка существования опоры
    pole = await db.get(Pole, pole_id)
    if not pole:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pole not found"
        )
    
    db_equipment = Equipment(
        **equipment_data.dict(),
        pole_id=pole_id,
        created_by=current_user.id
    )
    db.add(db_equipment)
    await db.commit()
    await db.refresh(db_equipment)
    return db_equipment

@router.get("/{pole_id}/equipment", response_model=List[EquipmentResponse])
async def get_pole_equipment(
    pole_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение оборудования опоры"""
    result = await db.execute(
        select(Equipment).where(Equipment.pole_id == pole_id)
    )
    equipment = result.scalars().all()
    return equipment

