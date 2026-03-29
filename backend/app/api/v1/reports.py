from __future__ import annotations

import csv
import io
import json
from datetime import datetime
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, Query
from fastapi.responses import StreamingResponse
from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_active_user
from app.database import get_db
from app.models.change_log import ChangeLog
from app.models.patrol_session import PatrolSession
from app.models.power_line import Equipment, PowerLine, Pole
from app.models.user import User

router = APIRouter()


def _parse_iso_datetime(s: Optional[str]) -> Optional[datetime]:
    if not s:
        return None
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except Exception:
        return None


def _parse_defect_attachment(raw: Optional[str]) -> List[Dict[str, Any]]:
    """
    defect_attachment хранится как JSON.
    В идеале это список: [{"t","url","thumbnail_url?"}, ...]
    Но на всякий случай поддерживаем legacy: [{"t","p"}, ...] (локальные пути без URL).
    """
    if not raw or not str(raw).strip():
        return []
    try:
        data = json.loads(raw)
    except Exception:
        return []

    # Возможные форматы:
    # - list[dict]
    # - {"items": list[dict]}
    items = None
    if isinstance(data, list):
        items = data
    elif isinstance(data, dict):
        items = data.get("items")
    if not isinstance(items, list):
        return []

    out: List[Dict[str, Any]] = []
    for it in items:
        if not isinstance(it, dict):
            continue
        try:
            t = str(it.get("t") or "photo").lower()
        except Exception:
            t = "photo"

        url = it.get("url")
        thumbnail_url = it.get("thumbnail_url")
        p = it.get("p")

        # В отчёте URL важнее p (локальные пути не пригодны на сервере/другим пользователям).
        entry: Dict[str, Any] = {"t": t}
        if isinstance(url, str) and url.strip():
            entry["url"] = url
        if isinstance(thumbnail_url, str) and thumbnail_url.strip():
            entry["thumbnail_url"] = thumbnail_url
        if "url" not in entry and isinstance(p, str) and p.strip():
            entry["p"] = p
        out.append(entry)
    return out


def _equipment_to_defect_item(
    *,
    eq: Equipment,
    pole: Pole,
    line: PowerLine,
) -> Dict[str, Any]:
    attachments = _parse_defect_attachment(getattr(eq, "defect_attachment", None))
    return {
        "line_id": line.id,
        "line_name": line.name,
        "pole_id": pole.id,
        "pole_number": pole.pole_number,
        "equipment_id": eq.id,
        "equipment_type": eq.equipment_type,
        "equipment_name": eq.name,
        "defect": eq.defect,
        "criticality": eq.criticality,
        "condition": eq.condition,
        "notes": eq.notes,
        "defect_attachments": attachments,
        "created_at": eq.created_at.isoformat() if getattr(eq, "created_at", None) else None,
        "updated_at": eq.updated_at.isoformat() if getattr(eq, "updated_at", None) else None,
    }


