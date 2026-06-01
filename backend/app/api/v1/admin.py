from __future__ import annotations

import asyncio
import time
from typing import Optional, Tuple
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status
from fastapi.responses import PlainTextResponse
from sqlalchemy import func, select, text, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.redis_client import get_redis_client
from app.core.app_metrics import get_load_timeseries
from app.core.user_presence import count_online_users, get_users_presence
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


def _admin_user_response(user: User, presence_map: dict) -> AdminUserResponse:
    info = presence_map.get(int(user.id), {})
    base = AdminUserResponse.model_validate(user)
    return base.model_copy(
        update={
            "password_plain": user.password_plain,
            "is_online": bool(info.get("is_online", False)),
            "last_seen_at": info.get("last_seen_at"),
        }
    )

_DOCKER_CONTAINERS: dict[str, str] = {
    "backend": "lepm_backend",
    "postgres": "lepm_postgres",
    "redis": "lepm_redis",
    "minio": "lepm_minio",
    "nginx": "lepm_nginx",
}

_docker_client_cache: Optional[Tuple[float, bool]] = None


def _docker_logs_allowed() -> bool:
    return settings.ENVIRONMENT == "development" or settings.ADMIN_DOCKER_LOGS_ENABLED


async def _docker_client_available() -> bool:
    """Проверка: docker CLI доступен и отвечает (нужен docker.sock на хосте)."""
    global _docker_client_cache
    if not _docker_logs_allowed():
        return False

    now = time.monotonic()
    if _docker_client_cache is not None and now - _docker_client_cache[0] < 30:
        return _docker_client_cache[1]

    ok = False
    try:
        proc = await asyncio.create_subprocess_exec(
            "docker",
            "info",
            "--format",
            "{{.ServerVersion}}",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL,
        )
        await asyncio.wait_for(proc.communicate(), timeout=4.0)
        ok = proc.returncode == 0
    except (FileNotFoundError, asyncio.TimeoutError, OSError):
        ok = False

    _docker_client_cache = (now, ok)
    return ok


def _development_guide_path() -> Path:
    # backend/app/api/v1/admin.py → корень репозитория
    return Path(__file__).resolve().parents[3].parent / "DEVELOPMENT_GUIDE.md"


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


@router.get("/infrastructure")
async def admin_infrastructure(
    request: Request,
    _: User = Depends(require_admin_user),
):
    """Ссылки на MinIO, Swagger, ReDoc и главную API для кнопок в панели администратора."""
    backend_base = (settings.ADMIN_BACKEND_PUBLIC_URL or "").strip().rstrip("/")
    if not backend_base:
        host = request.headers.get("x-forwarded-host") or request.url.netloc or "localhost:8000"
        scheme = request.headers.get("x-forwarded-proto") or request.url.scheme or "http"
        backend_base = f"{scheme}://{host}".rstrip("/")
        if ":8000" not in backend_base and "localhost" in host:
            backend_base = f"{scheme}://{host.split(':')[0]}:8000"

    minio_url = (settings.ADMIN_MINIO_CONSOLE_URL or "").strip().rstrip("/")
    if not minio_url:
        try:
            from urllib.parse import urlparse

            parsed = urlparse(backend_base)
            host = parsed.hostname or "localhost"
            scheme = parsed.scheme or "http"
            minio_url = f"{scheme}://{host}:9001"
        except Exception:
            minio_url = "http://localhost:9001"

    return {
        "minio_console_url": minio_url,
        "swagger_url": f"{backend_base}/docs",
        "redoc_url": f"{backend_base}/redoc",
        "api_home_url": f"{backend_base}/",
        "openapi_url": f"{backend_base}/openapi.json",
        "development_guide_available": _development_guide_path().is_file(),
        "docker_logs_available": await _docker_client_available(),
    }


@router.get("/development-guide")
async def admin_development_guide(_: User = Depends(require_admin_user)):
    path = _development_guide_path()
    if not path.is_file():
        raise HTTPException(status_code=404, detail="DEVELOPMENT_GUIDE.md не найден на сервере")
    return PlainTextResponse(
        path.read_text(encoding="utf-8"),
        media_type="text/plain; charset=utf-8",
    )


