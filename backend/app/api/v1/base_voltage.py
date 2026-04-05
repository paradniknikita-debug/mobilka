"""
API endpoints для BaseVoltage (CIM стандарт)
"""
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.database import get_db
from app.core.security import get_current_active_user
from app.models.user import User
from app.models.base_voltage import BaseVoltage
from app.schemas.base_voltage import BaseVoltageCreate, BaseVoltageResponse
from app.models.base import generate_mrid

router = APIRouter()


@router.get("/", response_model=List[BaseVoltageResponse])
async def get_base_voltages(
    skip: int = 0,
    limit: int = 100,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение списка базовых уровней напряжения"""
    result = await db.execute(
        select(BaseVoltage)
        .offset(skip)
        .limit(limit)
        .order_by(BaseVoltage.nominal_voltage)
    )
    base_voltages = result.scalars().all()
    return base_voltages


@router.get("/{base_voltage_id}", response_model=BaseVoltageResponse)
async def get_base_voltage(
    base_voltage_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение базового уровня напряжения по ID"""
    result = await db.execute(
        select(BaseVoltage).where(BaseVoltage.id == base_voltage_id)
    )
    base_voltage = result.scalar_one_or_none()
    if not base_voltage:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="BaseVoltage not found"
        )
    return base_voltage


@router.post("/", response_model=BaseVoltageResponse)
async def create_base_voltage(
    base_voltage_data: BaseVoltageCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Создание нового базового уровня напряжения"""
    # Проверяем уникальность номинального напряжения
    existing = await db.execute(
        select(BaseVoltage).where(BaseVoltage.nominal_voltage == base_voltage_data.nominal_voltage)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="BaseVoltage with this nominal_voltage already exists"
        )
    
    # Создаем новый BaseVoltage
    db_base_voltage = BaseVoltage(
        mrid=base_voltage_data.mrid or generate_mrid(),
        **base_voltage_data.dict(exclude={'mrid'})
    )
    db.add(db_base_voltage)
    await db.commit()
    await db.refresh(db_base_voltage)
    
    return db_base_voltage


@router.put("/{base_voltage_id}", response_model=BaseVoltageResponse)
async def update_base_voltage(
    base_voltage_id: int,
    base_voltage_data: BaseVoltageCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Обновление базового уровня напряжения"""
    result = await db.execute(
        select(BaseVoltage).where(BaseVoltage.id == base_voltage_id)
    )
    db_base_voltage = result.scalar_one_or_none()
    if not db_base_voltage:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="BaseVoltage not found"
        )
    
    # Проверяем уникальность номинального напряжения (если изменилось)
    if base_voltage_data.nominal_voltage != db_base_voltage.nominal_voltage:
        existing = await db.execute(
            select(BaseVoltage).where(
                BaseVoltage.nominal_voltage == base_voltage_data.nominal_voltage,
                BaseVoltage.id != base_voltage_id
            )
        )
        if existing.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="BaseVoltage with this nominal_voltage already exists"
            )
    
    # Обновляем поля
    for key, value in base_voltage_data.dict(exclude={'mrid'}).items():
        setattr(db_base_voltage, key, value)
    
    await db.commit()
    await db.refresh(db_base_voltage)
    
    return db_base_voltage


@router.delete("/{base_voltage_id}")
async def delete_base_voltage(
    base_voltage_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Удаление базового уровня напряжения"""
    result = await db.execute(
        select(BaseVoltage).where(BaseVoltage.id == base_voltage_id)
    )
    db_base_voltage = result.scalar_one_or_none()
    if not db_base_voltage:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="BaseVoltage not found"
        )
    
    # Проверяем, используется ли BaseVoltage
    from app.models.substation import VoltageLevel
    from app.models.power_line import PowerLine
    
    voltage_levels = await db.execute(
        select(VoltageLevel).where(VoltageLevel.base_voltage_id == base_voltage_id)
    )
    if voltage_levels.scalars().first():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot delete BaseVoltage: it is used by VoltageLevels"
        )
    
    power_lines = await db.execute(
        select(PowerLine).where(PowerLine.base_voltage_id == base_voltage_id)
    )
    if power_lines.scalars().first():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot delete BaseVoltage: it is used by PowerLines"
        )
    
    await db.delete(db_base_voltage)
    await db.commit()
    
    return {"message": "BaseVoltage deleted successfully"}

