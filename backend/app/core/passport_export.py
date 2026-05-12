"""Экспорт технического паспорта в PDF, DOCX, XLSX."""

from __future__ import annotations

import json
import re
from io import BytesIO
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple
from xml.sax.saxutils import escape

from openpyxl import Workbook
from openpyxl.styles import Font

try:
    from docx import Document
    from docx.shared import Pt
except ImportError:  # pragma: no cover
    Document = None  # type: ignore[misc, assignment]

try:
    from reportlab.lib import colors
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
    from reportlab.lib.units import cm
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
    from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle
except ImportError:  # pragma: no cover
    SimpleDocTemplate = None  # type: ignore[misc, assignment]


def _flatten(obj: Any, prefix: str = "") -> List[Tuple[str, Any]]:
    rows: List[Tuple[str, Any]] = []
    if isinstance(obj, dict):
        for k, v in obj.items():
            key = f"{prefix}.{k}" if prefix else str(k)
            rows.extend(_flatten(v, key))
    elif isinstance(obj, list):
        for i, item in enumerate(obj):
            rows.extend(_flatten(item, f"{prefix}[{i}]"))
    else:
        rows.append((prefix, obj))
    return rows


def _safe_filename_part(s: str, max_len: int = 60) -> str:
    t = re.sub(r"[^a-zA-Z0-9._-]+", "_", (s or "").strip())[:max_len]
    t = re.sub(r"_+", "_", t).strip("._-")
    return t or "passport"


def _bundled_passport_ttf() -> Optional[Path]:
    """DejaVu Sans из репозитория (fonts/DejaVuSans.ttf) — чтобы PDF с кириллицей работал в Docker без системных шрифтов."""
    p = Path(__file__).resolve().parent / "fonts" / "DejaVuSans.ttf"
    return p if p.is_file() else None


def _system_ttf_candidates() -> List[Path]:
    bundled = _bundled_passport_ttf()
    out: List[Path] = []
    if bundled is not None:
        out.append(bundled)
    out.extend(
        [
            Path(r"C:\Windows\Fonts\arial.ttf"),
            Path(r"C:\Windows\Fonts\ARIAL.TTF"),
            Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
            Path("/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"),
        ]
    )
    return out


def _first_existing_ttf() -> Optional[Path]:
    for p in _system_ttf_candidates():
        if p.is_file():
            return p
    return None


def _register_pdf_cyrillic_font() -> str:
    """Регистрирует TTF с кириллицей для ReportLab; иначе Helvetica (кириллица может сломать сборку)."""
    if SimpleDocTemplate is None:
        return "Helvetica"
    for p in _system_ttf_candidates():
        try:
            if p.is_file():
                pdfmetrics.registerFont(TTFont("PassportSans", str(p)))
                return "PassportSans"
        except Exception:
            continue
    return "Helvetica"


def _p(text: str, font_name: str, size: int = 10, space_after: int = 6) -> Any:
    styles = getSampleStyleSheet()
    base = styles["Normal"]
    st = ParagraphStyle(
        name="PassportP",
        parent=base,
        fontName=font_name,
        fontSize=size,
        leading=size + 2,
        spaceAfter=space_after,
    )
    return Paragraph(escape(str(text)).replace("\n", "<br/>"), st)


