"""
API endpoints для экспорта данных в CIM форматы
Соответствует стандартам IEC 61970-301 и IEC 61970-552:2016
"""
from typing import List, Optional, Dict
from datetime import datetime
import tempfile
import os
from fastapi import APIRouter, Depends, HTTPException, status, Query, UploadFile, File
from fastapi.responses import Response, StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from io import BytesIO

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
from app.core.cim.cim_xml_cimpy import CIMpyXMLExporter, CIMPY_AVAILABLE
from app.core.cim.cim_json import CIMJSONExporter
from app.core.cim.cim_552_protocol import CIM552Service, MessagePurpose
from app.core.cim.cim_base import CIMObject
from app.core.config import settings
from app.models.base import generate_mrid
from app.core.cim.cim_objects import (
    SubstationCIMObject,
    VoltageLevelCIMObject,
    BaseVoltageCIMObject,
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
)

router = APIRouter()


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
    for vl in (getattr(substation, "voltage_levels", None) or []):
        vl_obj = VoltageLevelCIMObject(
            mrid=vl.mrid,
            name=vl.name,
            nominal_voltage=vl.nominal_voltage,
            base_voltage=None,
        )
        objects.append(vl_obj)
        voltage_level_refs.append({"mRID": vl_obj.mrid})

    # Location (+ PositionPoints)
    location_ref: Optional[Dict[str, str]] = None
    location_obj: Optional[LocationCIMObject] = None
    if include_gps and getattr(substation, "location", None) is not None:
        loc = substation.location
        pp_refs = [{"mRID": pp.mrid} for pp in (getattr(loc, "position_points", None) or [])]
        location_obj = LocationCIMObject(
            mrid=loc.mrid,
            position_points=pp_refs,
        )
        objects.append(location_obj)
        for pp in getattr(loc, "position_points", None) or []:
            objects.append(
                PositionPointCIMObject(
                    mrid=pp.mrid,
                    x_position=pp.x_position,
                    y_position=pp.y_position,
                    z_position=pp.z_position,
                )
            )
        location_ref = {"mRID": location_obj.mrid}

    substation_obj = SubstationCIMObject(
        mrid=substation.mrid,
        name=substation.name,
        voltage_levels=voltage_level_refs,
        location=location_ref,
    )
    objects.append(substation_obj)

    return objects


