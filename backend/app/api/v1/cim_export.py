"""
API endpoints для экспорта данных в CIM форматы
Соответствует стандартам IEC 61970-301 и IEC 61970-552:2016
"""
from typing import List, Optional, Dict
from datetime import datetime
import tempfile
import os
import logging
from fastapi import APIRouter, Depends, HTTPException, status, Query, UploadFile, File
from fastapi.responses import Response, StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload
from io import BytesIO
from collections import Counter, defaultdict

from app.database import get_db
from app.core.security import get_current_active_user
from app.models.user import User
from app.models.substation import Substation, VoltageLevel
from app.models.power_line import PowerLine, Pole, Span, Equipment
from app.models.location import Location, PositionPoint
from app.models.acline_segment import AClineSegment
from app.models.cim_line_structure import ConnectivityNode, LineSection, Terminal
from app.models.base_voltage import BaseVoltage
from app.models.wire_info import WireInfo
from app.core.cim.cim_xml import CIMXMLExporter, CIMXMLImporter
from app.core.cim.cim_json import CIMJSONExporter
from app.core.cim.cim_552_protocol import CIM552Service, MessagePurpose
from app.core.cim.cim_base import CIMObject
from app.core.config import settings
from app.models.base import generate_mrid
from app.core.cim.cim_objects import (
    SubstationCIMObject,
    VoltageLevelCIMObject,
    PowerLineCIMObject,
    LocationCIMObject,
    PositionPointCIMObject,
    ConnectivityNodeCIMObject,
    AClineSegmentCIMObject,
    LineSectionCIMObject,
    SpanCIMObject,
    LineSpanCIMObject,
    WireInfoCIMObject,
    TerminalCIMObject,
    ConductingEquipmentCIMObject,
    FolderCIMObject,
    PoleCIMObject,
    GenericNamedCIMObject,
    GeographicalRegionCIMObject,
    SubGeographicalRegionCIMObject,
)
from app.core.cim.cim_export_profile import (
    DEFAULT_IMPORT_FOLDER_NAME,
    build_export_tree,
    cim_ref,
    external_resource_ref,
    external_root_ref,
    DEFAULT_GEO_REGION_NAME,
    DEFAULT_SUB_REGION_NAME,
    DEFAULT_FOLDER_SUBSTATIONS_NAME,
    DEFAULT_FOLDER_LINES_NAME,
)
from app.core.cim.base_voltage_profile import base_voltage_resource_by_kv
from app.core.cim.equipment_type_mapping import (
    is_cim_exportable_equipment,
    map_equipment_type_to_cim_profile,
    normalize_equipment_type,
)


DISCONNECTOR_PSR_TYPE_RESOURCE = "gm:#_6c49d145-bd34-4f17-89f6-34dfc8698998"

router = APIRouter()


def _apply_export_preset(
    export_preset: Optional[str],
    *,
    include_gps: bool,
    include_equipment: bool,
    include_electrical_model: bool,
    include_defects: bool,
    include_substation_voltage_levels: bool,
) -> tuple[bool, bool, bool, bool, bool]:
    """
    Пресеты выгрузки (атрибутный профиль). Если preset задан, переопределяет соответствующие флаги.

    full — полный набор (как явные query-параметры по умолчанию).
    coordinates_only — только геометрия: подстанции/опоры с Location, без электромодели и без оборудования.
    no_equipment — топология ЛЭП без ConductingEquipment.
    without_defects — как полный, но без полей дефектов оборудования в CIM.
    """
    if not export_preset:
        return (
            include_gps,
            include_equipment,
            include_electrical_model,
            include_defects,
            include_substation_voltage_levels,
        )
    key = export_preset.strip().lower()
    if key == "full":
        return (
            include_gps,
            include_equipment,
            include_electrical_model,
            include_defects,
            include_substation_voltage_levels,
        )
    if key == "coordinates_only":
        return True, False, False, False, False
    if key == "no_equipment":
        return include_gps, False, True, include_defects, include_substation_voltage_levels
    if key in ("without_defects", "no_defects"):
        return include_gps, include_equipment, include_electrical_model, False, include_substation_voltage_levels
    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="Неизвестный export_preset. Допустимо: full, coordinates_only, no_equipment, without_defects",
    )


def _build_export_tree(
    substation_mrids: List[str],
    power_line_mrids: List[str],
    *,
    import_folder_name: str = DEFAULT_IMPORT_FOLDER_NAME,
    geo_region_name: str = DEFAULT_GEO_REGION_NAME,
    sub_region_name: str = DEFAULT_SUB_REGION_NAME,
    folder_substations_name: str = DEFAULT_FOLDER_SUBSTATIONS_NAME,
    folder_lines_name: str = DEFAULT_FOLDER_LINES_NAME,
) :
    return build_export_tree(
        substation_mrids,
        power_line_mrids,
        import_folder_name=import_folder_name,
        geo_region_name=geo_region_name,
        sub_region_name=sub_region_name,
        folder_substations_name=folder_substations_name,
        folder_lines_name=folder_lines_name,
    )


def _manual_cim_objects_list(
    substations_list: List[Substation],
    power_lines_list: List[PowerLine],
    *,
    include_gps: bool,
    include_equipment: bool,
    include_electrical_model: bool = True,
    include_defects: bool = True,
    include_substation_voltage_levels: bool = True,
) -> List[CIMObject]:
    """Ручная сборка CIM XML: фиксированная география + подстанции + ЛЭП."""
    tree = _build_export_tree(
        [s.mrid for s in substations_list],
        [pl.mrid for pl in power_lines_list],
    )
    out = list(tree.objects)
    for substation in substations_list:
        out.extend(
            _substation_to_cim_objects_for_xml(
                substation,
                include_gps=include_gps,
                include_voltage_levels=include_substation_voltage_levels,
                substations_folder_mrid=tree.substations_folder_mrid,
                sub_geographical_region_mrid=tree.sub_geographical_region_mrid,
            )
        )
    for power_line in power_lines_list:
        out.extend(
            _power_line_to_cim(
                power_line,
                include_equipment=include_equipment,
                include_gps=include_gps,
                include_electrical_model=include_electrical_model,
                include_defects=include_defects,
                line_parent_folder_mrid=tree.lines_folder_mrid,
                sub_geographical_region_mrid=tree.sub_geographical_region_mrid,
            )
        )
    return out


def _substation_to_cim(substation: Substation, include_gps: bool = True) -> SubstationCIMObject:
    """Преобразование модели Substation в CIM объект"""
    location = None
    if include_gps and substation.location:
        position_points = []
        for pp in substation.location.position_points:
            position_points.append({
                "mRID": pp.mrid,
                "xPosition": pp.x_position,
                "yPosition": pp.y_position,
                "zPosition": pp.z_position
            })
        
        location = {
            "mRID": substation.location.mrid,
            "PositionPoint": position_points
        }
    
    voltage_levels = []
    for vl in substation.voltage_levels:
        base_voltage = None
        # if vl.base_voltage:
        #     base_voltage = {"mRID": vl.base_voltage.mrid}
        
        voltage_levels.append({
            "mRID": vl.mrid,
            "name": vl.name,
            "nominalVoltage": vl.nominal_voltage,
            "BaseVoltage": base_voltage
        })
    
    return SubstationCIMObject(
        mrid=substation.mrid,
        name=substation.name,
        voltage_levels=voltage_levels,
        location=location
    )