def _build_pdf_reportlab(
    snapshot_envelope: Dict[str, Any],
    title: str,
    manual_sections: Optional[Dict[str, Any]] = None,
) -> bytes:
    if SimpleDocTemplate is None:
        raise RuntimeError("reportlab не установлен")
    font = _register_pdf_cyrillic_font()
    buf = BytesIO()
    doc = SimpleDocTemplate(
        buf,
        pagesize=A4,
        rightMargin=2 * cm,
        leftMargin=2 * cm,
        topMargin=2 * cm,
        bottomMargin=2 * cm,
    )
    story: List[Any] = []
    story.append(_p(f"<b>{escape(title)}</b>", font, size=14, space_after=12))

    meta_lines = [
        f"Дата формирования: {snapshot_envelope.get('formed_at', '—')}",
        f"Тип объекта: {snapshot_envelope.get('object_type', '—')}",
        f"Ссылка на СТП / норматив: {snapshot_envelope.get('stp_reference') or '—'}",
    ]
    story.append(_p("\n".join(meta_lines), font, size=10))
    story.append(Spacer(1, 0.4 * cm))

    flat = _flatten(snapshot_envelope.get("data") or {})
    cell_style = ParagraphStyle(
        name="PassportCell",
        parent=getSampleStyleSheet()["Normal"],
        fontName=font,
        fontSize=8,
        leading=10,
    )
    table_data: List[List[Any]] = [
        [_p("<b>Параметр</b>", font, size=9, space_after=0), _p("<b>Значение</b>", font, size=9, space_after=0)]
    ]
    for k, v in flat[:400]:
        vs = v
        if isinstance(v, (dict, list)):
            vs = json.dumps(v, ensure_ascii=False, default=str)[:500]
        ck = escape(str(k)).replace("\n", "<br/>")
        cv = escape(str(vs)).replace("\n", "<br/>")
        table_data.append([Paragraph(ck, cell_style), Paragraph(cv, cell_style)])

    if len(flat) > 400:
        table_data.append(
            [
                Paragraph(escape("…"), cell_style),
                Paragraph(
                    escape(f"ещё строк: {len(flat) - 400} (полные данные — в XLSX/JSON)"),
                    cell_style,
                ),
            ]
        )

    tw = doc.width
    t = Table(table_data, colWidths=[tw * 0.42, tw * 0.58])
    t.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#e8e8e8")),
                ("GRID", (0, 0), (-1, -1), 0.25, colors.grey),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ]
        )
    )
    story.append(t)

    if manual_sections:
        story.append(Spacer(1, 0.6 * cm))
        story.append(_p("<b>Дополнения (вручную)</b>", font, size=11))
        story.append(_p(json.dumps(manual_sections, ensure_ascii=False, indent=2), font, size=9))

    doc.build(story)
    return buf.getvalue()


def _build_pdf_fpdf2(
    snapshot_envelope: Dict[str, Any],
    title: str,
    manual_sections: Optional[Dict[str, Any]] = None,
) -> bytes:
    try:
        from fpdf import FPDF
    except ImportError as e:
        raise RuntimeError("fpdf2 не установлен (pip install fpdf2)") from e

    pdf = FPDF(orientation="P", unit="mm", format="A4")
    pdf.set_auto_page_break(True, margin=14)
    pdf.add_page()
    ttf = _first_existing_ttf()
    if ttf is not None:
        pdf.add_font("PassportSans", "", str(ttf))
        pdf.set_font("PassportSans", size=11)
    else:
        pdf.set_font("helvetica", size=10)

    def out_line(s: str) -> None:
        s = str(s).replace("\r", "")
        for part in s.split("\n"):
            try:
                pdf.multi_cell(0, 5.5, part)
            except Exception:
                pdf.multi_cell(0, 5.5, part.encode("latin-1", "replace").decode("latin-1"))

    out_line(title)
    out_line("")
    out_line(f"Дата формирования: {snapshot_envelope.get('formed_at', '—')}")
    out_line(f"Тип объекта: {snapshot_envelope.get('object_type', '—')}")
    out_line(f"СТП / норматив: {snapshot_envelope.get('stp_reference') or '—'}")
    out_line("")
    out_line("Сводка параметров:")
    for k, v in _flatten(snapshot_envelope.get("data") or {})[:350]:
        if isinstance(v, (dict, list)):
            vv = json.dumps(v, ensure_ascii=False, default=str)[:400]
        else:
            vv = str(v)
        out_line(f"{k}: {vv}")
    if manual_sections:
        out_line("")
        out_line("Дополнения (вручную):")
        out_line(json.dumps(manual_sections, ensure_ascii=False, indent=2))

    raw = pdf.output(dest="S")
    if isinstance(raw, bytearray):
        return bytes(raw)
    if isinstance(raw, bytes):
        return raw
    return str(raw).encode("latin-1", errors="replace")


def build_pdf_bytes(
    snapshot_envelope: Dict[str, Any],
    title: str,
    manual_sections: Optional[Dict[str, Any]] = None,
) -> bytes:
    errs: List[str] = []
    try:
        return _build_pdf_reportlab(snapshot_envelope, title, manual_sections)
    except Exception as e:
        errs.append(f"reportlab: {e}")
    try:
        return _build_pdf_fpdf2(snapshot_envelope, title, manual_sections)
    except Exception as e2:
        errs.append(f"fpdf2: {e2}")
    raise RuntimeError("Не удалось сформировать PDF. " + " | ".join(errs))


