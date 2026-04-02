"""
Служебный профиль ручного CIM-экспорта под целевое дерево импорта.
"""
from dataclasses import dataclass
from typing import Dict, List, Optional

from .cim_base import CIMObject


EXTERNAL_ROOT_RESOURCE = "gm:#_1033610f-0b5a-4999-ae72-21cb6a6713e4"
FIXED_GEO_REGION_MRID = "b2c3d4e5-f678-9012-bcde-f23456789012"
FIXED_SUB_GEO_REGION_MRID = "c3d4e5f6-7890-1234-cdef-345678901234"
FIXED_SUBSTATIONS_FOLDER_MRID = "4f7d7c91-0c42-4f5a-9ef6-1d9dbd7f4a11"
FIXED_LINES_FOLDER_MRID = "7b8b9cf2-34b1-4a3c-8d22-5e1c9d2a6f33"
DEFAULT_IMPORT_FOLDER_NAME = "LEPM импорт"
DEFAULT_HYPER_GEO_REGION_NAME = "LEPM гиперрегион"
DEFAULT_GEO_REGION_NAME = "LEPM регион"
DEFAULT_SUB_REGION_NAME = "LEPM субрегион"
DEFAULT_FOLDER_SUBSTATIONS_NAME = "lepm Подстанции"
DEFAULT_FOLDER_LINES_NAME = "lepm ЛЭП"


def cim_ref(mrid: str) -> Dict[str, str]:
    return {"mRID": mrid}


def external_root_ref() -> Dict[str, str]:
    return {"resource": EXTERNAL_ROOT_RESOURCE}


def external_resource_ref(resource: str) -> Dict[str, str]:
    return {"resource": resource}


@dataclass
class ExportTree:
    objects: List[CIMObject]
    import_folder_mrid: Optional[str]
    hyper_geo_region_mrid: str
    geographical_region_mrid: str
    sub_geographical_region_mrid: str
    substations_folder_mrid: str
    lines_folder_mrid: str


def build_export_tree(
    substation_mrids: List[str],
    power_line_mrids: List[str],
    *,
    import_folder_name: str = DEFAULT_IMPORT_FOLDER_NAME,
    geo_region_name: str = DEFAULT_GEO_REGION_NAME,
    sub_region_name: str = DEFAULT_SUB_REGION_NAME,
    folder_substations_name: str = DEFAULT_FOLDER_SUBSTATIONS_NAME,
    folder_lines_name: str = DEFAULT_FOLDER_LINES_NAME,
) -> ExportTree:
    geographical_region_mrid = FIXED_GEO_REGION_MRID
    sub_geographical_region_mrid = FIXED_SUB_GEO_REGION_MRID
    substations_folder_mrid = FIXED_SUBSTATIONS_FOLDER_MRID
    lines_folder_mrid = FIXED_LINES_FOLDER_MRID

    objects: List[CIMObject] = []

    return ExportTree(
        objects=objects,
        import_folder_mrid=None,
        hyper_geo_region_mrid=EXTERNAL_ROOT_RESOURCE.replace("gm:#_", ""),
        geographical_region_mrid=geographical_region_mrid,
        sub_geographical_region_mrid=sub_geographical_region_mrid,
        substations_folder_mrid=substations_folder_mrid,
        lines_folder_mrid=lines_folder_mrid,
    )
