"""
Redis: dependency и хелперы для кэша и blacklist токенов.
Если Redis недоступен — все функции безопасно возвращают None / пропускают операцию.
"""
from typing import Optional
import json
from fastapi import Request

# Глобальный клиент (выставляется в main.lifespan)
_redis = None


def set_redis_client(client):
    """Установить глобальный клиент Redis (вызывается из lifespan)."""
    global _redis
    _redis = client


def get_redis_client():
    """Вернуть глобальный клиент Redis или None."""
    return _redis


async def get_redis(request: Request):
    """
    FastAPI dependency: возвращает Redis-клиент или None.
    Использование: redis_client: Optional[Redis] = Depends(get_redis)
    """
    return get_redis_client()


# --- Blacklist JWT (для logout) ---

BLACKLIST_PREFIX = "blacklist:"


async def add_token_to_blacklist(token_jti: str, ttl_seconds: int) -> bool:
    """Добавить токен (jti) в blacklist до истечения TTL. Возвращает True при успехе."""
    client = get_redis_client()
    if not client:
        return False
    try:
        await client.setex(f"{BLACKLIST_PREFIX}{token_jti}", ttl_seconds, "1")
        return True
    except Exception:
        return False


async def is_token_blacklisted(token_jti: str) -> bool:
    """Проверить, в blacklist ли токен."""
    client = get_redis_client()
    if not client:
        return False
    try:
        val = await client.get(f"{BLACKLIST_PREFIX}{token_jti}")
        return val is not None
    except Exception:
        return False


# --- Кэш ответов (простой key-value с TTL) ---

CACHE_PREFIX = "cache:"
DEFAULT_CACHE_TTL = 300  # 5 минут


async def cache_get(key: str) -> Optional[str]:
    """Получить значение из кэша. Ключ будет с префиксом cache:."""
    client = get_redis_client()
    if not client:
        return None
    try:
        return await client.get(f"{CACHE_PREFIX}{key}")
    except Exception:
        return None


async def cache_set(key: str, value: str, ttl_seconds: int = DEFAULT_CACHE_TTL) -> bool:
    """Записать значение в кэш с TTL. Возвращает True при успехе."""
    client = get_redis_client()
    if not client:
        return False
    try:
        await client.setex(f"{CACHE_PREFIX}{key}", ttl_seconds, value)
        return True
    except Exception:
        return False


async def cache_delete(key: str) -> bool:
    """Удалить ключ из кэша (для инвалидации)."""
    client = get_redis_client()
    if not client:
        return False
    try:
        await client.delete(f"{CACHE_PREFIX}{key}")
        return True
    except Exception:
        return False


async def cache_get_json(key: str):
    """Получить из кэша JSON (десериализованный объект)."""
    raw = await cache_get(key)
    if raw is None:
        return None
    try:
        return json.loads(raw)
    except (TypeError, json.JSONDecodeError):
        return None


async def cache_set_json(key: str, value: object, ttl_seconds: int = DEFAULT_CACHE_TTL) -> bool:
    """Записать в кэш JSON. value будет сериализован через json.dumps."""
    try:
        raw = json.dumps(value, default=str)
        return await cache_set(key, raw, ttl_seconds)
    except (TypeError, ValueError):
        return False
