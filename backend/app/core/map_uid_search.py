"""Поиск объекта на карте по mRID / UID (в т.ч. из журнала изменений)."""

from __future__ import annotations

from typing import Any, Dict, List, Optional, Tuple

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.acline_segment import AClineSegment
from app.models.cim_line_structure import ConnectivityNode, LineSection, Terminal
from app.models.power_line import Equipment, Pole, PowerLine, Span, Tap
from app.models.substation import Substation


def _norm_mrid(q: str) -> str:
    return (q or "").strip().lower()


def _hit(
    entity_type: str,
    entity_id: int,
    mrid: str,
    label: str,
    *,
    line_id: Optional[int] = None,
    pole_id: Optional[int] = None,
    substation_id: Optional[int] = None,
    latitude: Optional[float] = None,
    longitude: Optional[float] = None,
) -> Dict[str, Any]:
    return {
        "entity_type": entity_type,
        "entity_id": int(entity_id),
        "mrid": mrid,
        "label": label,
        "line_id": line_id,
        "pole_id": pole_id,
        "substation_id": substation_id,
        "latitude": latitude,
        "longitude": longitude,
    }


async def _first_by_mrid(db: AsyncSession, model, mrid: str):
    q = _norm_mrid(mrid)
    if not q:
        return None
    stmt = select(model).where(func.lower(model.mrid) == q)
    return (await db.execute(stmt)).scalar_one_or_none()


async def find_map_entity_by_uid(db: AsyncSession, query: str) -> Optional[Dict[str, Any]]:
    """
    Точное совпадение mRID (регистр не важен).
    Порядок: сущности, которые можно показать на карте.
    """
    mrid = (query or "").strip()
    if len(mrid) < 8:
        return None

    pole = await _first_by_mrid(db, Pole, mrid)
    if pole:
        return _hit(
            "pole",
            pole.id,
            pole.mrid,
            f"Опора {pole.pole_number or pole.id}",
            line_id=pole.line_id,
            pole_id=pole.id,
            latitude=pole.get_latitude(),
            longitude=pole.get_longitude(),
        )

    eq = await _first_by_mrid(db, Equipment, mrid)
    if eq:
        pole_id = eq.pole_id
        line_id = None
        lat = lon = None
        if pole_id:
            p = await db.get(Pole, pole_id)
            if p:
                line_id = p.line_id
                lat = p.get_latitude()
                lon = p.get_longitude()
        return _hit(
            "equipment",
            eq.id,
            eq.mrid,
            f"Оборудование: {eq.name or eq.equipment_type or eq.id}",
            line_id=line_id,
            pole_id=pole_id,
            latitude=lat,
            longitude=lon,
        )

    sub = await _first_by_mrid(db, Substation, mrid)
    if sub:
        return _hit(
            "substation",
            sub.id,
            sub.mrid,
            f"Подстанция: {sub.name}",
            substation_id=sub.id,
            latitude=sub.get_latitude(),
            longitude=sub.get_longitude(),
        )

    line = await _first_by_mrid(db, PowerLine, mrid)
    if line:
        return _hit(
            "power_line",
            line.id,
            line.mrid,
            f"ЛЭП: {line.name}",
            line_id=line.id,
        )

    span = await _first_by_mrid(db, Span, mrid)
    if span:
        pole_id = span.from_pole_id or span.to_pole_id
        return _hit(
            "span",
            span.id,
            span.mrid,
            f"Пролёт: {span.span_number or span.id}",
            line_id=span.line_id,
            pole_id=pole_id,
        )

    tap = await _first_by_mrid(db, Tap, mrid)
    if tap:
        return _hit(
            "tap",
            tap.id,
            tap.mrid,
            f"Отпайка: {tap.tap_number or tap.id}",
            line_id=tap.line_id,
            pole_id=tap.pole_id,
        )

    cn = await _first_by_mrid(db, ConnectivityNode, mrid)
    if cn:
        label = cn.name or f"Узел {cn.id}"
        if cn.pole_id:
            p_cn = await db.get(Pole, cn.pole_id)
            if p_cn and p_cn.pole_number:
                label = f"Узел на опоре {p_cn.pole_number}"
        return _hit(
            "connectivity_node",
            cn.id,
            cn.mrid,
            label,
            line_id=cn.line_id,
            pole_id=cn.pole_id,
            latitude=float(cn.y_position) if cn.y_position is not None else None,
            longitude=float(cn.x_position) if cn.x_position is not None else None,
        )

    seg = await _first_by_mrid(db, AClineSegment, mrid)
    if seg:
        return _hit(
            "acline_segment",
            seg.id,
            seg.mrid,
            f"Участок линии: {seg.name or seg.id}",
            line_id=seg.line_id,
        )

    ls = await _first_by_mrid(db, LineSection, mrid)
    if ls:
        line_id = None
        if ls.acline_segment_id:
            seg_row = await db.get(AClineSegment, ls.acline_segment_id)
            if seg_row:
                line_id = seg_row.line_id
        return _hit(
            "line_section",
            ls.id,
            ls.mrid,
            f"Секция провода: {ls.name or ls.id}",
            line_id=line_id,
        )

    term = await _first_by_mrid(db, Terminal, mrid)
    if term:
        line_id = pole_id = None
        lat = lon = None
        if term.connectivity_node_id:
            cn_row = await db.get(ConnectivityNode, term.connectivity_node_id)
            if cn_row:
                line_id = cn_row.line_id
                pole_id = cn_row.pole_id
                lat = float(cn_row.y_position) if cn_row.y_position is not None else None
                lon = float(cn_row.x_position) if cn_row.x_position is not None else None
        elif term.acline_segment_id:
            seg_row = await db.get(AClineSegment, term.acline_segment_id)
            if seg_row:
                line_id = seg_row.line_id
        return _hit(
            "terminal",
            term.id,
            term.mrid,
            f"Терминал: {term.name or term.id}",
            line_id=line_id,
            pole_id=pole_id,
            latitude=lat,
            longitude=lon,
        )

    return None
