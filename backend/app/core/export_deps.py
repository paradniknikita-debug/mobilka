"""Проверка зависимостей экспорта паспортов (PDF / DOCX / XLSX)."""

from __future__ import annotations

from typing import Dict


def passport_export_dependency_status() -> Dict[str, bool]:
    reportlab_ok = False
    try:
        import reportlab  # noqa: F401

        reportlab_ok = True
    except ImportError:
        pass

    docx_ok = False
    try:
        from docx import Document  # noqa: F401

        docx_ok = True
    except ImportError:
        pass

    fpdf_ok = False
    try:
        from fpdf import FPDF  # noqa: F401

        fpdf_ok = True
    except ImportError:
        pass

    openpyxl_ok = False
    try:
        import openpyxl  # noqa: F401

        openpyxl_ok = True
    except ImportError:
        pass

    return {
        "reportlab": reportlab_ok,
        "python-docx": docx_ok,
        "fpdf2": fpdf_ok,
        "openpyxl": openpyxl_ok,
    }


def log_passport_export_dependencies() -> None:
    status = passport_export_dependency_status()
    missing = [name for name, ok in status.items() if not ok]
    if missing:
        print(
            "WARNING: для экспорта паспортов не установлены: "
            + ", ".join(missing)
            + ". Выполните: pip install reportlab python-docx fpdf2 openpyxl "
            "или пересоберите образ backend: docker compose build --no-cache backend"
        )
    else:
        print("OK: зависимости экспорта паспортов (PDF/DOCX/XLSX) доступны")
