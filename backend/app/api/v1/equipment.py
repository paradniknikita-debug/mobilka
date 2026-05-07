from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.core.security import get_current_active_user
from app.models.user import User
from app.models.power_line import Equipment, Pole
from app.models.equipment_catalog import EquipmentCatalogItem
from app.models.change_log import ChangeLog
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

    # Сохраняем значения для аудита (все изменяемые поля)
    old_snapshot = {
        "name": equipment.name,
        "equipment_type": equipment.equipment_type,
        "manufacturer": equipment.manufacturer,
        "model": equipment.model,
        "serial_number": equipment.serial_number,
        "year_manufactured": equipment.year_manufactured,
        "installation_date": equipment.installation_date.isoformat() if equipment.installation_date else None,
        "condition": equipment.condition,
        "notes": equipment.notes,
        "defect": equipment.defect,
        "criticality": equipment.criticality,
        "defect_attachment": getattr(equipment, "defect_attachment", None),
        "rated_current": equipment.rated_current,
        "i_th": equipment.i_th,
        "ip_max": equipment.ip_max,
        "t_th": equipment.t_th,
        "normal_open": equipment.normal_open,
        "retained": equipment.retained,
        "identified_object_description": equipment.identified_object_description,
        "nameplate": equipment.nameplate,
        "psr_subtype": equipment.psr_subtype,
        "installation_display_name": equipment.installation_display_name,
        "tm_code": equipment.tm_code,
        "object_subtype": equipment.object_subtype,
        "pole_count": equipment.pole_count,
        "parent_object_ref": equipment.parent_object_ref,
        "parent_main_equipment_pole_ref": equipment.parent_main_equipment_pole_ref,
        "nominal_voltage_kv": equipment.nominal_voltage_kv,
        "nominal_breaking_current_ka": equipment.nominal_breaking_current_ka,
        "own_trip_time_sec": equipment.own_trip_time_sec,
        "emergency_current_a": equipment.emergency_current_a,
        "continuous_current_a": equipment.continuous_current_a,
        "arrester_type": equipment.arrester_type,
    }

    data = equipment_data.model_dump() if hasattr(equipment_data, "model_dump") else equipment_data.dict()

    # Если выбрана справочная позиция и ток не задан вручную,
    # подставляем номинальный ток из каталога.
    catalog_item_id = data.get("catalog_item_id")
    if catalog_item_id is not None:
        try:
            catalog_item_id = int(catalog_item_id)
        except (TypeError, ValueError):
            catalog_item_id = None
    if data.get("rated_current") is None and catalog_item_id is not None:
        catalog_item = await db.get(EquipmentCatalogItem, catalog_item_id)
        if catalog_item is not None and getattr(catalog_item, "current_a", None) is not None:
            data["rated_current"] = float(catalog_item.current_a)

    # Переносим все обновляемые поля; координаты (x_position, y_position) и pole_id
    # при необходимости можно менять, при этом координаты считаются независимыми от опоры.
    for key, value in data.items():
        if not hasattr(equipment, key):
            continue
        setattr(equipment, key, value)

    await db.commit()
    await db.refresh(equipment)

    new_snapshot = {
        "name": equipment.name,
        "equipment_type": equipment.equipment_type,
        "manufacturer": equipment.manufacturer,
        "model": equipment.model,
        "serial_number": equipment.serial_number,
        "year_manufactured": equipment.year_manufactured,
        "installation_date": equipment.installation_date.isoformat() if equipment.installation_date else None,
        "condition": equipment.condition,
        "notes": equipment.notes,
        "defect": equipment.defect,
        "criticality": equipment.criticality,
        "defect_attachment": getattr(equipment, "defect_attachment", None),
        "rated_current": equipment.rated_current,
        "i_th": equipment.i_th,
        "ip_max": equipment.ip_max,
        "t_th": equipment.t_th,
        "normal_open": equipment.normal_open,
        "retained": equipment.retained,
        "identified_object_description": equipment.identified_object_description,
        "nameplate": equipment.nameplate,
        "psr_subtype": equipment.psr_subtype,
        "installation_display_name": equipment.installation_display_name,
        "tm_code": equipment.tm_code,
        "object_subtype": equipment.object_subtype,
        "pole_count": equipment.pole_count,
        "parent_object_ref": equipment.parent_object_ref,
        "parent_main_equipment_pole_ref": equipment.parent_main_equipment_pole_ref,
        "nominal_voltage_kv": equipment.nominal_voltage_kv,
        "nominal_breaking_current_ka": equipment.nominal_breaking_current_ka,
        "own_trip_time_sec": equipment.own_trip_time_sec,
        "emergency_current_a": equipment.emergency_current_a,
        "continuous_current_a": equipment.continuous_current_a,
        "arrester_type": equipment.arrester_type,
    }
    changed_fields = [k for k, v in old_snapshot.items() if new_snapshot.get(k) != v]
    if changed_fields:
        line_id = None
        pole = await db.get(Pole, equipment.pole_id)
        if pole is not None:
            line_id = pole.line_id
        db.add(
            ChangeLog(
                user_id=current_user.id,
                source="web",
                action="update",
                entity_type="equipment",
                entity_id=equipment.id,
                payload={
                    "equipment_type": equipment.equipment_type,
                    "equipment_name": equipment.name,
                    "pole_id": equipment.pole_id,
                    "line_id": line_id,
                    "changed_fields": changed_fields,
                    "old": {k: old_snapshot.get(k) for k in changed_fields},
                    "new": {k: new_snapshot.get(k) for k in changed_fields},
                },
            )
        )
        await db.commit()
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
