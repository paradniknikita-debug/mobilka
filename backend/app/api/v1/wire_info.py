"""
Справочник марок проводов (WireInfo): CRUD, импорт/экспорт Excel, вывод из эксплуатации.
"""
from __future__ import annotations

import io
from typing import List, Optional

import pandas as pd
from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from fastapi.responses import Response
from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.roles import is_admin, require_admin_user, require_catalog_manager
from app.core.security import get_current_active_user
from app.database import get_db
from app.models.base import generate_mrid
from app.models.line_conductor_catalog import LineConductorCatalogItem
from app.models.user import User
from app.models.wire_info import WireInfo
from app.schemas.wire_info import WireInfoCreate, WireInfoResponse, WireInfoUpdate

router = APIRouter()

_WIRE_TEMPLATE_COLUMNS = [
    "name",
    "code",
    "material",
    "section",
    "voltage_kv",
    "nominal_current",
    "i_th",
    "ip_max",
    "t_th",
    "r",
    "x",
    "b",
    "g",
    "max_operating_temperature",
    "breaking_load",
    "weight_per_length",
    "description",
    "in_service",
]


def _normalize_mark(value: str) -> str:
    return " ".join((value or "").strip().split())


def _to_bool(v: object, default: bool = True) -> bool:
    if v is None or (isinstance(v, float) and pd.isna(v)):
        return default
    if isinstance(v, bool):
        return v
    s = str(v).strip().lower()
    if s in {"1", "true", "yes", "y", "да", "в эксплуатации"}:
        return True
    if s in {"0", "false", "no", "n", "нет", "выведена", "выведен"}:
        return False
    return default


def _float_or_none(v: object) -> Optional[float]:
    if v is None or (isinstance(v, float) and pd.isna(v)):
        return None
    try:
        return float(str(v).replace(",", "."))
    except (TypeError, ValueError):
        return None


async def _sync_line_conductor_catalog(db: AsyncSession, wire: WireInfo) -> None:
    """Дублировать марку в line_conductor_catalog для автодополнения на карте."""
    if not wire.name or wire.voltage_kv is None:
        return
    mark = _normalize_mark(wire.name)
    kv = float(wire.voltage_kv)
    result = await db.execute(
        select(LineConductorCatalogItem).where(
            and_(
                func.lower(LineConductorCatalogItem.mark) == mark.lower(),
                LineConductorCatalogItem.voltage_kv == kv,
            )
        )
    )
    row = result.scalar_one_or_none()
    in_svc = bool(getattr(wire, "in_service", True))
    if row is None:
        db.add(
            LineConductorCatalogItem(
                mark=mark,
                voltage_kv=kv,
                is_active=in_svc,
            )
        )
    else:
        row.is_active = in_svc


def _apply_in_service_flags(wire: WireInfo) -> None:
    in_svc = bool(getattr(wire, "in_service", True))
    wire.in_service = in_svc
    wire.is_active = in_svc


