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
    df = pd.DataFrame(
        [
            {
                "type_code": "disconnector",
                "brand": "РЛНД",
                "model": "РЛНД-10/400",
                "full_name": "Разъединитель линейный наружной установки РЛНД-10/400",
                "voltage_kv": 10,
                "current_a": 400,
                "manufacturer": "Энергомаш",
                "country": "BY",
                "description": "Базовая позиция для ВЛ 6-10 кВ",
                "attrs_json": json.dumps({"climatic": "У1"}, ensure_ascii=False),
                "is_active": True,
            }
        ],
        columns=columns,
    )
    output = io.BytesIO()
    with pd.ExcelWriter(output, engine="openpyxl") as writer:
        df.to_excel(writer, index=False, sheet_name="equipment_catalog")
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
    defaults = [
        ("disconnector", "РЛНД", "РЛНД-10/400", 10, 400),
        ("disconnector", "РЛК", "РЛК-10/400", 10, 400),
        ("breaker", "ВВ/TEL", "ВВ/TEL-10-20/1000", 10, 1000),
        ("breaker", "ВМП", "ВМП-10", 10, 630),
        ("arrester", "ОПН", "ОПН-10", 10, None),
        ("arrester", "ОПН", "ОПН-35", 35, None),
        ("recloser", "NOJA", "NOJA OSM15", 10, 630),
        ("recloser", "Tavrida", "Tavrida REC15", 10, 630),
        ("zn", "ЗН", "ЗН-10", 10, None),
    ]
    inserted = 0
    for type_code, brand, model, kv, current in defaults:
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
            continue
        db.add(
            EquipmentCatalogItem(
                type_code=type_code,
                brand=brand,
                model=model,
                full_name=f"{brand} {model}",
                voltage_kv=kv,
                current_a=current,
                is_active=True,
                created_by=current_user.id,
            )
        )
        inserted += 1
    await db.commit()
    return {"inserted": inserted}

