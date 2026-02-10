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
from app.models.power_line import PowerLine
from app.models.location import Location, PositionPoint
from app.models.acline_segment import AClineSegment
from app.core.cim.cim_xml import CIMXMLExporter
from app.core.cim.cim_xml_cimpy import CIMpyXMLExporter, CIMPY_AVAILABLE
from app.core.cim.cim_json import CIMJSONExporter
from app.core.cim.cim_552_protocol import CIM552Service, MessagePurpose
from app.core.cim.cim_objects import (
    SubstationCIMObject,
    VoltageLevelCIMObject,
    PowerLineCIMObject,
    LocationCIMObject,
    PositionPointCIMObject,
    ConnectivityNodeCIMObject,
    AClineSegmentCIMObject
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


def _power_line_to_cim(power_line: PowerLine) -> PowerLineCIMObject:
    """Преобразование модели PowerLine в CIM объект"""
    base_voltage = None
    # if power_line.base_voltage:
    #     base_voltage = {"mRID": power_line.base_voltage.mrid}
    
    acline_segments = []
    for segment in power_line.acline_segments:
        from_node = None
        to_node = None
        
        if segment.from_node:
            from_node = {
                "mRID": segment.from_node.mrid,
                "name": segment.from_node.name
            }
        
        if segment.to_node:
            to_node = {
                "mRID": segment.to_node.mrid,
                "name": segment.to_node.name
            }
        
        acline_segments.append({
            "mRID": segment.mrid,
            "name": segment.name,
            "fromNode": from_node,
            "toNode": to_node,
            "length": segment.length,
            "r": segment.r,
            "x": segment.x,
            "b": segment.b,
            "g": segment.g
        })
    
    return PowerLineCIMObject(
        mrid=power_line.mrid,
        name=power_line.name,
        acline_segments=acline_segments,
        base_voltage=base_voltage
    )


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
    
    # Загружаем ЛЭП
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
                    cim_objects.append(_power_line_to_cim(power_line))
                
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
                    cim_objects.append(_power_line_to_cim(power_line))
                
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
            cim_objects.append(_power_line_to_cim(power_line))
    
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
                cim_objects.append(_power_line_to_cim(power_line).to_cim_dict())
    
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

