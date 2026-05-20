"""Человекочитаемые заголовки паспортов и имена файлов выгрузки."""

from __future__ import annotations

import re
from datetime import datetime, timezone
from typing import Any, Dict, Optional, Tuple

try:
    from zoneinfo import ZoneInfo
except ImportError:  # pragma: no cover
    ZoneInfo = None  # type: ignore[misc, assignment]

_FORBIDDEN_FN = re.compile(r'[<>:"/\\|?*\x00-\x1f]+')


def _format_kv(v: Any) -> str:
    if v is None or v == "":
        return ""
    try:
        fv = float(v)
        if fv == int(fv):
            return f"{int(fv)} кВ"
        return f"{fv:g} кВ"
    except (TypeError, ValueError):
        return ""


def default_passport_title(object_type: str, data: Dict[str, Any]) -> str:
    """Заголовок паспорта для списка, PDF и имени файла."""
    ot = (object_type or "").strip().lower()
    if ot == "power_line":
        pl = data.get("power_line") or {}
        name = (pl.get("name") or "без имени").strip()
        u = _format_kv(pl.get("voltage_level_kv"))
        if u:
            return f"Паспорт ЛЭП {u} — {name}"
        return f"Паспорт ЛЭП — {name}"
    if ot == "pole":
        p = data.get("pole") or {}
        num = p.get("pole_number") or "?"
        line = data.get("power_line") or {}
        line_name = (line.get("name") or "").strip()
        u = _format_kv(line.get("voltage_level_kv"))
        if line_name and u:
            return f"Паспорт опоры №{num} — {line_name} ({u})"
        if line_name:
            return f"Паспорт опоры №{num} — {line_name}"
        return f"Паспорт опоры №{num}"
    if ot == "substation":
        ss = data.get("substation") or {}
        name = (ss.get("name") or "без имени").strip()
        u = _format_kv(ss.get("voltage_level_kv"))
        if u:
            return f"Паспорт ПС {u} — {name}"
        return f"Паспорт подстанции — {name}"
    return "Технический паспорт"


def _date_slug(formed_at: Any) -> str:
    if formed_at is None or formed_at == "":
        return ""
    try:
        if isinstance(formed_at, datetime):
            dt = formed_at
        else:
            dt = datetime.fromisoformat(str(formed_at).strip().replace("Z", "+00:00"))
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        if ZoneInfo is not None:
            dt = dt.astimezone(ZoneInfo("Europe/Moscow"))
        return dt.strftime("%Y-%m-%d")
    except (TypeError, ValueError):
        return ""


def passport_export_filename(
    title: str,
    passport_id: int,
    ext: str,
    *,
    formed_at: Any = None,
) -> Tuple[str, str]:
    """
    Имя файла выгрузки: кириллица + дата.
    Возвращает (utf8_имя, ascii_запасное).
    """
    ext_clean = (ext or "pdf").lstrip(".").lower()
    core = (title or "Паспорт").strip()
    core = _FORBIDDEN_FN.sub("_", core)
    core = core.replace("—", "-").replace("«", "").replace("»", "")
    core = re.sub(r"\s+", " ", core)
    core = core.replace(" ", "_")
    core = re.sub(r"_+", "_", core).strip("._-")[:70] or f"Паспорт_{passport_id}"

    date = _date_slug(formed_at)
    if date:
        utf8_name = f"{core}_{date}.{ext_clean}"
    else:
        utf8_name = f"{core}_{passport_id}.{ext_clean}"

    ascii_name = re.sub(r"[^a-zA-Z0-9._-]+", "_", utf8_name)
    ascii_name = re.sub(r"_+", "_", ascii_name).strip("._-") or f"passport_{passport_id}.{ext_clean}"
    return utf8_name, ascii_name