def build_docx_bytes(
    snapshot_envelope: Dict[str, Any],
    title: str,
    manual_sections: Optional[Dict[str, Any]] = None,
) -> bytes:
    if Document is None:
        raise RuntimeError("python-docx не установлен (pip install python-docx)")
    try:
        d = Document()
        h = d.add_heading(title, level=0)
        for run in h.runs:
            run.font.size = Pt(16)

        p = d.add_paragraph()
        p.add_run(f"Дата формирования: {snapshot_envelope.get('formed_at', '—')}\n")
        p.add_run(f"Тип объекта: {snapshot_envelope.get('object_type', '—')}\n")
        p.add_run(f"СТП / норматив: {snapshot_envelope.get('stp_reference') or '—'}\n")

        d.add_heading("Сводная таблица параметров", level=1)
        table = d.add_table(rows=1, cols=2)
        table.style = "Table Grid"
        hdr = table.rows[0].cells
        hdr[0].text = "Параметр"
        hdr[1].text = "Значение"

        flat = _flatten(snapshot_envelope.get("data") or {})
        for k, v in flat[:500]:
            row = table.add_row().cells
            row[0].text = str(k)
            if isinstance(v, (dict, list)):
                row[1].text = json.dumps(v, ensure_ascii=False, default=str)[:2000]
            else:
                row[1].text = str(v)

        if manual_sections:
            d.add_heading("Дополнения (вручную)", level=1)
            d.add_paragraph(json.dumps(manual_sections, ensure_ascii=False, indent=2))

        bio = BytesIO()
        d.save(bio)
        return bio.getvalue()
    except Exception as e:
        raise RuntimeError(f"Ошибка python-docx: {e}") from e


def build_xlsx_bytes(
    snapshot_envelope: Dict[str, Any],
    title: str,
    manual_sections: Optional[Dict[str, Any]] = None,
) -> bytes:
    ot = (snapshot_envelope.get("object_type") or "").strip().lower()
    data = snapshot_envelope.get("data") or {}
    if ot == "power_line":
        try:
            from app.core.passport_stp_xlsx_fill import TEMPLATE_PATH, build_stp_line_passport_xlsx

            if TEMPLATE_PATH.is_file():
                return build_stp_line_passport_xlsx(
                    data,
                    title,
                    snapshot_envelope.get("stp_reference"),
                    manual_sections,
                )
        except Exception:
            pass

    wb = Workbook()
    ws0 = wb.active
    ws0.title = "Титул"
    ws0["A1"] = "Технический паспорт"
    ws0["A1"].font = Font(bold=True, size=14)
    ws0["A2"] = title
    ws0["A4"] = "Дата формирования"
    ws0["B4"] = str(snapshot_envelope.get("formed_at", ""))
    ws0["A5"] = "Тип объекта"
    ws0["B5"] = str(snapshot_envelope.get("object_type", ""))
    ws0["A6"] = "СТП / норматив"
    ws0["B6"] = str(snapshot_envelope.get("stp_reference") or "")

    ws = wb.create_sheet("Параметры")
    ws.append(["Параметр", "Значение"])
    for c in ws[1]:
        c.font = Font(bold=True)
    for k, v in _flatten(data):
        if isinstance(v, (dict, list)):
            ws.append([k, json.dumps(v, ensure_ascii=False, default=str)])
        else:
            ws.append([k, v])

    if manual_sections:
        wm = wb.create_sheet("Вручную")
        wm.append(["Ключ", "Значение"])
        for c in wm[1]:
            c.font = Font(bold=True)
        for k, v in _flatten(manual_sections):
            wm.append([k, str(v)])

    bio = BytesIO()
    wb.save(bio)
    return bio.getvalue()


def export_passport_file(
    snapshot_envelope: Dict[str, Any],
    title: str,
    fmt: str,
    manual_sections: Optional[Dict[str, Any]] = None,
) -> Tuple[bytes, str, str]:
    """
    Возвращает (content, media_type, filename_suffix).
    fmt: pdf | docx | xlsx
    """
    key = (fmt or "").strip().lower()
    slug = _safe_filename_part(title)
    if key == "pdf":
        body = build_pdf_bytes(snapshot_envelope, title, manual_sections)
        return body, "application/pdf", f"{slug}.pdf"
    if key in ("docx", "doc"):
        body = build_docx_bytes(snapshot_envelope, title, manual_sections)
        return (
            body,
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            f"{slug}.docx",
        )
    if key == "xlsx":
        body = build_xlsx_bytes(snapshot_envelope, title, manual_sections)
        return (
            body,
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            f"{slug}.xlsx",
        )
    raise ValueError(f"Неизвестный формат: {fmt}")
