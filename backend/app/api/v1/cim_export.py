"""
API endpoints для экспорта данных в CIM форматы
Соответствует стандартам IEC 61970-301 и IEC 61970-552:2016
"""
from typing import List, Optional
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status, Query
from fastapi.responses import Response, StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from io import BytesIO

from app.database import get_db
from app.core.security import get_current_active_user
from app.models.user import User
from app.models.substation import Substation, VoltageLevel
from app.models.power_line import PowerLine, Pole, Span
from app.models.location import Location, PositionPoint
from app.models.acline_segment import AClineSegment
from app.models.cim_line_structure import ConnectivityNode, LineSection, Terminal
from app.models.base_voltage import BaseVoltage
from app.models.wire_info import WireInfo
from app.core.cim.cim_xml import CIMXMLExporter
from app.core.cim.cim_xml_cimpy import CIMpyXMLExporter, CIMPY_AVAILABLE
from app.core.cim.cim_json import CIMJSONExporter
from app.core.cim.cim_552_protocol import CIM552Service, MessagePurpose
from app.core.cim.cim_base import CIMObject
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
    WireInfoCIMObject,
    TerminalCIMObject
)

router = APIRouter()


def _substation_to_cim(substation: Substation) -> SubstationCIMObject:
    """Преобразование модели Substation в CIM объект"""
    location = None
    if substation.location:
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


