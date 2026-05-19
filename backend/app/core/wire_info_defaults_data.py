"""
Типовые удельные параметры (Ом/км, См/км) для марок из «Марки ЛЭП по номиналу.csv».
Значения ориентировочные (расчётная модель ЛЭП), по аналогии со справочниками АС/А.
"""
from __future__ import annotations

import re
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

# Алюминиевая стальная (АС / AC): активное R и реактивное X, См/км — емкостная B
# АС (ACSR): типовые r/x на 1 км (справочники ЛЭП, 50 Гц)
_AS_SECTION: Dict[int, Tuple[float, float, float]] = {
    16: (1.02, 0.37, 2.48e-6),
    25: (0.80, 0.36, 2.55e-6),
    35: (0.58, 0.35, 2.62e-6),
    40: (0.52, 0.35, 2.64e-6),
    50: (0.65, 0.34, 2.68e-6),
    63: (0.52, 0.34, 2.72e-6),
    70: (0.46, 0.35, 2.74e-6),
    95: (0.35, 0.34, 2.78e-6),
    120: (0.27, 0.33, 2.82e-6),
    150: (0.21, 0.32, 2.85e-6),
    185: (0.17, 0.32, 2.88e-6),
    240: (0.13, 0.31, 2.92e-6),
    300: (0.10, 0.31, 2.95e-6),
    330: (0.095, 0.30, 2.97e-6),
    400: (0.08, 0.30, 3.00e-6),
    500: (0.065, 0.29, 3.05e-6),
}

# Алюминиевый провод (А): несколько выше R
_A_SECTION: Dict[int, Tuple[float, float, float]] = {
    16: (1.91, 0.40, 2.45e-6),
    25: (1.20, 0.38, 2.52e-6),
    35: (0.84, 0.37, 2.58e-6),
    50: (0.60, 0.36, 2.62e-6),
    70: (0.43, 0.35, 2.66e-6),
    95: (0.32, 0.34, 2.70e-6),
    120: (0.25, 0.33, 2.74e-6),
    150: (0.20, 0.33, 2.78e-6),
    185: (0.164, 0.32, 2.82e-6),
    240: (0.125, 0.31, 2.86e-6),
}

# СИП (самонесущий изолированный): выше R, ниже B
_SIP_SECTION: Dict[int, Tuple[float, float, float]] = {
    35: (0.868, 0.08, 1.45e-6),
    50: (0.641, 0.078, 1.50e-6),
    70: (0.569, 0.077, 1.55e-6),
    95: (0.411, 0.076, 1.60e-6),
    120: (0.328, 0.075, 1.65e-6),
    150: (0.270, 0.074, 1.70e-6),
}

# Медный (М)
_CU_SECTION: Dict[int, Tuple[float, float, float]] = {
    50: (0.39, 0.36, 2.60e-6),
}

_NOMINAL_CURRENT_AS: Dict[int, float] = {
    16: 105,
    25: 135,
    35: 170,
    50: 215,
    70: 265,
    95: 325,
    120: 390,
    150: 450,
    185: 510,
    240: 610,
    300: 710,
    400: 860,
    500: 1000,
}

_CYR = str.maketrans({"А": "A", "а": "a", "С": "C", "с": "c", "И": "I", "и": "i"})


def _nearest_section(section: int, table: Dict[int, Tuple[float, float, float]]) -> Tuple[float, float, float]:
    if section in table:
        return table[section]
    keys = sorted(table.keys())
    if section <= keys[0]:
        return table[keys[0]]
    if section >= keys[-1]:
        return table[keys[-1]]
    lo, hi = keys[0], keys[-1]
    for k in keys:
        if k <= section:
            lo = k
        if k >= section:
            hi = k
            break
    if lo == hi:
        return table[lo]
    t = (section - lo) / (hi - lo)
    r0, x0, b0 = table[lo]
    r1, x1, b1 = table[hi]
    return (
        r0 + t * (r1 - r0),
        x0 + t * (x1 - x0),
        b0 + t * (b1 - b0),
    )


def _spec(
    name: str,
    section: float,
    r: float,
    x: float,
    b: float,
    material: str = "алюминий",
    g: float = 0.0,
    code: Optional[str] = None,
) -> Dict[str, Any]:
    sec = int(round(section))
    i_nom = _NOMINAL_CURRENT_AS.get(sec)
    return {
        "code": code or re.sub(r"[^A-Za-z0-9]", "", name)[:20],
        "material": material,
        "section": float(section),
        "r": r,
        "x": x,
        "b": b,
        "g": g,
        "nominal_current": i_nom,
    }


def _from_as_section(name: str, section: int) -> Dict[str, Any]:
    r, x, b = _nearest_section(section, _AS_SECTION)
    return _spec(name, section, r, x, b)


