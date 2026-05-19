from __future__ import annotations

import io
import json
from typing import List, Optional

import pandas as pd
from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from fastapi.responses import Response
from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.equipment_catalog_attrs import (
    FLAT_ATTR_COLUMNS,
    attrs_from_flat_row,
    flat_from_attrs_json,
)
from app.core.roles import require_admin_user, require_catalog_manager
from app.core.security import get_current_active_user
from app.database import get_db
from app.models.equipment_catalog import EquipmentCatalogItem
from app.models.user import User
from app.schemas.equipment_catalog import (
    EquipmentCatalogCreate,
    EquipmentCatalogResponse,
    EquipmentCatalogUpdate,
)

router = APIRouter()


def _catalog_full_name(brand: str, model: str) -> str:
    """
    Полное имя без дублирования: если модель уже начинается с марки (РЛК-10/400 при brand=РЛК),
    не повторяем марку в full_name.
    """
    b = (brand or "").strip()
    m = (model or "").strip()
    if not m:
        return b
    if not b:
        return m
    bl, ml = b.lower(), m.lower()
    if ml == bl:
        return m
    if ml.startswith(bl + "-") or ml.startswith(bl + " "):
        return m
    return f"{b} {m}"


def _normalize_type_code(value: Optional[str]) -> Optional[str]:
    if value is None:
        return None
    v = str(value).strip().lower()
    if not v:
        return None
    aliases = {
        "разъединитель": "disconnector",
        "disconnector": "disconnector",
        "выключатель": "breaker",
        "breaker": "breaker",
        "зн": "zn",
        "grounding_switch": "zn",
        "разрядник": "arrester",
        "опн": "arrester",
        "arrester": "arrester",
        "recloser": "recloser",
        "реклоузер": "recloser",
    }
    return aliases.get(v, v)


def _to_bool(v: object, default: bool = True) -> bool:
    if v is None:
        return default
    if isinstance(v, bool):
        return v
    s = str(v).strip().lower()
    if s in {"1", "true", "yes", "y", "да"}:
        return True
    if s in {"0", "false", "no", "n", "нет"}:
        return False
    return default


