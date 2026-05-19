"""
Нормализация 552-diff перед применением к нашей БД.

Служебные узлы дерева импорта LEPM (папки/регионы целевой или внешней системы) не пишутся в БД,
но ссылки на них в ParentObject / Region подменяются на канонические MRID профиля экспорта,
чтобы ЛЭП и объекты попадали в то же дерево, что при нашей выгрузке.
"""
from __future__ import annotations

import uuid
from typing import Any, Dict, List, Optional, Set, Tuple

from .cim_export_profile import (
    EXTERNAL_ROOT_RESOURCE,
    FIXED_GEO_REGION_MRID,
    FIXED_LINES_FOLDER_MRID,
    FIXED_SUBSTATIONS_FOLDER_MRID,
    FIXED_SUB_GEO_REGION_MRID,
)
from .cim_import_profile import (
    CIM_FOLDER_POWER_LINES_MRID,
    CIM_FOLDER_SUBSTATIONS_MRID,
    CIM_GEOGRAPHICAL_REGION_MRID,
    CIM_IMPORT_FOLDER_MRID,
    CIM_OBJECT_TREE_ROOT_MRID,
    CIM_SUB_GEOGRAPHICAL_REGION_MRID,
)
from .cim_import_scaffolding import normalize_cim_mrid

# Канонические MRID нашего дерева (совпадают с build_export_tree / cim_export_profile).
LOCAL_LINES_FOLDER_MRID = FIXED_LINES_FOLDER_MRID
LOCAL_SUBSTATIONS_FOLDER_MRID = FIXED_SUBSTATIONS_FOLDER_MRID
LOCAL_SUB_GEO_REGION_MRID = FIXED_SUB_GEO_REGION_MRID

_ALL_SCAFFOLDING_MRIDS: Optional[frozenset[str]] = None


def lepm_scaffolding_mrids() -> frozenset[str]:
    """Все известные служебные mRID (экспорт LEPM + профиль внешней системы)."""
    global _ALL_SCAFFOLDING_MRIDS
    if _ALL_SCAFFOLDING_MRIDS is None:
        raw = (
            EXTERNAL_ROOT_RESOURCE,
            FIXED_GEO_REGION_MRID,
            FIXED_SUB_GEO_REGION_MRID,
            FIXED_SUBSTATIONS_FOLDER_MRID,
            FIXED_LINES_FOLDER_MRID,
            CIM_OBJECT_TREE_ROOT_MRID,
            CIM_IMPORT_FOLDER_MRID,
            CIM_GEOGRAPHICAL_REGION_MRID,
            CIM_SUB_GEOGRAPHICAL_REGION_MRID,
            CIM_FOLDER_SUBSTATIONS_MRID,
            CIM_FOLDER_POWER_LINES_MRID,
        )
        _ALL_SCAFFOLDING_MRIDS = frozenset(
            m for m in (normalize_cim_mrid(x) for x in raw) if m
        )
    return _ALL_SCAFFOLDING_MRIDS


def is_scaffolding_mrid(mrid: Optional[str]) -> bool:
    m = normalize_cim_mrid(mrid)
    return bool(m) and m in lepm_scaffolding_mrids()


def is_poles_folder_mrid(mrid: Optional[str], line_mrid: Optional[str] = None) -> bool:
    """Папка «Опоры …» для одной ЛЭП (стабильный uuid5, не служебный корень дерева)."""
    m = normalize_cim_mrid(mrid)
    if not m or not line_mrid:
        return False
    expected = str(uuid.uuid5(uuid.NAMESPACE_URL, f"poles-folder:{normalize_cim_mrid(line_mrid)}"))
    return m == expected


def is_diff_scaffolding_object(obj: Dict[str, Any]) -> bool:
    """
    Объект не записывается в БД: служебные rdf:Description дерева LEPM
    или Folder/Region с известным служебным mRID.
    """
    cls = (obj.get("_class") or obj.get("type") or "").strip()
    if cls in ("Description", "Unknown"):
        m = normalize_cim_mrid(obj.get("mRID") or obj.get("mrid"))
        if m and m in lepm_scaffolding_mrids():
            return True
    mrid = normalize_cim_mrid(obj.get("mRID") or obj.get("mrid"))
    if not mrid or not is_scaffolding_mrid(mrid):
        return False
    if cls in ("Description", "Unknown", "Folder", "GeographicalRegion", "SubGeographicalRegion"):
        return True
    return False


