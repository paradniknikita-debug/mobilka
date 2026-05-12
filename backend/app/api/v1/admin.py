from __future__ import annotations

import time

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy import func, select, text, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.redis_client import get_redis_client
from app.core.roles import ROLE_ADMIN, require_admin_user, normalize_role, CANONICAL_ROLES
from app.core.security import get_password_hash
from app.database import get_db
from app.models.acline_segment import AClineSegment
from app.models.change_log import ChangeLog
from app.models.cim_line_structure import LineSection
from app.models.equipment_catalog import EquipmentCatalogItem
from app.models.patrol_session import PatrolSession
from app.models.power_line import Equipment, Pole, PowerLine, Span, Tap
from app.models.substation import ConductingEquipment, ProtectionEquipment, Substation
from app.models.tech_passport import TechPassport
from app.models.user import User
from app.schemas.admin_user import AdminUserResponse, AdminUserUpdate
from app.schemas.user import UserCreate

router = APIRouter()


async def _reassign_user_foreign_keys(db: AsyncSession, old_uid: int, new_uid: int) -> None:
    """Перенос ссылок created_by / user_id на другого пользователя перед удалением."""
    for model in (
        PowerLine,
        Pole,
        Span,
        Tap,
        Equipment,
        LineSection,
        AClineSegment,
        ConductingEquipment,
        ProtectionEquipment,
        TechPassport,
        EquipmentCatalogItem,
    ):
        await db.execute(update(model).where(model.created_by == old_uid).values(created_by=new_uid))
    await db.execute(update(PatrolSession).where(PatrolSession.user_id == old_uid).values(user_id=new_uid))
    await db.execute(update(ChangeLog).where(ChangeLog.user_id == old_uid).values(user_id=None))


@router.get("/stats")
async def admin_stats(
    _: User = Depends(require_admin_user),
    db: AsyncSession = Depends(get_db),
):
    redis_ok = False
    redis_ms: float | None = None
    client = get_redis_client()
    if client:
        try:
            t0 = time.perf_counter()
            await client.ping()
            redis_ms = round((time.perf_counter() - t0) * 1000, 2)
            redis_ok = True
        except Exception:
            pass

    db_ms: float | None = None
    try:
        t0 = time.perf_counter()
        await db.execute(text("SELECT 1"))
        db_ms = round((time.perf_counter() - t0) * 1000, 2)
    except Exception:
        db_ms = None

    users_c = (await db.execute(select(func.count()).select_from(User))).scalar_one()
    users_active_c = (
        await db.execute(select(func.count()).select_from(User).where(User.is_active == True))  # noqa: E712
    ).scalar_one()
    lines_c = (await db.execute(select(func.count()).select_from(PowerLine))).scalar_one()
    poles_c = (await db.execute(select(func.count()).select_from(Pole))).scalar_one()
    eq_c = (await db.execute(select(func.count()).select_from(Equipment))).scalar_one()
    sub_c = (await db.execute(select(func.count()).select_from(Substation))).scalar_one()
    tp_c = (await db.execute(select(func.count()).select_from(TechPassport))).scalar_one()
    cl_c = (await db.execute(select(func.count()).select_from(ChangeLog))).scalar_one()
    ps_c = (await db.execute(select(func.count()).select_from(PatrolSession))).scalar_one()
    seg_c = (await db.execute(select(func.count()).select_from(AClineSegment))).scalar_one()

    admins_c = (
        await db.execute(
            select(func.count()).select_from(User).where(User.is_active == True, User.role == ROLE_ADMIN)  # noqa: E712
        )
    ).scalar_one()

    return {
        "users": int(users_c),
        "users_active": int(users_active_c),
        "users_admins": int(admins_c),
        "power_lines": int(lines_c),
        "poles": int(poles_c),
        "equipment": int(eq_c),
        "substations": int(sub_c),
        "acline_segments": int(seg_c),
        "tech_passports": int(tp_c),
        "change_log_entries": int(cl_c),
        "patrol_sessions": int(ps_c),
        "redis": "connected" if redis_ok else "disconnected",
        "redis_ping_ms": redis_ms,
        "database": "connected" if db_ms is not None else "error",
        "database_ping_ms": db_ms,
    }


