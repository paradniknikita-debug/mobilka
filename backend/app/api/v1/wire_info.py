"""
API endpoints для WireInfo (CIM стандарт)
"""
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.database import get_db
from app.core.security import get_current_active_user
from app.models.user import User
from app.models.wire_info import WireInfo
from app.schemas.wire_info import WireInfoCreate, WireInfoResponse
from app.models.base import generate_mrid

router = APIRouter()


@router.get("/", response_model=List[WireInfoResponse])
async def get_wire_infos(
    skip: int = 0,
    limit: int = 100,
    is_active: Optional[bool] = None,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение списка информации о проводах"""
    query = select(WireInfo)
    
    if is_active is not None:
        query = query.where(WireInfo.is_active == is_active)
    
    result = await db.execute(
        query
        .offset(skip)
        .limit(limit)
        .order_by(WireInfo.name)
    )
    wire_infos = result.scalars().all()
    return wire_infos


@router.get("/{wire_info_id}", response_model=WireInfoResponse)
async def get_wire_info(
    wire_info_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение информации о проводе по ID"""
    result = await db.execute(
        select(WireInfo).where(WireInfo.id == wire_info_id)
    )
    wire_info = result.scalar_one_or_none()
    if not wire_info:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="WireInfo not found"
        )
    return wire_info


@router.post("/", response_model=WireInfoResponse)
async def create_wire_info(
    wire_info_data: WireInfoCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Создание новой информации о проводе"""
    # Проверяем уникальность названия
    existing = await db.execute(
        select(WireInfo).where(WireInfo.name == wire_info_data.name)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="WireInfo with this name already exists"
        )
    
    # Создаем новый WireInfo
    db_wire_info = WireInfo(
        mrid=wire_info_data.mrid or generate_mrid(),
        **wire_info_data.dict(exclude={'mrid'})
    )
    db.add(db_wire_info)
    await db.commit()
    await db.refresh(db_wire_info)
    
    return db_wire_info


@router.put("/{wire_info_id}", response_model=WireInfoResponse)
async def update_wire_info(
    wire_info_id: int,
    wire_info_data: WireInfoCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Обновление информации о проводе"""
    result = await db.execute(
        select(WireInfo).where(WireInfo.id == wire_info_id)
    )
    db_wire_info = result.scalar_one_or_none()
    if not db_wire_info:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="WireInfo not found"
        )
    
    # Проверяем уникальность названия (если изменилось)
    if wire_info_data.name != db_wire_info.name:
        existing = await db.execute(
            select(WireInfo).where(
                WireInfo.name == wire_info_data.name,
                WireInfo.id != wire_info_id
            )
        )
        if existing.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="WireInfo with this name already exists"
            )
    
    # Обновляем поля
    for key, value in wire_info_data.dict(exclude={'mrid'}).items():
        setattr(db_wire_info, key, value)
    
    await db.commit()
    await db.refresh(db_wire_info)
    
    return db_wire_info


@router.delete("/{wire_info_id}")
async def delete_wire_info(
    wire_info_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Удаление информации о проводе"""
    result = await db.execute(
        select(WireInfo).where(WireInfo.id == wire_info_id)
    )
    db_wire_info = result.scalar_one_or_none()
    if not db_wire_info:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="WireInfo not found"
        )
    
    # Проверяем, используется ли WireInfo
    from app.models.cim_line_structure import LineSection
    from app.models.acline_segment import AClineSegment
    
    line_sections = await db.execute(
        select(LineSection).where(LineSection.wire_info_id == wire_info_id)
    )
    if line_sections.scalars().first():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot delete WireInfo: it is used by LineSections"
        )
    
    acline_segments = await db.execute(
        select(AClineSegment).where(AClineSegment.wire_info_id == wire_info_id)
    )
    if acline_segments.scalars().first():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot delete WireInfo: it is used by AClineSegments"
        )
    
    await db.delete(db_wire_info)
    await db.commit()
    
    return {"message": "WireInfo deleted successfully"}

