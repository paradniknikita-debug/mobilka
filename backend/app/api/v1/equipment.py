from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.core.security import get_current_active_user
from app.models.user import User
from app.models.power_line import Equipment
from app.schemas.power_line import EquipmentResponse, EquipmentCreate

router = APIRouter()

@router.get("", response_model=List[EquipmentResponse])
@router.get("/", response_model=List[EquipmentResponse])
async def get_all_equipment(
    skip: int = 0,
    limit: int = 100,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Получение всего оборудования (по всем линиям/опорам).

    Для карты нам нужно всё оборудование, поэтому фактически игнорируем пагинацию
    и возвращаем полный список. Параметры skip/limit оставлены для обратной совместимости.
    """
    result = await db.execute(
        select(Equipment).options(
            selectinload(Equipment.pole)
        )
    )
    equipment_list = result.scalars().all()

    # Гарантируем, что x_position/y_position не None:
    # если в БД они пусты, наследуем координаты опоры (pole).
    from app.models.power_line import Pole  # локальный импорт, чтобы избежать циклов
    for eq in equipment_list:
        if getattr(eq, "__dict__", None) is None:
            continue
        x = eq.__dict__.get("x_position", None)
        y = eq.__dict__.get("y_position", None)
        if (x is None or y is None) and isinstance(eq.pole, Pole):
            pole = eq.pole
            pts = getattr(pole, "position_points", None)
            if pts:
                point = pts[0]
                if x is None and getattr(point, "x_position", None) is not None:
                    eq.__dict__["x_position"] = float(point.x_position)
                if y is None and getattr(point, "y_position", None) is not None:
                    eq.__dict__["y_position"] = float(point.y_position)

    return equipment_list


@router.get("/{equipment_id}", response_model=EquipmentResponse)
async def get_equipment(
    equipment_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Получение оборудования по ID."""
    equipment = await db.get(Equipment, equipment_id)
    if not equipment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Equipment not found",
        )
    return equipment


@router.put("/{equipment_id}", response_model=EquipmentResponse)
async def update_equipment(
    equipment_id: int,
    equipment_data: EquipmentCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Обновление оборудования по ID."""
    equipment = await db.get(Equipment, equipment_id)
    if not equipment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Equipment not found",
        )

    data = equipment_data.model_dump() if hasattr(equipment_data, "model_dump") else equipment_data.dict()

    # Переносим все обновляемые поля; координаты (x_position, y_position) и pole_id
    # при необходимости можно менять, при этом координаты считаются независимыми от опоры.
    for key, value in data.items():
        if not hasattr(equipment, key):
            continue
        setattr(equipment, key, value)

    await db.commit()
    await db.refresh(equipment)
    return equipment


@router.delete("/{equipment_id}", status_code=status.HTTP_200_OK)
async def delete_equipment(
    equipment_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Удаление оборудования по ID."""
    equipment = await db.get(Equipment, equipment_id)
    if not equipment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Equipment not found",
        )

    await db.execute(delete(Equipment).where(Equipment.id == equipment_id))
    await db.commit()
    return {"message": "Equipment deleted successfully"}