@router.get("", response_model=List[WireInfoResponse])
@router.get("/", response_model=List[WireInfoResponse])
async def list_wire_infos(
    q: Optional[str] = Query(default=None),
    in_service: Optional[bool] = Query(default=None, description="true — только в эксплуатации"),
    skip: int = Query(default=0, ge=0),
    limit: int = Query(default=500, ge=1, le=5000),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    _ = current_user
    query = select(WireInfo)
    if in_service is not None and hasattr(WireInfo, "in_service"):
        query = query.where(WireInfo.in_service == in_service)
    elif in_service is not None:
        query = query.where(WireInfo.is_active == in_service)
    if q:
        qq = f"%{q.strip()}%"
        query = query.where(
            or_(
                WireInfo.name.ilike(qq),
                WireInfo.code.ilike(qq),
                WireInfo.material.ilike(qq),
                WireInfo.description.ilike(qq),
            )
        )
    result = await db.execute(query.order_by(WireInfo.name).offset(skip).limit(limit))
    rows = result.scalars().all()
    for w in rows:
        _apply_in_service_flags(w)
    return rows


@router.get("/template")
async def download_wire_template(
    current_user: User = Depends(require_catalog_manager),
):
    _ = current_user
    sample = [
        {
            "name": "АС 70/11",
            "code": "AC70",
            "material": "алюминий",
            "section": 70,
            "voltage_kv": 10,
            "nominal_current": 265,
            "i_th": 5000,
            "ip_max": 12500,
            "t_th": 1,
            "r": 0.46,
            "x": 0.35,
            "b": 2.65e-6,
            "g": 0,
            "max_operating_temperature": 90,
            "breaking_load": None,
            "weight_per_length": None,
            "description": "Пример строки",
            "in_service": True,
        }
    ]
    df = pd.DataFrame(sample, columns=_WIRE_TEMPLATE_COLUMNS)
    help_df = pd.DataFrame(
        [
            {"column": "name", "required": "да", "note": "Марка провода (как в паспорте)"},
            {"column": "code", "required": "нет", "note": "Код / краткое обозначение"},
            {"column": "section", "required": "да", "note": "Сечение, мм²"},
            {"column": "voltage_kv", "required": "нет", "note": "Номинальное напряжение линии, кВ"},
            {"column": "nominal_current", "required": "нет", "note": "Длительно допустимый ток, А"},
            {"column": "i_th", "required": "нет", "note": "Ток термической стойкости, А"},
            {"column": "ip_max", "required": "нет", "note": "Ударный ток, А"},
            {"column": "t_th", "required": "нет", "note": "Время терм. стойкости, с"},
            {"column": "r/x/b/g", "required": "нет", "note": "Удельные параметры на 1 км"},
            {"column": "in_service", "required": "нет", "note": "да/нет — в эксплуатации"},
        ]
    )
    output = io.BytesIO()
    with pd.ExcelWriter(output, engine="openpyxl") as writer:
        df.to_excel(writer, index=False, sheet_name="wire_catalog")
        help_df.to_excel(writer, index=False, sheet_name="field_help")
    return Response(
        content=output.getvalue(),
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": 'attachment; filename="wire_catalog_template.xlsx"'},
    )


@router.get("/export")
async def export_wire_catalog(
    fmt: str = Query(default="xlsx", pattern="^(xlsx|csv)$"),
    current_user: User = Depends(require_catalog_manager),
    db: AsyncSession = Depends(get_db),
):
    _ = current_user
    rows = (await db.execute(select(WireInfo).order_by(WireInfo.name))).scalars().all()
    data = []
    for w in rows:
        data.append(
            {
                "id": w.id,
                "name": w.name,
                "code": w.code,
                "material": w.material,
                "section": w.section,
                "voltage_kv": w.voltage_kv,
                "nominal_current": w.nominal_current,
                "i_th": w.i_th,
                "ip_max": w.ip_max,
                "t_th": w.t_th,
                "r": w.r,
                "x": w.x,
                "b": w.b,
                "g": w.g,
                "max_operating_temperature": w.max_operating_temperature,
                "breaking_load": w.breaking_load,
                "weight_per_length": w.weight_per_length,
                "description": w.description,
                "in_service": getattr(w, "in_service", True),
            }
        )
    df = pd.DataFrame(data)
    if fmt == "csv":
        return Response(
            content=df.to_csv(index=False).encode("utf-8-sig"),
            media_type="text/csv; charset=utf-8",
            headers={"Content-Disposition": 'attachment; filename="wire_catalog.csv"'},
        )
    output = io.BytesIO()
    with pd.ExcelWriter(output, engine="openpyxl") as writer:
        df.to_excel(writer, index=False, sheet_name="wire_catalog")
    return Response(
        content=output.getvalue(),
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": 'attachment; filename="wire_catalog.xlsx"'},
    )


@router.post("/import")
async def import_wire_catalog(
    mode: str = Query(default="upsert", pattern="^(upsert|insert_only)$"),
    file: UploadFile = File(...),
    current_user: User = Depends(require_catalog_manager),
    db: AsyncSession = Depends(get_db),
):
    _ = current_user
    ext = (file.filename or "").lower()
    content = await file.read()
    if not content:
        raise HTTPException(status_code=400, detail="Пустой файл")
    try:
        if ext.endswith(".csv"):
            df = pd.read_csv(io.BytesIO(content))
        elif ext.endswith(".xlsx") or ext.endswith(".xls"):
            df = pd.read_excel(io.BytesIO(content))
        else:
            raise HTTPException(status_code=400, detail="Формат: .xlsx или .csv")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Ошибка чтения файла: {e}") from e

    if "name" not in df.columns:
        raise HTTPException(status_code=400, detail="Обязательная колонка: name")

    inserted = updated = skipped = 0
    for _, row in df.iterrows():
        name = _normalize_mark(str(row.get("name") or ""))
        if not name:
            skipped += 1
            continue
        existing = (
            await db.execute(select(WireInfo).where(func.lower(WireInfo.name) == name.lower()))
        ).scalar_one_or_none()
        in_svc = _to_bool(row.get("in_service"), True)
        payload = {
            "name": name,
            "code": None if pd.isna(row.get("code")) else str(row.get("code")).strip() or None,
            "material": (
                "алюминий"
                if pd.isna(row.get("material"))
                else str(row.get("material")).strip() or "алюминий"
            ),
            "section": _float_or_none(row.get("section")) or 0.0,
            "voltage_kv": _float_or_none(row.get("voltage_kv")),
            "nominal_current": _float_or_none(row.get("nominal_current")),
            "i_th": _float_or_none(row.get("i_th")),
            "ip_max": _float_or_none(row.get("ip_max")),
            "t_th": _float_or_none(row.get("t_th")),
            "r": _float_or_none(row.get("r")),
            "x": _float_or_none(row.get("x")),
            "b": _float_or_none(row.get("b")),
            "g": _float_or_none(row.get("g")),
            "max_operating_temperature": _float_or_none(row.get("max_operating_temperature")),
            "breaking_load": _float_or_none(row.get("breaking_load")),
            "weight_per_length": _float_or_none(row.get("weight_per_length")),
            "description": None if pd.isna(row.get("description")) else str(row.get("description")),
            "in_service": in_svc,
            "is_active": in_svc,
        }
        if existing:
            if mode == "insert_only":
                skipped += 1
                continue
            for k, v in payload.items():
                setattr(existing, k, v)
            await _sync_line_conductor_catalog(db, existing)
            updated += 1
        else:
            wi = WireInfo(mrid=generate_mrid(), **payload)
            db.add(wi)
            await db.flush()
            await _sync_line_conductor_catalog(db, wi)
            inserted += 1
    await db.commit()
    return {"inserted": inserted, "updated": updated, "skipped": skipped, "total": int(len(df.index))}


@router.get("/{wire_info_id}", response_model=WireInfoResponse)
async def get_wire_info(
    wire_info_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    wire = await db.get(WireInfo, wire_info_id)
    if not wire:
        raise HTTPException(status_code=404, detail="Марка не найдена")
    _apply_in_service_flags(wire)
    return wire


@router.post("/", response_model=WireInfoResponse, status_code=status.HTTP_201_CREATED)
async def create_wire_info(
    wire_info_data: WireInfoCreate,
    current_user: User = Depends(require_catalog_manager),
    db: AsyncSession = Depends(get_db),
):
    _ = current_user
    name = _normalize_mark(wire_info_data.name)
    dup = (
        await db.execute(select(WireInfo).where(func.lower(WireInfo.name) == name.lower()))
    ).scalar_one_or_none()
    if dup:
        raise HTTPException(status_code=400, detail="Марка с таким именем уже есть")
    data = wire_info_data.model_dump(exclude={"mrid"})
    data["name"] = name
    in_svc = data.get("in_service", True)
    data["is_active"] = in_svc
    wire = WireInfo(mrid=wire_info_data.mrid or generate_mrid(), **data)
    db.add(wire)
    await db.flush()
    await _sync_line_conductor_catalog(db, wire)
    await db.commit()
    await db.refresh(wire)
    return wire


@router.put("/{wire_info_id}", response_model=WireInfoResponse)
async def update_wire_info(
    wire_info_id: int,
    payload: WireInfoUpdate,
    current_user: User = Depends(require_catalog_manager),
    db: AsyncSession = Depends(get_db),
):
    _ = current_user
    wire = await db.get(WireInfo, wire_info_id)
    if not wire:
        raise HTTPException(status_code=404, detail="Марка не найдена")
    data = payload.model_dump(exclude_unset=True)
    if "name" in data and data["name"]:
        data["name"] = _normalize_mark(data["name"])
    if "in_service" in data:
        data["is_active"] = data["in_service"]
    for k, v in data.items():
        setattr(wire, k, v)
    await _sync_line_conductor_catalog(db, wire)
    await db.commit()
    await db.refresh(wire)
    return wire


@router.post("/{wire_info_id}/withdraw", status_code=status.HTTP_200_OK)
async def withdraw_wire_from_service(
    wire_info_id: int,
    current_user: User = Depends(require_catalog_manager),
    db: AsyncSession = Depends(get_db),
):
    """Вывод марки из эксплуатации (паспортист / администратор)."""
    _ = current_user
    wire = await db.get(WireInfo, wire_info_id)
    if not wire:
        raise HTTPException(status_code=404, detail="Марка не найдена")
    wire.in_service = False
    wire.is_active = False
    await _sync_line_conductor_catalog(db, wire)
    await db.commit()
    return {"message": "Марка выведена из эксплуатации"}


@router.delete("/{wire_info_id}", status_code=status.HTTP_200_OK)
async def delete_wire_info(
    wire_info_id: int,
    current_user: User = Depends(require_admin_user),
    db: AsyncSession = Depends(get_db),
):
    """Физическое удаление — только администратор."""
    wire = await db.get(WireInfo, wire_info_id)
    if not wire:
        raise HTTPException(status_code=404, detail="Марка не найдена")
    await db.delete(wire)
    await db.commit()
    return {"message": "Марка удалена"}