def filter_diff_scaffolding_objects(objects: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    return [o for o in objects if not is_diff_scaffolding_object(o)]


def mrid_from_ref(value: Any) -> Optional[str]:
    if value is None:
        return None
    if isinstance(value, dict):
        raw = value.get("mRID") or value.get("mrid") or value.get("resource")
        if raw is not None:
            return normalize_cim_mrid(str(raw)) or None
        return None
    if isinstance(value, str):
        return normalize_cim_mrid(value) or None
    return None


def local_parent_ref(mrid: str) -> str:
    """Формат parent_object_ref как в UI (#_uuid)."""
    m = normalize_cim_mrid(mrid)
    return f"#_{m}" if m else ""


def resolve_parent_object_ref_for_line(parent_mrid: Optional[str]) -> Optional[str]:
    """
    ParentObject из CIM → parent_object_ref в line.
    Служебная папка «lepm ЛЭП» → канонический MRID папки линий.
    """
    m = normalize_cim_mrid(parent_mrid)
    if not m:
        return local_parent_ref(LOCAL_LINES_FOLDER_MRID)
    if is_scaffolding_mrid(m):
        return local_parent_ref(LOCAL_LINES_FOLDER_MRID)
    return local_parent_ref(m)


def resolve_region_uid_for_line(region_mrid: Optional[str]) -> str:
    """Region / regionUid → region_uid в line (субрегион LEPM по умолчанию)."""
    m = normalize_cim_mrid(region_mrid)
    if not m or is_scaffolding_mrid(m):
        return LOCAL_SUB_GEO_REGION_MRID
    return m


def _object_class(objects_by_mrid: Dict[str, Dict[str, Any]], mrid: str) -> str:
    o = objects_by_mrid.get(normalize_cim_mrid(mrid) or "")
    if not o:
        return ""
    return (o.get("_class") or o.get("type") or "").strip()


def resolve_line_mrid_for_pole(
    pole_obj: Dict[str, Any],
    objects_by_mrid: Dict[str, Dict[str, Any]],
    *,
    known_line_mrids: Optional[Set[str]] = None,
) -> Optional[str]:
    """
    ЛЭП для опоры: cim:Asset.PowerSystemResources, иначе обход ParentObject
    (папка опор → Line), игнорируя служебные узлы.
    """
    known = known_line_mrids or set()

    psr = mrid_from_ref(pole_obj.get("PowerSystemResources"))
    if psr and not is_scaffolding_mrid(psr):
        if psr in known or _object_class(objects_by_mrid, psr) == "Line":
            return psr

    parent = mrid_from_ref(pole_obj.get("ParentObject"))
    visited: Set[str] = set()
    for _ in range(12):
        if not parent or parent in visited:
            break
        visited.add(parent)
        if is_scaffolding_mrid(parent):
            break
        cls = _object_class(objects_by_mrid, parent)
        if cls == "Line" or parent in known:
            return parent
        if cls == "Folder":
            folder = objects_by_mrid.get(parent) or {}
            parent = mrid_from_ref(folder.get("ParentObject"))
            continue
        break

    if len(known) == 1:
        return next(iter(known))
    return None


def normalize_objects_for_apply(
    objects: List[Dict[str, Any]],
) -> Tuple[List[Dict[str, Any]], int, Dict[str, Dict[str, Any]]]:
    """
    Отфильтровать служебное дерево и подготовить индекс по mRID для разрешения ссылок.
    Возвращает (объекты для apply, число пропущенных служебных, objects_by_mrid по всем forward).
    """
    forward = [o for o in objects if o.get("_diff_section") != "reverse"]
    skipped = sum(1 for o in forward if is_diff_scaffolding_object(o))
    apply_objects = filter_diff_scaffolding_objects(forward)

    by_mrid: Dict[str, Dict[str, Any]] = {}
    for o in objects:
        m = normalize_cim_mrid(o.get("mRID") or o.get("mrid"))
        if m:
            by_mrid[m] = o
    return apply_objects, skipped, by_mrid
