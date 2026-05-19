"""
Нормализация CIM-топологии ЛЭП перед экспортом и автосборкой.

ConnectivityNode — логический узел (стык): создаётся на опоре для пролётов/участков,
но в CIM экспортируется только если на узле сходятся ≥3 терминала (отпайка, ПС,
коммутация, третий участок/оборудование). На промежуточной опоре цепочки (2 терминала
двух последовательных ACLineSegment) узел остаётся виртуальным.
"""
from __future__ import annotations

from collections import defaultdict
from typing import Dict, List, Optional, Set

from sqlalchemy import select, update, delete, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from sqlalchemy.orm import attributes as orm_attributes

from app.models.acline_segment import AClineSegment
from app.models.cim_line_structure import ConnectivityNode, Terminal
from app.models.power_line import Pole, Span
from app.core.line_auto_assembly import _has_main_switching_equipment_on_pole


async def _rewire_connectivity_node_fk(
    db: AsyncSession, old_id: int, new_id: int
) -> None:
    """Перенаправить все ссылки с дублирующего CN на канонический."""
    if old_id == new_id:
        return
    await db.execute(
        update(AClineSegment)
        .where(AClineSegment.from_connectivity_node_id == old_id)
        .values(from_connectivity_node_id=new_id)
    )
    await db.execute(
        update(AClineSegment)
        .where(AClineSegment.to_connectivity_node_id == old_id)
        .values(to_connectivity_node_id=new_id)
    )
    await db.execute(
        update(Span)
        .where(Span.from_connectivity_node_id == old_id)
        .values(from_connectivity_node_id=new_id)
    )
    await db.execute(
        update(Span)
        .where(Span.to_connectivity_node_id == old_id)
        .values(to_connectivity_node_id=new_id)
    )
    await db.execute(
        update(Terminal)
        .where(Terminal.connectivity_node_id == old_id)
        .values(connectivity_node_id=new_id)
    )
    await db.execute(
        update(Pole)
        .where(Pole.connectivity_node_id == old_id)
        .values(connectivity_node_id=new_id)
    )


async def merge_duplicate_connectivity_nodes(
    db: AsyncSession, power_line_id: int
) -> int:
    """
    На одной опоре и линии оставляет один CN (минимальный id), остальные сливает.
    Возвращает число удалённых дубликатов.
    """
    result = await db.execute(
        select(ConnectivityNode)
        .where(ConnectivityNode.line_id == power_line_id)
        .order_by(ConnectivityNode.id.asc())
    )
    nodes = list(result.scalars().all())
    by_pole: Dict[int, List[ConnectivityNode]] = defaultdict(list)
    for cn in nodes:
        if cn.pole_id is not None:
            by_pole[int(cn.pole_id)].append(cn)

    removed = 0
    for _pole_id, group in by_pole.items():
        if len(group) <= 1:
            continue
        canonical = group[0]
        for dup in group[1:]:
            await _rewire_connectivity_node_fk(db, int(dup.id), int(canonical.id))
            await db.execute(delete(ConnectivityNode).where(ConnectivityNode.id == dup.id))
            removed += 1
    if removed:
        await db.flush()
    return removed


def _segment_endpoint_ids(segments: List[AClineSegment]) -> Dict[int, int]:
    """Сколько раз CN встречается как конец участков (from + to)."""
    degree: Dict[int, int] = defaultdict(int)
    for seg in segments:
        fid = getattr(seg, "from_connectivity_node_id", None)
        tid = getattr(seg, "to_connectivity_node_id", None)
        if fid is not None:
            degree[int(fid)] += 1
        if tid is not None:
            degree[int(tid)] += 1
    return degree


async def _terminal_count_per_cn(
    db: AsyncSession, power_line_id: int
) -> Dict[int, int]:
    """Число Terminal на каждом ConnectivityNode линии."""
    result = await db.execute(
        select(Terminal.connectivity_node_id, func.count(Terminal.id))
        .join(ConnectivityNode, ConnectivityNode.id == Terminal.connectivity_node_id)
        .where(
            ConnectivityNode.line_id == power_line_id,
            Terminal.connectivity_node_id.isnot(None),
        )
        .group_by(Terminal.connectivity_node_id)
    )
    return {int(row[0]): int(row[1]) for row in result.all() if row[0] is not None}


