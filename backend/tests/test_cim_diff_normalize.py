"""Тесты нормализации 552-diff (служебное дерево LEPM)."""
import uuid

from app.core.cim.cim_diff_normalize import (
    filter_diff_scaffolding_objects,
    is_diff_scaffolding_object,
    is_poles_folder_mrid,
    is_scaffolding_mrid,
    resolve_line_mrid_for_pole,
    resolve_parent_object_ref_for_line,
    resolve_region_uid_for_line,
)
from app.core.cim.cim_export_profile import (
    EXTERNAL_ROOT_RESOURCE,
    FIXED_LINES_FOLDER_MRID,
    FIXED_SUB_GEO_REGION_MRID,
)


def test_scaffolding_mrid_external_root():
    assert is_scaffolding_mrid(EXTERNAL_ROOT_RESOURCE)
    assert is_scaffolding_mrid("gm:#_1033610f-0b5a-4999-ae72-21cb6a6713e4")


def test_line_parent_maps_to_lines_folder():
    ref = resolve_parent_object_ref_for_line(FIXED_LINES_FOLDER_MRID)
    assert ref == f"#_{FIXED_LINES_FOLDER_MRID}"


def test_line_region_maps_to_sub_geo():
    assert resolve_region_uid_for_line(FIXED_SUB_GEO_REGION_MRID) == FIXED_SUB_GEO_REGION_MRID
    assert resolve_region_uid_for_line("c279a526-f085-4aa8-9575-85f50f70e3b0") == FIXED_SUB_GEO_REGION_MRID


def test_poles_folder_not_scaffolding():
    line_mrid = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    folder = str(uuid.uuid5(uuid.NAMESPACE_URL, f"poles-folder:{line_mrid}"))
    assert not is_scaffolding_mrid(folder)
    assert is_poles_folder_mrid(folder, line_mrid)


def test_resolve_line_from_pole_via_folder():
    line_mrid = "line-1111-2222-3333-444455556666"
    folder_mrid = str(uuid.uuid5(uuid.NAMESPACE_URL, f"poles-folder:{line_mrid}"))
    by_mrid = {
        line_mrid: {"mRID": line_mrid, "_class": "Line"},
        folder_mrid: {
            "mRID": folder_mrid,
            "_class": "Folder",
            "ParentObject": {"mRID": line_mrid},
        },
    }
    pole = {
        "mRID": "pole-1",
        "_class": "Pole",
        "ParentObject": {"mRID": folder_mrid},
    }
    assert resolve_line_mrid_for_pole(pole, by_mrid) == line_mrid


def test_filter_export_tree_descriptions():
    objs = [
        {"mRID": FIXED_LINES_FOLDER_MRID, "_class": "Description"},
        {"mRID": "real-line", "_class": "Line", "name": "ВЛ"},
    ]
    filtered = filter_diff_scaffolding_objects(objs)
    assert len(filtered) == 1
    assert filtered[0]["mRID"] == "real-line"
    assert is_diff_scaffolding_object(objs[0])
