"""Справочник WireInfo и расчёт параметров по маркам ЛЭП."""
import pytest

from app.core.wire_info_catalog import (
    default_wire_params,
    normalize_conductor_marker,
    wire_info_defaults,
)
from app.core.wire_info_defaults_data import (
    load_catalog_marks_from_csv,
    resolve_wire_spec,
)
from app.core.wire_parameters import _weighted_per_km


def test_normalize_conductor_marker_variants():
    assert normalize_conductor_marker("AC-70") == "AC-70"
    assert normalize_conductor_marker("ac 70") == "AC-70"
    assert normalize_conductor_marker("AC70") == "AC-70"
    assert normalize_conductor_marker("АС 70/11") == "АС 70/11"
    assert normalize_conductor_marker("А 70") == "А 70"


def test_catalog_has_all_csv_marks():
    marks = load_catalog_marks_from_csv()
    assert len(marks) >= 80
    defaults = wire_info_defaults()
    missing = [m for m in marks if m not in defaults]
    assert not missing, f"no spec for: {missing[:5]}"


def test_default_wire_params_ac70():
    p = default_wire_params("AC70")
    assert p is not None
    assert p["r"] == pytest.approx(0.46, rel=0.05)
    assert p["section"] == pytest.approx(70)


def test_resolve_as_mark():
    p = resolve_wire_spec("АС 95/16")
    assert p is not None
    assert p["r"] == pytest.approx(0.35, rel=0.05)
    assert p["section"] == pytest.approx(95)


def test_resolve_sip():
    p = resolve_wire_spec("СИП-3 1х70")
    assert p is not None
    assert p["r"] > 0.5


def test_resolve_a_mark():
    p = resolve_wire_spec("А 70")
    assert p is not None
    assert p["r"] == pytest.approx(0.43, rel=0.05)


def test_weighted_per_km_skips_missing():
    class Sec:
        def __init__(self, r, length):
            self.r = r
            self.total_length = length

    assert _weighted_per_km([Sec(0.46, 1.0), Sec(None, 2.0)], "r") == pytest.approx(0.46)
    assert _weighted_per_km([Sec(None, 1.0)], "r") is None
