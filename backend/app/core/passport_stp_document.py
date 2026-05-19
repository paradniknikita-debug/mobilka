"""
Формирование паспорта по разделам СТП (для PDF, DOCX, XLSX без шаблона).
"""
from __future__ import annotations

import json
from io import BytesIO
from typing import Any, Dict, List, Optional, Tuple

from openpyxl import Workbook
from openpyxl.styles import Font

from app.core.passport_sections import build_passport_sections

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
    from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle
    from xml.sax.saxutils import escape
except ImportError:  # pragma: no cover
    SimpleDocTemplate = None  # type: ignore[misc, assignment]


def _sections(envelope: Dict[str, Any], manual: Optional[Dict[str, Any]]) -> List[Dict[str, Any]]:
    return build_passport_sections(envelope, manual)


def _cell_values(row: Dict[str, Any]) -> List[str]:
    return [str(v) if v is not None and v != "" else "—" for v in row.values()]


def build_docx_from_sections(
    snapshot_envelope: Dict[str, Any],
    title: str,
    manual_sections: Optional[Dict[str, Any]] = None,
) -> bytes:
    if Document is None:
        raise RuntimeError("python-docx не установлен (pip install python-docx)")

    d = Document()
    h = d.add_heading(title, level=0)
    for run in h.runs:
        run.font.size = Pt(16)

    subtitle = d.add_paragraph()
    subtitle.add_run("Технический паспорт объекта электросетевого хозяйства\n").bold = True
    subtitle.add_run(f"Дата формирования: {snapshot_envelope.get('formed_at', '—')}\n")
    subtitle.add_run(f"Тип объекта: {snapshot_envelope.get('object_type', '—')}\n")
    stp = snapshot_envelope.get("stp_reference") or "—"
    subtitle.add_run(f"Нормативная база (СТП): {stp}\n")

    for sec in _sections(snapshot_envelope, manual_sections):
        d.add_heading(sec["title"], level=1)

        if sec.get("rows"):
            t = d.add_table(rows=1, cols=2)
            t.style = "Table Grid"
            t.rows[0].cells[0].text = "Показатель"
            t.rows[0].cells[1].text = "Значение"
            for r in sec["rows"]:
                cells = t.add_row().cells
                cells[0].text = str(r.get("label", ""))
                cells[1].text = str(r.get("value", ""))

        for tbl in sec.get("tables") or []:
            d.add_paragraph()
            p = d.add_paragraph()
            p.add_run(str(tbl.get("title", ""))).bold = True
            columns: List[str] = list(tbl.get("columns") or [])
            rows_data: List[Dict[str, Any]] = list(tbl.get("rows") or [])
            if not columns or not rows_data:
                continue
            table = d.add_table(rows=1, cols=len(columns))
            table.style = "Table Grid"
            for i, col in enumerate(columns):
                table.rows[0].cells[i].text = col
            for row in rows_data:
                vals = _cell_values(row)
                cells = table.add_row().cells
                for i, val in enumerate(vals[: len(columns)]):
                    cells[i].text = val

    bio = BytesIO()
    d.save(bio)
    return bio.getvalue()