def _from_a_section(name: str, section: int) -> Dict[str, Any]:
    r, x, b = _nearest_section(section, _A_SECTION)
    return _spec(name, section, r, x, b)


def _from_sip_section(name: str, section: int) -> Dict[str, Any]:
    r, x, b = _nearest_section(section, _SIP_SECTION)
    return _spec(name, section, r, x, b, material="алюминий (СИП)")


def _extract_section_from_mark(mark: str) -> Optional[int]:
    s = mark.translate(_CYR).upper()
    m = re.search(r"AC-?(\d{2,3})\b", s)
    if m:
        return int(m.group(1))
    m = re.search(r"\bA\s*(\d{2,3})\b", s)
    if m:
        return int(m.group(1))
    m = re.search(r"AC\s*(\d{2,3})\s*/", s)
    if m:
        return int(m.group(1))
    m = re.search(r"SIP[^0-9]*1[XХ](\d{2,3})", s.replace("Х", "X"))
    if m:
        return int(m.group(1))
    m = re.search(r"(\d{2,3})\s*/\s*\d", s)
    if m:
        return int(m.group(1))
    m = re.search(r"(?:AN|AP|APV|APS|ASO|ASU|PS|AJ)\s*-?\s*(\d{2,3})\b", s)
    if m:
        return int(m.group(1))
    m = re.search(r"\bC-(\d{2,3})\b", s)
    if m:
        return int(m.group(1))
    m = re.search(r"\bM\s*(\d{2,3})\b", s)
    if m:
        return int(m.group(1))
  # последнее число в строке
    nums = re.findall(r"\d{2,3}", s)
    if nums:
        return int(nums[0])
    return None


def resolve_wire_spec(mark: str) -> Optional[Dict[str, Any]]:
    """
    Параметры WireInfo по марке (точное имя из справочника или AC-70 / АС 70/11).
    """
    name = " ".join((mark or "").strip().split())
    if not name:
        return None

  # Латинские AC-* (как в мобильном приложении)
    key = name.translate(_CYR).upper().replace(" ", "")
    m_ac = re.fullmatch(r"AC-?(\d{2,3})", key)
    if m_ac:
        sec = int(m_ac.group(1))
        return _from_as_section(f"AC-{sec}", sec)

    upper = name.upper()
    sec = _extract_section_from_mark(name)

    if upper.startswith("СИП") or "SIP" in key:
        if sec:
            return _from_sip_section(name, sec)
        return None

    if upper.startswith("А ") or re.match(r"^А\s+\d", name):
        if sec:
            return _from_a_section(name, sec)
        return None

    if upper.startswith("М ") or re.match(r"^М\s*\d", name):
        if sec and sec in _CU_SECTION:
            r, x, b = _CU_SECTION[sec]
            return _spec(name, sec, r, x, b, material="медь")
        return None

    if upper.startswith("ПС-") or upper.startswith("С-"):
        if sec:
            r, x, b = _nearest_section(sec, _A_SECTION)
            return _spec(name, sec, r * 1.05, x, b, material="сталемедный")
        return None

    # АС, АН, АП, АЖ, АСО, АСУ, АПС, АСИ, АСКП, АСКС и т.д. — по сечению алюминия
    if sec:
        return _from_as_section(name, sec)

    return None


def load_catalog_marks_from_csv() -> List[str]:
    """Уникальные марки из CSV в корне проекта."""
    root = Path(__file__).resolve().parents[3]
    for fname in ("Марки ЛЭП по номиналу.csv", "marks_lep_by_nominal.csv"):
        path = root / fname
        if not path.exists():
            continue
        import csv

        marks: List[str] = []
        seen: set[str] = set()
        with path.open("r", encoding="cp1251", newline="") as fp:
            reader = csv.reader(fp, delimiter=";")
            next(reader, None)
            for row in reader:
                if not row:
                    continue
                m = " ".join((row[0] or "").strip().split())
                if m and m not in seen:
                    seen.add(m)
                    marks.append(m)
        return sorted(marks, key=lambda x: x.lower())
    return []


def build_all_wire_defaults() -> Dict[str, Dict[str, Any]]:
    """Все марки из CSV + латинские псевдонимы AC-xx."""
    out: Dict[str, Dict[str, Any]] = {}
    for mark in load_catalog_marks_from_csv():
        spec = resolve_wire_spec(mark)
        if spec:
            out[mark] = spec
    for sec in (16, 25, 35, 50, 70, 95, 120, 150, 185, 240, 300, 400, 500):
        alias = f"AC-{sec}"
        if alias not in out:
            spec = resolve_wire_spec(alias)
            if spec:
                out[alias] = {**spec, "code": f"AC{sec}"}
    return out
