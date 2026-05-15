"""
Прокси растровых тайлов (OSM) с кэшем PNG в Redis.
Отдельное Redis-соединение с decode_responses=False — см. main.lifespan.
При отключённом кэше или недоступном Redis ответ всё равно отдаётся с апстрима.
"""
import httpx
from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import Response

from app.core.config import settings
from app.core.redis_client import get_redis_binary_client

TILE_KEY_PREFIX = "maptile:osm:"
OSM_MAX_ZOOM = 19

router = APIRouter()


async def _fetch_upstream(request: Request, upstream: str, headers: dict) -> httpx.Response:
    client = getattr(request.app.state, "osm_tile_http_client", None)
    if client is not None:
        return await client.get(upstream, headers=headers)
    async with httpx.AsyncClient(timeout=20.0, follow_redirects=True) as tmp:
        return await tmp.get(upstream, headers=headers)


def _valid_tile(z: int, x: int, y: int) -> bool:
    if z < 0 or z > OSM_MAX_ZOOM:
        return False
    n = 1 << z
    return 0 <= x < n and 0 <= y < n


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

    upstream = settings.OSM_TILE_UPSTREAM_TEMPLATE.format(z=z, x=x, y=y)
    headers = {"User-Agent": settings.OSM_TILE_USER_AGENT}

    resp = await _fetch_upstream(request, upstream, headers)

    if resp.status_code == 404:
        raise HTTPException(status_code=404, detail="Tile not found")
    if resp.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=f"Upstream returned {resp.status_code}",
        )

    body = resp.content
    if not body:
        raise HTTPException(status_code=502, detail="Empty tile body")

    ct = resp.headers.get("content-type", "image/png")
    if not ct.startswith("image/"):
        ct = "image/png"

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