def build_pdf_from_sections(
    snapshot_envelope: Dict[str, Any],
    title: str,
    manual_sections: Optional[Dict[str, Any]] = None,
) -> bytes:
    if SimpleDocTemplate is None:
        raise RuntimeError("reportlab не установлен")

    from app.core.passport_export import _p, _register_pdf_cyrillic_font

    font = _register_pdf_cyrillic_font()
    buf = BytesIO()
    doc = SimpleDocTemplate(
        buf,
        pagesize=A4,
        rightMargin=1.8 * cm,
        leftMargin=1.8 * cm,
        topMargin=1.8 * cm,
        bottomMargin=1.8 * cm,
    )
    story: List[Any] = []
    story.append(_p(f"<b>{escape(title)}</b>", font, size=14, space_after=8))
    story.append(
        _p(
            "Технический паспорт объекта электросетевого хозяйства<br/>"
            f"Дата: {escape(str(snapshot_envelope.get('formed_at', '—')))}<br/>"
            f"СТП: {escape(str(snapshot_envelope.get('stp_reference') or '—'))}",
            font,
            size=10,
        )
    )
    story.append(Spacer(1, 0.3 * cm))

    cell_style = ParagraphStyle(
        name="StpCell",
        parent=getSampleStyleSheet()["Normal"],
        fontName=font,
        fontSize=8,
        leading=10,
    )

    for sec in _sections(snapshot_envelope, manual_sections):
        story.append(_p(f"<b>{escape(sec['title'])}</b>", font, size=11, space_after=6))

        if sec.get("rows"):
            kv_data: List[List[Any]] = [
                [
                    Paragraph("<b>Показатель</b>", cell_style),
                    Paragraph("<b>Значение</b>", cell_style),
                ]
            ]
            for r in sec["rows"]:
                kv_data.append(
                    [
                        Paragraph(escape(str(r.get("label", ""))), cell_style),
                        Paragraph(escape(str(r.get("value", ""))), cell_style),
                    ]
                )
            tw = doc.width
            t = Table(kv_data, colWidths=[tw * 0.4, tw * 0.6])
            t.setStyle(
                TableStyle(
                    [
                        ("GRID", (0, 0), (-1, -1), 0.25, colors.grey),
                        ("VALIGN", (0, 0), (-1, -1), "TOP"),
                    ]
                )
            )
            story.append(t)
            story.append(Spacer(1, 0.25 * cm))

        for tbl in sec.get("tables") or []:
            cols: List[str] = list(tbl.get("columns") or [])
            rows_data = list(tbl.get("rows") or [])
            if not cols or not rows_data:
                continue
            story.append(_p(f"<i>{escape(str(tbl.get('title', '')))}</i>", font, size=9))
            head = [Paragraph(f"<b>{escape(c)}</b>", cell_style) for c in cols]
            body: List[List[Any]] = [head]
            for row in rows_data[:150]:
                body.append([Paragraph(escape(v), cell_style) for v in _cell_values(row)])
            if len(rows_data) > 150:
                body.append(
                    [
                        Paragraph(escape("…"), cell_style),
                        Paragraph(escape(f"ещё {len(rows_data) - 150} строк"), cell_style),
                    ]
                    + [Paragraph("", cell_style)] * max(0, len(cols) - 2)
                )
            col_w = doc.width / max(len(cols), 1)
            t2 = Table(body, colWidths=[col_w] * len(cols))
            t2.setStyle(
                TableStyle(
                    [
                        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#e8e8e8")),
                        ("GRID", (0, 0), (-1, -1), 0.25, colors.grey),
                        ("VALIGN", (0, 0), (-1, -1), "TOP"),
                    ]
                )
            )
            story.append(t2)
            story.append(Spacer(1, 0.3 * cm))

    doc.build(story)
    return buf.getvalue()


def build_xlsx_from_sections(
    snapshot_envelope: Dict[str, Any],
    title: str,
    manual_sections: Optional[Dict[str, Any]] = None,
) -> bytes:
    """XLSX по разделам (опора, ПС или запасной вариант для ЛЭП без шаблона СТП)."""
    wb = Workbook()
    ws0 = wb.active
    ws0.title = "Титул"
    ws0["A1"] = "ТЕХНИЧЕСКИЙ ПАСПОРТ"
    ws0["A1"].font = Font(bold=True, size=14)
    ws0["A2"] = title
    ws0["A4"], ws0["B4"] = "Дата формирования", str(snapshot_envelope.get("formed_at", ""))
    ws0["A5"], ws0["B5"] = "Тип объекта", str(snapshot_envelope.get("object_type", ""))
    ws0["A6"], ws0["B6"] = "СТП / норматив", str(snapshot_envelope.get("stp_reference") or "")

    for sec in _sections(snapshot_envelope, manual_sections):
        name = (sec.get("id") or "раздел")[:28]
        base = name
        n = 1
        while name in wb.sheetnames:
            name = f"{base[:24]}_{n}"[:31]
            n += 1
        ws = wb.create_sheet(name)
        ws.append([sec.get("title", "")])
        ws["A1"].font = Font(bold=True, size=12)

        if sec.get("rows"):
            ws.append([])
            ws.append(["Показатель", "Значение"])
            for c in ws[ws.max_row]:
                if c.value:
                    c.font = Font(bold=True)
            for r in sec["rows"]:
                ws.append([r.get("label"), r.get("value")])

        for tbl in sec.get("tables") or []:
            ws.append([])
            ws.append([tbl.get("title", "Таблица")])
            cols = list(tbl.get("columns") or [])
            if cols:
                ws.append(cols)
                for c in ws[ws.max_row]:
                    if c.value:
                        c.font = Font(bold=True)
                for row in tbl.get("rows") or []:
                    ws.append(_cell_values(row))

        for col in ws.columns:
            ws.column_dimensions[col[0].column_letter].width = 18

    bio = BytesIO()
    wb.save(bio)
    return bio.getvalue()
