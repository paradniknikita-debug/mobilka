"""Номинальное напряжение коммутационного оборудования = напряжение ЛЭП (опоры)."""
from __future__ import annotations

from typing import Optional, Set

# Типы, для которых номинальное напряжение задаётся классом напряжения линии, а не вручную.
_EQUIPMENT_TYPES_LINE_NOMINAL: Set[str] = frozenset(
    {
        "disconnector",
        "grounding_switch",
        "breaker",
        "recloser",
        "surge_arrester",
        "arrester",
        "разъединитель",
        "зн",
        "zn",
        "выключатель",
        "реклоузер",
        "разрядник",
    }
)


def equipment_inherits_line_nominal_voltage(equipment_type: Optional[str]) -> bool:
    if not equipment_type:
        return False
    t = str(equipment_type).strip().lower()
    return t in _EQUIPMENT_TYPES_LINE_NOMINAL


def nominal_kv_from_line_voltage(
    equipment_type: Optional[str],
    line_voltage_level: Optional[float],
    client_nominal_kv: Optional[float],
) -> Optional[float]:
    """
    Если у линии задано voltage_level и тип оборудования в списке — возвращаем его.
    Иначе — значение клиента (может быть None).
    """
    if line_voltage_level is None:
        return client_nominal_kv
    try:
        v = float(line_voltage_level)
    except (TypeError, ValueError):
        return client_nominal_kv
    if not equipment_inherits_line_nominal_voltage(equipment_type):
        return client_nominal_kv
    return v
