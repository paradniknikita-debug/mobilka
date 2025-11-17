from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.core.security import get_current_active_user
from app.models.user import User
from app.models.substation import Substation, Connection
from app.schemas.substation import (
    SubstationCreate, SubstationResponse, ConnectionCreate, ConnectionResponse
)

router = APIRouter()

# ===== ENDPOINTS ДЛЯ ПОДСТАНЦИЙ =====

@router.post("/", response_model=SubstationResponse)
async def create_substation(
    substation_data: SubstationCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Создание новой подстанции"""
    
    # Проверяем уникальность кода подстанции
    existing_code = await db.execute(
        select(Substation).where(Substation.code == substation_data.code)
    )
    if existing_code.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Substation code already exists"
        )
    
    # Создаем новую подстанцию
    db_substation = Substation(**substation_data.dict())
    db.add(db_substation)
    await db.commit()
    await db.refresh(db_substation)
    
    return db_substation

@router.get("/", response_model=List[SubstationResponse])
async def get_substations(
    skip: int = 0,
    limit: int = 100,
    is_active: Optional[bool] = None,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение списка подстанций с фильтрацией"""
    
    query = select(Substation)
    
    # Добавляем фильтр по активности если указан
    if is_active is not None:
        query = query.where(Substation.is_active == is_active)
    
    # Добавляем пагинацию
    query = query.offset(skip).limit(limit)
    
    result = await db.execute(query)
    substations = result.scalars().all()
    
    return substations

@router.get("/{substation_id}", response_model=SubstationResponse)
async def get_substation(
    substation_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение подстанции по ID"""
    
    result = await db.execute(
        select(Substation)
        .options(selectinload(Substation.connections))
        .where(Substation.id == substation_id)
    )
    substation = result.scalar_one_or_none()
    
    if not substation:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Substation not found"
        )
    
    return substation

@router.put("/{substation_id}", response_model=SubstationResponse)
async def update_substation(
    substation_id: int,
    substation_data: SubstationCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Обновление подстанции"""
    
    # Получаем существующую подстанцию
    result = await db.execute(
        select(Substation).where(Substation.id == substation_id)
    )
    substation = result.scalar_one_or_none()
    
    if not substation:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Substation not found"
        )
    
    # Проверяем уникальность кода (если изменился)
    if substation.code != substation_data.code:
        existing_code = await db.execute(
            select(Substation).where(Substation.code == substation_data.code)
        )
        if existing_code.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Substation code already exists"
            )
    
    # Обновляем данные
    for field, value in substation_data.dict().items():
        setattr(substation, field, value)
    
    await db.commit()
    await db.refresh(substation)
    
    return substation

@router.delete("/{substation_id}")
async def delete_substation(
    substation_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Удаление подстанции (мягкое удаление - деактивация)"""
    
    result = await db.execute(
        select(Substation).where(Substation.id == substation_id)
    )
    substation = result.scalar_one_or_none()
    
    if not substation:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Substation not found"
        )
    
    # Мягкое удаление - деактивируем
    substation.is_active = False
    await db.commit()
    
    return {"message": "Substation deactivated successfully"}

# ===== ENDPOINTS ДЛЯ ПОДКЛЮЧЕНИЙ =====

@router.post("/{substation_id}/connections", response_model=ConnectionResponse)
async def create_connection(
    substation_id: int,
    connection_data: ConnectionCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Создание подключения ЛЭП к подстанции"""
    
    # Проверяем существование подстанции
    substation = await db.get(Substation, substation_id)
    if not substation:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Substation not found"
        )
    
    # Создаем подключение
    db_connection = Connection(
        **connection_data.dict(),
        substation_id=substation_id
    )
    db.add(db_connection)
    await db.commit()
    await db.refresh(db_connection)
    
    return db_connection

@router.get("/{substation_id}/connections", response_model=List[ConnectionResponse])
async def get_substation_connections(
    substation_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение подключений подстанции"""
    
    result = await db.execute(
        select(Connection).where(Connection.substation_id == substation_id)
    )
    connections = result.scalars().all()
    
    return connections
