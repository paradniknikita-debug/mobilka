"""
Кэш ответов GeoJSON карты в Redis (JSON + TTL).
Инвалидация при изменении опор, ЛЭП, оборудования, подстанций, пролётов.
"""
from __future__ import annotations

import logging
from typing import Any, Awaitable, Callable, Dict, List, Optional

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.redis_client import cache_get_json, cache_set_json, get_redis_client

logger = logging.getLogger(__name__)

MAP_GEOJSON_LAYERS: List[str] = [
    "power-lines",
    "poles",
    "taps",
    "substations",
    "equipment",
    "spans",
]


def _cache_key(layer: str) -> str:
    return f"map:geojson:{layer}"


async def get_map_geojson_cached(
    layer: str,
    loader: Callable[[AsyncSession], Awaitable[Dict[str, Any]]],
    db: AsyncSession,
) -> Dict[str, Any]:
    """Вернуть GeoJSON слоя из Redis или пересчитать и положить в кэш."""
    if not settings.MAP_GEOJSON_CACHE_ENABLED:
        return await loader(db)

    key = _cache_key(layer)
    cached = await cache_get_json(key)
    if cached is not None:
        return cached

    data = await loader(db)
    ttl = settings.MAP_GEOJSON_CACHE_TTL_SECONDS
    ok = await cache_set_json(key, data, ttl_seconds=ttl)
    if ok:
        logger.debug("map geojson cache set: %s ttl=%ss", layer, ttl)
    return data


async def invalidate_map_geojson_cache(layers: Optional[List[str]] = None) -> None:
    """Сбросить кэш GeoJSON (все слои или перечисленные)."""
    client = get_redis_client()
    if not client:
        return
    targets = layers if layers is not None else MAP_GEOJSON_LAYERS
    prefix = "cache:"
    try:
        for layer in targets:
            await client.delete(f"{prefix}{_cache_key(layer)}")
    except Exception as e:
        logger.warning("map geojson cache invalidate failed: %s", e)
