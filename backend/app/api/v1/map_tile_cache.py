"""
Прокси растровых тайлов (OSM) с кэшем PNG в Redis.
Отдельное Redis-сoединение с decode_responses=False — см. main.lifespan.
При недоступном апстриме пробуются запасные CDN; при полном сбое — HTTP 502 (клиент переключается на прямой источник).
"""
import logging
from typing import List, Optional

import httpx
from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import Response

from app.core.config import settings
from app.core.redis_client import get_redis_binary_client

logger = logging.getLogger(__name__)

TILE_KEY_PREFIX = "maptile:osm:"
OSM_MAX_ZOOM = 19

_DEFAULT_UPSTREAM_FALLBACKS = (
    "https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png",
    "https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}",
    "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
    "https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png",
)

router = APIRouter()


def _upstream_templates() -> List[str]:
    templates: List[str] = []
    primary = (settings.OSM_TILE_UPSTREAM_TEMPLATE or "").strip()
    if primary:
        templates.append(primary)
    extra = (settings.OSM_TILE_UPSTREAM_FALLBACKS or "").strip()
    if extra:
        templates.extend(part.strip() for part in extra.split(",") if part.strip())
    else:
        templates.extend(_DEFAULT_UPSTREAM_FALLBACKS)
    seen: set[str] = set()
    unique: List[str] = []
    for item in templates:
        if item not in seen:
            seen.add(item)
            unique.append(item)
    return unique


async def _fetch_upstream(request: Request, upstream: str, headers: dict) -> httpx.Response:
    client = getattr(request.app.state, "osm_tile_http_client", None)
    if client is not None:
        return await client.get(upstream, headers=headers)
    timeout = httpx.Timeout(
        connect=settings.OSM_TILE_CONNECT_TIMEOUT_SECONDS,
        read=settings.OSM_TILE_READ_TIMEOUT_SECONDS,
        write=10.0,
        pool=10.0,
    )
    async with httpx.AsyncClient(timeout=timeout, follow_redirects=True) as tmp:
        return await tmp.get(upstream, headers=headers)


def _valid_tile(z: int, x: int, y: int) -> bool:
    if z < 0 or z > OSM_MAX_ZOOM:
        return False
    n = 1 << z
    return 0 <= x < n and 0 <= y < n


async def _fetch_tile_from_upstreams(
    request: Request, z: int, x: int, y: int
) -> Optional[tuple[bytes, str]]:
    headers = {"User-Agent": settings.OSM_TILE_USER_AGENT}
    last_error: Optional[str] = None
    for template in _upstream_templates():
        url = template.format(z=z, x=x, y=y)
        try:
            resp = await _fetch_upstream(request, url, headers)
        except httpx.HTTPError as exc:
            last_error = f"{url}: {type(exc).__name__}"
            logger.warning("Tile upstream HTTP error: %s", last_error)
            continue
        if resp.status_code == 404:
            continue
        if resp.status_code != 200:
            last_error = f"{url}: HTTP {resp.status_code}"
            logger.warning("Tile upstream bad status: %s", last_error)
            continue
        body = resp.content
        if not body:
            last_error = f"{url}: empty body"
            continue
        ct = resp.headers.get("content-type", "image/png")
        if not ct.startswith("image/"):
            ct = "image/png"
        return body, ct
    if last_error:
        logger.error("All tile upstreams failed for z=%s x=%s y=%s (%s)", z, x, y, last_error)
    return None


@router.get("/tiles/{z}/{x}/{y}.png")
async def proxy_osm_tile(request: Request, z: int, x: int, y: int):
    if not _valid_tile(z, x, y):
        raise HTTPException(status_code=400, detail="Invalid tile coordinates")

    cache_control = "public, max-age=86400"
    r = get_redis_binary_client()
    key = f"{TILE_KEY_PREFIX}{z}:{x}:{y}"

    if settings.TILE_CACHE_ENABLED and r:
        try:
            cached = await r.get(key)
            if cached:
                return Response(
                    content=cached,
                    media_type="image/png",
                    headers={"Cache-Control": cache_control},
                )
        except Exception:
            pass

    fetched = await _fetch_tile_from_upstreams(request, z, x, y)
    if fetched is None:
        raise HTTPException(status_code=502, detail="Tile upstream unavailable")

    body, ct = fetched

    if settings.TILE_CACHE_ENABLED and r:
        try:
            await r.set(key, body, ex=settings.TILE_CACHE_REDIS_TTL_SECONDS)
        except Exception:
            pass

    return Response(
        content=body,
        media_type=ct,
        headers={"Cache-Control": cache_control},
    )