@router.get("/defects")
async def defects_report(
    line_id: Optional[int] = Query(None, description="Фильтр по ЛЭП (id)"),
    pole_id: Optional[int] = Query(None, description="Фильтр по опоре (id)"),
    criticality: Optional[str] = Query(None, description="low | medium | high"),
    defect_contains: Optional[str] = Query(None, description="Подстрока в названии дефекта"),
    from_dt: Optional[str] = Query(None, description="ISO datetime: начало периода (по created_at)"),
    to_dt: Optional[str] = Query(None, description="ISO datetime: конец периода (по created_at)"),
    limit: int = Query(200, ge=1, le=2000),
    offset: int = Query(0, ge=0),
    format: str = Query("json", description="json | csv"),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Отчёт по дефектам оборудования:
    - defect != null/empty
    - критичность + мультимедиа (defect_attachment)
    """

    from_dt_parsed = _parse_iso_datetime(from_dt)
    to_dt_parsed = _parse_iso_datetime(to_dt)

    # Базовая выборка: Equipment + Pole + PowerLine (для line/pole атрибутов)
    q = (
        select(Equipment, Pole, PowerLine)
        .join(Pole, Equipment.pole_id == Pole.id)
        .join(PowerLine, Pole.line_id == PowerLine.id)
        .where(
            and_(
                Equipment.defect.isnot(None),
                func.length(func.trim(Equipment.defect)) > 0,
            )
        )
    )

    if line_id is not None:
        q = q.where(PowerLine.id == line_id)
    if pole_id is not None:
        q = q.where(Pole.id == pole_id)
    if criticality:
        q = q.where(func.lower(Equipment.criticality) == criticality.lower())
    if defect_contains:
        q = q.where(func.lower(Equipment.defect).contains(defect_contains.lower()))
    if from_dt_parsed is not None:
        q = q.where(Equipment.created_at >= from_dt_parsed)
    if to_dt_parsed is not None:
        q = q.where(Equipment.created_at <= to_dt_parsed)

    q = q.order_by(func.coalesce(Equipment.updated_at, Equipment.created_at).desc()).limit(limit).offset(offset)

    result = await db.execute(q)
    rows = result.all()

    items: List[Dict[str, Any]] = []
    for eq, pole, line in rows:
        items.append(_equipment_to_defect_item(eq=eq, pole=pole, line=line))

    if format.lower() != "csv":
        return {"items": items, "count": len(items), "limit": limit, "offset": offset}

    # CSV
    stream = io.StringIO()
    writer = csv.writer(stream, delimiter=",", quotechar='"', quoting=csv.QUOTE_MINIMAL)
    writer.writerow(
        [
            "line_id",
            "line_name",
            "pole_id",
            "pole_number",
            "equipment_id",
            "equipment_type",
            "equipment_name",
            "defect",
            "criticality",
            "condition",
            "notes",
            "attachment_count",
            "attachment_urls",
        ]
    )
    for it in items:
        attachments = it.get("defect_attachments") or []
        urls = [a.get("url") for a in attachments if isinstance(a, dict) and a.get("url")]
        writer.writerow(
            [
                it.get("line_id"),
                it.get("line_name"),
                it.get("pole_id"),
                it.get("pole_number"),
                it.get("equipment_id"),
                it.get("equipment_type"),
                it.get("equipment_name"),
                it.get("defect"),
                it.get("criticality"),
                it.get("condition"),
                it.get("notes"),
                len(attachments),
                ";".join(urls),
            ]
        )

    csv_bytes = stream.getvalue().encode("utf-8-sig")
    return StreamingResponse(
        io.BytesIO(csv_bytes),
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": 'attachment; filename="defects_report.csv"'},
    )


@router.get("/by-line")
async def by_line_report(
    line_id: int = Query(..., ge=1, description="ID ЛЭП"),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Отчёт по ЛЭП:
    - сколько опор
    - сколько оборудования с дефектами
    - разбиение дефектов по критичности
    """

    line = await db.get(PowerLine, line_id)
    if not line:
        return {"error": "power line not found", "line_id": line_id}

    poles_q = await db.execute(select(func.count(Pole.id)).where(Pole.line_id == line_id))
    poles_count = poles_q.scalar_one()

    defects_base = (
        select(
            Equipment.criticality,
            func.count(Equipment.id).label("cnt"),
        )
        .select_from(Equipment)
        .join(Pole, Equipment.pole_id == Pole.id)
        .where(
            and_(
                Pole.line_id == line_id,
                Equipment.defect.isnot(None),
                func.length(func.trim(Equipment.defect)) > 0,
            )
        )
        .group_by(Equipment.criticality)
    )
    defects_rows = (await db.execute(defects_base)).all()
    defects_by_criticality = {r[0] or "unknown": int(r[1]) for r in defects_rows}
    equipment_with_defects_total = sum(defects_by_criticality.values()) if defects_by_criticality else 0

    # ТОП-дефекты (по частоте)
    top_defects_q = (
        select(Equipment.defect, func.count(Equipment.id).label("cnt"))
        .select_from(Equipment)
        .join(Pole, Equipment.pole_id == Pole.id)
        .where(
            and_(
                Pole.line_id == line_id,
                Equipment.defect.isnot(None),
                func.length(func.trim(Equipment.defect)) > 0,
            )
        )
        .group_by(Equipment.defect)
        .order_by(func.count(Equipment.id).desc())
        .limit(10)
    )
    top_defects_rows = (await db.execute(top_defects_q)).all()
    top_defects = [{"defect": r[0], "count": int(r[1])} for r in top_defects_rows]

    return {
        "line_id": line.id,
        "line_name": line.name,
        "poles_count": int(poles_count),
        "equipment_with_defects_total": int(equipment_with_defects_total),
        "defects_by_criticality": defects_by_criticality,
        "top_defects": top_defects,
    }


@router.get("/patrol")
async def patrol_report(
    line_id: Optional[int] = Query(None, description="Фильтр по ЛЭП (id)"),
    from_dt: Optional[str] = Query(None, description="ISO datetime: начало периода (по started_at)"),
    to_dt: Optional[str] = Query(None, description="ISO datetime: конец периода (по started_at)"),
    limit: int = Query(200, ge=1, le=2000),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Отчёт по обходам:
    - список сессий
    - количество change_log записей в окне [started_at; ended_at]
    """

    from_dt_parsed = _parse_iso_datetime(from_dt)
    to_dt_parsed = _parse_iso_datetime(to_dt)

    q = select(PatrolSession)
    if current_user.role != "admin":
        q = q.where(PatrolSession.user_id == current_user.id)
    if line_id is not None:
        q = q.where(PatrolSession.line_id == line_id)
    if from_dt_parsed is not None:
        q = q.where(PatrolSession.started_at >= from_dt_parsed)
    if to_dt_parsed is not None:
        q = q.where(PatrolSession.started_at <= to_dt_parsed)
    q = q.order_by(PatrolSession.started_at.desc()).offset(offset).limit(limit)

    result = await db.execute(q)
    sessions = result.scalars().all()

    if not sessions:
        return {"items": [], "count": 0, "limit": limit, "offset": offset}

    # Подгружаем имена пользователей и ЛЭП
    user_ids = {s.user_id for s in sessions if s.user_id is not None}
    line_ids = {s.line_id for s in sessions if s.line_id is not None}

    users_q = await db.execute(select(User.id, User.full_name, User.username).where(User.id.in_(user_ids)))
    users = {r[0]: (r[1] or r[2] or str(r[0])) for r in users_q.fetchall()}

    lines_q = await db.execute(select(PowerLine.id, PowerLine.name).where(PowerLine.id.in_(line_ids)))
    lines = {r[0]: r[1] for r in lines_q.fetchall()}

    items: List[Dict[str, Any]] = []
    for s in sessions:
        started = s.started_at
        ended = s.ended_at or datetime.now()

        # считаем изменения (включая equipment/pole/etc) в окне обхода
        changes_cnt_q = (
            select(func.count(ChangeLog.id))
            .where(
                and_(
                    ChangeLog.created_at >= started,
                    ChangeLog.created_at <= ended,
                )
            )
        )
        changes_cnt = (await db.execute(changes_cnt_q)).scalar_one()

        items.append(
            {
                "id": s.id,
                "user_id": s.user_id,
                "user_name": users.get(s.user_id, ""),
                "line_id": s.line_id,
                "line_name": lines.get(s.line_id, ""),
                "note": s.note,
                "started_at": s.started_at.isoformat() if s.started_at else None,
                "ended_at": s.ended_at.isoformat() if s.ended_at else None,
                "changes_count": int(changes_cnt),
            }
        )

    return {"items": items, "count": len(items), "limit": limit, "offset": offset}

