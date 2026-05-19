"""Метрики нагрузки (HTTP и записи в БД) по минутным интервалам в Redis."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional

from app.core.config import settings
from app.core.redis_client import get_redis_client

_PREFIX_HTTP = "metrics:http:"
_PREFIX_DB = "metrics:db_write:"
_TTL = 86400  # сутки истории в Redis


def _minute_key(prefix: str, dt: Optional[datetime] = None) -> str:
    t = dt or datetime.now(timezone.utc)
    bucket = t.strftime("%Y%m%d%H%M")
    return f"{prefix}{bucket}"


async def _incr_bucket(prefix: str, delta: int = 1) -> None:
    client = get_redis_client()
    if not client:
        return
    key = _minute_key(prefix)
    try:
        pipe = client.pipeline()
        pipe.incrby(key, delta)
        pipe.expire(key, _TTL)
        await pipe.execute()
    except Exception:
        pass


async def record_http_request() -> None:
    await _incr_bucket(_PREFIX_HTTP)


async def record_db_write() -> None:
    await _incr_bucket(_PREFIX_DB)


def _default_bucket_minutes(minutes: int) -> int:
    if minutes <= 60:
        return 1
    if minutes <= 180:
        return 5
    if minutes <= 720:
        return 15
    if minutes <= 1440:
        return 30
    return 60


def _aggregate_minute_points(
    points: List[Dict[str, Any]], bucket_minutes: int, max_points: int
) -> List[Dict[str, Any]]:
    if not points:
        return []
    bucket_minutes = max(1, int(bucket_minutes))
    if bucket_minutes <= 1:
        out = points
    else:
        buckets: List[Dict[str, Any]] = []
        chunk: List[Dict[str, Any]] = []
        for p in points:
            chunk.append(p)
            if len(chunk) >= bucket_minutes:
                buckets.append(
                    {
                        "ts": chunk[-1]["ts"],
                        "http_requests": sum(int(x["http_requests"]) for x in chunk),
                        "db_writes": sum(int(x["db_writes"]) for x in chunk),
                    }
                )
                chunk = []
        if chunk:
            buckets.append(
                {
                    "ts": chunk[-1]["ts"],
                    "http_requests": sum(int(x["http_requests"]) for x in chunk),
                    "db_writes": sum(int(x["db_writes"]) for x in chunk),
                }
            )
        out = buckets
    if len(out) <= max_points:
        return out
    step = max(1, len(out) // max_points)
    merged: List[Dict[str, Any]] = []
    buf: List[Dict[str, Any]] = []
    for p in out:
        buf.append(p)
        if len(buf) >= step:
            merged.append(
                {
                    "ts": buf[-1]["ts"],
                    "http_requests": sum(int(x["http_requests"]) for x in buf),
                    "db_writes": sum(int(x["db_writes"]) for x in buf),
                }
            )
            buf = []
    if buf:
        merged.append(
            {
                "ts": buf[-1]["ts"],
                "http_requests": sum(int(x["http_requests"]) for x in buf),
                "db_writes": sum(int(x["db_writes"]) for x in buf),
            }
        )
    return merged[:max_points]


async def get_load_timeseries(
    minutes: int = 60,
    bucket_minutes: Optional[int] = None,
    max_points: int = 96,
) -> Dict[str, Any]:
    """
    Нагрузка за последние N минут (UTC), с агрегацией по bucket_minutes для длинных периодов.
    points: [{ts, http_requests, db_writes}, ...]
    """
    minutes = max(5, min(int(minutes), 7 * 24 * 60))
    bucket = int(bucket_minutes) if bucket_minutes else _default_bucket_minutes(minutes)
    bucket = max(1, bucket)
    max_points = max(12, min(int(max_points), 240))
    now = datetime.now(timezone.utc).replace(second=0, microsecond=0)
    start = now - timedelta(minutes=minutes - 1)

    http_keys: List[str] = []
    db_keys: List[str] = []
    labels: List[str] = []
    for i in range(minutes):
        t = start + timedelta(minutes=i)
        labels.append(t.isoformat())
        http_keys.append(_minute_key(_PREFIX_HTTP, t))
        db_keys.append(_minute_key(_PREFIX_DB, t))

    client = get_redis_client()
    http_vals: List[int] = [0] * minutes
    db_vals: List[int] = [0] * minutes
    if client:
        try:
            raw_http = await client.mget(http_keys)
            raw_db = await client.mget(db_keys)
            for i, v in enumerate(raw_http or []):
                http_vals[i] = int(v or 0)
            for i, v in enumerate(raw_db or []):
                db_vals[i] = int(v or 0)
        except Exception:
            pass

    minute_points = [
        {
            "ts": labels[i],
            "http_requests": http_vals[i],
            "db_writes": db_vals[i],
        }
        for i in range(minutes)
    ]
    points = _aggregate_minute_points(minute_points, bucket, max_points)
    return {
        "minutes": minutes,
        "bucket_minutes": bucket,
        "from_ts": labels[0] if labels else None,
        "to_ts": labels[-1] if labels else None,
        "points": points,
        "totals": {
            "http_requests": sum(http_vals),
            "db_writes": sum(db_vals),
        },
        "redis_available": client is not None,
    }
