"""Экспорт технического паспорта в PDF, DOCX, XLSX."""

from __future__ import annotations

import json
import logging
import re
from io import BytesIO
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from app.core.passport_naming import passport_export_filename
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
                pdfmetrics.registerFont(TTFont("PassportTimes", str(p)))
                return "PassportTimes"
        except Exception:
            continue
    return "Helvetica"


def _pdf_style(font_name: str, size: int = 10, space_after: int = 6) -> Any:
    styles = getSampleStyleSheet()
    return ParagraphStyle(
        name="PassportP",
        parent=styles["Normal"],
        fontName=font_name,
        fontSize=size,
        leading=size + 2,
        spaceAfter=space_after,
    )


def _p(text: str, font_name: str, size: int = 10, space_after: int = 6) -> Any:
    """Обычный текст (без HTML-тегов в выводе)."""
    return Paragraph(escape(str(text)).replace("\n", "<br/>"), _pdf_style(font_name, size, space_after))


def _p_bold(text: str, font_name: str, size: int = 10, space_after: int = 6) -> Any:
    return Paragraph(f"<b>{escape(str(text))}</b>", _pdf_style(font_name, size, space_after))


def _p_lines(lines: List[str], font_name: str, size: int = 10, space_after: int = 6) -> Any:
    html = "<br/>".join(escape(str(line)) for line in lines)
    return Paragraph(html, _pdf_style(font_name, size, space_after))


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
    story.append(_p_bold(title, font, size=14, space_after=12))

    from app.core.passport_sections import format_formed_at_human

    meta_lines = [
        f"Дата формирования: {format_formed_at_human(snapshot_envelope.get('formed_at'))}",
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
        [_p_bold("Параметр", font, size=9, space_after=0), _p_bold("Значение", font, size=9, space_after=0)]
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
        story.append(_p_bold("Дополнения (вручную)", font, size=11))
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
    from app.core.passport_sections import format_formed_at_human

    out_line(f"Дата формирования: {format_formed_at_human(snapshot_envelope.get('formed_at'))}")
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
    from app.core.passport_stp_document import build_pdf_from_sections

    errs: List[str] = []
    try:
        return build_pdf_from_sections(snapshot_envelope, title, manual_sections)
    except Exception as e:
        errs.append(f"sections: {e}")
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
    from app.core.passport_stp_document import build_docx_from_sections

    if Document is None:
        raise RuntimeError("python-docx не установлен (pip install python-docx)")
    try:
        return build_docx_from_sections(snapshot_envelope, title, manual_sections)
    except Exception as e:
        raise RuntimeError(f"Ошибка формирования DOCX: {e}") from e


def build_xlsx_bytes(
    snapshot_envelope: Dict[str, Any],
    title: str,
    manual_sections: Optional[Dict[str, Any]] = None,
) -> bytes:
    """XLSX: один лист «Паспорт» по разделам (как PDF/DOCX), без шаблона TDSheet."""
    from app.core.passport_stp_document import build_xlsx_from_sections

    return build_xlsx_from_sections(snapshot_envelope, title, manual_sections)


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
    formed = snapshot_envelope.get("formed_at")
    passport_id = int(snapshot_envelope.get("passport_id") or 0)

    def _fname(ext: str) -> str:
        utf8, _ = passport_export_filename(
            title,
            passport_id or 0,
            ext,
            formed_at=formed,
        )
        return utf8

    if key == "pdf":
        body = build_pdf_bytes(snapshot_envelope, title, manual_sections)
        return body, "application/pdf", _fname("pdf")
    if key in ("docx", "doc"):
        body = build_docx_bytes(snapshot_envelope, title, manual_sections)
        return (
            body,
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            _fname("docx"),
        )
    if key == "xlsx":
        body = build_xlsx_bytes(snapshot_envelope, title, manual_sections)
        return (
            body,
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            _fname("xlsx"),
        )
    raise ValueError(f"Неизвестный формат: {fmt}")
