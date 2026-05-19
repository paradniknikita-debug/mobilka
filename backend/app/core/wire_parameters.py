"""
Расчёт электрических параметров участков ЛЭП по марке провода (WireInfo) и длине.
Используется при автосборке топологии и перед экспортом CIM.
"""
from __future__ import annotations

from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.acline_segment import AClineSegment
from app.models.cim_line_structure import LineSection, Terminal
from app.models.base import generate_mrid
from app.core.wire_info_catalog import find_wire_info, normalize_conductor_marker
from app.core.cim_topology import normalize_line_cim_topology


def _section_conductor_marker(section: LineSection) -> Optional[str]:
    marker = (section.conductor_type or "").strip() or None
    if marker:
        return marker
    for span in getattr(section, "spans", None) or []:
        sm = (getattr(span, "conductor_type", None) or "").strip()
        if sm:
            return sm
    return None


def _weighted_per_km(
    sections: list, attr: str
) -> Optional[float]:
    """Усреднение удельного параметра по длине; пропускает секции без значения."""
    total_len = 0.0
    weighted = 0.0
    for ls in sections:
        val = getattr(ls, attr, None)
        if val is None:
            continue
        ln = float(getattr(ls, "total_length", 0.0) or 0.0)
        if ln <= 0:
            continue
        total_len += ln
        weighted += float(val) * ln
    if total_len <= 0:
        return None
    return weighted / total_len


def _apply_per_km_from_wire_info(section: LineSection, wire_info) -> None:
    """Удельные параметры Ом/См на 1 км (как в справочнике WireInfo)."""
    if wire_info is None:
        return
    for attr, key in (("r", "r"), ("x", "x"), ("b", "b"), ("g", "g")):
        if getattr(section, attr, None) is None:
            val = getattr(wire_info, key, None)
            if val is not None:
                setattr(section, attr, float(val))


async def apply_wire_params_to_line_section(
    db: AsyncSession, section: LineSection
) -> None:
    """Заполнить r/x/b/g секции: удельные Ом/См·км и суммарная длина в км."""
    length_km = float(section.total_length or 0.0)
    if length_km <= 0 and section.spans:
        length_km = sum(float(getattr(s, "length", 0.0) or 0.0) for s in section.spans) / 1000.0
        section.total_length = length_km if length_km > 0 else section.total_length

    marker = _section_conductor_marker(section)
    if marker and not (section.conductor_type or "").strip():
        section.conductor_type = normalize_conductor_marker(marker) or marker
    wire_info = await find_wire_info(db, marker or "AC-70")
    if wire_info is not None:
        if not section.conductor_material and getattr(wire_info, "material", None):
            section.conductor_material = wire_info.material
        if not section.conductor_section and getattr(wire_info, "section", None) is not None:
            section.conductor_section = str(wire_info.section)
    _apply_per_km_from_wire_info(section, wire_info)
    if length_km > 0:
        section.total_length = length_km


async def apply_wire_params_to_acline_segment(
    db: AsyncSession, segment: AClineSegment
) -> None:
    """Длина сегмента и усреднённые параметры по секциям или марке провода."""
    sections = list(segment.line_sections or [])
    length_km = 0.0
    if sections:
        length_km = sum(float(getattr(ls, "total_length", 0.0) or 0.0) for ls in sections)
    if length_km <= 0:
        length_km = float(segment.length or 0.0)

    if sections:
        sec_len_sum = sum(float(getattr(ls, "total_length", 0.0) or 0.0) for ls in sections)
        if sec_len_sum > 0:
            segment.r = _weighted_per_km(sections, "r")
            segment.x = _weighted_per_km(sections, "x")
            segment.b = _weighted_per_km(sections, "b")
            segment.g = _weighted_per_km(sections, "g")
            if segment.r is not None:
                segment.r0 = segment.r
            if segment.x is not None:
                segment.x0 = segment.x
            if segment.b is not None:
                segment.bch = segment.b
            if segment.g is not None:
                segment.gch = segment.g
            segment.b0ch = 0.0 if segment.b is not None else None
            segment.g0ch = 0.0 if segment.g is not None else None
            segment.length = sec_len_sum
            return

    if length_km > 0:
        segment.length = length_km
    marker = (segment.conductor_type or "").strip() or None
    if not marker and sections:
        marker = (sections[0].conductor_type or "").strip() or None
    wire_info = await find_wire_info(db, marker or "AC-70")
    if wire_info is not None:
        if segment.r is None and wire_info.r is not None:
            segment.r = float(wire_info.r)
        if segment.x is None and wire_info.x is not None:
            segment.x = float(wire_info.x)
        if segment.b is None and wire_info.b is not None:
            segment.b = float(wire_info.b)
        if segment.g is None and wire_info.g is not None:
            segment.g = float(wire_info.g)
        segment.r0 = segment.r
        segment.x0 = segment.x
        segment.bch = segment.b
        segment.gch = segment.g
        segment.b0ch = 0.0
        segment.g0ch = 0.0


async def ensure_acline_segment_terminals(db: AsyncSession, segment: AClineSegment) -> None:
    """Два терминала ACLineSegment: начало и конец участка (ConnectivityNode)."""
    result = await db.execute(
        select(Terminal).where(Terminal.acline_segment_id == segment.id)
    )
    existing = list(result.scalars().all())
    if len(existing) >= 2:
        return

    used_cn = {t.connectivity_node_id for t in existing if t.connectivity_node_id}
    seq = max((t.sequence_number or 0) for t in existing) if existing else 0

    pairs = [
        (segment.from_connectivity_node_id, "from", "Начало"),
        (segment.to_connectivity_node_id, "to", "Конец"),
    ]
    for cn_id, direction, label in pairs:
        if cn_id is None or cn_id in used_cn:
            continue
        seq += 1
        db.add(
            Terminal(
                mrid=generate_mrid(),
                name=label,
                connectivity_node_id=cn_id,
                acline_segment_id=segment.id,
                sequence_number=seq,
                connection_direction=direction,
            )
        )
        used_cn.add(cn_id)
    await db.flush()


async def refresh_power_line_electrical_parameters(
    db: AsyncSession, power_line_id: int
) -> None:
    """Нормализовать топологию, пересчитать параметры проводников и терминалы участков."""
    from app.core.wire_info_catalog import ensure_wire_info_catalog_seeded

    await ensure_wire_info_catalog_seeded(db)
    await normalize_line_cim_topology(db, power_line_id)
    result = await db.execute(
        select(AClineSegment)
        .where(AClineSegment.line_id == power_line_id)
        .options(
            selectinload(AClineSegment.line_sections).selectinload(LineSection.spans),
            selectinload(AClineSegment.terminals),
        )
    )
    segments = result.scalars().all()
    for segment in segments:
        for section in segment.line_sections or []:
            await apply_wire_params_to_line_section(db, section)
        await apply_wire_params_to_acline_segment(db, segment)
        await ensure_acline_segment_terminals(db, segment)
    await db.flush()