def _default_catalog_payloads() -> list[dict]:
    """Базовый расширенный справочник: >=10 позиций на каждый основной тип."""
    rows: list[dict] = []

    def add(
        type_code: str,
        brand: str,
        model: str,
        kv: float | None,
        current_a: float | None,
        attrs: dict,
        *,
        manufacturer: str = "Н/Д",
        country: str = "BY",
        description: str | None = None,
    ) -> None:
        rows.append(
            {
                "type_code": type_code,
                "brand": brand,
                "model": model,
                "full_name": _catalog_full_name(brand, model),
                "voltage_kv": kv,
                "current_a": current_a,
                "manufacturer": manufacturer,
                "country": country,
                "description": description or f"{type_code}: {brand} {model}",
                "attrs_json": json.dumps(attrs, ensure_ascii=False),
                "is_active": True,
            }
        )

    # Disconnector (10)
    add("disconnector", "РЛНД", "РЛНД-10/400", 10, 400, {"i_th": 10000, "ip_max": 25000, "t_th": 1, "normal_open": False, "retained": False, "object_subtype": "withdrawable_disconnector"})
    add("disconnector", "РЛНД", "РЛНД-10/630", 10, 630, {"i_th": 12500, "ip_max": 32000, "t_th": 1, "normal_open": False, "retained": False})
    add("disconnector", "РЛК", "РЛК-10/400", 10, 400, {"i_th": 16000, "ip_max": 40000, "t_th": 2, "normal_open": False, "retained": False})
    add("disconnector", "РЛК", "РЛК-10/630", 10, 630, {"i_th": 20000, "ip_max": 50000, "t_th": 2, "normal_open": False, "retained": False})
    add("disconnector", "РЛК", "РЛК-35/630", 35, 630, {"i_th": 20000, "ip_max": 50000, "t_th": 3, "normal_open": False, "retained": False})
    add("disconnector", "РГН", "РГН-35/1000", 35, 1000, {"i_th": 25000, "ip_max": 63000, "t_th": 3, "normal_open": False, "retained": False})
    add("disconnector", "УЗТТ", "РР-110/630", 110, 630, {"i_th": 31500, "ip_max": 80000, "t_th": 3, "normal_open": False, "retained": False}, manufacturer="Н/Д", country="BY")
    add("disconnector", "КЭАЗ", "РВЗ-10/630", 10, 630, {"i_th": 20000, "ip_max": 50000, "t_th": 3, "normal_open": False, "retained": False}, manufacturer="КЭАЗ", country="RU")
    add("disconnector", "РВ", "РВ-10/630", 10, 630, {"i_th": 25000, "ip_max": 63000, "t_th": 4, "normal_open": False, "retained": False})
    add("disconnector", "Tavrida", "DS-10/630", 10, 630, {"i_th": 20000, "ip_max": 50000, "t_th": 3, "normal_open": False, "retained": False}, manufacturer="Tavrida Electric", country="RU")

    # Breaker (10)
    add("breaker", "ВВ/TEL", "ВВ/TEL-10-20/1000", 10, 1000, {"i_th": 20000, "ip_max": 51000, "t_th": 3, "nominal_breaking_current_ka": 20, "own_trip_time_sec": 0.015, "object_subtype": "vacuum_breaker"})
    add("breaker", "ВВ/TEL", "ВВ/TEL-10-31.5/1600", 10, 1600, {"i_th": 31500, "ip_max": 80000, "t_th": 3, "nominal_breaking_current_ka": 31.5, "own_trip_time_sec": 0.05, "object_subtype": "vacuum_breaker"})
    add("breaker", "ВМП", "ВМП-10-20/630", 10, 630, {"i_th": 20000, "ip_max": 50000, "t_th": 3, "nominal_breaking_current_ka": 20, "own_trip_time_sec": 0.09, "object_subtype": "withdrawable_breaker"})
    add("breaker", "ВМП", "ВМП-10-31.5/1000", 10, 1000, {"i_th": 31500, "ip_max": 80000, "t_th": 3, "nominal_breaking_current_ka": 31.5, "own_trip_time_sec": 0.09, "object_subtype": "withdrawable_breaker"})
    add("breaker", "КЭАЗ", "ВА-35/1600", 35, 1600, {"i_th": 25000, "ip_max": 63000, "t_th": 3, "nominal_breaking_current_ka": 25, "own_trip_time_sec": 0.06, "object_subtype": "vacuum_breaker"}, manufacturer="КЭАЗ", country="RU")
    add("breaker", "КЭАЗ", "ВА-10-20/630", 10, 630, {"i_th": 20000, "ip_max": 50000, "t_th": 3, "nominal_breaking_current_ka": 20, "own_trip_time_sec": 0.08, "object_subtype": "vacuum_breaker"}, manufacturer="КЭАЗ", country="RU")
    add("breaker", "Tavrida", "BB/TEL-35-25/1600", 35, 1600, {"i_th": 25000, "ip_max": 63000, "t_th": 3, "nominal_breaking_current_ka": 25, "own_trip_time_sec": 0.06, "object_subtype": "vacuum_breaker"})
    add("breaker", "IEK", "ВУ-10-20/1000", 10, 1000, {"i_th": 25000, "ip_max": 63000, "t_th": 3, "nominal_breaking_current_ka": 20, "own_trip_time_sec": 0.09, "object_subtype": "vacuum_breaker"}, manufacturer="IEK", country="RU")
    add("breaker", "УЗТТ", "ВГ-110/3150", 110, 3150, {"i_th": 40000, "ip_max": 100000, "t_th": 3, "nominal_breaking_current_ka": 40, "own_trip_time_sec": 0.04, "object_subtype": "sf6_breaker"}, manufacturer="Н/Д", country="BY")
    add("breaker", "УЗТТ", "ВН-10/630", 10, 630, {"i_th": 20000, "ip_max": 50000, "t_th": 3, "nominal_breaking_current_ka": 20, "own_trip_time_sec": 0.08, "object_subtype": "vacuum_breaker"}, manufacturer="Н/Д", country="BY")

    # Grounding switch / ZN (10)
    add("zn", "ЗН", "ЗН-10", 10, 400, {"psr_subtype": "short_circuiter", "pole_count": 1, "normal_open": True, "retained": False, "object_subtype": "short_circuiter", "i_th": 10000, "ip_max": 25000, "t_th": 1})
    add("zn", "ЗН", "ЗН-10У1", 10, 630, {"psr_subtype": "short_circuiter", "pole_count": 1, "normal_open": True, "retained": False, "i_th": 12500, "ip_max": 32000, "t_th": 1})
    add("zn", "ЗН", "ЗН-35", 35, 1000, {"psr_subtype": "short_circuiter", "pole_count": 1, "normal_open": True, "retained": False, "i_th": 25000, "ip_max": 63000, "t_th": 3})
    add("zn", "ЗОН", "ЗОН-10/400", 10, 400, {"psr_subtype": "short_circuiter", "pole_count": 1, "normal_open": True, "retained": False})
    add("zn", "ЗОН", "ЗОН-10/630", 10, 630, {"psr_subtype": "short_circuiter", "pole_count": 1, "normal_open": True, "retained": False})
    add("zn", "EKF", "ЗН-10/400-УХЛ1", 10, 400, {"psr_subtype": "short_circuiter", "pole_count": 1, "normal_open": True, "retained": False})
    add("zn", "КЭАЗ", "ЗНЛ-10/630", 10, 630, {"psr_subtype": "short_circuiter", "pole_count": 1, "normal_open": True, "retained": False})
    add("zn", "IEK", "ЗН-6/400", 6, 400, {"psr_subtype": "short_circuiter", "pole_count": 1, "normal_open": True, "retained": False})
    add("zn", "IEK", "ЗНП-10/400", 10, 400, {"psr_subtype": "short_circuiter", "pole_count": 1, "normal_open": True, "retained": False}, manufacturer="IEK", country="RU")
    add("zn", "Tavrida", "ЗНП-10/630", 10, 630, {"psr_subtype": "short_circuiter", "pole_count": 1, "normal_open": True, "retained": False}, manufacturer="Tavrida Electric", country="RU")

    # Arrester (10)
    add("arrester", "ОПН", "ОПН-6", 6, 10000, {"arrester_type": "opn", "tm_code": "AR-OPN-6", "pole_count": 0, "nominal_discharge_current_a": 10000, "continuous_current_a": 400, "emergency_current_a": 20000})
    add("arrester", "ОПН", "ОПН-10", 10, 10000, {"arrester_type": "opn", "tm_code": "AR-OPN-10", "pole_count": 0, "nominal_discharge_current_a": 10000, "continuous_current_a": 550, "emergency_current_a": 20000})
    add("arrester", "ОПН", "ОПН-20", 20, 10000, {"arrester_type": "opn", "tm_code": "AR-OPN-20", "pole_count": 0, "nominal_discharge_current_a": 10000, "continuous_current_a": 550, "emergency_current_a": 20000})
    add("arrester", "ОПН", "ОПН-35", 35, 10000, {"arrester_type": "opn", "tm_code": "AR-OPN-35", "pole_count": 0, "nominal_discharge_current_a": 10000, "continuous_current_a": 550, "emergency_current_a": 20000})
    add("arrester", "КЭАЗ", "ПОДТ-10", 10, None, {"arrester_type": "opn", "tm_code": "AR-KEAZ-10", "pole_count": 0}, manufacturer="КЭАЗ", country="RU")
    add("arrester", "Tavrida", "ОПНп-6/400", 6, None, {"arrester_type": "valve", "tm_code": "AR-TVR-6", "pole_count": 0}, manufacturer="Tavrida Electric", country="RU")
    add("arrester", "IEK", "ОПНп-10", 10, None, {"arrester_type": "valve", "tm_code": "AR-IEK-10", "pole_count": 0}, manufacturer="IEK", country="RU")
    add("arrester", "КЭАЗ", "РВО-10", 10, 5000, {"arrester_type": "tube", "tm_code": "AR-RVO-10", "pole_count": 0, "nominal_discharge_current_a": 5000, "continuous_current_a": 300, "emergency_current_a": 10000})
    add("arrester", "РВМ", "РВМ-10", 10, 5000, {"arrester_type": "valve", "tm_code": "AR-RVM-10", "pole_count": 0, "nominal_discharge_current_a": 5000, "continuous_current_a": 300, "emergency_current_a": 10000})
    add("arrester", "ОПН", "ОПН-110", 110, 10000, {"arrester_type": "opn", "tm_code": "AR-OPN-110", "pole_count": 0, "nominal_discharge_current_a": 10000, "continuous_current_a": 550, "emergency_current_a": 20000})

    # Recloser (10) — только BY/RU
    add("recloser", "УЗТТ", "РВ-15/630", 15, 630, {"i_th": 20000, "ip_max": 50000, "t_th": 3, "nominal_breaking_current_ka": 16, "own_trip_time_sec": 0.05, "tm_code": "REC-UZ-15", "pole_count": 2}, manufacturer="Н/Д", country="BY")
    add("recloser", "КЭАЗ", "КР-10/630", 10, 630, {"i_th": 20000, "ip_max": 50000, "t_th": 3, "nominal_breaking_current_ka": 20, "own_trip_time_sec": 0.05, "tm_code": "REC-KEAZ-10", "pole_count": 2}, manufacturer="КЭАЗ", country="RU")
    add("recloser", "Tavrida", "REC15", 15, 630, {"i_th": 20000, "ip_max": 50000, "t_th": 3, "nominal_breaking_current_ka": 16, "own_trip_time_sec": 0.05, "tm_code": "REC-TVR-15", "pole_count": 2}, manufacturer="Tavrida Electric", country="RU")
    add("recloser", "Tavrida", "REC27", 27, 630, {"i_th": 25000, "ip_max": 63000, "t_th": 3, "nominal_breaking_current_ka": 20, "own_trip_time_sec": 0.05, "tm_code": "REC-TVR-27", "pole_count": 2}, manufacturer="Tavrida Electric", country="RU")
    add("recloser", "IEK", "РТ-10/630", 10, 630, {"i_th": 20000, "ip_max": 50000, "t_th": 3, "nominal_breaking_current_ka": 20, "own_trip_time_sec": 0.05, "tm_code": "REC-IEK-10", "pole_count": 2}, manufacturer="IEK", country="RU")
    add("recloser", "Tavrida", "REC-10M", 10, 630, {"i_th": 20000, "ip_max": 50000, "t_th": 3, "nominal_breaking_current_ka": 20, "own_trip_time_sec": 0.05, "tm_code": "REC-TVR-10M", "pole_count": 2}, manufacturer="Tavrida Electric", country="RU")
    add("recloser", "Tavrida", "REC-35/630", 35, 630, {"i_th": 25000, "ip_max": 63000, "t_th": 3, "nominal_breaking_current_ka": 20, "own_trip_time_sec": 0.05, "tm_code": "REC-TVR-35", "pole_count": 2}, manufacturer="Tavrida Electric", country="RU")
    add("recloser", "УЗТТ", "РВ-27/630", 27, 630, {"i_th": 25000, "ip_max": 63000, "t_th": 3, "nominal_breaking_current_ka": 20, "own_trip_time_sec": 0.05, "tm_code": "REC-UZ-27", "pole_count": 2}, manufacturer="Н/Д", country="BY")
    add("recloser", "RECLOSER", "RECLOSER-10", 10, 630, {"i_th": 20000, "ip_max": 50000, "t_th": 3, "nominal_breaking_current_ka": 20, "own_trip_time_sec": 0.05, "tm_code": "REC-10", "pole_count": 2}, manufacturer="Generic", country="BY")
    add("recloser", "RCB", "RCB-10", 10, 630, {"i_th": 20000, "ip_max": 50000, "t_th": 3, "nominal_breaking_current_ka": 20, "own_trip_time_sec": 0.05, "tm_code": "RCB-10", "pole_count": 2}, manufacturer="Generic", country="BY")

    return rows


