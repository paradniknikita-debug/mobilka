from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.core.security import get_current_active_user
from app.models.user import User
from app.models.power_line import PowerLine, Pole, Span, Tap, Equipment
from app.schemas.power_line import (
    PowerLineCreate, PowerLineResponse, PoleCreate, PoleResponse,
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
    from app.models.base import generate_mrid
    
    power_line_dict = power_line_data.dict()
    mrid = power_line_dict.pop('mrid', None)
    branch_name = power_line_dict.pop('branch_name', None)
    region_name = power_line_dict.pop('region_name', None)
    
    # Проверяем уникальность mrid, если он указан
    if mrid:
        existing = await db.execute(
            select(PowerLine).where(PowerLine.mrid == mrid)
        )
        if existing.scalar_one_or_none():
            raise HTTPException(status_code=400, detail=f"ЛЭП с UID '{mrid}' уже существует")
    else:
        mrid = generate_mrid()
    
    # Генерируем код автоматически на основе mrid
    code = f"LEP-{mrid[:8].upper()}"
    
    # Проверяем уникальность code
    existing = await db.execute(
        select(PowerLine).where(PowerLine.code == code)
    )
    if existing.scalar_one_or_none():
        # Если код уже существует, добавляем суффикс
        counter = 1
        while True:
            new_code = f"{code}-{counter}"
            existing = await db.execute(
                select(PowerLine).where(PowerLine.code == new_code)
            )
            if not existing.scalar_one_or_none():
                code = new_code
                break
            counter += 1
    
    # Формируем описание из branch_name и region_name
    description_parts = []
    if branch_name:
        description_parts.append(f"Административная принадлежность: {branch_name}")
    if region_name:
        description_parts.append(f"Географический регион: {region_name}")
    if power_line_dict.get('description'):
        description_parts.append(power_line_dict.get('description'))
    
    final_description = '\n'.join(description_parts) if description_parts else None
    
    # Валидация напряжения (стандартные значения)
    voltage_level = power_line_dict.get('voltage_level')
    if voltage_level is not None:
        if voltage_level != 0:
            standard_voltages = [0.4, 6, 10, 35, 110, 220, 330, 500, 750]
            # Проверяем с учетом возможных погрешностей float (округляем до 1 знака)
            voltage_rounded = round(float(voltage_level), 1)
            if voltage_rounded not in standard_voltages:
                raise HTTPException(
                    status_code=400, 
                    detail=f"Номинальное напряжение должно быть одним из стандартных значений: {', '.join(map(str, standard_voltages))} кВ"
                )
        if voltage_level < 0:
            raise HTTPException(status_code=400, detail="Напряжение не может быть отрицательным")
    
    # Если напряжение не указано, устанавливаем значение по умолчанию (0)
    # Это требуется, так как поле voltage_level в модели не nullable
    if 'voltage_level' not in power_line_dict or power_line_dict.get('voltage_level') is None:
        power_line_dict['voltage_level'] = 0.0
    
    # Валидация длины
    length = power_line_dict.get('length')
    if length is not None:
        if length < 0:
            raise HTTPException(status_code=400, detail="Длина не может быть отрицательной")
    
    # Удаляем поля, которые не должны передаваться в модель
    power_line_dict.pop('branch_id', None)
    power_line_dict.pop('region_id', None)
    power_line_dict.pop('code', None)  # code генерируется автоматически
    
    db_power_line = PowerLine(
        mrid=mrid,
        code=code,
        description=final_description,
        **power_line_dict,
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
        .options(selectinload(PowerLine.poles))
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
        .options(selectinload(PowerLine.poles))
        .where(PowerLine.id == power_line_id)
    )
    power_line = result.scalar_one_or_none()
    if not power_line:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Power line not found"
        )
    return power_line

@router.post("/{power_line_id}/poles", response_model=PoleResponse)
async def create_pole(
    power_line_id: int,
    pole_data: PoleCreate,
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
    
    # Проверка уникальности mrid, если он передан
    if pole_data.mrid:
        existing_pole = await db.execute(
            select(Pole).where(Pole.mrid == pole_data.mrid)
        )
        if existing_pole.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Pole with mrid '{pole_data.mrid}' already exists"
            )
    
    # Создаем словарь данных, исключая mrid если он None
    pole_dict = pole_data.dict(exclude={'mrid'})
    if pole_data.mrid:
        pole_dict['mrid'] = pole_data.mrid
    
    db_pole = Pole(
        **pole_dict,
        power_line_id=power_line_id,
        created_by=current_user.id
    )
    db.add(db_pole)
    await db.commit()
    await db.refresh(db_pole)
    return db_pole

@router.get("/{power_line_id}/poles", response_model=List[PoleResponse])
async def get_poles(
    power_line_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение опор ЛЭП"""
    result = await db.execute(
        select(Pole).where(Pole.power_line_id == power_line_id)
    )
    poles = result.scalars().all()
    return poles

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

@router.delete("/{power_line_id}")
async def delete_power_line(
    power_line_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Удаление ЛЭП"""
    # Проверяем существование ЛЭП
    result = await db.execute(
        select(PowerLine).where(PowerLine.id == power_line_id)
    )
    power_line = result.scalar_one_or_none()
    
    if not power_line:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Power line not found"
        )
    
    # Удаляем ЛЭП
    await db.execute(delete(PowerLine).where(PowerLine.id == power_line_id))
    await db.commit()
    
    return {"message": "Power line deleted successfully"}