def _substation_to_cim_objects_for_xml(
    substation: Substation,
    include_gps: bool = True,
    include_voltage_levels: bool = True,
    substations_folder_mrid: Optional[str] = None,
    sub_geographical_region_mrid: Optional[str] = None,
) -> List[CIMObject]:
    """
    Экспорт подстанции в CIM XML с корректными ссылками:
    - Substation.VoltageLevels -> VoltageLevel (rdf:resource)
    - PowerSystemResource.Location -> Location (rdf:resource)

    Возвращает полный набор CIM объектов, которые должны попасть в XML.
    """
    objects: List[CIMObject] = []

    # VoltageLevels
    voltage_level_refs: List[Dict[str, str]] = []
    if include_voltage_levels:
        for vl in (getattr(substation, "voltage_levels", None) or []):
            base_voltage_resource = base_voltage_resource_by_kv(getattr(vl, "nominal_voltage", None))
            vl_obj = VoltageLevelCIMObject(
                mrid=vl.mrid,
                name=vl.name,
                nominal_voltage=vl.nominal_voltage,
                base_voltage=external_resource_ref(base_voltage_resource) if base_voltage_resource else None,
                parent_object=cim_ref(substation.mrid),
            )
            objects.append(vl_obj)
            voltage_level_refs.append(cim_ref(vl_obj.mrid))

    # Location (+ PositionPoints)
    location_ref: Optional[Dict[str, str]] = None
    if include_gps and getattr(substation, "location", None) is not None:
        loc = substation.location
        pp_refs = [{"mRID": pp.mrid} for pp in (getattr(loc, "position_points", None) or [])]
        location_obj = LocationCIMObject(
            mrid=loc.mrid,
            position_points=pp_refs,
            parent_object={"mRID": substation.mrid},
        )
        objects.append(location_obj)
        for pp in getattr(loc, "position_points", None) or []:
            objects.append(
                PositionPointCIMObject(
                    mrid=pp.mrid,
                    x_position=pp.x_position,
                    y_position=pp.y_position,
                    z_position=pp.z_position,
                    parent_object={"mRID": loc.mrid},
                )
            )
        location_ref = cim_ref(location_obj.mrid)

    sub_children: List[Dict[str, str]] = list(voltage_level_refs)
    if location_ref:
        sub_children.append(location_ref)

    substation_obj = SubstationCIMObject(
        mrid=substation.mrid,
        name=substation.name,
        voltage_levels=voltage_level_refs,
        location=location_ref,
        parent_object=cim_ref(substations_folder_mrid) if substations_folder_mrid else None,
        child_objects=sub_children if substations_folder_mrid else None,
    )
    objects.append(substation_obj)

    return objects


def _pole_ref_from_connectivity_node(cn) -> Optional[Dict[str, str]]:
    """Ссылка на cim:Pole (опора) для its:LineSpan.StartTower / EndTower."""
    if cn is None:
        return None
    pole = getattr(cn, "pole", None)
    if pole is not None and getattr(pole, "mrid", None):
        return cim_ref(pole.mrid)
    return None


def _power_line_to_cim_geometry_only(
    power_line: PowerLine,
    *,
    include_gps: bool,
    line_parent_folder_mrid: Optional[str] = None,
    sub_geographical_region_mrid: Optional[str] = None,
) -> List[CIMObject]:
    """
    Упрощённая выгрузка ЛЭП: только Line + папка опор + Pole + Location/PositionPoint
    (без ACLineSegment / ConnectivityNode / оборудования).
    Требует загруженный relationship PowerLine.poles (+ Pole.location при include_gps).
    """
    cim_objects: List[CIMObject] = []
    folder_mrid = generate_mrid()
    folder_ref = cim_ref(folder_mrid)
    pole_child_refs: List[Dict[str, str]] = []
    poles = sorted(
        getattr(power_line, "poles", None) or [],
        key=lambda p: (getattr(p, "sequence_number", 0) or 0, getattr(p, "id", 0)),
    )
    for pole in poles:
        location_ref = None
        if include_gps and getattr(pole, "location", None) is not None:
            loc = pole.location
            pp_refs = [{"mRID": pp.mrid} for pp in (getattr(loc, "position_points", None) or [])]
            location_obj = LocationCIMObject(
                mrid=loc.mrid,
                position_points=pp_refs,
                parent_object={"mRID": pole.mrid},
            )
            cim_objects.append(location_obj)
            for pp in getattr(loc, "position_points", None) or []:
                cim_objects.append(
                    PositionPointCIMObject(
                        mrid=pp.mrid,
                        x_position=pp.x_position,
                        y_position=pp.y_position,
                        z_position=pp.z_position,
                        parent_object={"mRID": loc.mrid},
                    )
                )
            location_ref = cim_ref(location_obj.mrid)

        pole_name = (getattr(pole, "pole_number", None) or f"Опора {pole.id}").strip()
        if not pole_name.lower().startswith(("опора", "оп.")):
            pole_name = f"Опора {pole_name}"

        pole_obj = PoleCIMObject(
            mrid=pole.mrid,
            name=pole_name,
            location=location_ref,
            parent_object=folder_ref,
            child_objects=[],
            pole_type=getattr(pole, "pole_type", None),
            material=getattr(pole, "material", None),
            height=getattr(pole, "height", None),
            asset_power_system_resource=cim_ref(power_line.mrid),
        )
        cim_objects.append(pole_obj)
        pole_child_refs.append(cim_ref(pole.mrid))

    poles_folder_obj = FolderCIMObject(
        mrid=folder_mrid,
        name=f"Опоры {power_line.name}",
        child_objects=pole_child_refs,
        creating_node=None,
        parent_object=cim_ref(power_line.mrid),
    )
    cim_objects.append(poles_folder_obj)

    pl_parent = cim_ref(line_parent_folder_mrid) if line_parent_folder_mrid else None
    line_obj = PowerLineCIMObject(
        mrid=power_line.mrid,
        name=power_line.name,
        acline_segments=[],
        base_voltage=None,
        extra_child_objects=[cim_ref(folder_mrid)],
        parent_object=pl_parent,
        region=cim_ref(sub_geographical_region_mrid) if sub_geographical_region_mrid else None,
        connectivity_nodes=[],
    )
    cim_objects.insert(0, line_obj)
    return cim_objects


