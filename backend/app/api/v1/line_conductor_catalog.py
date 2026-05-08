from __future__ import annotations

import csv
from pathlib import Path
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_active_user
from app.database import get_db
from app.models.line_conductor_catalog import LineConductorCatalogItem
from app.models.user import User
from app.schemas.line_conductor_catalog import (
    LineConductorCatalogCreate,
    LineConductorCatalogResponse,
)

router = APIRouter()


def _normalize_mark(value: str) -> str:
    return " ".join((value or "").strip().split())


def _csv_candidates() -> list[Path]:
    here = Path(__file__).resolve()
    root = here.parents[4]
    return [
        root / "Марки ЛЭП по номиналу.csv",
        root / "marks_lep_by_nominal.csv",
    ]


def load_defaults_from_csv() -> list[dict]:
    csv_path: Optional[Path] = next((p for p in _csv_candidates() if p.exists()), None)
    if csv_path is None:
        return []

    rows: list[dict] = []
    seen: set[tuple[str, float]] = set()
    with csv_path.open("r", encoding="cp1251", newline="") as fp:
        reader = csv.reader(fp, delimiter=";")
        next(reader, None)
        for row in reader:
            if len(row) < 2:
                continue
            mark = _normalize_mark(row[0])
            kv_str = (row[1] or "").strip().lower().replace("кв", "").replace(" ", "")
            if not mark or not kv_str:
                continue
            try:
                voltage_kv = float(kv_str.replace(",", "."))
            except ValueError:
                continue
            key = (mark.lower(), voltage_kv)
            if key in seen:
                continue
            seen.add(key)
            rows.append({"mark": mark, "voltage_kv": voltage_kv, "is_active": True})
    return rows


@router.get("", response_model=list[LineConductorCatalogResponse])
@router.get("/", response_model=list[LineConductorCatalogResponse])
async def get_line_conductor_catalog(
    q: Optional[str] = Query(default=None),
    voltage_kv: Optional[float] = Query(default=None),
    is_active: Optional[bool] = Query(default=True),
    skip: int = Query(default=0, ge=0),
    limit: int = Query(default=500, ge=1, le=5000),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    _ = current_user
    filters = []
    if is_active is not None:
        filters.append(LineConductorCatalogItem.is_active == is_active)
    if voltage_kv is not None:
        filters.append(LineConductorCatalogItem.voltage_kv == voltage_kv)
    if q:
        qq = f"%{q.strip()}%"
        filters.append(LineConductorCatalogItem.mark.ilike(qq))

    stmt = select(LineConductorCatalogItem)
    if filters:
        stmt = stmt.where(and_(*filters))
    stmt = stmt.order_by(LineConductorCatalogItem.voltage_kv, LineConductorCatalogItem.mark).offset(skip).limit(limit)
    return (await db.execute(stmt)).scalars().all()


@router.post("", response_model=LineConductorCatalogResponse)
@router.post("/", response_model=LineConductorCatalogResponse)
async def create_line_conductor_catalog_item(
    payload: LineConductorCatalogCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    _ = current_user
    mark = _normalize_mark(payload.mark)
    if not mark:
        raise HTTPException(status_code=400, detail="mark is required")

    existing = (
        await db.execute(
            select(LineConductorCatalogItem).where(
                and_(
                    func.lower(LineConductorCatalogItem.mark) == mark.lower(),
                    LineConductorCatalogItem.voltage_kv == payload.voltage_kv,
                )
            )
        )
    ).scalar_one_or_none()
    if existing:
        existing.is_active = payload.is_active
        await db.commit()
        await db.refresh(existing)
        return existing

    item = LineConductorCatalogItem(
        mark=mark,
        voltage_kv=payload.voltage_kv,
        is_active=payload.is_active,
    )
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return item
