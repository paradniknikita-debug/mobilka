"""
Служебные узлы профиля LEPM в выгрузке CIM (rdf:Description — дерево папок под внешний импорт).

Имеют фиксированные mRID в `cim_export_profile`; при импорте и записи в БД их нужно игнорировать,
оставляя только реальную модель (подстанции, ЛЭП, опоры и т.д.).
"""
from typing import Any, Dict, List, Optional

from .cim_export_profile import (
    EXTERNAL_ROOT_RESOURCE,
    FIXED_GEO_REGION_MRID,
    FIXED_LINES_FOLDER_MRID,
    FIXED_SUBSTATIONS_FOLDER_MRID,
    FIXED_SUB_GEO_REGION_MRID,
)


def normalize_cim_mrid(raw: Optional[str]) -> str:
    """Привести mRID из RDF/XML к виду UUID без префиксов #_, urn:, gm:#_."""
    if raw is None:
        return ""
    s = str(raw).strip()
    if not s:
        return ""
    if s.startswith("urn:uuid:"):
        return s.replace("urn:uuid:", "")
    if s.startswith("gm:#_"):
        return s[len("gm:#_") :]
    if s.startswith("gm:#"):
        return s[len("gm:#") :].lstrip("_")
    if s.startswith("#_"):
        return s[2:]
    if s.startswith("#"):
        return s[1:]
    return s


# Нормализованные идентификаторы пяти служебных Description из build_export_tree
_LEPM_IMPORT_FOLDER_SCAFFOLD_MRIDS = frozenset(
    {
        normalize_cim_mrid(EXTERNAL_ROOT_RESOURCE),
        FIXED_GEO_REGION_MRID,
        FIXED_SUB_GEO_REGION_MRID,
        FIXED_SUBSTATIONS_FOLDER_MRID,
        FIXED_LINES_FOLDER_MRID,
    }
)


def is_lepm_import_folder_scaffolding(obj: Dict[str, Any]) -> bool:
    """
    True, если объект — известная служебная rdf:Description дерева импорта LEPM
    (не подстанция/ЛЭП и не часть электромодели).
    """
    cls = (obj.get("_class") or obj.get("type") or "").strip()
    if cls not in ("Description", "Unknown"):
        return False
    m = normalize_cim_mrid(obj.get("mRID") or obj.get("mrid"))
    return bool(m) and m in _LEPM_IMPORT_FOLDER_SCAFFOLD_MRIDS


def filter_lepm_import_folder_scaffolding(objects: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Убрать служебные узлы профиля LEPM из списка разобранных CIM-объектов."""
    return [o for o in objects if not is_lepm_import_folder_scaffolding(o)]
