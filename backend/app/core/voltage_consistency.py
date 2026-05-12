"""Согласованность напряжений: ЛЭП, опора, марка каталога, сегмент."""

from __future__ import annotations

from typing import Optional

from fastapi import HTTPException, status

from app.core.equipment_nominal_voltage import equipment_inherits_line_nominal_voltage
from app.models.equipment_catalog import EquipmentCatalogItem


def voltage_tier(kv: float) -> int:
    """
    Грубые «классы» для запрета смешения (напр. 110 кВ с 0,4 или 35 кВ).
    Внутри класса допускается небольшой разброс (10 / 10,5 кВ).
    """
    if kv <= 1.2:
        return 0
    if kv <= 15:
        return 1
    if kv <= 45:
        return 2
    if kv <= 200:
        return 3
    return 4


def voltages_compatible(line_kv: Optional[float], other_kv: Optional[float]) -> bool:
    """Совместимы ли два номинала относительно одной ЛЭП."""
    if line_kv is None or other_kv is None:
        return True
    try:
        a = float(line_kv)
        b = float(other_kv)
    except (TypeError, ValueError):
        return True
    if voltage_tier(a) != voltage_tier(b):
        return False
    maxv = max(abs(a), abs(b), 1.0)
    if abs(a - b) <= 0.2 * maxv:
        return True
    return round(a) == round(b)


def raise_if_voltages_incompatible(
    line_kv: Optional[float],
    other_kv: Optional[float],
    *,
    subject: str,
) -> None:
    if not voltages_compatible(line_kv, other_kv):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                f"Несовместимость напряжения с ЛЭП ({line_kv} кВ): {subject} ({other_kv} кВ). "
                "Проверьте класс напряжения (например, для линии 110 кВ нельзя указать 0,4 или 35 кВ)."
            ),
        )


def validate_catalog_item_for_line(
    line_kv: Optional[float],
    catalog: Optional[EquipmentCatalogItem],
) -> None:
    if catalog is None or line_kv is None:
        return
    cv = getattr(catalog, "voltage_kv", None)
    if cv is None:
        return
    try:
        cvf = float(cv)
    except (TypeError, ValueError):
        return
    raise_if_voltages_incompatible(line_kv, cvf, subject=f"марка каталога «{catalog.brand} {catalog.model}»")


def validate_equipment_nominal_for_line(
    line_kv: Optional[float],
    equipment_type: Optional[str],
    nominal_voltage_kv: Optional[float],
) -> None:
    """Для типов, не наследующих U от линии, проверяем явный номинал."""
    if line_kv is None or nominal_voltage_kv is None:
        return
    if equipment_inherits_line_nominal_voltage(equipment_type):
        return
    raise_if_voltages_incompatible(line_kv, nominal_voltage_kv, subject="номинальное напряжение оборудования")


def validate_pole_rated_voltage_for_line(line_kv: Optional[float], rated_voltage: Optional[float]) -> None:
    if line_kv is None or rated_voltage is None:
        return
    raise_if_voltages_incompatible(line_kv, rated_voltage, subject="номинальное напряжение опоры (rated_voltage)")


def validate_segment_voltage_for_line(line_kv: Optional[float], segment_voltage_kv: Optional[float]) -> None:
    if line_kv is None or segment_voltage_kv is None:
        return
    raise_if_voltages_incompatible(line_kv, segment_voltage_kv, subject="напряжение сегмента ACLineSegment")