@router.get("", response_model=List[EquipmentCatalogResponse])
@router.get("/", response_model=List[EquipmentCatalogResponse])
async def get_catalog_items(
    type_code: Optional[str] = Query(default=None),
    q: Optional[str] = Query(default=None, description="Поиск по brand/model/full_name/manufacturer"),
    is_active: Optional[bool] = Query(default=True),
    skip: int = Query(default=0, ge=0),
    limit: int = Query(default=500, ge=1, le=5000),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    _ = current_user
    filters = []
    if type_code:
        filters.append(EquipmentCatalogItem.type_code == _normalize_type_code(type_code))
    if is_active is not None:
        filters.append(EquipmentCatalogItem.is_active == is_active)
    if q:
        qq = f"%{q.strip()}%"
        filters.append(
            or_(
                EquipmentCatalogItem.brand.ilike(qq),
                EquipmentCatalogItem.model.ilike(qq),
                EquipmentCatalogItem.full_name.ilike(qq),
                EquipmentCatalogItem.manufacturer.ilike(qq),
            )
        )

    stmt = select(EquipmentCatalogItem)
    if filters:
        stmt = stmt.where(and_(*filters))
    stmt = stmt.order_by(EquipmentCatalogItem.type_code, EquipmentCatalogItem.brand, EquipmentCatalogItem.model).offset(skip).limit(limit)
    rows = (await db.execute(stmt)).scalars().all()
    return rows


@router.post("", response_model=EquipmentCatalogResponse)
@router.post("/", response_model=EquipmentCatalogResponse)
async def create_catalog_item(
    payload: EquipmentCatalogCreate,
    current_user: User = Depends(require_catalog_manager),
    db: AsyncSession = Depends(get_db),
):
    type_code = _normalize_type_code(payload.type_code)
    if not type_code:
        raise HTTPException(status_code=400, detail="type_code is required")
    brand_s = payload.brand.strip()
    model_s = payload.model.strip()
    fn = (payload.full_name or "").strip() or None
    if not fn:
        fn = _catalog_full_name(brand_s, model_s)
    item = EquipmentCatalogItem(
        type_code=type_code,
        brand=brand_s,
        model=model_s,
        full_name=fn,
        voltage_kv=payload.voltage_kv,
        current_a=payload.current_a,
        manufacturer=payload.manufacturer,
        country=payload.country,
        description=payload.description,
        attrs_json=payload.attrs_json,
        is_active=payload.is_active,
        created_by=current_user.id,
    )
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return item


@router.put("/{item_id}", response_model=EquipmentCatalogResponse)
async def update_catalog_item(
    item_id: int,
    payload: EquipmentCatalogUpdate,
    current_user: User = Depends(require_catalog_manager),
    db: AsyncSession = Depends(get_db),
):
    _ = current_user
    item = await db.get(EquipmentCatalogItem, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Catalog item not found")
    data = payload.model_dump(exclude_unset=True)
    if "type_code" in data:
        data["type_code"] = _normalize_type_code(data["type_code"])
    if "full_name" not in data and ("brand" in data or "model" in data):
        b = (data.get("brand") if "brand" in data else item.brand) or ""
        m = (data.get("model") if "model" in data else item.model) or ""
        data["full_name"] = _catalog_full_name(str(b).strip(), str(m).strip())
    for k, v in data.items():
        setattr(item, k, v)
    await db.commit()
    await db.refresh(item)
    return item


@router.post("/{item_id}/withdraw", status_code=status.HTTP_200_OK)
async def withdraw_catalog_item(
    item_id: int,
    current_user: User = Depends(require_catalog_manager),
    db: AsyncSession = Depends(get_db),
):
    """Вывод позиции из эксплуатации (паспортист / администратор)."""
    _ = current_user
    item = await db.get(EquipmentCatalogItem, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Catalog item not found")
    item.is_active = False
    await db.commit()
    return {"message": "Позиция выведена из эксплуатации"}


@router.delete("/{item_id}", status_code=status.HTTP_200_OK)
async def delete_catalog_item(
    item_id: int,
    current_user: User = Depends(require_admin_user),
    db: AsyncSession = Depends(get_db),
):
    """Физическое удаление — только администратор."""
    item = await db.get(EquipmentCatalogItem, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Catalog item not found")
    await db.delete(item)
    await db.commit()
    return {"message": "Позиция удалена"}


@router.get("/template")
async def download_catalog_template(
    current_user: User = Depends(require_catalog_manager),
):
    _ = current_user
    columns = [
        "type_code",
        "brand",
        "model",
        "full_name",
        "voltage_kv",
        "current_a",
        "manufacturer",
        "country",
        "description",
        *FLAT_ATTR_COLUMNS,
        "in_service",
    ]
    sample_rows = [
        {
            "type_code": "disconnector",
            "brand": "РЛНД",
            "model": "РЛНД-10/400",
            "full_name": "РЛНД-10/400",
            "voltage_kv": 10,
            "current_a": 400,
            "manufacturer": "Энергомаш",
            "country": "BY",
            "description": "Пример для разъединителя",
            "i_th": 16000,
            "ip_max": 40000,
            "t_th": 3,
            "normal_open": False,
            "retained": False,
            "in_service": True,
        },
        {
            "type_code": "breaker",
            "brand": "ВВ/TEL",
            "model": "ВВ/TEL-10-20/1000",
            "full_name": "Вакуумный выключатель ВВ/TEL-10-20/1000",
            "voltage_kv": 10,
            "current_a": 1000,
            "manufacturer": "Таврида Электрик",
            "country": "RU",
            "description": "Пример для выключателя",
            "i_th": 20000,
            "ip_max": 51000,
            "t_th": 3,
            "nominal_breaking_current_ka": 20,
            "own_trip_time_sec": 0.06,
            "object_subtype": "vacuum_breaker",
            "in_service": True,
        },
        {
            "type_code": "arrester",
            "brand": "ОПН",
            "model": "ОПН-10",
            "full_name": "ОПН-10",
            "voltage_kv": 10,
            "current_a": None,
            "manufacturer": "Н/Д",
            "country": "BY",
            "description": "Пример для ОПН",
            "arrester_type": "opn",
            "tm_code": "AR-OPN-10",
            "nominal_discharge_current_a": 10000,
            "continuous_current_a": 550,
            "emergency_current_a": 20000,
            "pole_count": 0,
            "in_service": True,
        },
    ]
    df = pd.DataFrame(sample_rows, columns=columns)
    reference_df = pd.DataFrame(
        [
            {"type_code": "disconnector", "description": "Разъединитель"},
            {"type_code": "breaker", "description": "Выключатель"},
            {"type_code": "zn", "description": "ЗН / grounding switch"},
            {"type_code": "arrester", "description": "Разрядник / ОПН"},
            {"type_code": "recloser", "description": "Реклоузер"},
        ]
    )
    fields_df = pd.DataFrame(
        [
            {"column": "type_code", "required": "да", "note": "disconnector, breaker, zn, arrester, recloser"},
            {"column": "brand", "required": "да", "note": "Марка / линейка"},
            {"column": "model", "required": "да", "note": "Модель (типоразмер)"},
            {"column": "current_a", "required": "нет", "note": "Номинальный ток, А"},
            {"column": "i_th", "required": "нет", "note": "Ток термической стойкости, А"},
            {"column": "ip_max", "required": "нет", "note": "Ударный ток, А"},
            {"column": "t_th", "required": "нет", "note": "Время терм. стойкости, с"},
            {"column": "nominal_breaking_current_ka", "required": "нет", "note": "Отключающая способность, кА"},
            {"column": "own_trip_time_sec", "required": "нет", "note": "Собственное время отключения, с"},
            {"column": "in_service", "required": "нет", "note": "да/нет — в эксплуатации"},
        ]
    )
    output = io.BytesIO()
    with pd.ExcelWriter(output, engine="openpyxl") as writer:
        df.to_excel(writer, index=False, sheet_name="equipment_catalog")
        reference_df.to_excel(writer, index=False, sheet_name="reference_types")
        fields_df.to_excel(writer, index=False, sheet_name="field_help")
    content = output.getvalue()
    headers = {"Content-Disposition": 'attachment; filename="equipment_catalog_template.xlsx"'}
    return Response(content=content, media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", headers=headers)


@router.get("/export")
async def export_catalog(
    fmt: str = Query(default="xlsx", pattern="^(xlsx|csv)$"),
    current_user: User = Depends(require_catalog_manager),
    db: AsyncSession = Depends(get_db),
):
    _ = current_user
    rows = (
        await db.execute(
            select(EquipmentCatalogItem).order_by(EquipmentCatalogItem.type_code, EquipmentCatalogItem.brand, EquipmentCatalogItem.model)
        )
    ).scalars().all()
    data = [
        {
            "id": r.id,
            "type_code": r.type_code,
            "brand": r.brand,
            "model": r.model,
            "full_name": r.full_name,
            "voltage_kv": r.voltage_kv,
            "current_a": r.current_a,
            "manufacturer": r.manufacturer,
            "country": r.country,
            "description": r.description,
            "attrs_json": r.attrs_json,
            "is_active": r.is_active,
            "created_at": r.created_at.isoformat() if r.created_at else None,
            "updated_at": r.updated_at.isoformat() if r.updated_at else None,
        }
        for r in rows
    ]
    df = pd.DataFrame(data)
    if fmt == "csv":
        content = df.to_csv(index=False).encode("utf-8-sig")
        headers = {"Content-Disposition": 'attachment; filename="equipment_catalog.csv"'}
        return Response(content=content, media_type="text/csv; charset=utf-8", headers=headers)

    output = io.BytesIO()
    with pd.ExcelWriter(output, engine="openpyxl") as writer:
        df.to_excel(writer, index=False, sheet_name="equipment_catalog")
    headers = {"Content-Disposition": 'attachment; filename="equipment_catalog.xlsx"'}
    return Response(
        content=output.getvalue(),
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers=headers,
    )


@router.post("/import")
async def import_catalog(
    mode: str = Query(default="upsert", pattern="^(upsert|insert_only)$"),
    file: UploadFile = File(...),
    current_user: User = Depends(require_catalog_manager),
    db: AsyncSession = Depends(get_db),
):
    ext = (file.filename or "").lower()
    content = await file.read()
    if not content:
        raise HTTPException(status_code=400, detail="Empty file")
    try:
        if ext.endswith(".csv"):
            df = pd.read_csv(io.BytesIO(content))
        elif ext.endswith(".xlsx") or ext.endswith(".xls"):
            df = pd.read_excel(io.BytesIO(content))
        else:
            raise HTTPException(status_code=400, detail="Unsupported format. Use .xlsx or .csv")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to parse file: {e}") from e

    required_cols = {"type_code", "brand", "model"}
    missing = [c for c in required_cols if c not in df.columns]
    if missing:
        raise HTTPException(status_code=400, detail=f"Missing required columns: {', '.join(missing)}")

    inserted = 0
    updated = 0
    skipped = 0
    for _, row in df.iterrows():
        type_code = _normalize_type_code(row.get("type_code"))
        brand = str(row.get("brand") or "").strip()
        model = str(row.get("model") or "").strip()
        if not type_code or not brand or not model:
            skipped += 1
            continue
        stmt = select(EquipmentCatalogItem).where(
            and_(
                EquipmentCatalogItem.type_code == type_code,
                func.lower(EquipmentCatalogItem.brand) == brand.lower(),
                func.lower(EquipmentCatalogItem.model) == model.lower(),
            )
        )
        existing = (await db.execute(stmt)).scalar_one_or_none()
        raw_fn = None if pd.isna(row.get("full_name")) else str(row.get("full_name")).strip()
        if not raw_fn:
            raw_fn = _catalog_full_name(brand, model)
        in_svc = _to_bool(
            row.get("in_service") if "in_service" in df.columns else row.get("is_active"),
            True,
        )
        attrs_json = attrs_from_flat_row(row.to_dict())
        payload = {
            "type_code": type_code,
            "brand": brand,
            "model": model,
            "full_name": raw_fn,
            "voltage_kv": None if pd.isna(row.get("voltage_kv")) else float(row.get("voltage_kv")),
            "current_a": None if pd.isna(row.get("current_a")) else float(row.get("current_a")),
            "manufacturer": None if pd.isna(row.get("manufacturer")) else str(row.get("manufacturer")),
            "country": None if pd.isna(row.get("country")) else str(row.get("country")),
            "description": None if pd.isna(row.get("description")) else str(row.get("description")),
            "attrs_json": attrs_json,
            "is_active": in_svc,
        }
        if existing:
            if mode == "insert_only":
                skipped += 1
                continue
            for k, v in payload.items():
                setattr(existing, k, v)
            updated += 1
        else:
            db.add(EquipmentCatalogItem(**payload, created_by=current_user.id))
            inserted += 1
    await db.commit()
    return {"inserted": inserted, "updated": updated, "skipped": skipped, "total": int(len(df.index))}


@router.post("/seed-defaults")
async def seed_default_catalog(
    current_user: User = Depends(require_catalog_manager),
    db: AsyncSession = Depends(get_db),
):
    defaults = _default_catalog_payloads()
    inserted = 0
    updated = 0
    for row in defaults:
        type_code = row["type_code"]
        brand = row["brand"]
        model = row["model"]
        existing = (
            await db.execute(
                select(EquipmentCatalogItem).where(
                    and_(
                        EquipmentCatalogItem.type_code == type_code,
                        func.lower(EquipmentCatalogItem.brand) == brand.lower(),
                        func.lower(EquipmentCatalogItem.model) == model.lower(),
                    )
                )
            )
        ).scalar_one_or_none()
        if existing:
            changed = False
            new_fn = row.get("full_name")
            if new_fn and getattr(existing, "full_name") != new_fn:
                setattr(existing, "full_name", new_fn)
                changed = True
            for field in (
                "voltage_kv",
                "current_a",
                "manufacturer",
                "country",
                "description",
                "attrs_json",
            ):
                current_value = getattr(existing, field)
                new_value = row.get(field)
                is_empty = current_value is None or (
                    isinstance(current_value, str) and not current_value.strip()
                )
                if is_empty and new_value is not None:
                    setattr(existing, field, new_value)
                    changed = True
            if changed:
                updated += 1
            continue
        db.add(
            EquipmentCatalogItem(
                type_code=type_code,
                brand=brand,
                model=model,
                full_name=row.get("full_name"),
                voltage_kv=row.get("voltage_kv"),
                current_a=row.get("current_a"),
                manufacturer=row.get("manufacturer"),
                country=row.get("country"),
                description=row.get("description"),
                attrs_json=row.get("attrs_json"),
                is_active=bool(row.get("is_active", True)),
                created_by=current_user.id,
            )
        )
        inserted += 1
    await db.commit()
    return {"inserted": inserted, "updated": updated}