def _power_line_to_cim(
    power_line: PowerLine,
    include_equipment: bool = True,
    include_gps: bool = True,
    line_parent_folder_mrid: Optional[str] = None,
    sub_geographical_region_mrid: Optional[str] = None,
    include_electrical_model: bool = True,
    include_defects: bool = True,
) -> List[CIMObject]:
    """
    Преобразование модели PowerLine в список CIM объектов
    Возвращает список объектов: Line, ACLineSegment, LineSection, Span, ConnectivityNode, Location, PositionPoint, BaseVoltage, WireInfo, Terminal
    """
    if not include_electrical_model:
        return _power_line_to_cim_geometry_only(
            power_line,
            include_gps=include_gps,
            line_parent_folder_mrid=line_parent_folder_mrid,
            sub_geographical_region_mrid=sub_geographical_region_mrid,
        )
    cim_objects = []
    cn_line_parent = cim_ref(power_line.mrid)
    connectivity_node_terminal_refs: Dict[str, List[Dict[str, str]]] = defaultdict(list)
    shared_registry: Dict[tuple[str, str], Dict[str, str]] = {}
    exported_equipment_refs: List[Dict[str, str]] = []

    def _ensure_named_shared_object(cim_class: str, name: str) -> Dict[str, str]:
        key = (cim_class, name)
        if key not in shared_registry:
            obj = GenericNamedCIMObject(
                mrid=generate_mrid(),
                name=name,
                cim_class=cim_class,
            )
            cim_objects.append(obj)
            shared_registry[key] = cim_ref(obj.mrid)
        return shared_registry[key]

    base_voltage_resource = base_voltage_resource_by_kv(getattr(power_line, "voltage_level", None))
    base_voltage_ref = external_resource_ref(base_voltage_resource) if base_voltage_resource else None

    line_psr_type_ref = None
    
    # 2. Создаём ConnectivityNode для «реальных» узлов (подстанции и отпаечные опоры).
    # Узлы, связанные только с обычными опорами (промежуточные точки линии), считаем
    # виртуальными для CIM и не экспортируем их.
    connectivity_nodes_dict = {}  # mrid -> ConnectivityNodeCIMObject
    
    # 3. Обрабатываем ACLineSegment с полной структурой
    acline_segments_list = []
    
    for segment in power_line.acline_segments:
        # Создаём ConnectivityNode для from_node и to_node
        from_node_ref = None
        to_node_ref = None
        
        if segment.from_node:
            # Экспортируем только реальные CN (не виртуальные): подстанция, отпаечная опора, оборудование
            from_pole = getattr(segment.from_node, "pole", None)
            is_real_cn = bool(getattr(segment.from_node, "substation_id", None))
            if from_pole is not None:
                is_real_cn = is_real_cn or bool(getattr(from_pole, "is_tap_pole", False))
            is_real_cn = is_real_cn and not getattr(segment.from_node, "is_virtual", False)
            if is_real_cn and segment.from_node.mrid not in connectivity_nodes_dict:
                # Создаём Location и PositionPoint для опоры
                cn = ConnectivityNodeCIMObject(
                    mrid=segment.from_node.mrid,
                    name=segment.from_node.name or f"Узел {segment.from_node.mrid}",
                    location=None,
                    parent_object=cn_line_parent,
                    connectivity_node_container=cim_ref(power_line.mrid),
                )
                connectivity_nodes_dict[segment.from_node.mrid] = cn
                cim_objects.append(cn)
            
            from_node_ref = cim_ref(segment.from_node.mrid) if is_real_cn else None
        
        if segment.to_node:
            to_pole = getattr(segment.to_node, "pole", None)
            is_real_cn = bool(getattr(segment.to_node, "substation_id", None))
            if to_pole is not None:
                is_real_cn = is_real_cn or bool(getattr(to_pole, "is_tap_pole", False))
            is_real_cn = is_real_cn and not getattr(segment.to_node, "is_virtual", False)
            if is_real_cn and segment.to_node.mrid not in connectivity_nodes_dict:
                # Создаём Location и PositionPoint для опоры
                cn = ConnectivityNodeCIMObject(
                    mrid=segment.to_node.mrid,
                    name=segment.to_node.name or f"Узел {segment.to_node.mrid}",
                    location=None,
                    parent_object=cn_line_parent,
                    connectivity_node_container=cim_ref(power_line.mrid),
                )
                connectivity_nodes_dict[segment.to_node.mrid] = cn
                cim_objects.append(cn)
            
            to_node_ref = cim_ref(segment.to_node.mrid) if is_real_cn else None
        
        # Обрабатываем LineSection с Span
        line_sections_list = []
        segment_span_objs: List = []
        for line_section in segment.line_sections:
            # Создаём WireInfo (если есть параметры провода)
            wire_info_ref = None
            if line_section.conductor_type or line_section.conductor_material:
                wire_info = WireInfoCIMObject(
                    mrid=generate_mrid(),
                    name=line_section.conductor_type or "Unknown",
                    material=line_section.conductor_material or "Unknown",
                    section=float(line_section.conductor_section) if line_section.conductor_section else 0.0,
                    r=line_section.r,
                    x=line_section.x,
                    b=line_section.b,
                    g=line_section.g
                )
                cim_objects.append(wire_info)
                wire_info_ref = {"mRID": wire_info.mrid}
            
            # Обрабатываем Span
            spans_list = []
            for span in line_section.spans:
                # Создаём ConnectivityNode для опор пролёта (если ещё не созданы).
                # Аналогично выше, экспортируем только реальные узлы (ПС и отпаечные опоры).
                span_from_node_ref = None
                span_to_node_ref = None
                
                if span.from_connectivity_node:
                    from_pole = getattr(span.from_connectivity_node, "pole", None)
                    is_real_cn = bool(getattr(span.from_connectivity_node, "substation_id", None))
                    if from_pole is not None:
                        is_real_cn = is_real_cn or bool(getattr(from_pole, "is_tap_pole", False))
                    is_real_cn = is_real_cn and not getattr(span.from_connectivity_node, "is_virtual", False)
                    if is_real_cn and span.from_connectivity_node.mrid not in connectivity_nodes_dict:
                        cn = ConnectivityNodeCIMObject(
                            mrid=span.from_connectivity_node.mrid,
                            name=span.from_connectivity_node.name or f"Узел {span.from_connectivity_node.mrid}",
                            location=None,
                            parent_object=cn_line_parent,
                            connectivity_node_container=cim_ref(power_line.mrid),
                        )
                        connectivity_nodes_dict[span.from_connectivity_node.mrid] = cn
                        cim_objects.append(cn)
                    
                    span_from_node_ref = cim_ref(span.from_connectivity_node.mrid) if is_real_cn else None
                
                if span.to_connectivity_node:
                    to_pole = getattr(span.to_connectivity_node, "pole", None)
                    is_real_cn = bool(getattr(span.to_connectivity_node, "substation_id", None))
                    if to_pole is not None:
                        is_real_cn = is_real_cn or bool(getattr(to_pole, "is_tap_pole", False))
                    is_real_cn = is_real_cn and not getattr(span.to_connectivity_node, "is_virtual", False)
                    if is_real_cn and span.to_connectivity_node.mrid not in connectivity_nodes_dict:
                        cn = ConnectivityNodeCIMObject(
                            mrid=span.to_connectivity_node.mrid,
                            name=span.to_connectivity_node.name or f"Узел {span.to_connectivity_node.mrid}",
                            location=None,
                            parent_object=cn_line_parent,
                            connectivity_node_container=cim_ref(power_line.mrid),
                        )
                        connectivity_nodes_dict[span.to_connectivity_node.mrid] = cn
                        cim_objects.append(cn)
                    
                    span_to_node_ref = cim_ref(span.to_connectivity_node.mrid) if is_real_cn else None
                
                # its:LineSpan — пролёт под ACLineSegment (см. профиль intechs)
                wire_type = (span.conductor_type or line_section.conductor_type or "").strip() or None
                span_obj = LineSpanCIMObject(
                    mrid=span.mrid,
                    name=span.span_number,
                    description=getattr(span, "notes", None),
                    length=span.length,
                    from_node=span_from_node_ref,
                    to_node=span_to_node_ref,
                    a_wire_type_name=wire_type,
                    b_wire_type_name=wire_type,
                    c_wire_type_name=wire_type,
                    is_from_substation=bool(getattr(span.from_connectivity_node, "substation_id", None)) if span.from_connectivity_node else None,
                    is_to_substation=bool(getattr(span.to_connectivity_node, "substation_id", None)) if span.to_connectivity_node else None,
                    parent_object=cim_ref(segment.mrid),
                    start_tower=_pole_ref_from_connectivity_node(span.from_connectivity_node),
                    end_tower=_pole_ref_from_connectivity_node(span.to_connectivity_node),
                    line_ref=cim_ref(power_line.mrid),
                    acline_segment_ref=cim_ref(segment.mrid),
                    switches=[],
                )
                spans_list.append(span_obj)
                segment_span_objs.append(span_obj)
                cim_objects.append(span_obj)
            
            # Создаём LineSection объект
            line_section_obj = LineSectionCIMObject(
                mrid=line_section.mrid,
                name=line_section.name,
                conductor_type=line_section.conductor_type,
                conductor_material=line_section.conductor_material,
                conductor_section=line_section.conductor_section,
                r=line_section.r,
                x=line_section.x,
                b=line_section.b,
                g=line_section.g,
                total_length=line_section.total_length,
                wire_info=wire_info_ref,
                spans=[cim_ref(s.mrid) for s in spans_list],
                parent_object=cim_ref(segment.mrid),
                section_number=getattr(line_section, "sequence_number", None),
                r0=line_section.r,
                x0=line_section.x,
                bch=line_section.b,
                b0ch=0.0,
                gch=line_section.g,
                g0ch=0.0,
                is_cable=False,
                short_circuit_end_temperature=None,
                t_th=None,
                section_type=line_section.conductor_type,
            )
            line_sections_list.append(line_section_obj)
            cim_objects.append(line_section_obj)
        
        # Создаём Terminal для сегмента (если есть)
        terminals_list = []
        for terminal in segment.terminals:
            terminal_cn_ref = None
            if terminal.connectivity_node:
                if terminal.connectivity_node.mrid not in connectivity_nodes_dict:
                    # Создаём ConnectivityNode для терминала
                    cn = ConnectivityNodeCIMObject(
                        mrid=terminal.connectivity_node.mrid,
                        name=terminal.connectivity_node.name or f"Узел {terminal.connectivity_node.mrid}",
                        location=None,
                        parent_object=cn_line_parent,
                        connectivity_node_container=cim_ref(power_line.mrid),
                    )
                    connectivity_nodes_dict[terminal.connectivity_node.mrid] = cn
                    cim_objects.append(cn)
                
                terminal_cn_ref = cim_ref(terminal.connectivity_node.mrid)
            
            terminal_obj = TerminalCIMObject(
                mrid=terminal.mrid,
                name=terminal.name,
                connectivity_node=terminal_cn_ref,
                conducting_equipment=cim_ref(segment.mrid),
                sequence_number=terminal.sequence_number,
                parent_object=cim_ref(segment.mrid),
            )
            terminals_list.append(terminal_obj)
            cim_objects.append(terminal_obj)
            if terminal.connectivity_node and getattr(terminal.connectivity_node, "mrid", None):
                connectivity_node_terminal_refs[terminal.connectivity_node.mrid].append(cim_ref(terminal.mrid))
        
        series_refs = [cim_ref(ls.mrid) for ls in line_sections_list]
        term_refs = [cim_ref(t.mrid) for t in terminals_list]
        seg_child_refs: List[Dict[str, str]] = []
        seg_child_refs.extend(series_refs)
        seg_child_refs.extend(term_refs)
        for sp in segment_span_objs:
            seg_child_refs.append(cim_ref(sp.mrid))
        if from_node_ref:
            seg_child_refs.append(from_node_ref)
        if to_node_ref:
            seg_child_refs.append(to_node_ref)

        segment_obj = AClineSegmentCIMObject(
            mrid=segment.mrid,
            name=segment.name or segment.code,
            from_node=from_node_ref,
            to_node=to_node_ref,
            length=segment.length,
            r=segment.r,
            x=segment.x,
            b=segment.b,
            g=segment.g,
            parent_object=cim_ref(power_line.mrid),
            description=getattr(segment, "description", None),
            child_object_refs=seg_child_refs,
            series_section_refs=series_refs,
            terminal_refs=term_refs,
            r0=segment.r,
            x0=segment.x,
            bch=segment.b,
            b0ch=0.0,
            gch=segment.g,
            g0ch=0.0,
            model_detail="2",
            sections_blob=None,
            normally_in_service=getattr(segment, "normally_in_service", True),
            equipment_container=cim_ref(power_line.mrid),
            base_voltage=base_voltage_ref,
        )
        acline_segments_list.append(cim_ref(segment.mrid))
        cim_objects.append(segment_obj)
    
    # 3. Экспорт оборудования (ConductingEquipment) и его терминалов.
    # Оборудование создаёт отдельные Terminal записи на ConnectivityNode (Pole),
    # но эти Terminal'ы могут быть не привязаны к AClineSegment.terminals,
    # поэтому без отдельной обработки они не попадут в CIM выгрузку.
    if include_equipment:
        try:
            # Оборудование хранится на Pole (Pole.equipment), а не на PowerLine.
            # Поэтому заполняем словарь оборудования через ConnectivityNode->pole.
            equipment_by_id: Dict[int, Equipment] = {}
            equipment_cn_map: Dict[int, List[ConnectivityNode]] = defaultdict(list)

            def _parse_equipment_id_from_terminal_desc(desc: Optional[str]) -> Optional[int]:
                if not desc:
                    return None
                low = desc.lower()
                if "equipment_id=" not in low:
                    return None
                try:
                    part = low.split("equipment_id=", 1)[1]
                    num_str = ""
                    for ch in part:
                        if ch.isdigit():
                            num_str += ch
                        else:
                            break
                    return int(num_str) if num_str else None
                except Exception:
                    return None

            exported_terminals_mrids: set[str] = set()
            exported_equipment_ids: set[int] = set()
            equipment_objects_by_id: Dict[int, ConductingEquipmentCIMObject] = {}

            # Соберём ORM-объекты ConnectivityNode, чтобы вытащить из них Terminal'ы оборудования.
            cn_orm_by_id: Dict[int, ConnectivityNode] = {}
            for segment in power_line.acline_segments:
                if getattr(segment, "from_node", None) is not None:
                    cn = segment.from_node
                    cn_id = getattr(cn, "id", None)
                    if cn_id is not None:
                        cn_orm_by_id[int(cn_id)] = cn
                if getattr(segment, "to_node", None) is not None:
                    cn = segment.to_node
                    cn_id = getattr(cn, "id", None)
                    if cn_id is not None:
                        cn_orm_by_id[int(cn_id)] = cn

            for cn in cn_orm_by_id.values():
                pole = getattr(cn, "pole", None)
                for eq in getattr(pole, "equipment", None) or []:
                    eq_id = getattr(eq, "id", None)
                    if eq_id is None:
                        continue
                    if not is_cim_exportable_equipment(getattr(eq, "equipment_type", None)):
                        continue
                    equipment_by_id[int(eq_id)] = eq
                    equipment_cn_map[int(eq_id)].append(cn)

            def _ensure_connectivity_node_exported(cn: ConnectivityNode) -> None:
                cn_mrid = getattr(cn, "mrid", None)
                if not cn_mrid or cn_mrid in connectivity_nodes_dict:
                    return
                cn_obj = ConnectivityNodeCIMObject(
                    mrid=cn_mrid,
                    name=getattr(cn, "name", None) or f"Узел {cn_mrid}",
                    location=None,
                    parent_object=cn_line_parent,
                    connectivity_node_container=cim_ref(power_line.mrid),
                )
                connectivity_nodes_dict[cn_mrid] = cn_obj
                cim_objects.append(cn_obj)

            def _ensure_equipment_exported(eq_id: int) -> None:
                if eq_id in exported_equipment_ids:
                    return
                eq = equipment_by_id[eq_id]
                profile = map_equipment_type_to_cim_profile(getattr(eq, "equipment_type", None))
                eq_type_normalized = normalize_equipment_type(getattr(eq, "equipment_type", None))
                eq_psr_type_ref = (
                    external_resource_ref(DISCONNECTOR_PSR_TYPE_RESOURCE)
                    if eq_type_normalized == "disconnector"
                    else None
                )

                conducting_eq = ConductingEquipmentCIMObject(
                    mrid=eq.mrid,
                    name=eq.name,
                    equipment_type=getattr(eq, "equipment_type", None),
                    location=None,
                    parent_object=cim_ref(power_line.mrid),
                    equipment_container=cim_ref(power_line.mrid),
                    base_voltage=base_voltage_ref,
                    psr_type=eq_psr_type_ref,
                    control_area=None,
                    normal_in_service=True,
                    cim_class=profile.cim_class,
                    defect_note=(getattr(eq, "defect", None) or None) if include_defects else None,
                    criticality=(getattr(eq, "criticality", None) or None) if include_defects else None,
                )
                cim_objects.append(conducting_eq)
                equipment_objects_by_id[eq_id] = conducting_eq
                exported_equipment_ids.add(eq_id)
                exported_equipment_refs.append(cim_ref(eq.mrid))

            for eq_id in sorted(equipment_by_id.keys()):
                _ensure_equipment_exported(eq_id)

            for cn in cn_orm_by_id.values():
                for term in getattr(cn, "terminals", None) or []:
                    # Нам нужны терминалы оборудования, которые не привязаны к AClineSegment.
                    if getattr(term, "acline_segment_id", None) is not None:
                        continue
                    eq_id = _parse_equipment_id_from_terminal_desc(getattr(term, "description", None))
                    if eq_id is None:
                        continue
                    if eq_id not in equipment_by_id:
                        continue
                    if getattr(term, "mrid", None) in exported_terminals_mrids:
                        continue

                    eq = equipment_by_id[eq_id]
                    _ensure_equipment_exported(eq_id)
                    _ensure_connectivity_node_exported(cn)

                    conducting_eq_ref = cim_ref(eq.mrid)
                    term_mrid = getattr(term, "mrid", None)
                    if not term_mrid:
                        continue

                    term_obj = TerminalCIMObject(
                        mrid=term_mrid,
                        name=getattr(term, "name", None),
                        connectivity_node=cim_ref(cn.mrid),
                        conducting_equipment=conducting_eq_ref,
                        sequence_number=getattr(term, "sequence_number", None),
                        parent_object=conducting_eq_ref,
                    )
                    cim_objects.append(term_obj)
                    connectivity_node_terminal_refs[cn.mrid].append(cim_ref(term_mrid))
                    if eq_id in equipment_objects_by_id:
                        equipment_objects_by_id[eq_id].terminal_refs.append(cim_ref(term_mrid))
                        equipment_objects_by_id[eq_id].child_object_refs.append(cim_ref(term_mrid))
                    exported_terminals_mrids.add(term_mrid)

            for eq_id, eq in equipment_by_id.items():
                eq_obj = equipment_objects_by_id.get(eq_id)
                if eq_obj is None or eq_obj.terminal_refs:
                    continue
                profile = map_equipment_type_to_cim_profile(getattr(eq, "equipment_type", None))
                candidate_cns = equipment_cn_map.get(eq_id, [])
                unique_cns: List[ConnectivityNode] = []
                seen_cn_ids: set[int] = set()
                for cn in candidate_cns:
                    cn_id = getattr(cn, "id", None)
                    if cn_id is None or int(cn_id) in seen_cn_ids:
                        continue
                    seen_cn_ids.add(int(cn_id))
                    unique_cns.append(cn)

                for index, cn in enumerate(unique_cns[: profile.terminal_count], start=1):
                    _ensure_connectivity_node_exported(cn)
                    term_mrid = generate_mrid()
                    term_ref = cim_ref(term_mrid)
                    term_obj = TerminalCIMObject(
                        mrid=term_mrid,
                        name=f"T{index}",
                        connectivity_node=cim_ref(cn.mrid),
                        conducting_equipment=cim_ref(eq.mrid),
                        sequence_number=index,
                        parent_object=cim_ref(eq.mrid),
                    )
                    cim_objects.append(term_obj)
                    eq_obj.terminal_refs.append(term_ref)
                    eq_obj.child_object_refs.append(term_ref)
                    connectivity_node_terminal_refs[cn.mrid].append(term_ref)
                    exported_terminals_mrids.add(term_mrid)
        except Exception as _equip_ex:
            import logging
            logging.getLogger(__name__).exception(
                "Equipment export failed for line_id=%s (skipping equipment in CIM XML): %s",
                getattr(power_line, "id", None),
                str(_equip_ex),
            )

    # 4. Экспорт папки опор и самих опор (Monitel extension me:Folder/me:Pole)
    poles_by_id: Dict[int, Pole] = {}
    # На одной опоре может быть один CN, но он встречается в нескольких сегментах/пролётах — только уникальные mRID.
    pole_cn_mrids: Dict[int, set] = defaultdict(set)
    for segment in power_line.acline_segments:
        for cn in (getattr(segment, "from_node", None), getattr(segment, "to_node", None)):
            p = getattr(cn, "pole", None)
            p_id = getattr(p, "id", None)
            if p is not None and p_id is not None:
                poles_by_id[int(p_id)] = p
                m = getattr(cn, "mrid", None)
                if m:
                    pole_cn_mrids[int(p_id)].add(m)
        for line_section in getattr(segment, "line_sections", None) or []:
            for span in getattr(line_section, "spans", None) or []:
                fcn = getattr(span, "from_connectivity_node", None)
                tcn = getattr(span, "to_connectivity_node", None)
                fp = getattr(fcn, "pole", None)
                tp = getattr(tcn, "pole", None)
                fp_id = getattr(fp, "id", None)
                tp_id = getattr(tp, "id", None)
                if fp is not None and fp_id is not None:
                    poles_by_id[int(fp_id)] = fp
                    m = getattr(fcn, "mrid", None)
                    if m:
                        pole_cn_mrids[int(fp_id)].add(m)
                if tp is not None and tp_id is not None:
                    poles_by_id[int(tp_id)] = tp
                    m = getattr(tcn, "mrid", None)
                    if m:
                        pole_cn_mrids[int(tp_id)].add(m)

    folder_mrid = generate_mrid()
    folder_ref = cim_ref(folder_mrid)
    pole_child_refs: List[Dict[str, str]] = []

    # Добавляем объекты опор перед объектом папки.
    for pole in sorted(poles_by_id.values(), key=lambda p: (getattr(p, "sequence_number", 0) or 0, getattr(p, "id", 0))):
        pole_name = (getattr(pole, "pole_number", None) or f"Опора {pole.id}").strip()
        if not pole_name.lower().startswith(("опора", "оп.")):
            pole_name = f"Опора {pole_name}"

        # ChildObjects опоры: уникальные ConnectivityNode этой опоры на линии.
        child_refs = [cim_ref(m) for m in sorted(pole_cn_mrids.get(int(pole.id), set()))]

        location_ref = None
        if include_gps and getattr(pole, "location", None) is not None:
            location_ref = cim_ref(pole.location.mrid)

        pole_obj = PoleCIMObject(
            mrid=pole.mrid,
            name=pole_name,
            location=location_ref,
            parent_object=folder_ref,
            child_objects=child_refs,
            pole_type=getattr(pole, "pole_type", None),
            material=getattr(pole, "material", None),
            height=getattr(pole, "height", None),
            asset_power_system_resource=cim_ref(power_line.mrid),
        )
        cim_objects.append(pole_obj)
        pole_child_refs.append(cim_ref(pole.mrid))

    creating_node_ref = None
    if power_line.acline_segments:
        first_seg = power_line.acline_segments[0]
        cn = getattr(first_seg, "from_node", None) or getattr(first_seg, "to_node", None)
        if cn is not None and getattr(cn, "mrid", None):
            creating_node_ref = cim_ref(cn.mrid)

    poles_folder_obj = FolderCIMObject(
        mrid=folder_mrid,
        name=f"Опоры {power_line.name}",
        child_objects=pole_child_refs,
        creating_node=creating_node_ref,
        parent_object=cim_ref(power_line.mrid),
    )
    cim_objects.append(poles_folder_obj)

    # 5. Создаём Line объект (родитель — папка ЛЭП в субрегионе)
    pl_parent = cim_ref(line_parent_folder_mrid) if line_parent_folder_mrid else None
    for cn_mrid, cn_obj in connectivity_nodes_dict.items():
        cn_obj.terminal_refs = connectivity_node_terminal_refs.get(cn_mrid, [])
    line_obj = PowerLineCIMObject(
        mrid=power_line.mrid,
        name=power_line.name,
        acline_segments=acline_segments_list,
        base_voltage=base_voltage_ref,
        extra_child_objects=[
            *exported_equipment_refs,
            *[cim_ref(cn_mrid) for cn_mrid in connectivity_nodes_dict.keys()],
            cim_ref(folder_mrid),
        ],
        parent_object=pl_parent,
        psr_type=line_psr_type_ref,
        region=cim_ref(sub_geographical_region_mrid) if sub_geographical_region_mrid else None,
        connectivity_nodes=[cim_ref(cn_mrid) for cn_mrid in connectivity_nodes_dict.keys()],
    )
    cim_objects.insert(0, line_obj)  # Line должен быть первым

    return cim_objects


