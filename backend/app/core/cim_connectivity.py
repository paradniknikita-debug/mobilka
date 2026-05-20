"""
CIM-топология: ConnectivityNode — стык, в котором сходятся Terminal проводящего оборудования.

На одном CN:
  - терминалы концов ACLineSegment (От / К) — сколько сходится участков (2, 3, …);
  - не более одного терминала на каждое оборудование (T1 или T2), не оба сразу.

Двухполюсное оборудование (разъединитель, реклоузер): T1 на CN опоры установки,
T2 на CN соседней опоры (parent_main_equipment_pole_ref или сосед по участку).
Однополюсное (ЗН, разрядник): один терминал на CN опоры.
Если оборудования нет — на CN только терминалы ACLineSegment.
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Dict, List, Optional, Set, Tuple

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.acline_segment import AClineSegment
from app.models.cim_line_structure import ConnectivityNode, Terminal
from app.models.power_line import Equipment, Pole
from app.core.line_auto_assembly import get_or_create_connectivity_node_for_pole
from app.core.wire_parameters import ensure_acline_segment_terminals
from app.core.cim_topology import normalize_line_cim_topology


_EQUIPMENT_ID_RE = re.compile(r"equipment_id=(\d+)", re.I)


@dataclass(frozen=True)
class _TerminalPlacement:
    pole_id: int
    sequence_number: int
    connection_direction: str


def equipment_is_two_terminal_device(equipment: Equipment) -> bool:
    """У оборудования два полюса (T1 и T2), но на одном CN — только один из них."""
    etype = (getattr(equipment, "equipment_type", None) or "").lower()
    name = (getattr(equipment, "name", None) or "").lower()
    combined = f"{etype} {name}"
    return any(
        k in combined
        for k in ("разъедин", "disconnector", "выключат", "breaker", "реклозер", "recloser")
    )


def equipment_has_line_terminals(equipment: Equipment) -> bool:
    """Нужны ли терминалы на карте/CIM (линейное коммутационное и ЗН/ОПН)."""
    if equipment_is_two_terminal_device(equipment):
        return True
    etype = (getattr(equipment, "equipment_type", None) or "").lower()
    name = (getattr(equipment, "name", None) or "").lower()
    combined = f"{etype} {name}"
    if any(k in combined for k in ("зн", "заземлен", "разряд", "опн", "arrester", "surge")):
        return True
    no_icon = ("фундамент", "изолятор", "траверс", "грозоотвод", "грозотрос", "traverse")
    return not any(x in combined for x in no_icon)


def _terminal_equipment_id(term: Terminal) -> Optional[int]:
    eid = getattr(term, "equipment_id", None)
    if eid is not None:
        return int(eid)
    desc = (getattr(term, "description", None) or "").lower()
    m = _EQUIPMENT_ID_RE.search(desc)
    return int(m.group(1)) if m else None


def _resolve_pole_by_ref(
    ref: str,
    poles_by_id: Dict[int, Pole],
    poles_by_number: Dict[str, Pole],
) -> Optional[Pole]:
    r = (ref or "").strip().lower()
    if not r:
        return None
    if r.isdigit():
        return poles_by_id.get(int(r))
    return poles_by_number.get(r)


async def _pole_adjacency(
    db: AsyncSession, power_line_id: int, poles_by_id: Dict[int, Pole]
) -> Dict[int, Set[int]]:
    """Соседние опоры по концам ACLineSegment (От/К на CN опор)."""
    adj: Dict[int, Set[int]] = {pid: set() for pid in poles_by_id}
    cn_to_pole: Dict[int, int] = {}
    for pole in poles_by_id.values():
        cn = pole.get_connectivity_node_for_line(power_line_id)
        if cn is not None:
            cn_to_pole[int(cn.id)] = int(pole.id)

    seg_result = await db.execute(
        select(AClineSegment).where(AClineSegment.line_id == power_line_id)
    )
    for seg in seg_result.scalars().all():
        ends: List[int] = []
        for cn_id in (seg.from_connectivity_node_id, seg.to_connectivity_node_id):
            if cn_id is None:
                continue
            pid = cn_to_pole.get(int(cn_id))
            if pid is not None:
                ends.append(pid)
        if len(ends) >= 2:
            a, b = ends[0], ends[1]
            adj[a].add(b)
            adj[b].add(a)
    return adj


def _other_pole_for_two_terminal_equipment(
    equipment: Equipment,
    mount_pole: Pole,
    poles_by_id: Dict[int, Pole],
    poles_by_number: Dict[str, Pole],
    adjacency: Dict[int, Set[int]],
) -> Optional[Pole]:
    ref = getattr(equipment, "parent_main_equipment_pole_ref", None)
    if ref:
        other = _resolve_pole_by_ref(str(ref), poles_by_id, poles_by_number)
        if other is not None and other.id != mount_pole.id:
            return other
    neighbors = sorted(
        adjacency.get(int(mount_pole.id), set()),
        key=lambda pid: (poles_by_id[pid].sequence_number or 0, pid),
    )
    for pid in neighbors:
        if pid != mount_pole.id:
            return poles_by_id.get(pid)
    return None


def _placements_for_equipment(
    equipment: Equipment,
    mount_pole: Pole,
    poles_by_id: Dict[int, Pole],
    poles_by_number: Dict[str, Pole],
    adjacency: Dict[int, Set[int]],
) -> List[_TerminalPlacement]:
    if not equipment_has_line_terminals(equipment):
        return []

    if not equipment_is_two_terminal_device(equipment):
        return [
            _TerminalPlacement(
                pole_id=int(mount_pole.id),
                sequence_number=1,
                connection_direction="both",
            )
        ]

    other = _other_pole_for_two_terminal_equipment(
        equipment, mount_pole, poles_by_id, poles_by_number, adjacency
    )
    placements = [
        _TerminalPlacement(
            pole_id=int(mount_pole.id),
            sequence_number=1,
            connection_direction="from",
        ),
    ]
    if other is not None:
        placements.append(
            _TerminalPlacement(
                pole_id=int(other.id),
                sequence_number=2,
                connection_direction="to",
            )
        )
    return placements


async def _ensure_cn_for_pole(
    db: AsyncSession, pole: Pole, power_line_id: int
) -> ConnectivityNode:
    cn = pole.get_connectivity_node_for_line(power_line_id)
    if cn is not None:
        return cn
    return await get_or_create_connectivity_node_for_pole(db, pole, power_line_id)


async def sync_equipment_terminals_for_line(db: AsyncSession, power_line_id: int) -> None:
    """
    Терминалы оборудования: не более одного на CN (T1 или T2).
    Двухполюсное — T1 и T2 на разных CN (опора установки и соседняя).
    """
    poles_result = await db.execute(
        select(Pole)
        .where(Pole.line_id == power_line_id)
        .options(selectinload(Pole.equipment), selectinload(Pole.connectivity_nodes))
    )
    poles = list(poles_result.scalars().all())
    if not poles:
        return

    poles_by_id = {int(p.id): p for p in poles}
    poles_by_number = {
        (p.pole_number or "").strip().lower(): p
        for p in poles
        if (p.pole_number or "").strip()
    }
    adjacency = await _pole_adjacency(db, power_line_id, poles_by_id)

    cn_ids: List[int] = []
    for pole in poles:
        cn = await _ensure_cn_for_pole(db, pole, power_line_id)
        cn_ids.append(int(cn.id))

    await db.execute(
        delete(Terminal).where(
            Terminal.connectivity_node_id.in_(cn_ids),
            Terminal.acline_segment_id.is_(None),
        )
    )

    for pole in poles:
        for equipment in pole.equipment or []:
            for placement in _placements_for_equipment(
                equipment, pole, poles_by_id, poles_by_number, adjacency
            ):
                target_pole = poles_by_id.get(placement.pole_id)
                if target_pole is None:
                    continue
                cn = await _ensure_cn_for_pole(db, target_pole, power_line_id)
                from app.models.base import generate_mrid

                term = Terminal(
                    mrid=generate_mrid(),
                    name=f"T{placement.sequence_number}",
                    connectivity_node_id=cn.id,
                    acline_segment_id=None,
                    sequence_number=placement.sequence_number,
                    connection_direction=placement.connection_direction,
                    description=f"equipment_id={equipment.id}",
                )
                if hasattr(term, "equipment_id"):
                    term.equipment_id = int(equipment.id)
                db.add(term)

    await db.flush()


async def sync_line_connectivity_topology(db: AsyncSession, power_line_id: int) -> None:
    """CN + терминалы ACLineSegment (От/К) + терминалы оборудования (по одному на CN)."""
    await normalize_line_cim_topology(db, power_line_id)

    seg_result = await db.execute(
        select(AClineSegment)
        .where(AClineSegment.line_id == power_line_id)
        .options(selectinload(AClineSegment.terminals))
    )
    for segment in seg_result.scalars().all():
        await ensure_acline_segment_terminals(db, segment)

    await sync_equipment_terminals_for_line(db, power_line_id)
    await db.flush()