def _power_line_to_cim(
    power_line: PowerLine,
    include_equipment: bool = True,
    include_gps: bool = True,
) -> List[CIMObject]:
    """
    Преобразование модели PowerLine в список CIM объектов
    Возвращает список объектов: Line, ACLineSegment, LineSection, Span, ConnectivityNode, Location, PositionPoint, BaseVoltage, WireInfo, Terminal
    """
    cim_objects = []
    
    # 1. Создаём BaseVoltage для линии (если есть voltage_level)
    base_voltage = None
    if power_line.voltage_level:
        base_voltage = BaseVoltageCIMObject(
            mrid=f"BV_{power_line.mrid}",
            name=f"{power_line.voltage_level} кВ",
            nominal_voltage=power_line.voltage_level
        )
        cim_objects.append(base_voltage)
        base_voltage_ref = {"mRID": base_voltage.mrid}
    else:
        base_voltage_ref = None
    
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
                location = None
                if include_gps and from_pole and from_pole.position_points:
                    position_points = []
                    for pp in segment.from_node.pole.position_points:
                        position_points.append({
                            "mRID": pp.mrid,
                            "xPosition": pp.x_position,
                            "yPosition": pp.y_position,
                            "zPosition": pp.z_position if pp.z_position is not None else None
                        })
                    
                    location_mrid = from_pole.location.mrid if from_pole.location else f"LOC_{segment.from_node.mrid}"
                    location = LocationCIMObject(
                        mrid=location_mrid,
                        position_points=position_points
                    )
                    cim_objects.append(location)
                    # Добавляем PositionPoint как отдельные объекты
                    for pp in from_pole.position_points:
                        cim_objects.append(PositionPointCIMObject(
                            mrid=pp.mrid,
                            x_position=pp.x_position,
                            y_position=pp.y_position,
                            z_position=pp.z_position
                        ))
                
                cn = ConnectivityNodeCIMObject(
                    mrid=segment.from_node.mrid,
                    name=segment.from_node.name or f"Узел {segment.from_node.mrid}",
                    location={"mRID": location.mrid} if location else None
                )
                connectivity_nodes_dict[segment.from_node.mrid] = cn
                cim_objects.append(cn)
            
            from_node_ref = {"mRID": segment.from_node.mrid} if is_real_cn else None
        
        if segment.to_node:
            to_pole = getattr(segment.to_node, "pole", None)
            is_real_cn = bool(getattr(segment.to_node, "substation_id", None))
            if to_pole is not None:
                is_real_cn = is_real_cn or bool(getattr(to_pole, "is_tap_pole", False))
            is_real_cn = is_real_cn and not getattr(segment.to_node, "is_virtual", False)
            if is_real_cn and segment.to_node.mrid not in connectivity_nodes_dict:
                # Создаём Location и PositionPoint для опоры
                location = None
                if include_gps and to_pole and to_pole.position_points:
                    position_points = []
                    for pp in segment.to_node.pole.position_points:
                        position_points.append({
                            "mRID": pp.mrid,
                            "xPosition": pp.x_position,
                            "yPosition": pp.y_position,
                            "zPosition": pp.z_position if pp.z_position is not None else None
                        })
                    
                    location_mrid = to_pole.location.mrid if to_pole.location else f"LOC_{segment.to_node.mrid}"
                    location = LocationCIMObject(
                        mrid=location_mrid,
                        position_points=position_points
                    )
                    cim_objects.append(location)
                    # Добавляем PositionPoint как отдельные объекты
                    for pp in to_pole.position_points:
                        cim_objects.append(PositionPointCIMObject(
                            mrid=pp.mrid,
                            x_position=pp.x_position,
                            y_position=pp.y_position,
                            z_position=pp.z_position
                        ))
                
                cn = ConnectivityNodeCIMObject(
                    mrid=segment.to_node.mrid,
                    name=segment.to_node.name or f"Узел {segment.to_node.mrid}",
                    location={"mRID": location.mrid} if location else None
                )
                connectivity_nodes_dict[segment.to_node.mrid] = cn
                cim_objects.append(cn)
            
            to_node_ref = {"mRID": segment.to_node.mrid} if is_real_cn else None
        
        # Обрабатываем LineSection с Span
        line_sections_list = []
        for line_section in segment.line_sections:
            # Создаём WireInfo (если есть параметры провода)
            wire_info_ref = None
            if line_section.conductor_type or line_section.conductor_material:
                wire_info = WireInfoCIMObject(
                    mrid=f"WI_{line_section.mrid}",
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
                        location = None
                        if include_gps and from_pole and from_pole.position_points:
                            position_points = []
                            for pp in span.from_connectivity_node.pole.position_points:
                                position_points.append({
                                    "mRID": pp.mrid,
                                    "xPosition": pp.x_position,
                                    "yPosition": pp.y_position,
                                    "zPosition": pp.z_position if pp.z_position is not None else None
                                })
                            
                            location_mrid = from_pole.location.mrid if from_pole.location else f"LOC_{span.from_connectivity_node.mrid}"
                            location = LocationCIMObject(
                                mrid=location_mrid,
                                position_points=position_points
                            )
                            cim_objects.append(location)
                            for pp in from_pole.position_points:
                                cim_objects.append(PositionPointCIMObject(
                                    mrid=pp.mrid,
                                    x_position=pp.x_position,
                                    y_position=pp.y_position,
                                    z_position=pp.z_position
                                ))
                        
                        cn = ConnectivityNodeCIMObject(
                            mrid=span.from_connectivity_node.mrid,
                            name=span.from_connectivity_node.name or f"Узел {span.from_connectivity_node.mrid}",
                            location={"mRID": location.mrid} if location else None
                        )
                        connectivity_nodes_dict[span.from_connectivity_node.mrid] = cn
                        cim_objects.append(cn)
                    
                    span_from_node_ref = {"mRID": span.from_connectivity_node.mrid} if is_real_cn else None
                
                if span.to_connectivity_node:
                    to_pole = getattr(span.to_connectivity_node, "pole", None)
                    is_real_cn = bool(getattr(span.to_connectivity_node, "substation_id", None))
                    if to_pole is not None:
                        is_real_cn = is_real_cn or bool(getattr(to_pole, "is_tap_pole", False))
                    is_real_cn = is_real_cn and not getattr(span.to_connectivity_node, "is_virtual", False)
                    if is_real_cn and span.to_connectivity_node.mrid not in connectivity_nodes_dict:
                        location = None
                        if include_gps and to_pole and to_pole.position_points:
                            position_points = []
                            for pp in span.to_connectivity_node.pole.position_points:
                                position_points.append({
                                    "mRID": pp.mrid,
                                    "xPosition": pp.x_position,
                                    "yPosition": pp.y_position,
                                    "zPosition": pp.z_position if pp.z_position is not None else None
                                })
                            
                            location_mrid = to_pole.location.mrid if to_pole.location else f"LOC_{span.to_connectivity_node.mrid}"
                            location = LocationCIMObject(
                                mrid=location_mrid,
                                position_points=position_points
                            )
                            cim_objects.append(location)
                            for pp in to_pole.position_points:
                                cim_objects.append(PositionPointCIMObject(
                                    mrid=pp.mrid,
                                    x_position=pp.x_position,
                                    y_position=pp.y_position,
                                    z_position=pp.z_position
                                ))
                        
                        cn = ConnectivityNodeCIMObject(
                            mrid=span.to_connectivity_node.mrid,
                            name=span.to_connectivity_node.name or f"Узел {span.to_connectivity_node.mrid}",
                            location={"mRID": location.mrid} if location else None
                        )
                        connectivity_nodes_dict[span.to_connectivity_node.mrid] = cn
                        cim_objects.append(cn)
                    
                    span_to_node_ref = {"mRID": span.to_connectivity_node.mrid} if is_real_cn else None
                
                # Создаём LineSpan объект (по CIM профилю FromPlatform)
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
                )
                spans_list.append(span_obj)
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
                spans=[{"mRID": s.mrid} for s in spans_list]
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
                    location = None
                    if include_gps and terminal.connectivity_node.pole and terminal.connectivity_node.pole.position_points:
                        position_points = []
                        for pp in terminal.connectivity_node.pole.position_points:
                            position_points.append({
                                "mRID": pp.mrid,
                                "xPosition": pp.x_position,
                                "yPosition": pp.y_position,
                                "zPosition": pp.z_position if pp.z_position is not None else None
                            })
                        
                        location_mrid = terminal.connectivity_node.pole.location.mrid if terminal.connectivity_node.pole.location else f"LOC_{terminal.connectivity_node.mrid}"
                        location = LocationCIMObject(
                            mrid=location_mrid,
                            position_points=position_points
                        )
                        cim_objects.append(location)
                        for pp in terminal.connectivity_node.pole.position_points:
                            cim_objects.append(PositionPointCIMObject(
                                mrid=pp.mrid,
                                x_position=pp.x_position,
                                y_position=pp.y_position,
                                z_position=pp.z_position
                            ))
                    
                    cn = ConnectivityNodeCIMObject(
                        mrid=terminal.connectivity_node.mrid,
                        name=terminal.connectivity_node.name or f"Узел {terminal.connectivity_node.mrid}",
                        location={"mRID": location.mrid} if location else None
                    )
                    connectivity_nodes_dict[terminal.connectivity_node.mrid] = cn
                    cim_objects.append(cn)
                
                terminal_cn_ref = {"mRID": terminal.connectivity_node.mrid}
            
            terminal_obj = TerminalCIMObject(
                mrid=terminal.mrid,
                name=terminal.name,
                connectivity_node=terminal_cn_ref,
                sequence_number=terminal.sequence_number
            )
            terminals_list.append(terminal_obj)
            cim_objects.append(terminal_obj)
        
        # Создаём ACLineSegment объект
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
            parent_object={"mRID": power_line.mrid},
        )
        # Добавляем ссылки на LineSection и Terminal
        segment_dict = segment_obj.to_cim_dict()
        if line_sections_list:
            segment_dict["LineSection"] = [{"mRID": ls.mrid} for ls in line_sections_list]
        if terminals_list:
            segment_dict["Terminal"] = [{"mRID": t.mrid} for t in terminals_list]
        
        acline_segments_list.append(segment_dict)
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

            # Соберём ORM-объекты ConnectivityNode, чтобы вытащить из них Terminal'ы оборудования.
            cn_orm_by_id: Dict[int, ConnectivityNode] = {}
            for segment in power_line.acline_segments:
                if getattr(segment, "from_node", None) is not None:
                    cn = segment.from_node
                    cn_id = getattr(cn, "id", None)
                    if cn_id is not None:
                        cn_orm_by_id[int(cn_id)] = cn

            # Собираем equipment только из полюсов, которые реально участвуют в данной линии.
            for cn in cn_orm_by_id.values():
                pole = getattr(cn, "pole", None)
                for eq in getattr(pole, "equipment", None) or []:
                    eq_id = getattr(eq, "id", None)
                    if eq_id is not None:
                        equipment_by_id[int(eq_id)] = eq
                if getattr(segment, "to_node", None) is not None:
                    cn = segment.to_node
                    cn_id = getattr(cn, "id", None)
                    if cn_id is not None:
                        cn_orm_by_id[int(cn_id)] = cn

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

                    # Создадим CIM-представление оборудования один раз.
                    if eq_id not in exported_equipment_ids:
                        location_obj = None
                        position_points_dicts = []
                        if include_gps and getattr(eq, "location", None) is not None and getattr(eq.location, "position_points", None):
                            eq_location = eq.location
                            if getattr(eq_location, "position_points", None):
                                for pp in eq_location.position_points:
                                    position_points_dicts.append({
                                        "mRID": pp.mrid,
                                        "xPosition": pp.x_position,
                                        "yPosition": pp.y_position,
                                        "zPosition": pp.z_position if pp.z_position is not None else None
                                    })
                                location_mrid = eq_location.mrid
                                location_obj = LocationCIMObject(
                                    mrid=location_mrid,
                                    position_points=position_points_dicts
                                )
                                cim_objects.append(location_obj)
                                for pp in eq_location.position_points:
                                    cim_objects.append(PositionPointCIMObject(
                                        mrid=pp.mrid,
                                        x_position=pp.x_position,
                                        y_position=pp.y_position,
                                        z_position=pp.z_position
                                    ))

                        if include_gps and location_obj is None:
                            x = getattr(eq, "x_position", None)
                            y = getattr(eq, "y_position", None)
                            if x is not None and y is not None:
                                location_mrid = f"LOC_EQ_{eq.id}"
                                pp_mrid = f"PP_EQ_{eq.id}"
                                location_obj = LocationCIMObject(
                                    mrid=location_mrid,
                                    position_points=[{
                                        "mRID": pp_mrid,
                                        "xPosition": x,
                                        "yPosition": y,
                                        "zPosition": None
                                    }]
                                )
                                cim_objects.append(location_obj)
                                cim_objects.append(PositionPointCIMObject(
                                    mrid=pp_mrid,
                                    x_position=x,
                                    y_position=y,
                                    z_position=None
                                ))

                        cim_location_ref = {"mRID": location_obj.mrid} if location_obj else None

                        conducting_eq = ConductingEquipmentCIMObject(
                            mrid=eq.mrid,
                            name=eq.name,
                            equipment_type=getattr(eq, "equipment_type", None),
                            location=cim_location_ref
                        )
                        cim_objects.append(conducting_eq)
                        exported_equipment_ids.add(eq_id)

                    # Убедимся, что ConnectivityNode экспортирован.
                    cn_mrid = getattr(cn, "mrid", None)
                    if cn_mrid and cn_mrid not in connectivity_nodes_dict:
                        location = None
                        if include_gps and getattr(cn, "pole", None) is not None and getattr(cn.pole, "position_points", None):
                            if cn.pole.position_points:
                                position_points = []
                                for pp in cn.pole.position_points:
                                    position_points.append({
                                        "mRID": pp.mrid,
                                        "xPosition": pp.x_position,
                                        "yPosition": pp.y_position,
                                        "zPosition": pp.z_position if pp.z_position is not None else None
                                    })

                                location_mrid = cn.pole.location.mrid if cn.pole.location else f"LOC_{cn_mrid}"
                                location = LocationCIMObject(
                                    mrid=location_mrid,
                                    position_points=position_points
                                )
                                cim_objects.append(location)
                                for pp in cn.pole.position_points:
                                    cim_objects.append(PositionPointCIMObject(
                                        mrid=pp.mrid,
                                        x_position=pp.x_position,
                                        y_position=pp.y_position,
                                        z_position=pp.z_position
                                    ))
                        cn_obj = ConnectivityNodeCIMObject(
                            mrid=cn_mrid,
                            name=getattr(cn, "name", None) or f"Узел {cn_mrid}",
                            location={"mRID": location.mrid} if location else None
                        )
                        connectivity_nodes_dict[cn_mrid] = cn_obj
                        cim_objects.append(cn_obj)

                    conducting_eq_ref = {"mRID": eq.mrid}
                    term_mrid = getattr(term, "mrid", None)
                    if not term_mrid:
                        continue

                    term_obj = TerminalCIMObject(
                        mrid=term_mrid,
                        name=getattr(term, "name", None),
                        connectivity_node={"mRID": cn.mrid},
                        conducting_equipment=conducting_eq_ref,
                        sequence_number=getattr(term, "sequence_number", None)
                    )
                    cim_objects.append(term_obj)
                    exported_terminals_mrids.add(term_mrid)
        except Exception as _equip_ex:
            import logging
            logging.getLogger(__name__).exception(
                "Equipment export failed for line_id=%s (skipping equipment in CIM XML): %s",
                getattr(power_line, "id", None),
                str(_equip_ex),
            )

    # 4. Создаём Line объект
    line_obj = PowerLineCIMObject(
        mrid=power_line.mrid,
        name=power_line.name,
        acline_segments=acline_segments_list,
        base_voltage=base_voltage_ref
    )
    cim_objects.insert(0, line_obj)  # Line должен быть первым
    
    return cim_objects


