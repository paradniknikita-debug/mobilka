from __future__ import annotations

import io
import json
from typing import List, Optional

import pandas as pd
from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from fastapi.responses import Response
from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

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
                "full_name": f"{brand} {model}",
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
    add("disconnector", "Siemens", "3DN1-110/2000", 110, 2000, {"i_th": 31500, "ip_max": 80000, "t_th": 3, "normal_open": False, "retained": False}, manufacturer="Siemens", country="DE")
    add("disconnector", "ABB", "NALF-24/630", 24, 630, {"i_th": 20000, "ip_max": 50000, "t_th": 3, "normal_open": False, "retained": False}, manufacturer="ABB", country="SE")
    add("disconnector", "РВ", "РВ-10/630", 10, 630, {"i_th": 25000, "ip_max": 63000, "t_th": 4, "normal_open": False, "retained": False})
    add("disconnector", "Tavrida", "DS-10/630", 10, 630, {"i_th": 20000, "ip_max": 50000, "t_th": 3, "normal_open": False, "retained": False}, manufacturer="Tavrida Electric", country="RU")

    # Breaker (10)
    add("breaker", "ВВ/TEL", "ВВ/TEL-10-20/1000", 10, 1000, {"i_th": 20000, "ip_max": 51000, "t_th": 3, "nominal_breaking_current_ka": 20, "own_trip_time_sec": 0.015, "object_subtype": "vacuum_breaker"})
    add("breaker", "ВВ/TEL", "ВВ/TEL-10-31.5/1600", 10, 1600, {"i_th": 31500, "ip_max": 80000, "t_th": 3, "nominal_breaking_current_ka": 31.5, "own_trip_time_sec": 0.05, "object_subtype": "vacuum_breaker"})
    add("breaker", "ВМП", "ВМП-10-20/630", 10, 630, {"i_th": 20000, "ip_max": 50000, "t_th": 3, "nominal_breaking_current_ka": 20, "own_trip_time_sec": 0.09, "object_subtype": "withdrawable_breaker"})
    add("breaker", "ВМП", "ВМП-10-31.5/1000", 10, 1000, {"i_th": 31500, "ip_max": 80000, "t_th": 3, "nominal_breaking_current_ka": 31.5, "own_trip_time_sec": 0.09, "object_subtype": "withdrawable_breaker"})
    add("breaker", "Siemens", "3AH5-35/1250", 35, 1250, {"i_th": 25000, "ip_max": 63000, "t_th": 3, "nominal_breaking_current_ka": 25, "own_trip_time_sec": 0.05, "object_subtype": "vacuum_breaker"}, manufacturer="Siemens", country="DE")
    add("breaker", "ABB", "VD4-12/1250", 12, 1250, {"i_th": 25000, "ip_max": 63000, "t_th": 3, "nominal_breaking_current_ka": 25, "own_trip_time_sec": 0.05, "object_subtype": "vacuum_breaker"}, manufacturer="ABB", country="IT")
    add("breaker", "Schneider", "Evolis-17.5/1250", 17.5, 1250, {"i_th": 25000, "ip_max": 63000, "t_th": 3, "nominal_breaking_current_ka": 25, "own_trip_time_sec": 0.06, "object_subtype": "vacuum_breaker"}, manufacturer="Schneider", country="FR")
    add("breaker", "Tavrida", "BB/TEL-35-25/1600", 35, 1600, {"i_th": 25000, "ip_max": 63000, "t_th": 3, "nominal_breaking_current_ka": 25, "own_trip_time_sec": 0.06, "object_subtype": "vacuum_breaker"})
    add("breaker", "Hyundai", "HVG-24/1250", 24, 1250, {"i_th": 25000, "ip_max": 63000, "t_th": 3, "nominal_breaking_current_ka": 25, "own_trip_time_sec": 0.05, "object_subtype": "vacuum_breaker"}, manufacturer="Hyundai", country="KR")
    add("breaker", "LFB", "LFB-110/3150", 110, 3150, {"i_th": 40000, "ip_max": 100000, "t_th": 3, "nominal_breaking_current_ka": 40, "own_trip_time_sec": 0.03, "object_subtype": "sf6_breaker"}, manufacturer="Alstom Grid", country="FR")

    # Grounding switch / ZN (10)
    add("zn", "ЗН", "ЗН-10", 10, 400, {"psr_subtype": "short_circuiter", "pole_count": 1, "normal_open": True, "retained": False, "object_subtype": "short_circuiter", "i_th": 10000, "ip_max": 25000, "t_th": 1})
    add("zn", "ЗН", "ЗН-10У1", 10, 630, {"psr_subtype": "short_circuiter", "pole_count": 1, "normal_open": True, "retained": False, "i_th": 12500, "ip_max": 32000, "t_th": 1})
    add("zn", "ЗН", "ЗН-35", 35, 1000, {"psr_subtype": "short_circuiter", "pole_count": 1, "normal_open": True, "retained": False, "i_th": 25000, "ip_max": 63000, "t_th": 3})
    add("zn", "ЗОН", "ЗОН-10/400", 10, 400, {"psr_subtype": "short_circuiter", "pole_count": 1, "normal_open": True, "retained": False})
    add("zn", "ЗОН", "ЗОН-10/630", 10, 630, {"psr_subtype": "short_circuiter", "pole_count": 1, "normal_open": True, "retained": False})
    add("zn", "EKF", "ЗН-10/400-УХЛ1", 10, 400, {"psr_subtype": "short_circuiter", "pole_count": 1, "normal_open": True, "retained": False})
    add("zn", "КЭАЗ", "ЗНЛ-10/630", 10, 630, {"psr_subtype": "short_circuiter", "pole_count": 1, "normal_open": True, "retained": False})
    add("zn", "IEK", "ЗН-6/400", 6, 400, {"psr_subtype": "short_circuiter", "pole_count": 1, "normal_open": True, "retained": False})
    add("zn", "Hyundai", "GS-24/630", 24, 630, {"psr_subtype": "short_circuiter", "pole_count": 1, "normal_open": True, "retained": False}, manufacturer="Hyundai", country="KR")
    add("zn", "Siemens", "8DH10-GS/1250", 10, 1250, {"psr_subtype": "short_circuiter", "pole_count": 1, "normal_open": True, "retained": False}, manufacturer="Siemens", country="DE")

    # Arrester (10)
    add("arrester", "ОПН", "ОПН-6", 6, 10000, {"arrester_type": "opn", "tm_code": "AR-OPN-6", "pole_count": 0, "nominal_discharge_current_a": 10000, "continuous_current_a": 400, "emergency_current_a": 20000})
    add("arrester", "ОПН", "ОПН-10", 10, 10000, {"arrester_type": "opn", "tm_code": "AR-OPN-10", "pole_count": 0, "nominal_discharge_current_a": 10000, "continuous_current_a": 550, "emergency_current_a": 20000})
    add("arrester", "ОПН", "ОПН-20", 20, 10000, {"arrester_type": "opn", "tm_code": "AR-OPN-20", "pole_count": 0, "nominal_discharge_current_a": 10000, "continuous_current_a": 550, "emergency_current_a": 20000})
    add("arrester", "ОПН", "ОПН-35", 35, 10000, {"arrester_type": "opn", "tm_code": "AR-OPN-35", "pole_count": 0, "nominal_discharge_current_a": 10000, "continuous_current_a": 550, "emergency_current_a": 20000})
    add("arrester", "ABB", "POLIM-D-10", 10, None, {"arrester_type": "opn", "tm_code": "AR-POLIM-10", "pole_count": 0}, manufacturer="ABB", country="SE")
    add("arrester", "Siemens", "3EK4-10", 10, None, {"arrester_type": "opn", "tm_code": "AR-3EK4-10", "pole_count": 0}, manufacturer="Siemens", country="DE")
    add("arrester", "IEK", "ОПНп-10", 10, None, {"arrester_type": "valve", "tm_code": "AR-IEK-10", "pole_count": 0})
    add("arrester", "КЭАЗ", "РВО-10", 10, 5000, {"arrester_type": "tube", "tm_code": "AR-RVO-10", "pole_count": 0, "nominal_discharge_current_a": 5000, "continuous_current_a": 300, "emergency_current_a": 10000})
    add("arrester", "РВМ", "РВМ-10", 10, 5000, {"arrester_type": "valve", "tm_code": "AR-RVM-10", "pole_count": 0, "nominal_discharge_current_a": 5000, "continuous_current_a": 300, "emergency_current_a": 10000})
    add("arrester", "Schneider", "PRD-36", 36, 10000, {"arrester_type": "opn", "tm_code": "AR-PRD-36", "pole_count": 0, "nominal_discharge_current_a": 10000, "continuous_current_a": 600, "emergency_current_a": 20000}, manufacturer="Schneider", country="FR")

    # Recloser (10)
    add("recloser", "NOJA", "OSM15", 15, 630, {"i_th": 12500, "ip_max": 32000, "t_th": 3, "nominal_breaking_current_ka": 12.5, "own_trip_time_sec": 0.04, "tm_code": "REC-OSM15", "pole_count": 2}, manufacturer="NOJA Power", country="AU")
    add("recloser", "NOJA", "OSM27", 27, 630, {"i_th": 25000, "ip_max": 63000, "t_th": 3, "nominal_breaking_current_ka": 20, "own_trip_time_sec": 0.04, "tm_code": "REC-OSM27", "pole_count": 2}, manufacturer="NOJA Power", country="AU")
    add("recloser", "Tavrida", "REC15", 15, 630, {"i_th": 20000, "ip_max": 50000, "t_th": 3, "nominal_breaking_current_ka": 16, "own_trip_time_sec": 0.05, "tm_code": "REC-TVR-15", "pole_count": 2}, manufacturer="Tavrida Electric", country="RU")
    add("recloser", "Tavrida", "REC27", 27, 630, {"i_th": 25000, "ip_max": 63000, "t_th": 3, "nominal_breaking_current_ka": 20, "own_trip_time_sec": 0.05, "tm_code": "REC-TVR-27", "pole_count": 2}, manufacturer="Tavrida Electric", country="RU")
    add("recloser", "ABB", "RER615", 15, 800, {"i_th": 20000, "ip_max": 50000, "t_th": 3, "nominal_breaking_current_ka": 16, "own_trip_time_sec": 0.05, "tm_code": "REC-RER615", "pole_count": 2}, manufacturer="ABB", country="SE")
    add("recloser", "Schneider", "Nulec-N27", 27, 630, {"i_th": 25000, "ip_max": 63000, "t_th": 3, "nominal_breaking_current_ka": 20, "own_trip_time_sec": 0.05, "tm_code": "REC-NULEC-N27", "pole_count": 2}, manufacturer="Schneider", country="FR")
    add("recloser", "Siemens", "Fusesaver-24", 24, 630, {"i_th": 20000, "ip_max": 50000, "t_th": 3, "nominal_breaking_current_ka": 16, "own_trip_time_sec": 0.04, "tm_code": "REC-FS-24", "pole_count": 2}, manufacturer="Siemens", country="DE")
    add("recloser", "Eaton", "NOVA-27", 27, 630, {"i_th": 25000, "ip_max": 63000, "t_th": 3, "nominal_breaking_current_ka": 20, "own_trip_time_sec": 0.05, "tm_code": "REC-NOVA-27", "pole_count": 2}, manufacturer="Eaton", country="US")
    add("recloser", "GE", "TriShot-15", 15, 630, {"i_th": 20000, "ip_max": 50000, "t_th": 3, "nominal_breaking_current_ka": 16, "own_trip_time_sec": 0.06, "tm_code": "REC-TRISHOT-15", "pole_count": 2}, manufacturer="GE", country="US")
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
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    type_code = _normalize_type_code(payload.type_code)
    if not type_code:
        raise HTTPException(status_code=400, detail="type_code is required")
    item = EquipmentCatalogItem(
        type_code=type_code,
        brand=payload.brand.strip(),
        model=payload.model.strip(),
        full_name=payload.full_name,
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
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    _ = current_user
    item = await db.get(EquipmentCatalogItem, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Catalog item not found")
    data = payload.model_dump(exclude_unset=True)
    if "type_code" in data:
        data["type_code"] = _normalize_type_code(data["type_code"])
    for k, v in data.items():
        setattr(item, k, v)
    await db.commit()
    await db.refresh(item)
    return item


@router.delete("/{item_id}", status_code=status.HTTP_200_OK)
async def delete_catalog_item(
    item_id: int,
    hard: bool = Query(default=False, description="hard=true удаляет запись физически"),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    _ = current_user
    item = await db.get(EquipmentCatalogItem, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Catalog item not found")
    if hard:
        await db.delete(item)
    else:
        item.is_active = False
    await db.commit()
    return {"message": "ok"}


@router.get("/template")
async def download_catalog_template(
    current_user: User = Depends(get_current_active_user),
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
        "attrs_json",
        "is_active",
    ]
    sample_rows = [
        {
            "type_code": "disconnector",
            "brand": "РЛНД",
            "model": "РЛНД-10/400",
            "full_name": "Разъединитель линейный наружной установки РЛНД-10/400",
            "voltage_kv": 10,
            "current_a": 400,
            "manufacturer": "Энергомаш",
            "country": "BY",
            "description": "Пример для разъединителя",
            "attrs_json": json.dumps({"i_th": 16000, "ip_max": 40000, "t_th": 3, "normal_open": False}, ensure_ascii=False),
            "is_active": True,
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
            "attrs_json": json.dumps({"object_subtype": "vacuum_breaker", "nominal_breaking_current_ka": 20, "own_trip_time_sec": 0.06}, ensure_ascii=False),
            "is_active": True,
        },
        {
            "type_code": "zn",
            "brand": "ЗН",
            "model": "ЗН-10",
            "full_name": "Заземляющий нож ЗН-10",
            "voltage_kv": 10,
            "current_a": None,
            "manufacturer": "Н/Д",
            "country": "BY",
            "description": "Пример для ЗН",
            "attrs_json": json.dumps({"psr_subtype": "short_circuiter", "pole_count": 1}, ensure_ascii=False),
            "is_active": True,
        },
        {
            "type_code": "arrester",
            "brand": "ОПН",
            "model": "ОПН-10",
            "full_name": "Ограничитель перенапряжения ОПН-10",
            "voltage_kv": 10,
            "current_a": None,
            "manufacturer": "Н/Д",
            "country": "BY",
            "description": "Пример для разрядника",
            "attrs_json": json.dumps({"arrester_type": "opn", "tm_code": "AR-OPN-10", "pole_count": 0}, ensure_ascii=False),
            "is_active": True,
        },
        {
            "type_code": "recloser",
            "brand": "NOJA",
            "model": "OSM15",
            "full_name": "Реклоузер NOJA OSM15",
            "voltage_kv": 15,
            "current_a": 630,
            "manufacturer": "NOJA Power",
            "country": "AU",
            "description": "Пример для реклоузера",
            "attrs_json": json.dumps({"tm_code": "REC-OSM15", "nominal_breaking_current_ka": 16, "own_trip_time_sec": 0.04, "pole_count": 2}, ensure_ascii=False),
            "is_active": True,
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
            {"column": "type_code", "required": "yes", "note": "Код типа, см. reference_types"},
            {"column": "brand", "required": "yes", "note": "Марка/линейка оборудования"},
            {"column": "model", "required": "yes", "note": "Модель оборудования"},
            {"column": "attrs_json", "required": "no", "note": "JSON со спец-характеристиками (например i_th, ip_max, t_th, tm_code, arrester_type)"},
            {"column": "is_active", "required": "no", "note": "true/false, по умолчанию true"},
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
    current_user: User = Depends(get_current_active_user),
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
    current_user: User = Depends(get_current_active_user),
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
        payload = {
            "type_code": type_code,
            "brand": brand,
            "model": model,
            "full_name": None if pd.isna(row.get("full_name")) else str(row.get("full_name")),
            "voltage_kv": None if pd.isna(row.get("voltage_kv")) else float(row.get("voltage_kv")),
            "current_a": None if pd.isna(row.get("current_a")) else float(row.get("current_a")),
            "manufacturer": None if pd.isna(row.get("manufacturer")) else str(row.get("manufacturer")),
            "country": None if pd.isna(row.get("country")) else str(row.get("country")),
            "description": None if pd.isna(row.get("description")) else str(row.get("description")),
            "attrs_json": None if pd.isna(row.get("attrs_json")) else str(row.get("attrs_json")),
            "is_active": _to_bool(row.get("is_active"), True),
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
    current_user: User = Depends(get_current_active_user),
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
            for field in (
                "full_name",
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

