from typing import List, Dict, Any
import math
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.core.security import get_current_active_user
from app.models.user import User
from app.models.power_line import PowerLine, Pole, Tap, Span
from app.models.substation import Substation
from app.models.location import Location, PositionPoint
from app.models.cim_line_structure import ConnectivityNode
import logging

logger = logging.getLogger(__name__)
router = APIRouter()

def filter_none_properties(props: Dict[str, Any]) -> Dict[str, Any]:
    """Удаляет None значения из properties для совместимости с Flutter"""
    return {k: v for k, v in props.items() if v is not None}

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
    try:
        return await _get_power_lines_geojson_impl(db)
    except Exception as e:
        logger.exception("map/power-lines/geojson: %s", e)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"map/power-lines/geojson: {type(e).__name__}: {e}",
        ) from e


async def _get_power_lines_geojson_impl(db: AsyncSession):
    result = await db.execute(
        select(PowerLine).options(
            selectinload(PowerLine.poles).selectinload(Pole.position_points),
            selectinload(PowerLine.poles).selectinload(Pole.location).selectinload(Location.position_points)
        )
    )
    power_lines = result.scalars().all()
    
    features = []
    for power_line in power_lines:
        # Считаем количество опор с валидными координатами, используя helper-методы модели
        poles_with_coords = 0
        for p in power_line.poles:
            try:
                lon = p.get_longitude() if hasattr(p, "get_longitude") else getattr(p, "x_position", None)
                lat = p.get_latitude() if hasattr(p, "get_latitude") else getattr(p, "y_position", None)
            except Exception:
                lon = None
                lat = None
            if lon is not None and lat is not None:
                poles_with_coords += 1
        logger.info(
            "map/power-lines/geojson: ЛЭП id=%d name=%r опор=%d с координатами=%d",
            power_line.id, power_line.name, len(power_line.poles), poles_with_coords
        )

        def _default_properties():
            return {
                "id": int(power_line.id),
                "name": str(power_line.name) if power_line.name else "",
                "status": str(power_line.status) if power_line.status else "active",
                "pole_count": int(len(power_line.poles)),
            }

        def _default_point_feature():
            props = _default_properties()
            if power_line.voltage_level is not None:
                props["voltage_level"] = float(power_line.voltage_level)
            return {
                "type": "Feature",
                "properties": props,
                "geometry": {"type": "Point", "coordinates": [27.5615, 53.9045]},
            }

        # Строим геометрию: магистраль (опоры без "/" в номере) и отпайки (от опоры N линия N -> N/1 -> N/2 ...)
        if len(power_line.poles) >= 2:

            def _pole_coords(pole):
                try:
                    lon = pole.get_longitude() if hasattr(pole, "get_longitude") else getattr(pole, "x_position", None)
                    lat = pole.get_latitude() if hasattr(pole, "get_latitude") else getattr(pole, "y_position", None)
                    if lon is not None and lat is not None:
                        lon, lat = float(lon), float(lat)
                        if not (math.isnan(lon) or math.isnan(lat) or abs(lon) == float('inf') or abs(lat) == float('inf')):
                            return [lon, lat]
                except (TypeError, ValueError):
                    pass
                return None

            base_props = {
                "id": int(power_line.id),
                "name": str(power_line.name) if power_line.name else "",
                "status": str(power_line.status) if power_line.status else "active",
                "pole_count": int(len(power_line.poles)),
            }
            if power_line.voltage_level is not None:
                base_props["voltage_level"] = float(power_line.voltage_level)

            added_any = False
            # Магистраль: только опоры с номером без "/" (1, 2, 3 ...), линия не включает опоры отпаек
            main_poles = [p for p in power_line.poles if "/" not in (p.pole_number or "")]
            def _main_pole_sort_key(p):
                n = (p.pole_number or "").strip()
                try:
                    return (0, int(n))  # числовая сортировка: 1, 2, 3, 10
                except ValueError:
                    return (1, n)  # не число — в конец, по строке
            main_coords = []
            for pole in sorted(main_poles, key=_main_pole_sort_key):
                c = _pole_coords(pole)
                if c:
                    main_coords.append(c)
            if len(main_coords) >= 2:
                features.append({
                    "type": "Feature",
                    "properties": {**base_props, "is_tap": False},
                    "geometry": {"type": "LineString", "coordinates": main_coords},
                })
                added_any = True

            # Отпайки: для каждой N/M — отрезок к корню/предыдущей (2/1→2, 2/2→2/1) и к следующей при наличии (2/1→2/2).
            # 2/18: если 2/17 есть — к 2/17, если 2/19 есть — к 2/19; иначе к 2.
            tap_poles = [p for p in power_line.poles if p.pole_number and "/" in p.pole_number]
            if tap_poles:
                poles_by_num = {(p.pole_number or "").strip(): p for p in power_line.poles if (p.pole_number or "").strip()}
                seen_segments = set()

                def are_neighbors(key_a: str, key_b: str) -> bool:
                    """От опор отпайки не строим линии к основным; только к корню своей ветки (2/1 — только с 2)."""
                    parts_a, parts_b = key_a.split("/", 1), key_b.split("/", 1)
                    root_a, root_b = parts_a[0].strip(), parts_b[0].strip()
                    tap_a = len(parts_a) >= 2
                    tap_b = len(parts_b) >= 2
                    if tap_a and tap_b:
                        if root_a != root_b:
                            return False
                        try:
                            suf_a, suf_b = int(parts_a[1].strip()), int(parts_b[1].strip())
                            return abs(suf_a - suf_b) == 1
                        except ValueError:
                            return False
                    if not tap_a and not tap_b:
                        return False
                    tap_key, main_key = (key_a, key_b) if tap_a else (key_b, key_a)
                    root_tap = (tap_key.split("/", 1)[0] or "").strip()
                    return main_key == root_tap

                def add_segment(key_a, key_b):
                    if key_a == key_b:
                        return
                    if not are_neighbors(key_a, key_b):
                        return
                    seg = (key_a, key_b) if key_a < key_b else (key_b, key_a)
                    if seg in seen_segments:
                        return
                    seen_segments.add(seg)
                    pa, pb = poles_by_num.get(key_a), poles_by_num.get(key_b)
                    if not pa or not pb:
                        return
                    ca, cb = _pole_coords(pa), _pole_coords(pb)
                    if not ca or not cb:
                        return
                    features.append({
                        "type": "Feature",
                        "properties": {**base_props, "is_tap": True},
                        "geometry": {"type": "LineString", "coordinates": [ca, cb]},
                    })

                for p in tap_poles:
                    pn = (p.pole_number or "").strip()
                    parts = pn.split("/", 1)
                    if len(parts) < 2:
                        continue
                    root, suffix_str = parts[0].strip(), parts[1].strip()
                    try:
                        suffix = int(suffix_str)
                    except ValueError:
                        continue
                    if suffix < 1:
                        continue
                    prev_key = root if suffix == 1 else f"{root}/{suffix - 1}"
                    next_key = f"{root}/{suffix + 1}"
                    if prev_key in poles_by_num:
                        add_segment(pn, prev_key)
                    elif root in poles_by_num:
                        # Нет предыдущей в ветке (например 2/16) — связываем с корнем 2
                        add_segment(pn, root)
                    if next_key in poles_by_num:
                        add_segment(pn, next_key)

                if seen_segments:
                    added_any = True

            if not added_any:
                features.append(_default_point_feature())
        elif len(power_line.poles) == 1:
            # Если есть только одна опора, создаем Point
            pole = power_line.poles[0]
            # Получаем координаты опоры через helper-методы модели
            try:
                longitude = pole.get_longitude() if hasattr(pole, "get_longitude") else getattr(pole, "x_position", None)
                latitude = pole.get_latitude() if hasattr(pole, "get_latitude") else getattr(pole, "y_position", None)
            except Exception:
                longitude = None
                latitude = None
            
            if longitude is not None and latitude is not None:
                try:
                    longitude = float(longitude)
                    latitude = float(latitude)
                    # Проверяем, что координаты валидны
                    if not (isinstance(longitude, (int, float)) and isinstance(latitude, (int, float))):
                        raise ValueError("Invalid coordinates")
                    if longitude == float('inf') or latitude == float('inf') or longitude == float('-inf') or latitude == float('-inf'):
                        raise ValueError("Invalid coordinates")
                    
                    # Создаем properties, исключая None значения для числовых полей
                    properties = {
                        "id": int(power_line.id),
                        "name": str(power_line.name) if power_line.name else "",
                        "status": str(power_line.status) if power_line.status else "active",
                        "pole_count": int(len(power_line.poles))
                    }
                    # Добавляем voltage_level только если он не None
                    if power_line.voltage_level is not None:
                        properties["voltage_level"] = float(power_line.voltage_level)
                    
                    feature = {
                        "type": "Feature",
                        "properties": properties,
                        "geometry": {
                            "type": "Point",
                            "coordinates": [longitude, latitude]
                        }
                    }
                    features.append(feature)
                except (TypeError, ValueError):
                    pass  # Пропускаем объекты с невалидными координатами
            # Одна опора без валидных координат — всё равно показываем ЛЭП в дереве
            if not features or features[-1].get("properties", {}).get("id") != int(power_line.id):
                features.append(_default_point_feature())
        else:
            # Если опор нет, создаем пустую геометрию (но все равно возвращаем ЛЭП)
            # Используем координаты по умолчанию (центр Минска) для отображения в дереве
            # Для ЛЭП без опор используем координаты по умолчанию
            # Создаем properties, исключая None значения для числовых полей
            properties = {
                "id": int(power_line.id),
                "name": str(power_line.name) if power_line.name else "",
                "status": str(power_line.status) if power_line.status else "active",
                "pole_count": 0
            }
            # Добавляем voltage_level только если он не None
            if power_line.voltage_level is not None:
                properties["voltage_level"] = float(power_line.voltage_level)
            
            feature = {
                "type": "Feature",
                "properties": properties,
                "geometry": {
                    "type": "Point",
                    "coordinates": [27.5615, 53.9045]  # Центр Минска по умолчанию
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
    try:
        return await _get_poles_geojson_impl(db)
    except Exception as e:
        logger.exception("map/poles/geojson: %s", e)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"map/poles/geojson: {type(e).__name__}: {e}",
        ) from e


async def _get_poles_geojson_impl(db: AsyncSession):
    result = await db.execute(
        select(Pole).options(
            selectinload(Pole.line),
            selectinload(Pole.connectivity_nodes),
            selectinload(Pole.position_points),
            selectinload(Pole.location).selectinload(Location.position_points)
        )
    )
    poles = result.scalars().all()
    
    features = []
    for pole in poles:
        # Получаем координаты опоры через helper-методы модели (учитывают Location/PositionPoint и колонки x_position/y_position)
        try:
            longitude = pole.get_longitude() if hasattr(pole, "get_longitude") else getattr(pole, "x_position", None)
            latitude = pole.get_latitude() if hasattr(pole, "get_latitude") else getattr(pole, "y_position", None)
        except Exception:
            longitude = None
            latitude = None
        
        # Включаем только объекты с валидными координатами
        if longitude is not None and latitude is not None:
            # Убеждаемся, что координаты - это числа, а не None
            try:
                longitude = float(longitude)
                latitude = float(latitude)
                # Проверяем, что координаты валидны (не NaN, не Infinity)
                if not (isinstance(longitude, (int, float)) and isinstance(latitude, (int, float))):
                    continue
                if longitude == float('inf') or latitude == float('inf') or longitude == float('-inf') or latitude == float('-inf'):
                    continue
                # Проверяем, что координаты не NaN
                import math
                if math.isnan(longitude) or math.isnan(latitude):
                    continue
            except (TypeError, ValueError):
                continue  # Пропускаем объекты с невалидными координатами
            
            # Создаем properties, исключая None значения (mrid может отсутствовать в старых БД)
            properties = {
                "id": int(pole.id),
                "mrid": str(getattr(pole, "mrid", None) or ""),
                "pole_number": str(pole.pole_number) if pole.pole_number else "",
                "pole_type": str(pole.pole_type) if pole.pole_type else "",
                "condition": str(pole.condition) if pole.condition else "good"
            }
            # Добавляем опциональные поля только если они не None
            if pole.height is not None:
                properties["height"] = float(pole.height)
            if getattr(pole, 'line_id', None) is not None:
                properties["power_line_id"] = int(pole.line_id)
            if pole.line and pole.line.name:
                properties["power_line_name"] = str(pole.line.name)
            if pole.connectivity_node_id is not None:
                properties["connectivity_node_id"] = int(pole.connectivity_node_id)
            if pole.sequence_number is not None:
                properties["sequence_number"] = int(pole.sequence_number)
            if pole.material:
                properties["material"] = str(pole.material)
            if pole.year_installed is not None:
                properties["year_installed"] = int(pole.year_installed)
            # Отпаечная опора — показывать кнопку «Начать отпайку» в панели и карточке
            if getattr(pole, 'is_tap_pole', False):
                properties["is_tap_pole"] = True

            # Убеждаемся, что координаты - это числа, а не None
            feature = {
                "type": "Feature",
                "properties": properties,
                "geometry": {
                    "type": "Point",
                    "coordinates": [float(longitude), float(latitude)]  # Явное приведение к float
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
    result = await db.execute(
        select(Tap).options(
            selectinload(Tap.position_points),
            selectinload(Tap.location).selectinload(Location.position_points)
        )
    )
    taps = result.scalars().all()
    
    features = []
    for tap in taps:
        # Получаем координаты из position_point (новая структура)
        longitude = None
        latitude = None
        
        # Пытаемся получить из position_points напрямую
        try:
            if hasattr(tap, 'position_points') and tap.position_points:
                point = tap.position_points[0]
                longitude = point.x_position
                latitude = point.y_position
        except (AttributeError, IndexError):
            pass
        
        # Fallback: пытаемся получить из старого поля или Location
        if longitude is None or latitude is None:
            longitude = getattr(tap, 'longitude', None)
            latitude = getattr(tap, 'latitude', None)
            
            # Пытаемся получить из Location, если доступно (уже загружено через selectinload)
            if longitude is None or latitude is None:
                try:
                    location = getattr(tap, 'location', None)
                    if location:
                        position_points = getattr(location, 'position_points', None)
                        if position_points and len(position_points) > 0:
                            point = position_points[0]
                            longitude = getattr(point, 'x_position', None)
                            latitude = getattr(point, 'y_position', None)
                except (AttributeError, IndexError, TypeError):
                    pass
        
        # Включаем только объекты с валидными координатами
        if longitude is not None and latitude is not None:
            try:
                longitude = float(longitude)
                latitude = float(latitude)
                # Проверяем, что координаты валидны
                if not (isinstance(longitude, (int, float)) and isinstance(latitude, (int, float))):
                    continue
                if longitude == float('inf') or latitude == float('inf') or longitude == float('-inf') or latitude == float('-inf'):
                    continue
            except (TypeError, ValueError):
                continue  # Пропускаем объекты с невалидными координатами
            
            # Создаем properties, исключая None значения
            properties = {
                "id": int(tap.id),
                "tap_number": str(tap.tap_number) if tap.tap_number else "",
                "tap_type": str(tap.tap_type) if tap.tap_type else ""
            }
            # Добавляем опциональные поля только если они не None
            if tap.voltage_level is not None:
                properties["voltage_level"] = float(tap.voltage_level)
            if tap.power_rating is not None:
                properties["power_rating"] = float(tap.power_rating)
            if getattr(tap, 'line_id', None) is not None:
                properties["power_line_id"] = int(tap.line_id)
            if tap.pole_id is not None:
                properties["pole_id"] = int(tap.pole_id)
            
            feature = {
                "type": "Feature",
                "properties": properties,
                "geometry": {
                    "type": "Point",
                    "coordinates": [longitude, latitude]
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
    result = await db.execute(
        select(Substation)
        .where(Substation.is_active == True)
        .options(selectinload(Substation.voltage_levels))
    )
    substations = result.scalars().all()

    features = []
    for substation in substations:
        # Получаем координаты из position_point (новая структура)
        longitude = None
        latitude = None
        
        # Пытаемся получить из position_points напрямую
        # Получаем координаты из старого поля (пока миграция не применена)
        longitude = getattr(substation, 'longitude', None)
        latitude = getattr(substation, 'latitude', None)

        # Пытаемся получить из Location, если доступно
        try:
            if hasattr(substation, 'position_points') and substation.position_points:
                point = substation.position_points[0]
                longitude = point.x_position
                latitude = point.y_position
        except (AttributeError, IndexError):
            pass
        
        # Fallback: пытаемся получить из старого поля или Location
        if longitude is None or latitude is None:
            longitude = getattr(substation, 'longitude', None)
            latitude = getattr(substation, 'latitude', None)
            
            # Пытаемся получить из Location, если доступно (уже загружено через selectinload)
            if longitude is None or latitude is None:
                try:
                    location = getattr(substation, 'location', None)
                    if location:
                        position_points = getattr(location, 'position_points', None)
                        if position_points and len(position_points) > 0:
                            point = position_points[0]
                            longitude = getattr(point, 'x_position', None)
                            latitude = getattr(point, 'y_position', None)
                except (AttributeError, IndexError, TypeError):
                    pass
        
        # Включаем только объекты с валидными координатами

        # Номинал: из уровней напряжения (110/10) или одно значение
        voltage_level = substation.voltage_level
        voltage_level_display = None
        if hasattr(substation, 'voltage_levels') and substation.voltage_levels:
            nominals = sorted([vl.nominal_voltage for vl in substation.voltage_levels], reverse=True)
            voltage_level_display = "/".join(str(int(v) if v == int(v) else v) for v in nominals)

        if longitude is not None and latitude is not None:
            try:
                longitude = float(longitude)
                latitude = float(latitude)
                # Проверяем, что координаты валидны
                if not (isinstance(longitude, (int, float)) and isinstance(latitude, (int, float))):
                    continue
                if longitude == float('inf') or latitude == float('inf') or longitude == float('-inf') or latitude == float('-inf'):
                    continue
            except (TypeError, ValueError):
                continue  # Пропускаем объекты с невалидными координатами
            
            # Создаем properties, исключая None значения
            properties = {
                "id": int(substation.id),
                "name": str(substation.name) if substation.name else "",
                "dispatcher_name": str(substation.dispatcher_name) if substation.dispatcher_name else ""
            }
            if substation.voltage_level is not None:
                properties["voltage_level"] = float(substation.voltage_level)
            if substation.branch_id is not None:
                properties["branch_id"] = int(substation.branch_id)
            if substation.address:
                properties["address"] = str(substation.address)
            if voltage_level_display is not None:
                properties["voltage_level_display"] = voltage_level_display
            feature = {
                "type": "Feature",
                "properties": properties,
                "geometry": {
                    "type": "Point",
                    "coordinates": [longitude, latitude]
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
            func.min(Pole.y_position).label('min_lat'),
            func.max(Pole.y_position).label('max_lat'),
            func.min(Pole.x_position).label('min_lng'),
            func.max(Pole.x_position).label('max_lng')
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

@router.get("/spans/geojson")
async def get_spans_geojson(
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение пролётов в формате GeoJSON"""
    from app.models.power_line import Span
    from app.models.cim_line_structure import ConnectivityNode
    
    from app.models.cim_line_structure import LineSection
    
    result = await db.execute(
        select(Span)
        .options(
            selectinload(Span.from_connectivity_node).selectinload(ConnectivityNode.pole).selectinload(Pole.position_points),
            selectinload(Span.to_connectivity_node).selectinload(ConnectivityNode.pole).selectinload(Pole.position_points),
            selectinload(Span.line),
            selectinload(Span.line_section)
        )
    )
    spans = result.scalars().all()
    
    features = []
    for span in spans:
        # Создаём LineString из координат начальной и конечной опор
        if span.from_connectivity_node and span.to_connectivity_node:
            # Получаем координаты из position_point
            from_longitude = None
            from_latitude = None
            to_longitude = None
            to_latitude = None
            
            # Координаты начальной точки
            try:
                pole = getattr(span.from_connectivity_node, 'pole', None)
                if pole:
                    position_points = getattr(pole, 'position_points', None)
                    if position_points and len(position_points) > 0:
                        point = position_points[0]
                        from_longitude = getattr(point, 'x_position', None)
                        from_latitude = getattr(point, 'y_position', None)
            except (AttributeError, IndexError, TypeError):
                pass
            
            # Fallback для начальной точки
            if from_longitude is None or from_latitude is None:
                from_longitude = getattr(span.from_connectivity_node, 'longitude', None)
                from_latitude = getattr(span.from_connectivity_node, 'latitude', None)
            
            # Координаты конечной точки
            try:
                pole = getattr(span.to_connectivity_node, 'pole', None)
                if pole:
                    position_points = getattr(pole, 'position_points', None)
                    if position_points and len(position_points) > 0:
                        point = position_points[0]
                        to_longitude = getattr(point, 'x_position', None)
                        to_latitude = getattr(point, 'y_position', None)
            except (AttributeError, IndexError, TypeError):
                pass
            
            # Fallback для конечной точки
            if to_longitude is None or to_latitude is None:
                to_longitude = getattr(span.to_connectivity_node, 'longitude', None)
                to_latitude = getattr(span.to_connectivity_node, 'latitude', None)
            
            # Включаем только если обе точки имеют валидные координаты
            if (from_longitude is not None and from_latitude is not None and 
                to_longitude is not None and to_latitude is not None):
                try:
                    from_longitude = float(from_longitude)
                    from_latitude = float(from_latitude)
                    to_longitude = float(to_longitude)
                    to_latitude = float(to_latitude)
                    
                    # Проверяем валидность координат
                    if not all(isinstance(x, (int, float)) for x in [from_longitude, from_latitude, to_longitude, to_latitude]):
                        continue
                    if any(x == float('inf') or x == float('-inf') for x in [from_longitude, from_latitude, to_longitude, to_latitude]):
                        continue
                except (TypeError, ValueError):
                    continue
                
                # Явное приведение к float для всех координат
                coordinates = [
                    [float(from_longitude), float(from_latitude)],
                    [float(to_longitude), float(to_latitude)]
                ]
                
                # Получаем acline_segment_id через line_section
                acline_segment_id = None
                if span.line_section:
                    acline_segment_id = span.line_section.acline_segment_id
                
                feature = {
                    "type": "Feature",
                    "properties": {
                        "id": int(span.id),
                        "mrid": str(span.mrid),
                        "span_number": str(span.span_number),
                        "length": float(span.length) if span.length is not None else None,
                        "conductor_type": str(span.conductor_type) if span.conductor_type else None,
                        "conductor_material": str(span.conductor_material) if span.conductor_material else None,
                        "conductor_section": str(span.conductor_section) if span.conductor_section else None,
                        "tension": float(span.tension) if span.tension is not None else None,
                        "sag": float(span.sag) if span.sag is not None else None,
                        "power_line_id": int(getattr(span, 'line_id', None)) if getattr(span, 'line_id', None) is not None else None,
                        "power_line_name": str(span.line.name) if span.line and span.line.name else None,
                        "from_connectivity_node_id": int(span.from_connectivity_node_id) if span.from_connectivity_node_id is not None else None,
                        "to_connectivity_node_id": int(span.to_connectivity_node_id) if span.to_connectivity_node_id is not None else None,
                        "from_pole_id": int(span.from_pole_id) if span.from_pole_id is not None else None,
                        "to_pole_id": int(span.to_pole_id) if span.to_pole_id is not None else None,
                        "acline_segment_id": int(acline_segment_id) if acline_segment_id is not None else None,
                        "segment_id": int(acline_segment_id) if acline_segment_id is not None else None,  # Для совместимости
                        "sequence_number": int(span.sequence_number) if span.sequence_number is not None else None,
                        "notes": str(span.notes) if span.notes else None
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