def _is_logical_junction(
    cn_id: int,
    segment_endpoint_degree: Dict[int, int],
    terminal_counts: Dict[int, int],
) -> bool:
    """
    Стык: ≥3 терминала на узле (участки + оборудование) или ≥3 конца ACLineSegment.
    Два последовательных участка на опоре — не стык (degree=2, terminals=2).
    """
    tc = terminal_counts.get(cn_id, 0)
    seg_deg = segment_endpoint_degree.get(cn_id, 0)
    return tc >= 3 or seg_deg >= 3


async def mark_cim_exportable_connectivity_nodes(
    db: AsyncSession, power_line_id: int
) -> Dict[int, int]:
    """
    Помечает реальные узлы для CIM: ПС, отпаечные опоры, коммутация, стык (≥3 терминала).
    Возвращает карту cn_id -> число концов ACLineSegment (для экспорта).
    """
    result = await db.execute(
        select(AClineSegment)
        .where(AClineSegment.line_id == power_line_id)
        .options(
            selectinload(AClineSegment.from_node).selectinload(ConnectivityNode.pole),
            selectinload(AClineSegment.to_node).selectinload(ConnectivityNode.pole),
        )
    )
    segments = list(result.scalars().all())
    degree = _segment_endpoint_ids(segments)
    terminal_counts = await _terminal_count_per_cn(db, power_line_id)

    cn_ids: Set[int] = set(degree.keys()) | set(terminal_counts.keys())
    if not cn_ids:
        return degree

    cn_result = await db.execute(
        select(ConnectivityNode)
        .where(
            ConnectivityNode.line_id == power_line_id,
            ConnectivityNode.id.in_(cn_ids),
        )
        .options(selectinload(ConnectivityNode.pole))
    )
    cn_by_id = {int(cn.id): cn for cn in cn_result.scalars().all()}

    for cn_id, cn in cn_by_id.items():
        exportable = False
        if getattr(cn, "substation_id", None):
            exportable = True
        elif _is_logical_junction(cn_id, degree, terminal_counts):
            exportable = True
        elif cn.pole is not None:
            if getattr(cn.pole, "is_tap_pole", False):
                exportable = True
            elif await _has_main_switching_equipment_on_pole(db, cn.pole.id):
                exportable = True
        if exportable:
            cn.is_virtual = False
        elif cn.pole_id is not None:
            # Цепочка ACLineSegment через опору (2 терминала) — виртуальный CN
            cn.is_virtual = True

    await db.flush()
    return degree


async def normalize_line_cim_topology(db: AsyncSession, power_line_id: int) -> None:
    """Полная нормализация топологии линии перед расчётом параметров и CIM-экспортом."""
    await merge_duplicate_connectivity_nodes(db, power_line_id)
    await mark_cim_exportable_connectivity_nodes(db, power_line_id)


def cn_is_cim_exportable(
    cn: Optional[ConnectivityNode],
    endpoint_degree: Dict[int, int],
    terminal_counts: Optional[Dict[int, int]] = None,
) -> bool:
    """Экспортировать CN в контейнере Line: стык (≥3 терминала), ПС, отпайка, коммутация."""
    if cn is None:
        return False
    if getattr(cn, "substation_id", None):
        return True
    cn_id = getattr(cn, "id", None)
    cn_id_int = int(cn_id) if cn_id is not None else None
    cn_state = orm_attributes.instance_state(cn)
    tc_map = terminal_counts or {}
    if cn_id_int is not None:
        tc = tc_map.get(cn_id_int, 0)
        if tc == 0 and "terminals" not in cn_state.unloaded:
            loaded_terms = cn_state.dict.get("terminals")
            if loaded_terms is not None:
                tc = len(loaded_terms)
        if _is_logical_junction(cn_id_int, endpoint_degree, {cn_id_int: tc} if tc else tc_map):
            return True
    if "pole" not in cn_state.unloaded:
        pole = getattr(cn, "pole", None)
        if pole is not None and getattr(pole, "is_tap_pole", False):
            return True
    if getattr(cn, "is_virtual", False):
        return False
    return True
