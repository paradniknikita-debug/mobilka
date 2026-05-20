"""Сбор снимка данных объекта для технического паспорта (ЛЭП, опора, ПС)."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.acline_segment import AClineSegment
from app.models.power_line import Equipment, Pole, PowerLine
from app.models.substation import (
    Bay,
    BusbarSection,
    ConductingEquipment,
    Connection,
    ProtectionEquipment,
    Substation,
    VoltageLevel,
)


def _dt(v: Any) -> Optional[str]:
    if v is None:
        return None
    if isinstance(v, datetime):
        if v.tzinfo is None:
            v = v.replace(tzinfo=timezone.utc)
        return v.isoformat()
    return str(v)


def _equipment_row(eq: Equipment) -> Dict[str, Any]:
    return {
        "mrid": eq.mrid,
        "id": eq.id,
        "equipment_type": eq.equipment_type,
        "name": eq.name,
        "manufacturer": eq.manufacturer,
        "model": eq.model,
        "serial_number": eq.serial_number,
        "year_manufactured": eq.year_manufactured,
        "installation_date": _dt(eq.installation_date),
        "condition": eq.condition,
        "notes": eq.notes,
        "defect": eq.defect,
        "criticality": eq.criticality,
        "card_comment": eq.card_comment,
        "rated_current": eq.rated_current,
        "i_th": eq.i_th,
        "ip_max": eq.ip_max,
        "t_th": eq.t_th,
        "normal_open": eq.normal_open,
        "retained": eq.retained,
        "identified_object_description": eq.identified_object_description,
        "nameplate": eq.nameplate,
        "psr_subtype": eq.psr_subtype,
        "installation_display_name": eq.installation_display_name,
        "tm_code": eq.tm_code,
        "object_subtype": eq.object_subtype,
        "pole_count": eq.pole_count,
        "parent_object_ref": eq.parent_object_ref,
        "parent_main_equipment_pole_ref": eq.parent_main_equipment_pole_ref,
        "nominal_voltage_kv": eq.nominal_voltage_kv,
        "nominal_breaking_current_ka": eq.nominal_breaking_current_ka,
        "own_trip_time_sec": eq.own_trip_time_sec,
        "emergency_current_a": eq.emergency_current_a,
        "continuous_current_a": eq.continuous_current_a,
        "arrester_type": eq.arrester_type,
        "direction_angle": eq.direction_angle,
        "catalog_item_id": eq.catalog_item_id,
        "latitude": eq.get_latitude(),
        "longitude": eq.get_longitude(),
    }


def _pole_row(p: Pole, include_equipment: bool = True) -> Dict[str, Any]:
    row: Dict[str, Any] = {
        "mrid": p.mrid,
        "id": p.id,
        "pole_number": p.pole_number,
        "sequence_number": p.sequence_number,
        "pole_type": p.pole_type,
        "construction": p.construction,
        "rated_voltage": p.rated_voltage,
        "height": p.height,
        "foundation_type": p.foundation_type,
        "material": p.material,
        "year_installed": p.year_installed,
        "condition": p.condition,
        "notes": p.notes,
        "structural_defect": p.structural_defect,
        "structural_defect_criticality": p.structural_defect_criticality,
        "card_comment": p.card_comment,
        "conductor_type": p.conductor_type,
        "conductor_material": p.conductor_material,
        "conductor_section": p.conductor_section,
        "is_tap_pole": p.is_tap_pole,
        "branch_type": p.branch_type,
        "tap_pole_id": p.tap_pole_id,
        "tap_branch_index": p.tap_branch_index,
        "latitude": p.get_latitude(),
        "longitude": p.get_longitude(),
    }
    if include_equipment and p.equipment:
        row["equipment"] = [_equipment_row(eq) for eq in p.equipment]
    else:
        row["equipment"] = []
    return row


def _line_summary(line: PowerLine) -> Dict[str, Any]:
    return {
        "mrid": line.mrid,
        "id": line.id,
        "name": line.name,
        "voltage_level_kv": line.voltage_level,
        "length_km": line.length,
        "dispatcher_name": line.dispatcher_name,
        "branch_name": line.branch_name,
        "region_name": line.region_name,
        "balance_ownership": line.balance_ownership,
        "parent_object_ref": line.parent_object_ref,
        "alcs_ref": line.alcs_ref,
        "status": line.status,
        "substation_start_id": line.substation_start_id,
        "substation_end_id": line.substation_end_id,
    }


def _conducting_row(ce: ConductingEquipment) -> Dict[str, Any]:
    return {
        "mrid": ce.mrid,
        "id": ce.id,
        "equipment_type": ce.equipment_type,
        "name": ce.name,
        "manufacturer": ce.manufacturer,
        "model": ce.model,
        "serial_number": ce.serial_number,
        "specifications": ce.specifications,
        "installation_date": _dt(ce.installation_date),
        "last_maintenance_date": _dt(ce.last_maintenance_date),
        "next_maintenance_date": _dt(ce.next_maintenance_date),
        "status": ce.status,
        "notes": ce.notes,
    }


def _protection_row(pe: ProtectionEquipment) -> Dict[str, Any]:
    return {
        "mrid": pe.mrid,
        "id": pe.id,
        "name": pe.name,
        "protection_type": pe.protection_type,
        "manufacturer": pe.manufacturer,
        "model": pe.model,
        "serial_number": pe.serial_number,
        "specifications": pe.specifications,
        "installation_date": _dt(pe.installation_date),
        "status": pe.status,
        "notes": pe.notes,
    }


def _busbar_row(bs: BusbarSection) -> Dict[str, Any]:
    return {
        "mrid": bs.mrid,
        "id": bs.id,
        "name": bs.name,
        "section_number": bs.section_number,
        "nominal_current_a": bs.nominal_current,
        "description": bs.description,
    }


def _bay_row(bay: Bay) -> Dict[str, Any]:
    return {
        "mrid": bay.mrid,
        "id": bay.id,
        "name": bay.name,
        "bay_number": bay.bay_number,
        "bay_type": bay.bay_type,
        "description": bay.description,
        "busbar_sections": [_busbar_row(bs) for bs in (bay.busbar_sections or [])],
        "conducting_equipment": [_conducting_row(ce) for ce in (bay.conducting_equipment or [])],
        "protection_equipment": [_protection_row(pe) for pe in (bay.protection_equipment or [])],
    }


def _voltage_level_row(vl: VoltageLevel) -> Dict[str, Any]:
    return {
        "mrid": vl.mrid,
        "id": vl.id,
        "name": vl.name,
        "code": vl.code,
        "nominal_voltage_kv": vl.nominal_voltage,
        "high_voltage_limit_kv": vl.high_voltage_limit,
        "low_voltage_limit_kv": vl.low_voltage_limit,
        "description": vl.description,
        "bays": [_bay_row(b) for b in (vl.bays or [])],
    }


def _substation_row(ss: Substation) -> Dict[str, Any]:
    region_name = None
    if ss.region:
        region_name = getattr(ss.region, "name", None)
    return {
        "mrid": ss.mrid,
        "id": ss.id,
        "name": ss.name,
        "dispatcher_name": ss.dispatcher_name,
        "voltage_level_kv": ss.voltage_level,
        "address": ss.address,
        "region_id": ss.region_id,
        "region_name": region_name,
        "is_active": ss.is_active,
        "connected_line_ids": list(ss.connected_line_ids) if ss.connected_line_ids else [],
        "latitude": ss.get_latitude(),
        "longitude": ss.get_longitude(),
        "voltage_levels": [_voltage_level_row(vl) for vl in (ss.voltage_levels or [])],
    }


async def _collect_involved_substations(
    db: AsyncSession,
    line: PowerLine,
    segments: List[AClineSegment],
) -> List[Dict[str, Any]]:
    """Уникальный перечень ПС, связанных с линией (начало/конец, участки, Connection, connected_line_ids)."""
    seen: set[int] = set()
    out: List[Dict[str, Any]] = []

    def add(ss: Optional[Substation], role: str) -> None:
        if ss is None or ss.id in seen:
            return
        seen.add(ss.id)
        out.append({"id": ss.id, "mrid": ss.mrid, "name": ss.name, "role": role})

    if line.substation_start:
        add(line.substation_start, "Начало линии")
    if line.substation_end:
        add(line.substation_end, "Конец линии")

    for conn in line.connections or []:
        sub = conn.substation
        if sub is not None:
            ctype = (conn.connection_type or "").strip()
            role = f"Связь ({ctype})" if ctype else "Связь с линией"
            add(sub, role)

    seg_sub_ids = {s.to_substation_id for s in segments if s.to_substation_id}
    if seg_sub_ids:
        extra = (await db.execute(select(Substation).where(Substation.id.in_(seg_sub_ids)))).scalars().all()
        for ss in extra:
            add(ss, "Конец участка линии")

    linked = (
        await db.execute(
            select(Substation).where(
                Substation.connected_line_ids.isnot(None),
                Substation.connected_line_ids.contains([line.id]),
            )
        )
    ).scalars().all()
    for ss in linked:
        add(ss, "Подключена к линии")

    return out


async def build_power_line_snapshot(db: AsyncSession, line_id: int) -> Optional[Dict[str, Any]]:
    stmt = (
        select(PowerLine)
        .where(PowerLine.id == line_id)
        .options(
            selectinload(PowerLine.poles).selectinload(Pole.equipment),
            selectinload(PowerLine.substation_start),
            selectinload(PowerLine.substation_end),
            selectinload(PowerLine.region),
            selectinload(PowerLine.connections).selectinload(Connection.substation),
        )
    )
    line = (await db.execute(stmt)).scalar_one_or_none()
    if not line:
        return None

    seg_stmt = select(AClineSegment).where(AClineSegment.line_id == line_id)
    segments = (await db.execute(seg_stmt)).scalars().all()
    segments_brief: List[Dict[str, Any]] = []
    for seg in segments:
        segments_brief.append(
            {
                "mrid": seg.mrid,
                "id": seg.id,
                "name": seg.name,
                "length_km": seg.length,
                "description": seg.description,
                "is_tap": getattr(seg, "is_tap", None),
                "tap_number": getattr(seg, "tap_number", None),
                "voltage_level_kv": getattr(seg, "voltage_level", None),
                "conductor_type": getattr(seg, "conductor_type", None),
            }
        )

    poles = list(line.poles or [])
    poles.sort(key=lambda p: (p.sequence_number is None, p.sequence_number or 0, p.pole_number or ""))

    subst_start = None
    subst_end = None
    if line.substation_start:
        subst_start = {"mrid": line.substation_start.mrid, "name": line.substation_start.name}
    if line.substation_end:
        subst_end = {"mrid": line.substation_end.mrid, "name": line.substation_end.name}

    region_name = line.region_name
    if line.region and getattr(line.region, "name", None):
        region_name = line.region.name

    line_block = _line_summary(line)
    line_block["region_name_resolved"] = region_name
    line_block["substation_start"] = subst_start
    line_block["substation_end"] = subst_end

    involved_substations = await _collect_involved_substations(db, line, list(segments))

    return {
        "power_line": line_block,
        "poles": [_pole_row(p, True) for p in poles],
        "acline_segments": segments_brief,
        "involved_substations": involved_substations,
        "totals": {"poles_count": len(poles), "segments_count": len(segments_brief)},
    }


async def build_pole_snapshot(db: AsyncSession, pole_id: int) -> Optional[Dict[str, Any]]:
    stmt = (
        select(Pole)
        .where(Pole.id == pole_id)
        .options(
            selectinload(Pole.equipment),
            selectinload(Pole.line).selectinload(PowerLine.region),
        )
    )
    pole = (await db.execute(stmt)).scalar_one_or_none()
    if not pole:
        return None
    line_block = None
    if pole.line:
        line_block = _line_summary(pole.line)
        if pole.line.region and getattr(pole.line.region, "name", None):
            line_block["region_name_resolved"] = pole.line.region.name
    return {"pole": _pole_row(pole, True), "power_line": line_block}


async def build_substation_snapshot(db: AsyncSession, substation_id: int) -> Optional[Dict[str, Any]]:
    stmt = (
        select(Substation)
        .where(Substation.id == substation_id)
        .options(
            selectinload(Substation.region),
            selectinload(Substation.voltage_levels)
            .selectinload(VoltageLevel.bays)
            .selectinload(Bay.busbar_sections),
            selectinload(Substation.voltage_levels)
            .selectinload(VoltageLevel.bays)
            .selectinload(Bay.conducting_equipment),
            selectinload(Substation.voltage_levels)
            .selectinload(VoltageLevel.bays)
            .selectinload(Bay.protection_equipment),
        )
    )
    ss = (await db.execute(stmt)).scalar_one_or_none()
    if not ss:
        return None
    return {"substation": _substation_row(ss)}


async def build_snapshot_for_object(
    db: AsyncSession,
    object_type: str,
    *,
    object_id: Optional[int] = None,
    object_mrid: Optional[str] = None,
) -> Optional[Dict[str, Any]]:
    ot = (object_type or "").strip().lower()
    if ot == "power_line":
        if object_id is not None:
            return await build_power_line_snapshot(db, object_id)
        if object_mrid:
            r = await db.execute(select(PowerLine).where(PowerLine.mrid == object_mrid))
            pl = r.scalar_one_or_none()
            if pl:
                return await build_power_line_snapshot(db, pl.id)
        return None
    if ot == "pole":
        if object_id is not None:
            return await build_pole_snapshot(db, object_id)
        if object_mrid:
            r = await db.execute(select(Pole).where(Pole.mrid == object_mrid))
            p = r.scalar_one_or_none()
            if p:
                return await build_pole_snapshot(db, p.id)
        return None
    if ot == "substation":
        if object_id is not None:
            return await build_substation_snapshot(db, object_id)
        if object_mrid:
            r = await db.execute(select(Substation).where(Substation.mrid == object_mrid))
            s = r.scalar_one_or_none()
            if s:
                return await build_substation_snapshot(db, s.id)
        return None
    return None
