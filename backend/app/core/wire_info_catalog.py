"""
Справочник WireInfo (CIM): удельные r/x/b/g на 1 км.
Марки из «Марки ЛЭП по номиналу.csv» + псевдонимы AC-xx (мобильное приложение).
"""
from __future__ import annotations

import re
from functools import lru_cache
from typing import Any, Dict, Optional

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.wire_info_defaults_data import (
    build_all_wire_defaults,
    resolve_wire_spec,
)
from app.models.base import generate_mrid
from app.models.wire_info import WireInfo

_CYR_AC = str.maketrans({"А": "A", "а": "a", "С": "C", "с": "c"})


@lru_cache(maxsize=1)
def wire_info_defaults() -> Dict[str, Dict[str, Any]]:
    return build_all_wire_defaults()


def normalize_conductor_marker(marker: Optional[str]) -> Optional[str]:
    """
    Для латинских марок: AC70, AC 70, АС-70 (кириллица) -> AC-70.
    Каталожные «А 70», «АС 70/11» возвращаются без изменения (кроме сжатия пробелов).
    """
    raw = (marker or "").strip()
    if not raw:
        return None
    compact = " ".join(raw.split())
    s = compact.translate(_CYR_AC).upper()
    s_compact = re.sub(r"\s+", "", s).replace("_", "-")
    if re.fullmatch(r"AC\d{2,3}", s_compact):
        return f"AC-{s_compact[2:]}"
    if re.fullmatch(r"AC-\d{2,3}", s_compact):
        return s_compact
    return compact


def default_wire_params(marker: Optional[str]) -> Optional[Dict[str, Any]]:
    key = normalize_conductor_marker(marker)
    defaults = wire_info_defaults()
    if key and key in defaults:
        return defaults[key]
    spec = resolve_wire_spec(marker or "")
    if spec:
        return spec
    if key:
        return resolve_wire_spec(key)
    return None


def _spec_for_marker(marker: str) -> Optional[Dict[str, Any]]:
    defaults = wire_info_defaults()
    norm = normalize_conductor_marker(marker)
    if norm and norm in defaults:
        return defaults[norm]
    if marker in defaults:
        return defaults[marker]
    spec = resolve_wire_spec(marker)
    if spec:
        return spec
    if norm:
        return resolve_wire_spec(norm)
    return None


def _apply_spec_to_row(row: WireInfo, spec: Dict[str, Any]) -> None:
    for field in ("r", "x", "b", "g", "section", "material", "nominal_current", "code"):
        if getattr(row, field, None) is None and spec.get(field) is not None:
            setattr(row, field, spec[field])


async def ensure_wire_info_catalog_seeded(db: AsyncSession) -> int:
    """
    Идемпотентно создаёт/дополняет WireInfo для всех марок справочника.
    """
    inserted = 0
    updated = 0
    for name, spec in wire_info_defaults().items():
        result = await db.execute(
            select(WireInfo).where(func.lower(WireInfo.name) == name.lower())
        )
        row = result.scalar_one_or_none()
        if row is None:
            row = WireInfo(
                mrid=generate_mrid(),
                name=name,
                code=spec.get("code"),
                material=spec["material"],
                section=float(spec["section"]),
                r=spec.get("r"),
                x=spec.get("x"),
                b=spec.get("b"),
                g=spec.get("g"),
                nominal_current=spec.get("nominal_current"),
                description="Справочник LEPM (типовые удельные параметры, Ом/км)",
                is_active=True,
            )
            db.add(row)
            inserted += 1
        else:
            before = (row.r, row.x, row.b)
            _apply_spec_to_row(row, spec)
            if (row.r, row.x, row.b) != before and before == (None, None, None):
                updated += 1

    try:
        from app.models.line_conductor_catalog import LineConductorCatalogItem

        cat_rows = (
            await db.execute(
                select(LineConductorCatalogItem.mark).where(
                    LineConductorCatalogItem.is_active == True
                )
            )
        ).scalars().all()
        for mark in cat_rows:
            m = " ".join((mark or "").strip().split())
            if not m:
                continue
            spec = _spec_for_marker(m)
            if not spec:
                continue
            result = await db.execute(
                select(WireInfo).where(func.lower(WireInfo.name) == m.lower())
            )
            row = result.scalar_one_or_none()
            if row is None:
                db.add(
                    WireInfo(
                        mrid=generate_mrid(),
                        name=m,
                        code=spec.get("code"),
                        material=spec["material"],
                        section=float(spec["section"]),
                        r=spec.get("r"),
                        x=spec.get("x"),
                        b=spec.get("b"),
                        g=spec.get("g"),
                        nominal_current=spec.get("nominal_current"),
                        description="Из справочника марок ЛЭП",
                        is_active=True,
                    )
                )
                inserted += 1
            else:
                _apply_spec_to_row(row, spec)
    except Exception:
        pass

    if inserted or updated:
        await db.flush()
    return inserted


async def find_wire_info(db: AsyncSession, marker: Optional[str]) -> Optional[WireInfo]:
    """Поиск WireInfo по марке; при отсутствии — создание по типовым параметрам."""
    await ensure_wire_info_catalog_seeded(db)
    raw = (marker or "").strip()
    if not raw:
        return None

    for lookup in (raw, normalize_conductor_marker(raw)):
        if not lookup:
            continue
        result = await db.execute(
            select(WireInfo).where(func.lower(WireInfo.name) == lookup.lower())
        )
        wi = result.scalar_one_or_none()
        if wi is not None:
            return wi

    spec = _spec_for_marker(raw)
    if spec is None:
        return None

    display_name = normalize_conductor_marker(raw) or raw
    if display_name != raw:
        result = await db.execute(
            select(WireInfo).where(func.lower(WireInfo.name) == display_name.lower())
        )
        wi = result.scalar_one_or_none()
        if wi is not None:
            return wi

    wi = WireInfo(
        mrid=generate_mrid(),
        name=display_name,
        code=spec.get("code"),
        material=spec["material"],
        section=float(spec["section"]),
        r=spec.get("r"),
        x=spec.get("x"),
        b=spec.get("b"),
        g=spec.get("g"),
        nominal_current=spec.get("nominal_current"),
        description="Создано при расчёте по марке провода",
        is_active=True,
    )
    db.add(wi)
    await db.flush()
    return wi