def _power_line_to_cim(power_line: PowerLine) -> List[CIMObject]:
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
    
    # 2. Создаём ConnectivityNode для всех опор с Location и PositionPoint
    connectivity_nodes_dict = {}  # mrid -> ConnectivityNodeCIMObject
    
    # 3. Обрабатываем ACLineSegment с полной структурой
    acline_segments_list = []
    
    for segment in power_line.acline_segments:
        # Создаём ConnectivityNode для from_node и to_node
        from_node_ref = None
        to_node_ref = None
        
        if segment.from_node:
            if segment.from_node.mrid not in connectivity_nodes_dict:
                # Создаём Location и PositionPoint для опоры
                location = None
                if segment.from_node.pole and segment.from_node.pole.position_points:
                    position_points = []
                    for pp in segment.from_node.pole.position_points:
                        position_points.append({
                            "mRID": pp.mrid,
                            "xPosition": pp.x_position,
                            "yPosition": pp.y_position,
                            "zPosition": pp.z_position if pp.z_position is not None else None
                        })
                    
                    location_mrid = segment.from_node.pole.location.mrid if segment.from_node.pole.location else f"LOC_{segment.from_node.mrid}"
                    location = LocationCIMObject(
                        mrid=location_mrid,
                        position_points=position_points
                    )
                    cim_objects.append(location)
                    # Добавляем PositionPoint как отдельные объекты
                    for pp in segment.from_node.pole.position_points:
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
            
            from_node_ref = {"mRID": segment.from_node.mrid}
        
        if segment.to_node:
            if segment.to_node.mrid not in connectivity_nodes_dict:
                # Создаём Location и PositionPoint для опоры
                location = None
                if segment.to_node.pole and segment.to_node.pole.position_points:
                    position_points = []
                    for pp in segment.to_node.pole.position_points:
                        position_points.append({
                            "mRID": pp.mrid,
                            "xPosition": pp.x_position,
                            "yPosition": pp.y_position,
                            "zPosition": pp.z_position if pp.z_position is not None else None
                        })
                    
                    location_mrid = segment.to_node.pole.location.mrid if segment.to_node.pole.location else f"LOC_{segment.to_node.mrid}"
                    location = LocationCIMObject(
                        mrid=location_mrid,
                        position_points=position_points
                    )
                    cim_objects.append(location)
                    # Добавляем PositionPoint как отдельные объекты
                    for pp in segment.to_node.pole.position_points:
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
            
            to_node_ref = {"mRID": segment.to_node.mrid}
        
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
                # Создаём ConnectivityNode для опор пролёта (если ещё не созданы)
                span_from_node_ref = None
                span_to_node_ref = None
                
                if span.from_connectivity_node:
                    if span.from_connectivity_node.mrid not in connectivity_nodes_dict:
                        location = None
                        if span.from_connectivity_node.pole and span.from_connectivity_node.pole.position_points:
                            position_points = []
                            for pp in span.from_connectivity_node.pole.position_points:
                                position_points.append({
                                    "mRID": pp.mrid,
                                    "xPosition": pp.x_position,
                                    "yPosition": pp.y_position,
                                    "zPosition": pp.z_position if pp.z_position is not None else None
                                })
                            
                            location_mrid = span.from_connectivity_node.pole.location.mrid if span.from_connectivity_node.pole.location else f"LOC_{span.from_connectivity_node.mrid}"
                            location = LocationCIMObject(
                                mrid=location_mrid,
                                position_points=position_points
                            )
                            cim_objects.append(location)
                            for pp in span.from_connectivity_node.pole.position_points:
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
                    
                    span_from_node_ref = {"mRID": span.from_connectivity_node.mrid}
                
                if span.to_connectivity_node:
                    if span.to_connectivity_node.mrid not in connectivity_nodes_dict:
                        location = None
                        if span.to_connectivity_node.pole and span.to_connectivity_node.pole.position_points:
                            position_points = []
                            for pp in span.to_connectivity_node.pole.position_points:
                                position_points.append({
                                    "mRID": pp.mrid,
                                    "xPosition": pp.x_position,
                                    "yPosition": pp.y_position,
                                    "zPosition": pp.z_position if pp.z_position is not None else None
                                })
                            
                            location_mrid = span.to_connectivity_node.pole.location.mrid if span.to_connectivity_node.pole.location else f"LOC_{span.to_connectivity_node.mrid}"
                            location = LocationCIMObject(
                                mrid=location_mrid,
                                position_points=position_points
                            )
                            cim_objects.append(location)
                            for pp in span.to_connectivity_node.pole.position_points:
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
                    
                    span_to_node_ref = {"mRID": span.to_connectivity_node.mrid}
                
                # Создаём Span объект
                span_obj = SpanCIMObject(
                    mrid=span.mrid,
                    name=span.span_number,
                    length=span.length,
                    from_node=span_from_node_ref,
                    to_node=span_to_node_ref,
                    tension=span.tension,
                    sag=span.sag,
                    conductor_type=span.conductor_type or line_section.conductor_type,
                    conductor_material=span.conductor_material or line_section.conductor_material,
                    conductor_section=span.conductor_section or line_section.conductor_section
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
                    if terminal.connectivity_node.pole and terminal.connectivity_node.pole.position_points:
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
            g=segment.g
        )
        # Добавляем ссылки на LineSection и Terminal
        segment_dict = segment_obj.to_cim_dict()
        if line_sections_list:
            segment_dict["LineSection"] = [{"mRID": ls.mrid} for ls in line_sections_list]
        if terminals_list:
            segment_dict["Terminal"] = [{"mRID": t.mrid} for t in terminals_list]
        
        acline_segments_list.append(segment_dict)
        cim_objects.append(segment_obj)
    
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
        result = await db.execute(
            select(PowerLine)
            .options(
                selectinload(PowerLine.acline_segments)
                .selectinload(AClineSegment.from_node)
                .selectinload(ConnectivityNode.pole)
                .selectinload(Pole.position_points),
                selectinload(PowerLine.acline_segments)
                .selectinload(AClineSegment.to_node)
                .selectinload(ConnectivityNode.pole)
                .selectinload(Pole.position_points),
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
                    cim_objects.append(_substation_to_cim(substation))
                for power_line in power_lines_list:
                    # _power_line_to_cim возвращает список объектов
                    cim_objects.extend(_power_line_to_cim(power_line))
                
                exporter = CIMXMLExporter()
                xml_content = exporter.export(cim_objects)
            except Exception as e:
                # Другие ошибки при использовании CIMpy
                logger.error(f"Ошибка при экспорте через CIMpy: {str(e)}", exc_info=True)
                # Пробуем переключиться на ручную реализацию
                logger.info("Переключаемся на ручную реализацию из-за ошибки CIMpy")
                cim_objects = []
                for substation in substations_list:
                    cim_objects.append(_substation_to_cim(substation))
                for power_line in power_lines_list:
                    # _power_line_to_cim возвращает список объектов
                    cim_objects.extend(_power_line_to_cim(power_line))
                
                exporter = CIMXMLExporter()
                xml_content = exporter.export(cim_objects)
        else:
            # Используем ручную реализацию
            cim_objects = []
            for substation in substations_list:
                cim_objects.append(_substation_to_cim(substation))
            for power_line in power_lines_list:
                cim_objects.append(_power_line_to_cim(power_line))
            
            exporter = CIMXMLExporter()
            xml_content = exporter.export(cim_objects)
    except HTTPException:
        # Пробрасываем HTTP исключения как есть
        raise
    except Exception as e:
        # Обработка всех остальных ошибок
        logger.error(f"Ошибка при экспорте CIM XML: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Ошибка при экспорте CIM XML: {str(e)}"
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
            cim_objects.extend(_power_line_to_cim(power_line))
    
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

