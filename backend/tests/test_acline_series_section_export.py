"""Экспорт rf:ACLineSeriesSection — электрические параметры в namespace rf."""
from app.core.cim.cim_objects import LineSectionCIMObject


def test_series_section_exports_rf_electrical_tags():
    obj = LineSectionCIMObject(
        mrid="sec-1",
        name="Секция 1",
        r=1.2,
        x=3.4,
        g=5.6e-6,
        r0=1.2,
        x0=3.4,
        g0=0.0,
        total_length=0.5,
    )
    d = obj.to_cim_dict()
    assert d["rf:r"] == 1.2
    assert d["rf:x"] == 3.4
    assert d["rf:g"] == 5.6e-6
    assert d["rf:r0"] == 1.2
    assert d["rf:x0"] == 3.4
    assert d["rf:g0"] == 0.0
    assert d["rf:length"] == 0.5
