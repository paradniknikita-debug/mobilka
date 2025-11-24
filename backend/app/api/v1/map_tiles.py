from typing import List, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.core.security import get_current_active_user
from app.models.user import User
from app.models.power_line import PowerLine, Pole, Tap
from app.models.substation import Substation

router = APIRouter()

@router.get("/tiles/{z}/{x}/{y}")
async def get_tile(
    z: int,
    x: int,
    y: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение tile для карты (упрощенная версия)"""
    # В реальном приложении здесь должен быть tile server (например, с использованием PostGIS)
    # Пока возвращаем пустой tile
    return {"type": "FeatureCollection", "features": []}

@router.get("/power-lines/geojson")
async def get_power_lines_geojson(
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение ЛЭП в формате GeoJSON"""
    result = await db.execute(
        select(PowerLine).options(selectinload(PowerLine.poles))
    )
    power_lines = result.scalars().all()
    
    features = []
    for power_line in power_lines:
        # Создаем LineString из координат опор
        if len(power_line.poles) >= 2:
            coordinates = [[pole.longitude, pole.latitude] for pole in sorted(power_line.poles, key=lambda t: t.pole_number)]
            
            feature = {
                "type": "Feature",
                "properties": {
                    "id": power_line.id,
                    "name": power_line.name,
                    "code": power_line.code,
                    "voltage_level": power_line.voltage_level,
                    "status": power_line.status,
                    "pole_count": len(power_line.poles)
                },
                "geometry": {
                    "type": "LineString",
                    "coordinates": coordinates
                }
            }
            features.append(feature)
    
    return {
        "type": "FeatureCollection",
        "features": features
    }

@router.get("/poles/geojson")
async def get_poles_geojson(
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение опор в формате GeoJSON"""
    result = await db.execute(select(Pole))
    poles = result.scalars().all()
    
    features = []
    for pole in poles:
        feature = {
            "type": "Feature",
            "properties": {
                "id": pole.id,
                "pole_number": pole.pole_number,
                "pole_type": pole.pole_type,
                "height": pole.height,
                "condition": pole.condition,
                "power_line_id": pole.power_line_id,
                "material": pole.material,
                "year_installed": pole.year_installed
            },
            "geometry": {
                "type": "Point",
                "coordinates": [pole.longitude, pole.latitude]
            }
        }
        features.append(feature)
    
    return {
        "type": "FeatureCollection",
        "features": features
    }

@router.get("/taps/geojson")
async def get_taps_geojson(
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение отпаек в формате GeoJSON"""
    result = await db.execute(select(Tap))
    taps = result.scalars().all()
    
    features = []
    for tap in taps:
        if tap.latitude and tap.longitude:  # Только отпайки с координатами
            feature = {
                "type": "Feature",
                "properties": {
                    "id": tap.id,
                    "tap_number": tap.tap_number,
                    "tap_type": tap.tap_type,
                    "voltage_level": tap.voltage_level,
                    "power_rating": tap.power_rating,
                    "power_line_id": tap.power_line_id,
                    "pole_id": tap.pole_id
                },
                "geometry": {
                    "type": "Point",
                    "coordinates": [tap.longitude, tap.latitude]
                }
            }
            features.append(feature)
    
    return {
        "type": "FeatureCollection",
        "features": features
    }

@router.get("/substations/geojson")
async def get_substations_geojson(
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение подстанций в формате GeoJSON"""
    result = await db.execute(select(Substation))
    substations = result.scalars().all()
    
    features = []
    for substation in substations:
        feature = {
            "type": "Feature",
            "properties": {
                "id": substation.id,
                "name": substation.name,
                "code": substation.code,
                "voltage_level": substation.voltage_level,
                "branch_id": substation.branch_id,
                "address": substation.address
            },
            "geometry": {
                "type": "Point",
                "coordinates": [substation.longitude, substation.latitude]
            }
        }
        features.append(feature)
    
    return {
        "type": "FeatureCollection",
        "features": features
    }

@router.get("/bounds")
async def get_data_bounds(
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение границ всех данных для настройки карты"""
    
    # Получаем границы опор
    result = await db.execute(
        select(
            func.min(Pole.latitude).label('min_lat'),
            func.max(Pole.latitude).label('max_lat'),
            func.min(Pole.longitude).label('min_lng'),
            func.max(Pole.longitude).label('max_lng')
        )
    )
    bounds = result.first()
    
    if bounds and bounds.min_lat:
        return {
            "bounds": {
                "min_lat": float(bounds.min_lat),
                "max_lat": float(bounds.max_lat),
                "min_lng": float(bounds.min_lng),
                "max_lng": float(bounds.max_lng)
            }
        }
    else:
        # Значения по умолчанию для России
        return {
            "bounds": {
                "min_lat": 41.0,
                "max_lat": 82.0,
                "min_lng": 19.0,
                "max_lng": 169.0
            }
        }
