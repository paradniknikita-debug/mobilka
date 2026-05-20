"""
Структурирование снимка паспорта по разделам (как в типовых системах паспортизации ЛЭП/ПС).

Разделы: титул, общие сведения, технические параметры, состав оборудования, дефекты, дополнения.
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

try:
    from zoneinfo import ZoneInfo
except ImportError:  # pragma: no cover
    ZoneInfo = None  # type: ignore[misc, assignment]

_MONTHS_RU = (
    "января",
    "февраля",
    "марта",
    "апреля",
    "мая",
    "июня",
    "июля",
    "августа",
    "сентября",
    "октября",
    "ноября",
    "декабря",
)


def format_formed_at_human(formed_at: Any) -> str:
    """ISO/UTC → «20 мая 2026 г., 14:35 (МСК)»."""
    if formed_at is None or formed_at == "":
        return "—"
    try:
        if isinstance(formed_at, datetime):
            dt = formed_at
        else:
            s = str(formed_at).strip().replace("Z", "+00:00")
            dt = datetime.fromisoformat(s)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        if ZoneInfo is not None:
            local = dt.astimezone(ZoneInfo("Europe/Moscow"))
            tz_label = "МСК"
        else:
            local = dt.astimezone(timezone.utc)
            tz_label = "UTC"
        month = _MONTHS_RU[local.month - 1]
        return f"{local.day} {month} {local.year} г., {local.hour:02d}:{local.minute:02d} ({tz_label})"
    except (TypeError, ValueError):
        return str(formed_at)


def _format_coords(lat: Any, lon: Any) -> str:
    if lat is None or lon is None:
        return "—"
    try:
        la, lo = float(lat), float(lon)
        if la == 0.0 and lo == 0.0:
            return "—"
        return f"{la:.6f}, {lo:.6f}"
    except (TypeError, ValueError):
        return "—"


def _row(label: str, value: Any) -> Dict[str, Any]:
    if value is None or value == "":
        return {"label": label, "value": "—"}
    if isinstance(value, bool):
        return {"label": label, "value": "Да" if value else "Нет"}
    return {"label": label, "value": value}


def _section(section_id: str, title: str, rows: List[Dict[str, Any]], tables: Optional[List[Dict[str, Any]]] = None) -> Dict[str, Any]:
    return {
        "id": section_id,
        "title": title,
        "rows": rows,
        "tables": tables or [],
    }


def _equipment_defects_table(equipment: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    rows = []
    for eq in equipment:
        defect = (eq.get("defect") or "").strip()
        if not defect:
            continue
        rows.append(
            {
                "type": eq.get("equipment_type") or "—",
                "name": eq.get("name") or eq.get("nameplate") or "—",
                "defect": defect,
                "criticality": eq.get("criticality") or "—",
            }
        )
    if not rows:
        return None
    return {
        "title": "Дефекты оборудования",
        "columns": ["Тип", "Наименование", "Дефект", "Критичность"],
        "rows": rows,
    }


def _poles_summary_table(poles: List[Dict[str, Any]], limit: int = 200) -> Dict[str, Any]:
    rows = []
    for p in poles[:limit]:
        rows.append(
            {
                "number": p.get("pole_number") or "—",
                "type": p.get("pole_type") or "—",
                "construction": p.get("construction") or "—",
                "condition": p.get("condition") or "—",
                "coordinates": _format_coords(p.get("latitude"), p.get("longitude")),
                "equipment_count": len(p.get("equipment") or []),
            }
        )
    return {
        "title": "Опоры",
        "columns": ["№ опоры", "Тип", "Конструкция", "Состояние", "Координаты", "Ед. оборуд."],
        "rows": rows,
    }


def _substations_involved_table(items: List[Dict[str, Any]]) -> Dict[str, Any]:
    return {
        "title": "Подстанции, задействованные линией",
        "columns": ["Наименование", "mRID", "Роль в линии"],
        "rows": [
            {
                "name": it.get("name") or "—",
                "mrid": it.get("mrid") or "—",
                "role": it.get("role") or "—",
            }
            for it in items
        ],
    }


def _segments_table(segments: List[Dict[str, Any]]) -> Dict[str, Any]:
    rows = []
    for s in segments:
        rows.append(
            {
                "name": s.get("name") or "—",
                "length_km": s.get("length_km"),
                "voltage_kv": s.get("voltage_level_kv"),
                "conductor": s.get("conductor_type") or "—",
                "tap": "Да" if s.get("is_tap") else "Нет",
            }
        )
    return {
        "title": "Участки линии (ACLineSegment)",
        "columns": ["Наименование", "Длина, км", "U, кВ", "Марка", "Отпайка"],
        "rows": rows,
    }


def build_passport_sections(
    envelope: Dict[str, Any],
    manual_sections: Optional[Dict[str, Any]] = None,
) -> List[Dict[str, Any]]:
    """Преобразует snapshot_json + ручные дополнения в разделы для UI/печати."""
    data = envelope.get("data") if isinstance(envelope.get("data"), dict) else envelope
    object_type = (envelope.get("object_type") or "").strip().lower()
    formed_at = envelope.get("formed_at")
    stp = envelope.get("stp_reference")

    sections: List[Dict[str, Any]] = []

    title_rows = [
        _row("Дата формирования", format_formed_at_human(formed_at)),
        _row("Ссылка на СТП", stp),
        _row("Тип объекта", object_type),
    ]
    sections.append(_section("title", "Титульный лист", title_rows))

    if object_type == "power_line":
        pl = data.get("power_line") or {}
        totals = data.get("totals") or {}
        sections.append(
            _section(
                "general",
                "Общие сведения",
                [
                    _row("Наименование", pl.get("name")),
                    _row("mRID", pl.get("mrid")),
                    _row("Диспетчерское наименование", pl.get("dispatcher_name")),
                    _row("Регион", pl.get("region_name_resolved") or pl.get("region_name")),
                    _row("Филиал", pl.get("branch_name")),
                    _row("Балансовая принадлежность", pl.get("balance_ownership")),
                    _row("Статус", pl.get("status")),
                    _row("ПС начала", (pl.get("substation_start") or {}).get("name")),
                    _row("ПС конца", (pl.get("substation_end") or {}).get("name")),
                ],
            )
        )
        sections.append(
            _section(
                "technical",
                "Технические параметры",
                [
                    _row("Напряжение, кВ", pl.get("voltage_level_kv")),
                    _row("Протяжённость, км", pl.get("length_km")),
                    _row("Количество опор", totals.get("poles_count")),
                    _row("Количество участков", totals.get("segments_count")),
                ],
            )
        )
        involved_substations = data.get("involved_substations") or []
        if involved_substations:
            sections.append(
                _section(
                    "substations",
                    "Подстанции линии",
                    [],
                    [_substations_involved_table(involved_substations)],
                )
            )
        segments = data.get("acline_segments") or []
        if segments:
            sections.append(_section("segments", "Участки линии", [], [_segments_table(segments)]))
        poles = data.get("poles") or []
        if poles:
            pole_tables = [_poles_summary_table(poles)]
            all_eq: List[Dict[str, Any]] = []
            for p in poles:
                for eq in p.get("equipment") or []:
                    row = dict(eq)
                    row["pole_number"] = p.get("pole_number")
                    all_eq.append(row)
            if all_eq:
                pole_tables.append(
                    {
                        "title": "Реестр оборудования на опорах",
                        "columns": [
                            "№ опоры",
                            "Тип",
                            "Наименование",
                            "Марка",
                            "Состояние",
                            "Дефект",
                        ],
                        "rows": [
                            {
                                "number": eq.get("pole_number") or "—",
                                "type": eq.get("equipment_type") or "—",
                                "name": eq.get("name") or "—",
                                "mark": eq.get("nameplate") or "—",
                                "condition": eq.get("condition") or "—",
                                "defect": eq.get("defect") or "—",
                            }
                            for eq in all_eq[:300]
                        ],
                    }
                )
            defect_tbl = _equipment_defects_table(all_eq)
            if defect_tbl:
                pole_tables.append(defect_tbl)
            sections.append(_section("poles", "Опоры и оборудование", [], pole_tables))

    elif object_type == "pole":
        pole = data.get("pole") or {}
        line = data.get("power_line") or {}
        sections.append(
            _section(
                "general",
                "Общие сведения об опоре",
                [
                    _row("№ опоры", pole.get("pole_number")),
                    _row("mRID", pole.get("mrid")),
                    _row("Порядковый №", pole.get("sequence_number")),
                    _row("Тип опоры", pole.get("pole_type")),
                    _row("Конструкция", pole.get("construction")),
                    _row("Материал", pole.get("material")),
                    _row("Высота, м", pole.get("height")),
                    _row("Год установки", pole.get("year_installed")),
                    _row("Состояние", pole.get("condition")),
                    _row("Отпаечная", pole.get("is_tap_pole")),
                    _row("Координаты", f"{pole.get('latitude')}, {pole.get('longitude')}"),
                ],
            )
        )
        if line:
            sections.append(
                _section(
                    "line",
                    "Линия электропередачи",
                    [
                        _row("Наименование ЛЭП", line.get("name")),
                        _row("Напряжение, кВ", line.get("voltage_level_kv")),
                        _row("Длина линии, км", line.get("length_km")),
                    ],
                )
            )
        eq = pole.get("equipment") or []
        eq_rows = [
            _row("Дефект конструкции", pole.get("structural_defect")),
            _row("Критичность дефекта", pole.get("structural_defect_criticality")),
        ]
        tables = []
        if eq:
            tables.append(
                {
                    "title": "Оборудование на опоре",
                    "columns": ["Тип", "Наименование", "Марка", "Состояние", "Дефект"],
                    "rows": [
                        {
                            "type": e.get("equipment_type"),
                            "name": e.get("name"),
                            "mark": e.get("nameplate"),
                            "condition": e.get("condition"),
                            "defect": e.get("defect") or "—",
                        }
                        for e in eq
                    ],
                }
            )
        defect_tbl = _equipment_defects_table(eq)
        if defect_tbl:
            tables.append(defect_tbl)
        sections.append(_section("equipment", "Оборудование", eq_rows, tables))

    elif object_type == "substation":
        ss = data.get("substation") or {}
        sections.append(
            _section(
                "general",
                "Общие сведения о подстанции",
                [
                    _row("Наименование", ss.get("name")),
                    _row("mRID", ss.get("mrid")),
                    _row("Диспетчерское наименование", ss.get("dispatcher_name")),
                    _row("Напряжение, кВ", ss.get("voltage_level_kv")),
                    _row("Адрес", ss.get("address")),
                    _row("Регион", ss.get("region_name")),
                    _row("Активна", ss.get("is_active")),
                    _row("Координаты", f"{ss.get('latitude')}, {ss.get('longitude')}"),
                ],
            )
        )
        vl_tables = []
        for vl in ss.get("voltage_levels") or []:
            for bay in vl.get("bays") or []:
                vl_tables.append(
                    {
                        "title": f"РУ {vl.get('name') or vl.get('code')} — {bay.get('name') or bay.get('bay_number')}",
                        "columns": ["Класс", "Наименование", "Тип/модель"],
                        "rows": [
                            *[
                                {
                                    "class": "Оборудование",
                                    "name": ce.get("name"),
                                    "type": ce.get("equipment_type"),
                                }
                                for ce in (bay.get("conducting_equipment") or [])
                            ],
                            *[
                                {
                                    "class": "РЗА",
                                    "name": pe.get("name"),
                                    "type": pe.get("protection_type"),
                                }
                                for pe in (bay.get("protection_equipment") or [])
                            ],
                        ],
                    }
                )
        if vl_tables:
            sections.append(_section("switchgear", "Распределительные устройства", [], vl_tables))

    if manual_sections:
        manual_rows = []
        if isinstance(manual_sections, dict):
            for k, v in manual_sections.items():
                if k == "notes" and v:
                    manual_rows.append(_row("Примечания", v))
                elif v is not None and str(v).strip():
                    manual_rows.append(_row(str(k), v))
        if manual_rows:
            sections.append(_section("manual", "Дополнения (вручную)", manual_rows))

    return sections
