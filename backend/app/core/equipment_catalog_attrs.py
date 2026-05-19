"""Плоские колонки Excel ↔ attrs_json справочника оборудования."""
from __future__ import annotations

import json
from typing import Any, Dict, Optional

# Колонки шаблона (без JSON) — ключи как в карточке оборудования / Flutter.
FLAT_ATTR_COLUMNS = (
    "i_th",
    "ip_max",
    "t_th",
    "rated_current",
    "normal_open",
    "retained",
    "nominal_voltage_kv",
    "nominal_breaking_current_ka",
    "own_trip_time_sec",
    "emergency_current_a",
    "continuous_current_a",
    "nominal_discharge_current_a",
    "object_subtype",
    "psr_subtype",
    "arrester_type",
    "pole_count",
    "tm_code",
)


def attrs_from_flat_row(row: dict) -> Optional[str]:
    """Собрать attrs_json из отдельных колонок импорта."""
    data: Dict[str, Any] = {}
    raw_json = row.get("attrs_json")
    if raw_json is not None and str(raw_json).strip() not in ("", "nan", "None"):
        try:
            parsed = json.loads(str(raw_json))
            if isinstance(parsed, dict):
                data.update(parsed)
        except json.JSONDecodeError:
            pass
    for key in FLAT_ATTR_COLUMNS:
        val = row.get(key)
        if val is None or (isinstance(val, float) and str(val) == "nan"):
            continue
        s = str(val).strip()
        if s == "":
            continue
        if key in ("normal_open", "retained"):
            data[key] = s.lower() in ("1", "true", "yes", "да", "y")
        elif key == "pole_count":
            try:
                data[key] = int(float(s))
            except ValueError:
                pass
        else:
            try:
                if "." in s or "e" in s.lower():
                    data[key] = float(s.replace(",", "."))
                else:
                    data[key] = int(s)
            except ValueError:
                data[key] = s
    if not data:
        return None
    return json.dumps(data, ensure_ascii=False)


def flat_from_attrs_json(attrs_json: Optional[str]) -> Dict[str, Any]:
    if not attrs_json:
        return {}
    try:
        data = json.loads(attrs_json)
    except json.JSONDecodeError:
        return {}
    if not isinstance(data, dict):
        return {}
    return {k: data[k] for k in FLAT_ATTR_COLUMNS if k in data and data[k] is not None}