@router.get("/docker-logs/{service}")
async def admin_docker_logs(
    service: str,
    tail: int = Query(300, ge=50, le=3000),
    _: User = Depends(require_admin_user),
):
    """Хвост логов контейнера docker compose (только для администратора, нужен Docker CLI)."""
    if not _docker_logs_allowed():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Просмотр логов Docker отключён. Установите ADMIN_DOCKER_LOGS_ENABLED=true и смонтируйте docker.sock.",
        )
    if not await _docker_client_available():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Docker недоступен из контейнера backend. Смонтируйте /var/run/docker.sock и задайте DOCKER_GROUP_GID.",
        )
    container = _DOCKER_CONTAINERS.get(service.strip().lower())
    if not container:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Неизвестный сервис. Допустимо: {', '.join(sorted(_DOCKER_CONTAINERS))}",
        )
    try:
        proc = await asyncio.create_subprocess_exec(
            "docker",
            "logs",
            f"--tail={tail}",
            container,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
        )
        stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=20.0)
    except FileNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Docker CLI не найден. Запустите «docker compose logs -f <сервис>» на хосте.",
        ) from None
    except asyncio.TimeoutError:
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail="Превышено время ожидания вывода docker logs",
        ) from None

    text = (stdout or b"").decode("utf-8", errors="replace")
    if proc.returncode not in (0, None) and not text.strip():
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"docker logs завершился с кодом {proc.returncode}. Контейнер «{container}» запущен?",
        )
    return {
        "service": service,
        "container": container,
        "tail": tail,
        "log": text,
    }


@router.get("/stats")
async def admin_stats(
    _: User = Depends(require_admin_user),
    db: AsyncSession = Depends(get_db),
):
    redis_ok = False
    redis_ms: Optional[float] = None
    client = get_redis_client()
    if client:
        try:
            t0 = time.perf_counter()
            await client.ping()
            redis_ms = round((time.perf_counter() - t0) * 1000, 2)
            redis_ok = True
        except Exception:
            pass

    db_ms: Optional[float] = None
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
    sub_c = (await db.execute(select(func.count()).select_from(Substation))).scalar_one()
    tp_c = (await db.execute(select(func.count()).select_from(TechPassport))).scalar_one()
    ps_c = (await db.execute(select(func.count()).select_from(PatrolSession))).scalar_one()

    users_online = await count_online_users()

    return {
        "users": int(users_c),
        "users_active": int(users_active_c),
        "users_online": users_online,
        "power_lines": int(lines_c),
        "poles": int(poles_c),
        "substations": int(sub_c),
        "tech_passports": int(tp_c),
        "patrol_sessions": int(ps_c),
        "redis": "connected" if redis_ok else "disconnected",
        "redis_ping_ms": redis_ms,
        "database": "connected" if db_ms is not None else "error",
        "database_ping_ms": db_ms,
    }


@router.get("/metrics/load")
async def admin_load_metrics(
    minutes: int = Query(60, ge=5, le=7 * 24 * 60),
    bucket_minutes: Optional[int] = Query(None, ge=1, le=360),
    max_points: int = Query(96, ge=12, le=240),
    _: User = Depends(require_admin_user),
):
    """Нагрузка: HTTP-запросы к API и commit'ы в БД (Redis), с агрегацией для длинных периодов."""
    return await get_load_timeseries(minutes, bucket_minutes=bucket_minutes, max_points=max_points)


@router.get("/users", response_model=list[AdminUserResponse])
async def list_users(
    admin: User = Depends(require_admin_user),
    db: AsyncSession = Depends(get_db),
):
    from app.core.user_presence import touch_user_presence

    await touch_user_presence(admin.id)
    result = await db.execute(select(User).order_by(User.id))
    users = list(result.scalars().all())
    presence_map = await get_users_presence([int(u.id) for u in users])
    return [_admin_user_response(u, presence_map) for u in users]


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
    presence_map = await get_users_presence([db_user.id])
    return _admin_user_response(db_user, presence_map)


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
    presence_map = await get_users_presence([user.id])
    return _admin_user_response(user, presence_map)


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
