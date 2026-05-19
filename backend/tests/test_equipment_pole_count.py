"""poleCount / terminal_count для оборудования в CIM."""
from app.core.cim.equipment_type_mapping import effective_equipment_pole_count


def test_disconnector_defaults_to_two_poles():
    assert effective_equipment_pole_count("разъединитель", None) == 2
    assert effective_equipment_pole_count("disconnector", 1) == 2


def test_arrester_single_pole():
    assert effective_equipment_pole_count("разрядник", None) == 1
