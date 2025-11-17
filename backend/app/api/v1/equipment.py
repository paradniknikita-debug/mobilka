from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.database import get_db
from app.core.security import get_current_active_user
from app.models.user import User
from app.models.power_line import Equipment
from app.schemas.power_line import EquipmentResponse

router = APIRouter()

@router.get("/", response_model=List[EquipmentResponse])
async def get_all_equipment(
    skip: int = 0,
    limit: int = 100,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение всего оборудования"""
    result = await db.execute(
        select(Equipment).offset(skip).limit(limit)
    )
    equipment = result.scalars().all()
    return equipment

@router.get("/{equipment_id}", response_model=EquipmentResponse)
async def get_equipment(
    equipment_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение оборудования по ID"""
    equipment = await db.get(Equipment, equipment_id)
    if not equipment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Equipment not found"
        )
    return equipment
