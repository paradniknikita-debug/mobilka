"""Присутствие пользователей в системе (Redis + резерв в памяти процесса)."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional, TypedDict

from app.core.config import settings
from app.core.redis_client import get_redis_client

_PRESENCE_KEY = "user:presence:{user_id}"
# Если Redis недоступен — последняя активность в памяти воркера (для dev/админки).
_memory_last_seen: Dict[int, str] = {}


class UserPresenceInfo(TypedDict):
    is_online: bool
    last_seen_at: Optional[datetime]


def _parse_seen(raw: str) -> Optional[datetime]:
    try:
        seen = datetime.fromisoformat(str(raw).replace("Z", "+00:00"))
        if seen.tzinfo is None:
            seen = seen.replace(tzinfo=timezone.utc)
        return seen
    except (TypeError, ValueError):
        return None


def _is_online_from_seen(seen: Optional[datetime]) -> bool:
    if seen is None:
        return False
    ttl = timedelta(seconds=int(settings.USER_PRESENCE_TTL_SECONDS))
    return datetime.now(timezone.utc) - seen.astimezone(timezone.utc) <= ttl


async def touch_user_presence(user_id: int) -> None:
    """Отметить активность пользователя (любой авторизованный запрос или вход)."""
    if user_id is None:
        return
    now = datetime.now(timezone.utc).isoformat()
    _memory_last_seen[int(user_id)] = now
    client = get_redis_client()
    if not client:
        return
    key = _PRESENCE_KEY.format(user_id=int(user_id))
    try:
        await client.setex(key, settings.USER_PRESENCE_TTL_SECONDS, now)
    except Exception:
        pass


async def get_users_presence(user_ids: List[int]) -> Dict[int, UserPresenceInfo]:
    """Статус онлайн и время последней активности для списка id."""
    if not user_ids:
        return {}
    client = get_redis_client()
    empty: UserPresenceInfo = {"is_online": False, "last_seen_at": None}
    redis_values: Dict[int, Optional[str]] = {}
    client = get_redis_client()
    if client:
        keys = [_PRESENCE_KEY.format(user_id=int(uid)) for uid in user_ids]
        try:
            raw_list = await client.mget(keys)
            for uid, raw in zip(user_ids, raw_list or []):
                redis_values[int(uid)] = raw
        except Exception:
            pass

    out: Dict[int, UserPresenceInfo] = {}
    for uid in user_ids:
        raw = redis_values.get(int(uid)) or _memory_last_seen.get(int(uid))
        if not raw:
            out[int(uid)] = empty
            continue
        seen = _parse_seen(str(raw))
        out[int(uid)] = {
            "is_online": _is_online_from_seen(seen),
            "last_seen_at": seen,
        }
    return out


async def count_online_users() -> int:
    """Число ключей присутствия (приблизительно — активные за TTL)."""
    client = get_redis_client()
    if not client:
        return 0
    try:
        n = 0
        async for _ in client.scan_iter(match="user:presence:*", count=200):
            n += 1
        return n
    except Exception:
        return 0
