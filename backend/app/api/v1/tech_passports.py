"""API сохранённых технических паспортов и выгрузка PDF/DOCX/XLSX."""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from io import BytesIO
from typing import Any, Dict, Optional, Tuple

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from fastapi.responses import StreamingResponse
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.passport_export import export_passport_file
from app.core.passport_snapshot import build_snapshot_for_object
from app.core.roles import require_user_can_export
from app.core.security import get_current_active_user
from app.database import get_db
from app.models.tech_passport import TechPassport
from app.models.user import User
from app.schemas.tech_passport import TechPassportCreate, TechPassportDetail, TechPassportListItem, TechPassportListResponse

router = APIRouter()


def _default_title(object_type: str, data: Dict[str, Any]) -> str:
    if object_type == "power_line":
        pl = data.get("power_line") or {}
        name = pl.get("name") or pl.get("mrid") or "ЛЭП"
        return f"Технический паспорт ЛЭП — {name}"
    if object_type == "pole":
        p = data.get("pole") or {}
        num = p.get("pole_number") or p.get("mrid") or "опора"
        line = (data.get("power_line") or {}).get("name")
        if line:
            return f"Технический паспорт опоры №{num} ({line})"
        return f"Технический паспорт опоры — №{num}"
    if object_type == "substation":
        ss = data.get("substation") or {}
        name = ss.get("name") or ss.get("mrid") or "ПС"
        return f"Технический паспорт подстанции — {name}"
    return "Технический паспорт"


def _resolve_object_ids(object_type: str, data: Dict[str, Any]) -> Tuple[str, Optional[int]]:
    if object_type == "power_line":
        pl = data.get("power_line") or {}
        return str(pl.get("mrid")), pl.get("id")
    if object_type == "pole":
        p = data.get("pole") or {}
        return str(p.get("mrid")), p.get("id")
    if object_type == "substation":
        ss = data.get("substation") or {}
        return str(ss.get("mrid")), ss.get("id")
    return "", None


@router.get("", response_model=TechPassportListResponse)
async def list_tech_passports(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
    _user: User = Depends(get_current_active_user),
):
    count_q = await db.execute(select(func.count()).select_from(TechPassport))
    total = int(count_q.scalar() or 0)
    stmt = (
        select(TechPassport)
        .order_by(TechPassport.created_at.desc())
        .offset(skip)
        .limit(limit)
    )
    rows = (await db.execute(stmt)).scalars().all()
    items = [TechPassportListItem.model_validate(r) for r in rows]
    return TechPassportListResponse(items=items, total=total)


@router.post("", response_model=TechPassportDetail, status_code=status.HTTP_201_CREATED)
async def create_tech_passport(
    body: TechPassportCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_user_can_export),
):
    snap = await build_snapshot_for_object(
        db,
        body.object_type,
        object_id=body.object_id,
        object_mrid=(body.object_mrid.strip() if body.object_mrid else None),
    )
    if not snap:
        raise HTTPException(status_code=404, detail="Объект не найден или тип не поддерживается")

    object_mrid, object_id = _resolve_object_ids(body.object_type, snap)
    if not object_mrid:
        raise HTTPException(status_code=500, detail="Не удалось определить mRID объекта")

    formed_at = datetime.now(timezone.utc).isoformat()
    envelope: Dict[str, Any] = {
        "schema_version": 1,
        "formed_at": formed_at,
        "object_type": body.object_type,
        "stp_reference": body.stp_reference,
        "data": snap,
    }

    title = (body.title or "").strip() or _default_title(body.object_type, snap)

    row = TechPassport(
        title=title,
        object_type=body.object_type,
        object_mrid=object_mrid,
        object_id=object_id,
        snapshot_json=envelope,
        manual_sections=body.manual_sections,
        stp_reference=body.stp_reference,
        created_by=current_user.id,
    )
    db.add(row)
    await db.commit()
    await db.refresh(row)
    return TechPassportDetail.model_validate(row)


@router.get("/{passport_id}", response_model=TechPassportDetail)
async def get_tech_passport(
    passport_id: int,
    db: AsyncSession = Depends(get_db),
    _user: User = Depends(get_current_active_user),
):
    row = await db.get(TechPassport, passport_id)
    if not row:
        raise HTTPException(status_code=404, detail="Паспорт не найден")
    return TechPassportDetail.model_validate(row)


@router.delete("/{passport_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_tech_passport(
    passport_id: int,
    db: AsyncSession = Depends(get_db),
    _user: User = Depends(require_user_can_export),
):
    row = await db.get(TechPassport, passport_id)
    if not row:
        raise HTTPException(status_code=404, detail="Паспорт не найден")
    await db.delete(row)
    await db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/{passport_id}/export")
async def export_tech_passport(
    passport_id: int,
    export_format: str = Query("pdf", alias="format", description="pdf, docx или xlsx"),
    db: AsyncSession = Depends(get_db),
    _user: User = Depends(get_current_active_user),
):
    row = await db.get(TechPassport, passport_id)
    if not row:
        raise HTTPException(status_code=404, detail="Паспорт не найден")

    env = row.snapshot_json
    if not isinstance(env, dict):
        raise HTTPException(status_code=500, detail="Некорректный снимок паспорта")

    try:
        content, media_type, suffix = export_passport_file(
            env,
            row.title,
            export_format,
            manual_sections=row.manual_sections if isinstance(row.manual_sections, dict) else None,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    except RuntimeError as e:
        raise HTTPException(
            status_code=500,
            detail=str(e) or "Сбой формирования файла (проверьте зависимости: pip install reportlab python-docx fpdf2)",
        ) from e
    except Exception as e:
        logging.getLogger(__name__).exception("export_tech_passport failed: passport_id=%s format=%s", passport_id, export_format)
        raise HTTPException(status_code=500, detail=str(e) or "Сбой формирования файла") from e

    safe = f"passport_{row.id}_{suffix}"
    return StreamingResponse(
        BytesIO(content),
        media_type=media_type,
        headers={"Content-Disposition": f'attachment; filename="{safe}"'},
    )
