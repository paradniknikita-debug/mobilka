from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete, update
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

@router.delete("/{pole_id}", status_code=status.HTTP_200_OK)
async def delete_pole(
    pole_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Удаление опоры"""
    # Проверяем существование опоры
    result = await db.execute(
        select(Pole).where(Pole.id == pole_id)
    )
    pole = result.scalar_one_or_none()
    
    if not pole:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pole not found"
        )
    
    # Удаляем связанные объекты перед удалением опоры
    from app.models.cim_line_structure import ConnectivityNode
    from app.models.acline_segment import AClineSegment
    
    if pole.connectivity_node_id:
        connectivity_node_id = pole.connectivity_node_id
        
        # Удаляем связанные Span (пролёты, которые начинаются или заканчиваются в этом узле)
        from app.models.power_line import Span
        span_from_stmt = delete(Span).where(Span.from_connectivity_node_id == connectivity_node_id)
        span_to_stmt = delete(Span).where(Span.to_connectivity_node_id == connectivity_node_id)
        await db.execute(span_from_stmt)
        await db.execute(span_to_stmt)
        
        # Удаляем связанные AClineSegment (сегменты, которые начинаются или заканчиваются в этом узле)
        acline_from_stmt = delete(AClineSegment).where(AClineSegment.from_connectivity_node_id == connectivity_node_id)
        acline_to_stmt = delete(AClineSegment).where(AClineSegment.to_connectivity_node_id == connectivity_node_id)
        await db.execute(acline_from_stmt)
        await db.execute(acline_to_stmt)
        
        # Сначала обнуляем connectivity_node_id в опоре, чтобы разорвать внешний ключ
        update_stmt = update(Pole).where(Pole.id == pole_id).values(connectivity_node_id=None)
        await db.execute(update_stmt)
        
        # Теперь можем безопасно удалить ConnectivityNode
        connectivity_node_stmt = delete(ConnectivityNode).where(ConnectivityNode.pole_id == pole_id)
        await db.execute(connectivity_node_stmt)
    
    # Удаляем опору используя правильный синтаксис SQLAlchemy 2.0 async
    stmt = delete(Pole).where(Pole.id == pole_id)
    await db.execute(stmt)
    await db.commit()
    
    return {"message": "Pole deleted successfully"}

