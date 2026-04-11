"""
Маппинг типов оборудования из БД в профильные CIM-классы выгрузки.
"""
from dataclasses import dataclass
from typing import Optional


@dataclass(frozen=True)
class EquipmentProfile:
    cim_class: str
    normalized_type: str
    terminal_count: int
    psr_type_name: str
    control_area_name: Optional[str] = None


def is_cim_exportable_equipment(equipment_type: Optional[str]) -> bool:
    """
    В CIM выгружаем только коммутационное/линейное оборудование, которое моделируем как ПСР.
    Не выгружаем: траверсы, грозозащиту/ОПН/разрядники, фундаменты и прочую конструкцию.
    """
    v = (equipment_type or "").strip().lower()
    if not v:
        return False
    excluded = (
        "траверс",
        "traverse",
        "crossarm",
        "разрядник",
        "грозозащит",
        "опн",
        "arrester",
        "surge",
        "lightning",
        "фундамент",
        "foundation",
    )
    if any(x in v for x in excluded):
        return False
    n = normalize_equipment_type(equipment_type)
    # «Прочее» без распознанного типа — не выгружаем (избегаем траверсов как ConductingEquipment).
    if n == "conducting_equipment":
        return False
    return True


def normalize_equipment_type(equipment_type: Optional[str]) -> str:
    value = (equipment_type or "").strip().lower()
    if "земл" in value or "зн" in value or "ground" in value:
        return "ground_disconnector"
    if "разъедин" in value or "disconnector" in value:
        return "disconnector"
    if "выключат" in value or "breaker" in value:
        return "breaker"
    if "реклозер" in value or "recloser" in value:
        return "recloser"
    if "секцион" in value:
        return "sectionalizer"
    if "предох" in value or "fuse" in value:
        return "fuse"
    return "conducting_equipment"


def map_equipment_type_to_cim_profile(equipment_type: Optional[str]) -> EquipmentProfile:
    normalized = normalize_equipment_type(equipment_type)
    if normalized == "ground_disconnector":
        return EquipmentProfile(
            cim_class="GroundDisconnector",
            normalized_type=normalized,
            terminal_count=1,
            psr_type_name="GroundDisconnector",
            control_area_name="LineControlArea",
        )
    if normalized == "disconnector":
        return EquipmentProfile(
            cim_class="Disconnector",
            normalized_type=normalized,
            terminal_count=2,
            psr_type_name="Disconnector",
            control_area_name="LineControlArea",
        )
    if normalized == "breaker":
        return EquipmentProfile(
            cim_class="Breaker",
            normalized_type=normalized,
            terminal_count=2,
            psr_type_name="Breaker",
            control_area_name="LineControlArea",
        )
    if normalized == "recloser":
        return EquipmentProfile(
            cim_class="Recloser",
            normalized_type=normalized,
            terminal_count=2,
            psr_type_name="Recloser",
            control_area_name="LineControlArea",
        )
    return EquipmentProfile(
        cim_class="ConductingEquipment",
        normalized_type=normalized,
        terminal_count=2,
        psr_type_name=(equipment_type or "ConductingEquipment").strip() or "ConductingEquipment",
        control_area_name="LineControlArea",
    )