@router.get("/users", response_model=list[AdminUserResponse])
async def list_users(
    _: User = Depends(require_admin_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).order_by(User.id))
    return list(result.scalars().all())


@router.post("/users", response_model=AdminUserResponse, status_code=status.HTTP_201_CREATED)
async def admin_create_user(
    payload: UserCreate,
    _: User = Depends(require_admin_user),
    db: AsyncSession = Depends(get_db),
):
    existing_user = await db.execute(select(User).where(User.username == payload.username))
    if existing_user.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Username already registered")
    existing_email = await db.execute(select(User).where(User.email == payload.email))
    if existing_email.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Email already registered")

    role = normalize_role(payload.role)
    if role not in CANONICAL_ROLES:
        raise HTTPException(status_code=400, detail="Invalid role")

    db_user = User(
        username=payload.username,
        email=payload.email,
        full_name=payload.full_name,
        hashed_password=get_password_hash(payload.password),
        password_plain=payload.password,
        role=role,
        branch_id=payload.branch_id,
        is_active=True,
        is_superuser=False,
    )
    db.add(db_user)
    await db.commit()
    await db.refresh(db_user)
    return db_user


@router.patch("/users/{user_id}", response_model=AdminUserResponse)
async def admin_update_user(
    user_id: int,
    payload: AdminUserUpdate,
    admin: User = Depends(require_admin_user),
    db: AsyncSession = Depends(get_db),
):
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.id == admin.id and payload.is_active is False:
        raise HTTPException(status_code=400, detail="Нельзя деактивировать свою учётную запись")
    if user.id == admin.id and payload.role is not None and normalize_role(payload.role) != normalize_role(admin.role):
        raise HTTPException(status_code=400, detail="Нельзя сменить свою роль через эту форму")

    data = payload.model_dump(exclude_unset=True)
    if "email" in data and data["email"]:
        other = (
            await db.execute(select(User).where(User.email == str(data["email"]), User.id != user_id))
        ).scalar_one_or_none()
        if other:
            raise HTTPException(status_code=400, detail="Email already in use")
    if "password" in data and data["password"]:
        user.hashed_password = get_password_hash(data["password"])
        user.password_plain = data["password"]
        data.pop("password", None)
    for k, v in data.items():
        if k == "role" and v is not None:
            setattr(user, k, normalize_role(str(v)))
        elif v is not None:
            setattr(user, k, v)

    await db.commit()
    await db.refresh(user)
    return user


@router.delete("/users/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def admin_delete_user(
    user_id: int,
    admin: User = Depends(require_admin_user),
    db: AsyncSession = Depends(get_db),
):
    if user_id == admin.id:
        raise HTTPException(status_code=400, detail="Нельзя удалить свою учётную запись")

    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if normalize_role(user.role) == ROLE_ADMIN:
        admins = (
            await db.execute(
                select(func.count()).select_from(User).where(User.is_active == True, User.role == ROLE_ADMIN)  # noqa: E712
            )
        ).scalar_one()
        if int(admins) <= 1:
            raise HTTPException(status_code=400, detail="Нельзя удалить последнего администратора")

    await _reassign_user_foreign_keys(db, user_id, admin.id)
    try:
        await db.delete(user)
        await db.commit()
    except IntegrityError as e:
        await db.rollback()
        raise HTTPException(
            status_code=409,
            detail="Не удалось удалить пользователя: остались связи в базе. Обратитесь к разработчику или деактивируйте учётную запись.",
        ) from e
    return Response(status_code=status.HTTP_204_NO_CONTENT)