@router.get("/export/xml")
async def export_cim_xml(
    use_cimpy: bool = Query(True, description="Использовать CIMpy библиотеку (рекомендуется)"),
    include_substations: bool = Query(True, description="Включить подстанции"),
    include_power_lines: bool = Query(True, description="Включить ЛЭП"),
    include_equipment: bool = Query(True, description="Включить оборудование"),
    include_gps: bool = Query(True, description="Включить координаты GPS (Location/PositionPoint)"),
    line_id: Optional[int] = Query(None, description="Экспортировать только указанную ЛЭП (id)"),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Экспорт данных в CIM XML формат (RDF/XML)
    Соответствует стандартам IEC 61970-301 и IEC 61970-552:2016
    
    Поддерживает два режима:
    - use_cimpy=True: Использует библиотеку CIMpy (рекомендуется)
    - use_cimpy=False: Использует ручную реализацию
    """
    substations_list = []
    power_lines_list = []

    # Текущий CIMpy-экспорт в проекте упрощённо собирает только Line/ACLineSegment
    # и не включает ConductingEquipment/оборудование. Поэтому при включенном оборудовании
    # форсим ручную реализацию CIM XML, чтобы гарантировать наличие Equipment в выгрузке.
    if (include_equipment and use_cimpy) or (not include_gps):
        use_cimpy = False

    # Частичный экспорт “по ЛЭП” должен быть строго ограничен выбранной ЛЭП.
    # Поэтому при заданном line_id отключаем CIMpy и используем ручную сборку,
    # где мы экспортируем объекты только из `power_line.acline_segments`
    # и связанных ConnectivityNode/Terminal/оборудования для этой ЛЭП.
    if line_id is not None:
        use_cimpy = False
    
    # Загружаем подстанции
    if include_substations:
        result = await db.execute(
            select(Substation)
            .where(Substation.is_active == True)
            .options(
                selectinload(Substation.voltage_levels),
                selectinload(Substation.location).selectinload(Location.position_points)
            )
        )
        substations_list = result.scalars().all()
    
    # Загружаем ЛЭП с полной структурой (LineSection, Span, ConnectivityNode, Location)
    if include_power_lines:
        power_line_query = select(PowerLine)
        if line_id is not None:
            power_line_query = power_line_query.where(PowerLine.id == line_id)
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
    import logging
    logger = logging.getLogger(__name__)
    
    try:
        if use_cimpy:
            # Проверяем доступность CIMpy перед использованием
            try:
                if not CIMPY_AVAILABLE:
                    raise ImportError("CIMpy library is not installed")
                
                # Используем CIMpy
                exporter = CIMpyXMLExporter()
                xml_content = exporter.export_models(
                    substations=substations_list if include_substations else None,
                    power_lines=power_lines_list if include_power_lines else None
                )
            except ImportError as e:
                # Если CIMpy не установлен, автоматически переключаемся на ручную реализацию
                logger.warning(f"CIMpy не установлен, используем ручную реализацию: {str(e)}")
                
                cim_objects = []
                for substation in substations_list:
                    cim_objects.extend(_substation_to_cim_objects_for_xml(substation, include_gps=include_gps))
                for power_line in power_lines_list:
                    # _power_line_to_cim возвращает список объектов
                    cim_objects.extend(_power_line_to_cim(power_line, include_equipment=include_equipment, include_gps=include_gps))
                
                exporter = CIMXMLExporter()
                xml_content = exporter.export(cim_objects)
            except Exception as e:
                # Другие ошибки при использовании CIMpy
                logger.error(f"Ошибка при экспорте через CIMpy: {str(e)}", exc_info=True)
                # Пробуем переключиться на ручную реализацию
                logger.info("Переключаемся на ручную реализацию из-за ошибки CIMpy")
                cim_objects = []
                for substation in substations_list:
                    cim_objects.extend(_substation_to_cim_objects_for_xml(substation, include_gps=include_gps))
                for power_line in power_lines_list:
                    # _power_line_to_cim возвращает список объектов
                    cim_objects.extend(_power_line_to_cim(power_line, include_equipment=include_equipment, include_gps=include_gps))
                
                exporter = CIMXMLExporter()
                xml_content = exporter.export(cim_objects)
        else:
            # Используем ручную реализацию
            cim_objects = []
            def _build_cim_objects(with_equipment: bool) -> List[CIMObject]:
                built: List[CIMObject] = []
                for substation in substations_list:
                    built.extend(_substation_to_cim_objects_for_xml(substation, include_gps=include_gps))
                for power_line in power_lines_list:
                    built.extend(
                        _power_line_to_cim(
                            power_line,
                            include_equipment=with_equipment,
                            include_gps=include_gps,
                        )
                    )
                return built

            exporter = CIMXMLExporter()
            try:
                cim_objects = _build_cim_objects(with_equipment=include_equipment)
                xml_content = exporter.export(cim_objects)
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
                    xml_content = exporter.export(cim_objects_retry)
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
    
    return Response(
        content=xml_content,
        media_type="application/xml",
        headers={
            "Content-Disposition": f'attachment; filename="cim_export_{datetime.now().strftime("%Y%m%d_%H%M%S")}.xml"'
        }
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
    Импорт CIM XML (FullModel). Парсит файл и возвращает сводку по объектам для предпросмотра.
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
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Экспорт данных в формате 552 (один XML, по структуре как FullModel).
    Возвращает тот же CIM XML, что и /export/xml (для совместимости с кнопкой «Экспорт 552 diff» на фронте).
    """
    return await export_cim_xml(
        use_cimpy=False,
        include_substations=include_substations,
        include_power_lines=include_power_lines,
        include_equipment=include_equipment,
        include_gps=include_gps,
        line_id=line_id,
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
    Применить 552-диф к БД: создать подстанции, локации и точки координат из загруженного XML.
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
    return {
        "created_substations": created_substations,
        "created_locations": created_locations,
        "created_position_points": created_position_points,
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