@router.get("/export/xml")
async def export_cim_xml(
    use_cimpy: bool = Query(
        False,
        description="Устарело: игнорируется. Полный 552 diff / дерево gm: собирается только ручным пайплайном (не CIMpy).",
    ),
    include_substations: bool = Query(True, description="Включить подстанции"),
    include_power_lines: bool = Query(True, description="Включить ЛЭП"),
    include_equipment: bool = Query(True, description="Включить оборудование"),
    include_gps: bool = Query(True, description="Включить координаты GPS (Location/PositionPoint)"),
    line_id: Optional[int] = Query(None, description="Экспортировать только указанную ЛЭП (id)"),
    ensure_topology: bool = Query(
        True,
        description="При экспорте одной ЛЭП (line_id): если нет ACLineSegment, выполнить автосборку пролётов (preserve)",
    ),
    export_preset: Optional[str] = Query(
        None,
        description="Пресет: full, coordinates_only, no_equipment, without_defects (переопределяет часть флагов)",
    ),
    include_electrical_model: bool = Query(
        True,
        description="Включить электрическую модель ЛЭП (сегменты, узлы). False — только геометрия опор",
    ),
    include_defects: bool = Query(True, description="Включать в CIM поля дефектов оборудования (если есть в БД)"),
    include_substation_voltage_levels: bool = Query(
        True,
        description="Экспортировать уровни напряжения подстанции (VoltageLevel)",
    ),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Экспорт данных в CIM XML формат (RDF/XML)
    Соответствует стандартам IEC 61970-301 и IEC 61970-552:2016
    
    Всегда используется ручная сборка (_manual_cim_objects_list): dm:DifferenceModel, дерево gm:, LineSpan, оборудование.
    Параметр use_cimpy в запросе игнорируется — CIMpy даёт урезанный XML без целевого профиля обмена.
    """
    (
        include_gps,
        include_equipment,
        include_electrical_model,
        include_defects,
        include_substation_voltage_levels,
    ) = _apply_export_preset(
        export_preset,
        include_gps=include_gps,
        include_equipment=include_equipment,
        include_electrical_model=include_electrical_model,
        include_defects=include_defects,
        include_substation_voltage_levels=include_substation_voltage_levels,
    )

    substations_list = []
    power_lines_list = []
    cim_topology_ensure: Optional[str] = None

    # CIMpy не используем: иначе при include_equipment=false клиент получал бы «обрезанный» FullModel без дерева импорта.
    use_cimpy = False

    # Без ACLineSegment в XML попадут только Line/BaseVoltage; при частичном экспорте — автосборка пролётов.
    if include_power_lines and line_id is not None and ensure_topology and include_electrical_model:
        seg_cnt = await db.scalar(
            select(func.count()).select_from(AClineSegment).where(AClineSegment.line_id == line_id)
        ) or 0
        if seg_cnt == 0:
            try:
                from app.api.v1.power_lines import auto_create_spans_service

                await auto_create_spans_service(db, line_id, current_user, mode="preserve")
                cim_topology_ensure = "rebuilt"
                # После commit внутри автосборки сбрасываем кэш сессии, чтобы выборка ЛЭП подтянула новые сегменты.
                await db.expire_all()
            except HTTPException as ex:
                if ex.status_code == status.HTTP_400_BAD_REQUEST:
                    logging.getLogger(__name__).warning(
                        "CIM export: topology not rebuilt for line_id=%s: %s",
                        line_id,
                        ex.detail,
                    )
                    cim_topology_ensure = "skipped_no_span_pairs"
                else:
                    raise
    
    # Загружаем подстанции
    if include_substations:
        sub_opts = [selectinload(Substation.location).selectinload(Location.position_points)]
        if include_substation_voltage_levels:
            sub_opts.insert(0, selectinload(Substation.voltage_levels))
        result = await db.execute(
            select(Substation)
            .where(Substation.is_active == True)
            .options(*sub_opts)
        )
        substations_list = result.scalars().all()
    
    # Загружаем ЛЭП с полной структурой (LineSection, Span, ConnectivityNode, Location)
    if include_power_lines:
        power_line_query = select(PowerLine)
        if line_id is not None:
            power_line_query = power_line_query.where(PowerLine.id == line_id)
        if not include_electrical_model:
            result = await db.execute(
                power_line_query.options(
                    selectinload(PowerLine.poles)
                    .selectinload(Pole.location)
                    .selectinload(Location.position_points),
                )
            )
        else:
            result = await db.execute(
                power_line_query.options(
                selectinload(PowerLine.acline_segments)
                .selectinload(AClineSegment.from_node)
                .selectinload(ConnectivityNode.terminals),
                selectinload(PowerLine.acline_segments)
                .selectinload(AClineSegment.from_node)
                .selectinload(ConnectivityNode.pole)
                .selectinload(Pole.position_points),
                # Для CIM property PowerSystemResource.Location нам важно загружать Pole.location,
                # чтобы не приходилось подставлять синтетические Location/PositionPoint.
                selectinload(PowerLine.acline_segments)
                .selectinload(AClineSegment.from_node)
                .selectinload(ConnectivityNode.pole)
                .selectinload(Pole.location)
                .selectinload(Location.position_points),
                selectinload(PowerLine.acline_segments)
                .selectinload(AClineSegment.from_node)
                .selectinload(ConnectivityNode.pole)
                .selectinload(Pole.equipment)
                .selectinload(Equipment.location)
                .selectinload(Location.position_points),
                selectinload(PowerLine.acline_segments)
                .selectinload(AClineSegment.to_node)
                .selectinload(ConnectivityNode.terminals),
                selectinload(PowerLine.acline_segments)
                .selectinload(AClineSegment.to_node)
                .selectinload(ConnectivityNode.pole)
                .selectinload(Pole.position_points),
                # Для CIM property PowerSystemResource.Location также подгружаем Pole.location на to_node.
                selectinload(PowerLine.acline_segments)
                .selectinload(AClineSegment.to_node)
                .selectinload(ConnectivityNode.pole)
                .selectinload(Pole.location)
                .selectinload(Location.position_points),
                selectinload(PowerLine.acline_segments)
                .selectinload(AClineSegment.to_node)
                .selectinload(ConnectivityNode.pole)
                .selectinload(Pole.equipment)
                .selectinload(Equipment.location)
                .selectinload(Location.position_points),
                # В модели PowerLine нет relationship `equipment`,
                # оборудование хранится на уровне Pole (Pole.equipment),
                # поэтому тут не загружаем PowerLine.equipment.
                selectinload(PowerLine.acline_segments)
                .selectinload(AClineSegment.line_sections)
                .selectinload(LineSection.spans)
                .selectinload(Span.from_connectivity_node)
                .selectinload(ConnectivityNode.pole)
                .selectinload(Pole.position_points),
                selectinload(PowerLine.acline_segments)
                .selectinload(AClineSegment.line_sections)
                .selectinload(LineSection.spans)
                .selectinload(Span.to_connectivity_node)
                .selectinload(ConnectivityNode.pole)
                .selectinload(Pole.position_points),
                selectinload(PowerLine.acline_segments)
                .selectinload(AClineSegment.terminals)
                .selectinload(Terminal.connectivity_node)
            )
            )
        power_lines_list = result.scalars().all()

    # Если экспортируем только одну ЛЭП — ограничиваем и подстанции старт/финиш.
    if line_id is not None and include_substations and include_power_lines:
        # Частичный экспорт должен включать не только "начало/конец",
        # но и все подстанции, которые участвуют в отпайках выбранной ЛЭП.
        final_station_ids: set[int] = set()
        for pl in power_lines_list:
            if getattr(pl, "substation_start_id", None) is not None:
                final_station_ids.add(int(pl.substation_start_id))
            if getattr(pl, "substation_end_id", None) is not None:
                final_station_ids.add(int(pl.substation_end_id))

            for seg in getattr(pl, "acline_segments", None) or []:
                # Отпайка, заканчивающаяся на подстанции/КТП
                if getattr(seg, "to_substation_id", None) is not None:
                    final_station_ids.add(int(seg.to_substation_id))
                # Подстанция может быть задана и на ConnectivityNode
                fn = getattr(seg, "from_node", None)
                tn = getattr(seg, "to_node", None)
                if fn is not None and getattr(fn, "substation_id", None) is not None:
                    final_station_ids.add(int(fn.substation_id))
                if tn is not None and getattr(tn, "substation_id", None) is not None:
                    final_station_ids.add(int(tn.substation_id))

        substations_list = [s for s in substations_list if getattr(s, "id", None) in final_station_ids]
    
    # Экспорт в XML
    logger = logging.getLogger(__name__)
    cim_export_degraded: Optional[str] = None

    try:
        def _build_cim_objects(with_equipment: bool) -> List[CIMObject]:
            return _manual_cim_objects_list(
                substations_list,
                power_lines_list,
                include_gps=include_gps,
                include_equipment=with_equipment,
                include_electrical_model=include_electrical_model,
                include_defects=include_defects,
                include_substation_voltage_levels=include_substation_voltage_levels,
            )

        exporter = CIMXMLExporter()
        try:
            cim_objects = _build_cim_objects(with_equipment=include_equipment)
            xml_content = exporter.export(
                cim_objects,
                wrap_as_difference_model=True,
            )
        except Exception as export_err:
            # Частичный ретрай: если оборудование ломает пайплайн сборки/сериализации,
            # попробуем повторить выгрузку без оборудования.
            if include_equipment:
                logger.error(
                    "CIM XML export failed with include_equipment=true; retrying without equipment: %s",
                    str(export_err),
                    exc_info=True,
                )
                cim_objects_retry = _build_cim_objects(with_equipment=False)
                exporter = CIMXMLExporter()
                xml_content = exporter.export(
                    cim_objects_retry,
                    wrap_as_difference_model=True,
                )
                cim_export_degraded = "equipment-omitted"
            else:
                raise
    except HTTPException:
        # Пробрасываем HTTP исключения как есть
        raise
    except Exception as e:
        # Обработка всех остальных ошибок
        logger.error(f"Ошибка при экспорте CIM XML: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Ошибка при экспорте CIM XML: {type(e).__name__}: {str(e)}"
        )
    
    out_headers: Dict[str, str] = {
        "Content-Disposition": f'attachment; filename="cim_export_{datetime.now().strftime("%Y%m%d_%H%M%S")}.xml"'
    }
    if cim_export_degraded:
        out_headers["X-CIM-Export-Degraded"] = cim_export_degraded
    if cim_topology_ensure:
        out_headers["X-CIM-Topology-Ensure"] = cim_topology_ensure

    return Response(
        content=xml_content,
        media_type="application/xml",
        headers=out_headers,
    )


@router.get("/export/json")
async def export_cim_json(
    include_substations: bool = Query(True, description="Включить подстанции"),
    include_power_lines: bool = Query(True, description="Включить ЛЭП"),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Экспорт данных в CIM JSON формат
    """
    cim_objects = []
    
    # Экспорт подстанций
    if include_substations:
        result = await db.execute(
            select(Substation)
            .where(Substation.is_active == True)
            .options(
                selectinload(Substation.voltage_levels),
                selectinload(Substation.location).selectinload(Location.position_points)
            )
        )
        substations = result.scalars().all()
        
        for substation in substations:
            cim_objects.append(_substation_to_cim(substation))
    
    # Экспорт ЛЭП
    if include_power_lines:
        result = await db.execute(
            select(PowerLine)
            .options(
                selectinload(PowerLine.acline_segments)
                .selectinload(AClineSegment.from_node),
                selectinload(PowerLine.acline_segments)
                .selectinload(AClineSegment.to_node)
            )
        )
        power_lines = result.scalars().all()
        
        for power_line in power_lines:
            # _power_line_to_cim возвращает список объектов
            cim_objects.extend(_power_line_to_cim(power_line, include_equipment=False))
    
    # Экспорт в JSON
    exporter = CIMJSONExporter()
    json_content = exporter.export(cim_objects)
    
    return Response(
        content=json_content,
        media_type="application/json",
        headers={
            "Content-Disposition": f'attachment; filename="cim_export_{datetime.now().strftime("%Y%m%d_%H%M%S")}.json"'
        }
    )


@router.post("/import/xml")
async def import_cim_xml(
    file: UploadFile = File(..., description="CIM XML файл (FullModel RDF/XML)"),
    current_user: User = Depends(get_current_active_user),
):
    """
    Импорт CIM XML (md:FullModel или dm:DifferenceModel). Парсит файл и возвращает сводку по объектам для предпросмотра.
    """
    if not file.filename or not file.filename.lower().endswith(".xml"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Требуется файл .xml")
    importer = CIMXMLImporter()
    try:
        with tempfile.NamedTemporaryFile(mode="wb", suffix=".xml", delete=False) as tmp:
            content = await file.read()
            tmp.write(content)
            tmp_path = tmp.name
        try:
            objects = importer.import_from_file(tmp_path)
        finally:
            os.unlink(tmp_path)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Ошибка разбора CIM XML: {str(e)}",
        )
    summary: dict = {}
    for obj in objects:
        cls = obj.get("_class") or obj.get("type") or "Unknown"
        summary[cls] = summary.get(cls, 0) + 1
    return {"summary": summary, "count": len(objects), "objects": objects}


@router.get("/export/552-diff")
async def export_cim_552_diff(
    include_substations: bool = Query(True, description="Включить подстанции"),
    include_power_lines: bool = Query(True, description="Включить ЛЭП"),
    include_gps: bool = Query(True, description="Включить координаты GPS"),
    include_equipment: bool = Query(True, description="Включить оборудование"),
    line_id: Optional[int] = Query(None, description="Экспортировать только указанную ЛЭП (id)"),
    ensure_topology: bool = Query(
        True,
        description="При экспорте одной ЛЭП: при отсутствии ACLineSegment выполнить автосборку пролётов (preserve)",
    ),
    export_preset: Optional[str] = Query(None, description="Пресет выгрузки (см. /export/xml)"),
    include_electrical_model: bool = Query(True, description="Включить электрическую модель ЛЭП"),
    include_defects: bool = Query(True, description="Включать поля дефектов оборудования в CIM"),
    include_substation_voltage_levels: bool = Query(True, description="Экспортировать VoltageLevel подстанций"),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Экспорт 552 diff: тот же CIM XML, что и /export/xml (dm:DifferenceModel, PI floatExporter при ручной сборке).
    """
    return await export_cim_xml(
        use_cimpy=False,
        include_substations=include_substations,
        include_power_lines=include_power_lines,
        include_equipment=include_equipment,
        include_gps=include_gps,
        line_id=line_id,
        ensure_topology=ensure_topology,
        export_preset=export_preset,
        include_electrical_model=include_electrical_model,
        include_defects=include_defects,
        include_substation_voltage_levels=include_substation_voltage_levels,
        current_user=current_user,
        db=db,
    )


@router.post("/import/552-diff")
async def import_cim_552_diff(
    file: UploadFile = File(..., description="552 DifferenceModel XML"),
    current_user: User = Depends(get_current_active_user),
):
    """
    Импорт 552 DifferenceModel XML. Парсит файл и возвращает сводку по объектам.
    """
    return await import_cim_xml(file=file, current_user=current_user)


@router.post("/apply/552-diff")
async def apply_cim_552_diff(
    file: UploadFile = File(..., description="552 DifferenceModel XML для записи в БД"),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Применить 552-диф к БД.

    Сейчас в базу реально записываются только **Substation**, **Location** и **PositionPoint**.
    Остальные классы из XML (Line, ACLineSegment, Folder, Pole и т.д.) только разбираются;
    для полного импорта топологии ЛЭП нужна отдельная доработка.
    Ответ содержит `parsed_by_class` и при нулевом создании — поле `hint` с пояснением.
    """
    if not file.filename or not file.filename.lower().endswith(".xml"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Требуется файл .xml")
    importer = CIMXMLImporter()
    try:
        with tempfile.NamedTemporaryFile(mode="wb", suffix=".xml", delete=False) as tmp:
            content = await file.read()
            tmp.write(content)
            tmp_path = tmp.name
        try:
            objects = importer.import_from_file(tmp_path)
        finally:
            os.unlink(tmp_path)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Ошибка разбора XML: {str(e)}",
        )
    by_mrid: dict = {}
    for o in objects:
        m = o.get("mRID") or o.get("mrid")
        if m:
            by_mrid[str(m)] = o

    class_counts = Counter()
    for o in objects:
        cls_name = o.get("_class") or o.get("type") or "Unknown"
        class_counts[str(cls_name)] += 1

    created_locations = 0
    created_position_points = 0
    created_substations = 0

    for obj in objects:
        cls = obj.get("_class") or obj.get("type") or ""
        if cls == "Location":
            mrid = (obj.get("mRID") or obj.get("mrid") or "").strip() or generate_mrid()
            existing = await db.execute(select(Location).where(Location.mrid == mrid))
            if existing.scalar_one_or_none() is None:
                loc = Location(mrid=mrid)
                db.add(loc)
                await db.flush()
                created_locations += 1

    for obj in objects:
        cls = obj.get("_class") or obj.get("type") or ""
        if cls == "PositionPoint":
            x = obj.get("xPosition") or obj.get("XPosition")
            y = obj.get("yPosition") or obj.get("YPosition")
            if x is not None and y is not None:
                mrid = (obj.get("mRID") or obj.get("mrid") or "").strip() or generate_mrid()
                existing = await db.execute(select(PositionPoint).where(PositionPoint.mrid == mrid))
                if existing.scalar_one_or_none() is None:
                    loc_id = None
                    loc_ref = obj.get("Location") or obj.get("location")
                    if isinstance(loc_ref, dict):
                        ref_mrid = (loc_ref.get("mRID") or loc_ref.get("mrid") or "").strip()
                        if ref_mrid:
                            loc_res = await db.execute(select(Location).where(Location.mrid == ref_mrid))
                            loc_inst = loc_res.scalar_one_or_none()
                            if loc_inst:
                                loc_id = loc_inst.id
                    pp = PositionPoint(
                        mrid=mrid,
                        location_id=loc_id,
                        x_position=float(x),
                        y_position=float(y),
                        z_position=obj.get("zPosition") or obj.get("ZPosition"),
                    )
                    db.add(pp)
                    await db.flush()
                    created_position_points += 1

    for obj in objects:
        cls = obj.get("_class") or obj.get("type") or ""
        if cls == "Substation":
            mrid = (obj.get("mRID") or obj.get("mrid") or "").strip() or generate_mrid()
            existing = await db.execute(select(Substation).where(Substation.mrid == mrid))
            if existing.scalar_one_or_none() is None:
                name = (obj.get("name") or "Подстанция").strip() or "Подстанция"
                voltage = 10.0
                try:
                    v = obj.get("nominalVoltage") or obj.get("VoltageLevel")
                    if isinstance(v, dict):
                        v = v.get("nominalVoltage")
                    if v is not None:
                        voltage = float(v)
                except (TypeError, ValueError):
                    pass
                loc_id = None
                loc_ref = obj.get("Location") or obj.get("location")
                if isinstance(loc_ref, dict):
                    ref_mrid = (loc_ref.get("mRID") or loc_ref.get("mrid") or "").strip()
                    if ref_mrid:
                        loc_res = await db.execute(select(Location).where(Location.mrid == ref_mrid))
                        loc_inst = loc_res.scalar_one_or_none()
                        if loc_inst:
                            loc_id = loc_inst.id
                sub = Substation(
                    mrid=mrid,
                    name=name[:100],
                    voltage_level=voltage,
                    location_id=loc_id,
                    is_active=True,
                )
                db.add(sub)
                await db.flush()
                created_substations += 1
    await db.commit()

    total_created = created_substations + created_locations + created_position_points
    hint: Optional[str] = None
    if len(objects) == 0:
        hint = (
            "В XML не найдено ни одного ресурса с rdf:about (ожидаются элементы внутри "
            "dm:forwardDifferences или прямые дочерние rdf:RDF)."
        )
    elif total_created == 0:
        hint = (
            "Эндпоинт apply/552-diff пока записывает в БД только объекты классов "
            "Substation, Location и PositionPoint. "
            "Линии (Line), сегменты (ACLineSegment), папки (Folder), узлы, опоры и прочее "
            "в файле распознаются (см. parsed_by_class), но не создаются в базе."
        )

    return {
        "created_substations": created_substations,
        "created_locations": created_locations,
        "created_position_points": created_position_points,
        "parsed_total": len(objects),
        "parsed_by_class": dict(class_counts),
        "hint": hint,
    }


@router.post("/552/request")
async def cim_552_request(
    purpose: MessagePurpose = Query(..., description="Назначение запроса"),
    receiver_id: str = Query(..., description="ID получателя"),
    object_types: Optional[List[str]] = Query(None, description="Типы объектов для запроса"),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Создание запроса по протоколу IEC 61970-552:2016
    """
    service = CIM552Service(system_id=getattr(settings, 'SYSTEM_ID', 'LEPM_SYSTEM'))
    
    cim_objects = []
    
    # Формируем список объектов в зависимости от purpose
    if purpose == MessagePurpose.GET:
        if not object_types or "Substation" in object_types:
            result = await db.execute(
                select(Substation)
                .where(Substation.is_active == True)
                .options(
                    selectinload(Substation.voltage_levels),
                    selectinload(Substation.location).selectinload(Location.position_points)
                )
            )
            for substation in result.scalars().all():
                cim_objects.append(_substation_to_cim(substation).to_cim_dict())
        
        if not object_types or "Line" in object_types:
            result = await db.execute(
                select(PowerLine)
                .options(
                    selectinload(PowerLine.acline_segments)
                    .selectinload(AClineSegment.from_node),
                    selectinload(PowerLine.acline_segments)
                    .selectinload(AClineSegment.to_node)
                )
            )
            for power_line in result.scalars().all():
                # _power_line_to_cim возвращает список объектов, преобразуем каждый в dict
                power_line_objects = _power_line_to_cim(power_line)
                cim_objects.extend([obj.to_cim_dict() for obj in power_line_objects])
    
    request = service.create_request(
        purpose=purpose,
        receiver_id=receiver_id,
        cim_objects=cim_objects
    )
    
    # Валидация
    is_valid, error = service.validate_message(request)
    if not is_valid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=error
        )
    
    # Преобразуем в XML для отправки
    exporter = CIMXMLExporter()
    xml_content = exporter.export([SubstationCIMObject(mrid="", name="")])  # Заглушка для структуры
    
    return {
        "message": request.to_dict(),
        "xml": xml_content
    }


@router.post("/552/response")
async def cim_552_response(
    request_data: dict,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Обработка ответа по протоколу IEC 61970-552:2016
    """
    from app.core.cim.cim_552_protocol import CIM552Message
    
    service = CIM552Service(system_id=getattr(settings, 'SYSTEM_ID', 'LEPM_SYSTEM'))
    
    # Парсим входящее сообщение
    try:
        request = CIM552Message.from_dict(request_data)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid message format: {str(e)}"
        )
    
    # Валидация
    is_valid, error = service.validate_message(request)
    if not is_valid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=error
        )
    
    # Обрабатываем запрос
    cim_objects = []
    
    if request.message_purpose == MessagePurpose.GET:
        # Получаем запрошенные объекты
        # Здесь можно добавить логику фильтрации по типам объектов
        result = await db.execute(
            select(Substation)
            .where(Substation.is_active == True)
            .options(
                selectinload(Substation.voltage_levels),
                selectinload(Substation.location).selectinload(Location.position_points)
            )
        )
        for substation in result.scalars().all():
            cim_objects.append(_substation_to_cim(substation).to_cim_dict())
    
    # Создаем ответ
    response = service.create_response(
        request=request,
        cim_objects=cim_objects,
        success=True
    )
    
    return response.to_dict()

