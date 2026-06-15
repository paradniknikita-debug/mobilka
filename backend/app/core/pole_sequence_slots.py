"""Вставка опоры в заданный sequence_number: сдвиг соседей (field/mobile upload)."""
from __future__ import annotations

from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.power_line import Pole


def _branch_filter(q, tap_pole_id: Optional[int], tap_branch_index: int):
    if tap_pole_id is not None:
        q = q.where(Pole.tap_pole_id == tap_pole_id)
        if tap_branch_index == 1:
            q = q.where(
                (Pole.tap_branch_index == 1) | (Pole.tap_branch_index.is_(None))
            )
        else:
            q = q.where(Pole.tap_branch_index == tap_branch_index)
    else:
        q = q.where(Pole.tap_pole_id.is_(None))
    return q


async def shift_sequence_slots(
    db: AsyncSession,
    line_id: int,
    desired_seq: int,
    *,
    tap_pole_id: Optional[int] = None,
    tap_branch_index: Optional[int] = None,
    exclude_pole_id: Optional[int] = None,
) -> None:
    """Сдвигает опоры ветки с sequence_number >= desired_seq на +1 (с конца, без коллизий)."""
    if desired_seq < 1:
        return
    bi = tap_branch_index or 1
    q = select(Pole).where(
        Pole.line_id == line_id,
        Pole.sequence_number.is_not(None),
        Pole.sequence_number >= desired_seq,
    )
    q = _branch_filter(q, tap_pole_id, bi)
    if exclude_pole_id is not None:
        q = q.where(Pole.id != exclude_pole_id)
    q = q.order_by(Pole.sequence_number.desc())
    result = await db.execute(q)
    for pole in result.scalars():
        if pole.sequence_number is not None:
            pole.sequence_number += 1
    await db.flush()


async def assign_client_sequence_or_auto(
    db: AsyncSession,
    db_pole: Pole,
    power_line_id: int,
    *,
    client_sequence: Optional[int],
    start_new_tap: bool = False,
    tap_branch_from_request: Optional[int] = None,
) -> None:
    """
    Назначает sequence_number новой опоре.
    Если client_sequence задан (mobile) — вставка в слот со сдвигом.
    Иначе — прежняя логика max+1 / новая ветка отпайки.
    """
    from sqlalchemy import func as sql_func

    tap_pole_id_val = getattr(db_pole, "tap_pole_id", None)

    if tap_pole_id_val is not None:
        if start_new_tap:
            max_branch = await db.execute(
                select(sql_func.coalesce(sql_func.max(Pole.tap_branch_index), 0)).where(
                    Pole.line_id == power_line_id, Pole.tap_pole_id == tap_pole_id_val
                )
            )
            max_branch_val = max_branch.scalar() or 0
            db_pole.tap_branch_index = max_branch_val + 1
            db_pole.sequence_number = 1
            await db.flush()
            return

        if tap_branch_from_request is not None:
            db_pole.tap_branch_index = tap_branch_from_request
        elif getattr(db_pole, "tap_branch_index", None) is None:
            max_branch = await db.execute(
                select(sql_func.coalesce(sql_func.max(Pole.tap_branch_index), 0)).where(
                    Pole.line_id == power_line_id, Pole.tap_pole_id == tap_pole_id_val
                )
            )
            max_branch_val = max_branch.scalar() or 0
            db_pole.tap_branch_index = max_branch_val if max_branch_val > 0 else 1

        bi = getattr(db_pole, "tap_branch_index", None) or 1

        if client_sequence is not None and client_sequence > 0:
            await shift_sequence_slots(
                db,
                power_line_id,
                client_sequence,
                tap_pole_id=tap_pole_id_val,
                tap_branch_index=bi,
            )
            db_pole.sequence_number = client_sequence
            await db.flush()
            return

        max_seq_q = select(sql_func.coalesce(sql_func.max(Pole.sequence_number), 0)).where(
            Pole.line_id == power_line_id,
            Pole.tap_pole_id == tap_pole_id_val,
        )
        if bi == 1:
            max_seq_q = max_seq_q.where(
                (Pole.tap_branch_index == 1) | (Pole.tap_branch_index.is_(None))
            )
        else:
            max_seq_q = max_seq_q.where(Pole.tap_branch_index == bi)
        max_seq = await db.execute(max_seq_q)
        db_pole.sequence_number = (max_seq.scalar() or 0) + 1
        await db.flush()
        return

    # Магистраль
    if client_sequence is not None and client_sequence > 0:
        await shift_sequence_slots(
            db,
            power_line_id,
            client_sequence,
            tap_pole_id=None,
            tap_branch_index=1,
        )
        db_pole.sequence_number = client_sequence
        await db.flush()
        return

    max_seq = await db.execute(
        select(sql_func.coalesce(sql_func.max(Pole.sequence_number), 0)).where(
            Pole.line_id == power_line_id, Pole.tap_pole_id.is_(None)
        )
    )
    db_pole.sequence_number = (max_seq.scalar() or 0) + 1
    await db.flush()
