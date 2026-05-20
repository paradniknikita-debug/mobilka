"""
Нормализация CIM-топологии ЛЭП перед экспортом и автосборкой.

ConnectivityNode — стык: терминалы От/К ACLineSegment (2 на участок, на стыке 2–3+).
Оборудование даёт один терминал на CN (T1 или T2); второй полюс — на соседнем CN.
Без оборудования на стыке — только терминалы участков. Опора — геопривязка (pole_id).

Реальный CN (не виртуальный) только на развилке: от опоры ≥3 направлений (ветви, ПС, отпайки).
Промежуточная опора прямой линии — виртуальный CN (для пролётов в БД, не в CIM).
Оборудование на прямой без развилки не делает CN экспортируемым.
"""
from __future__ import annotations

from collections import defaultdict
from typing import Dict, List, Optional, Set

from sqlalchemy import select, update, delete, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.acline_segment import AClineSegment
from app.models.cim_line_structure import ConnectivityNode, Terminal
from app.models.power_line import Pole, Span


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


async def compute_cn_direction_counts(
    db: AsyncSession, power_line_id: int
) -> Dict[int, int]:
    """
    Число направлений от опоры (cn_id): уникальные соседи по пролётам, ПС, ветки отпайки.
    Прямая линия 1—2—3: у опоры 2 направления; развилка/отпайка — ≥3.
    """
    pole_dirs: Dict[int, Set[str]] = defaultdict(set)

    span_result = await db.execute(
        select(Span).where(Span.line_id == power_line_id)
    )
    for sp in span_result.scalars().all():
        fp = getattr(sp, "from_pole_id", None)
        tp = getattr(sp, "to_pole_id", None)
        fcn = getattr(sp, "from_connectivity_node_id", None)
        tcn = getattr(sp, "to_connectivity_node_id", None)
        if fp and tp:
            pole_dirs[int(fp)].add(f"pole:{tp}")
            pole_dirs[int(tp)].add(f"pole:{fp}")
        elif fp and tcn:
            pole_dirs[int(fp)].add(f"cn:{tcn}")
        elif tp and fcn:
            pole_dirs[int(tp)].add(f"cn:{fcn}")

    poles_result = await db.execute(
        select(Pole).where(Pole.line_id == power_line_id)
    )
    for pole in poles_result.scalars().all():
        tpid = getattr(pole, "tap_pole_id", None)
        if tpid is None:
            continue
        tbi = getattr(pole, "tap_branch_index", None) or 1
        if (pole.sequence_number or 0) == 1:
            pole_dirs[int(tpid)].add(f"tap:{tbi}")

    cn_result = await db.execute(
        select(ConnectivityNode.id, ConnectivityNode.pole_id).where(
            ConnectivityNode.line_id == power_line_id,
            ConnectivityNode.pole_id.isnot(None),
        )
    )
    out: Dict[int, int] = {}
    for cn_id, pole_id in cn_result.all():
        if pole_id is None:
            continue
        out[int(cn_id)] = len(pole_dirs.get(int(pole_id), set()))
    return out


def compute_cn_direction_counts_from_loaded(
    power_line_id: int,
    poles: List[Pole],
    segments: List[AClineSegment],
) -> Dict[int, int]:
    """Синхронный подсчёт направлений по уже загруженным ORM-объектам (CIM-экспорт)."""
    pole_dirs: Dict[int, Set[str]] = defaultdict(set)
    cn_by_pole: Dict[int, int] = {}

    for pole in poles or []:
        for cn in getattr(pole, "connectivity_nodes", None) or []:
            if int(getattr(cn, "line_id", 0) or 0) == int(power_line_id) and cn.pole_id:
                cn_by_pole[int(pole.id)] = int(cn.id)

    for segment in segments or []:
        for ls in getattr(segment, "line_sections", None) or []:
            for sp in getattr(ls, "spans", None) or []:
                fp = getattr(sp, "from_pole_id", None)
                tp = getattr(sp, "to_pole_id", None)
                fcn = getattr(sp, "from_connectivity_node_id", None)
                tcn = getattr(sp, "to_connectivity_node_id", None)
                if fp and tp:
                    pole_dirs[int(fp)].add(f"pole:{tp}")
                    pole_dirs[int(tp)].add(f"pole:{fp}")
                elif fp and tcn:
                    pole_dirs[int(fp)].add(f"cn:{tcn}")
                elif tp and fcn:
                    pole_dirs[int(tp)].add(f"cn:{fcn}")

    for pole in poles or []:
        tpid = getattr(pole, "tap_pole_id", None)
        if tpid is None:
            continue
        tbi = getattr(pole, "tap_branch_index", None) or 1
        if (pole.sequence_number or 0) == 1:
            pole_dirs[int(tpid)].add(f"tap:{tbi}")

    return {
        cn_by_pole[pid]: len(pole_dirs.get(pid, set()))
        for pid in cn_by_pole
    }


def _is_logical_junction(
    cn_id: int,
    segment_endpoint_degree: Dict[int, int],
    terminal_counts: Dict[int, int],
    direction_counts: Optional[Dict[int, int]] = None,
) -> bool:
    """
    Стык: ≥3 направления от опоры (ветви, ПС, отпайки) или ≥3 конца ACLineSegment на CN.
    Прямая с оборудованием: 2 направления и 2–3 терминала — не стык (терминалы не считаем).
    """
    dmap = direction_counts or {}
    if dmap.get(cn_id, 0) >= 3:
        return True
    if segment_endpoint_degree.get(cn_id, 0) >= 3:
        return True
    return False


async def mark_cim_exportable_connectivity_nodes(
    db: AsyncSession, power_line_id: int
) -> Dict[int, int]:
    """
    Помечает is_virtual: реальный CN только ПС и развилки (≥3 направления).
    Отпаечная опора без трёх направлений остаётся виртуальной до появления веток.
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
    direction_counts = await compute_cn_direction_counts(db, power_line_id)

    cn_result = await db.execute(
        select(ConnectivityNode)
        .where(ConnectivityNode.line_id == power_line_id)
        .options(selectinload(ConnectivityNode.pole))
    )
    for cn in cn_result.scalars().all():
        cn_id = int(cn.id)
        exportable = False
        if getattr(cn, "substation_id", None):
            exportable = True
        elif _is_logical_junction(
            cn_id, degree, terminal_counts, direction_counts
        ):
            exportable = True
        cn.is_virtual = not exportable

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
    direction_counts: Optional[Dict[int, int]] = None,
) -> bool:
    """
    Экспортировать ConnectivityNode в Line: только ПС и стык (развилка ≥3 направлений).
    Виртуальные CN промежуточных опор в CIM не попадают.
    """
    if cn is None:
        return False
    if getattr(cn, "substation_id", None):
        return True
    if getattr(cn, "is_virtual", True):
        return False
    cn_id = getattr(cn, "id", None)
    if cn_id is None:
        return False
    cn_id_int = int(cn_id)
    dmap = direction_counts or {}
    return _is_logical_junction(
        cn_id_int, endpoint_degree, terminal_counts or {}, dmap
    )
