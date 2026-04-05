from typing import List, Dict, Any, Optional
import math
import re
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.core.security import get_current_active_user
from app.models.user import User
from app.models.power_line import PowerLine, Pole, Tap, Span, Equipment
from app.models.substation import Substation
from app.models.location import Location, PositionPoint
from app.models.cim_line_structure import ConnectivityNode, LineSection
import logging

logger = logging.getLogger(__name__)
router = APIRouter()

def filter_none_properties(props: Dict[str, Any]) -> Dict[str, Any]:
    """Удаляет None значения из properties для совместимости с Flutter"""
    return {k: v for k, v in props.items() if v is not None}


def _segment_name_to_short(s: Optional[str]) -> Optional[str]:
    """«Опора 4 - Опора 5» → «оп.4 - оп.5». Имя ПС («Опора старт») не сокращать в «оп.старт»."""
    if not s or not s.strip():
        return s
    t = s.strip()
    # Только номера опор: «Опора 3» → «оп.3»
    t = re.sub(r"Опора\s+(?=\d)", "оп.", t, flags=re.IGNORECASE)
    # «Опора старт» и т.п. (не номер) — убрать приставку «Опора »
    t = re.sub(r"Опора\s+([^\d\s].*)", r"\1", t, flags=re.IGNORECASE)
    return t.strip()


def _equipment_icon_key(equipment_type: str, name: Optional[str] = None) -> Optional[str]:
    """
    Ключ иконки оборудования для отрисовки на карте (как во Flutter).
    Возвращает: recloser | breaker | zn | disconnector | arrester или None (не рисовать).
    """
    t = (equipment_type or "").lower()
    n = (name or "").lower()
    if "реклоузер" in t or "реклоузер" in n or "recloser" in n:
        return "recloser"
    if "выключател" in t or "выключател" in n or "breaker" in n:
        return "breaker"
    if "зн" in t or "заземлен" in t:
        return "zn"
    if "разъединитель" in t or "разъеденитель" in t or "разъедин" in t or "disconnector" in t:
        return "disconnector"
    if "разрядник" in t or "опн" in n:
        return "arrester"
    no_icon = ("фундамент", "изолятор", "траверс", "грозоотвод", "грозотрос")
    if any(x in t for x in no_icon):
        return None
    return None

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


def _pole_coords_from_position_point(pole):
    """Координаты опоры по CIM: только из PositionPoint (location/position_points или position_points)."""
    pts = getattr(pole, "position_points", None)
    if pts and len(pts) > 0:
        return getattr(pts[0], "x_position", None), getattr(pts[0], "y_position", None)
    loc = getattr(pole, "location", None)
    if loc and getattr(loc, "position_points", None) and len(loc.position_points) > 0:
        p = loc.position_points[0]
        return getattr(p, "x_position", None), getattr(p, "y_position", None)
    return None, None


def _tap_visual_group_key(pole) -> str | None:
    """
    Устойчивый ключ визуальной ветки отпайки.
    Две части номера (N/M) — обычная отпайка, корень N.
    Три и более сегментов — отпайка от отпайки: ключ по префиксу без последнего
    сегмента, чтобы не сливать с веткой N/M при совпадении первого сегмента.
    """
    tap_pole_id = getattr(pole, "tap_pole_id", None)
    if tap_pole_id is None:
        return None

    pole_number = (getattr(pole, "pole_number", None) or "").strip()
    parts = [p.strip() for p in pole_number.split("/") if p.strip()]
    tap_branch_index = getattr(pole, "tap_branch_index", None)

    if len(parts) >= 3:
        path_prefix = "/".join(parts[:-1])
        if tap_branch_index is not None:
            return f"{int(tap_pole_id)}:sub:{path_prefix}:b:{int(tap_branch_index)}"
        return f"{int(tap_pole_id)}:sub:{path_prefix}"

    if len(parts) >= 2:
        root = parts[0]
        if root:
            return f"{int(tap_pole_id)}:r:{root}"

    if tap_branch_index is not None:
        return f"{int(tap_pole_id)}:b:{int(tap_branch_index)}"

    return f"{int(tap_pole_id)}:fallback"


async def _get_power_lines_geojson_impl(db: AsyncSession):
    result = await db.execute(
        select(PowerLine).options(
            selectinload(PowerLine.poles).selectinload(Pole.position_points),
            selectinload(PowerLine.poles).selectinload(Pole.location).selectinload(Location.position_points),
        )
    )
    power_lines = result.scalars().all()

    features = []
    for power_line in power_lines:
        poles_list = list(power_line.poles or [])
        # Считаем количество опор с валидными координатами, используя helper-методы модели
        poles_with_coords = 0
        for p in poles_list:
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
            power_line.id, power_line.name, len(poles_list), poles_with_coords
        )

        def _default_properties():
            return {
                "id": int(power_line.id),
                "name": str(power_line.name) if power_line.name else "",
                "status": str(power_line.status) if power_line.status else "active",
                "pole_count": len(poles_list),
            }

        def _line_feature_no_geometry():
            """ЛЭП — не точка в пространстве; без опор или без координат у опор геометрия отсутствует."""
            props = _default_properties()
            if power_line.voltage_level is not None:
                props["voltage_level"] = float(power_line.voltage_level)
            return {
                "type": "Feature",
                "properties": props,
                "geometry": None,
            }

        # Создаем LineString из координат опор по CIM (только Location/PositionPoint)
        # Магистраль: опоры с tap_pole_id is None. Отпайки: отдельная цепочка от каждой отпаечной опоры (зелёный цвет на фронте).
        def _add_line_feature(coords: list, props: dict, branch_type: str = "main", tap_pole_id_val=None):
            if len(coords) < 2:
                return
            p = dict(props)
            if tap_pole_id_val is not None:
                p["branch_type"] = "tap"
                p["tap_pole_id"] = int(tap_pole_id_val)
            else:
                p["branch_type"] = "main"
            features.append({
                "type": "Feature",
                "properties": p,
                "geometry": {"type": "LineString", "coordinates": coords}
            })

        def _line_sort_key(p):
            sn = getattr(p, "sequence_number", None)
            if sn is not None:
                return (0, sn, (p.pole_number or ""))
            return (1, 0, (p.pole_number or ""))

        if len(poles_list) >= 2:
            # Магистраль: опоры с tap_pole_id is None
            main_poles = [p for p in poles_list if getattr(p, "tap_pole_id", None) is None]
            main_coords = []
            for pole in sorted(main_poles, key=_line_sort_key):
                longitude, latitude = _pole_coords_from_position_point(pole)
                if longitude is not None and latitude is not None:
                    try:
                        longitude, latitude = float(longitude), float(latitude)
                        if (longitude != float('inf') and latitude != float('inf') and
                            longitude != float('-inf') and latitude != float('-inf') and
                            not math.isnan(longitude) and not math.isnan(latitude)):
                            main_coords.append([longitude, latitude])
                    except (TypeError, ValueError):
                        continue
            if len(main_coords) >= 2:
                properties = {
                    "id": int(power_line.id),
                    "name": str(power_line.name) if power_line.name else "",
                    "status": str(power_line.status) if power_line.status else "active",
                    "pole_count": len(poles_list)
                }
                if power_line.voltage_level is not None:
                    properties["voltage_level"] = float(power_line.voltage_level)
                _add_line_feature(main_coords, properties, "main", None)

            tap_poles_by_id = {p.id: p for p in poles_list}
            branch_groups = {}
            for pole in poles_list:
                branch_key = _tap_visual_group_key(pole)
                if branch_key is None:
                    continue
                branch_groups.setdefault(branch_key, []).append(pole)

            for branch_key, branch_poles in branch_groups.items():
                if not branch_poles:
                    continue
                tpid = getattr(branch_poles[0], "tap_pole_id", None)
                if tpid is None:
                    continue
                tap_pole = tap_poles_by_id.get(tpid)
                if not tap_pole:
                    continue
                coords = []
                x0, y0 = _pole_coords_from_position_point(tap_pole)
                if x0 is not None and y0 is not None:
                    try:
                        coords.append([float(x0), float(y0)])
                    except (TypeError, ValueError):
                        pass
                for pole in sorted(branch_poles, key=_line_sort_key):
                    longitude, latitude = _pole_coords_from_position_point(pole)
                    if longitude is not None and latitude is not None:
                        try:
                            longitude, latitude = float(longitude), float(latitude)
                            if (longitude != float('inf') and latitude != float('inf') and
                                longitude != float('-inf') and latitude != float('-inf') and
                                not math.isnan(longitude) and not math.isnan(latitude)):
                                coords.append([longitude, latitude])
                        except (TypeError, ValueError):
                            continue
                if len(coords) >= 2:
                    properties = {
                        "id": int(power_line.id),
                        "name": str(power_line.name) if power_line.name else "",
                        "status": str(power_line.status) if power_line.status else "active",
                        "pole_count": len(poles_list)
                    }
                    if power_line.voltage_level is not None:
                        properties["voltage_level"] = float(power_line.voltage_level)
                    tap_branch_index = getattr(branch_poles[0], "tap_branch_index", None)
                    if tap_branch_index is not None:
                        properties["tap_branch_index"] = int(tap_branch_index)
                    # Чтобы ключ ветки на фронте совпадал с точками опор (getPoleVisualBranchKey: r:корень из pole_number),
                    # а не только с tap_branch_index (b:…), иначе полилиния строится из сырой геометрии API.
                    rep = sorted(branch_poles, key=_line_sort_key)[0]
                    rep_pn = (getattr(rep, "pole_number", None) or "").strip()
                    if rep_pn:
                        properties["pole_number"] = rep_pn
                    _add_line_feature(coords, properties, "tap", tpid)

            # Если не добавили ни одной линии (например, все опоры без координат), ЛЭП без геометрии
            if not features or features[-1].get("properties", {}).get("id") != int(power_line.id):
                if len(poles_list) >= 2:
                    features.append(_line_feature_no_geometry())
        elif len(poles_list) == 1:
            # Одна опора: линия не является точкой в пространстве — только свойства, без геометрии
            if not features or features[-1].get("properties", {}).get("id") != int(power_line.id):
                features.append(_line_feature_no_geometry())
        else:
            # Ноль опор: ЛЭП без геометрии (линия не точка в пространстве)
            properties = {
                "id": int(power_line.id),
                "name": str(power_line.name) if power_line.name else "",
                "status": str(power_line.status) if power_line.status else "active",
                "pole_count": 0
            }
            if power_line.voltage_level is not None:
                properties["voltage_level"] = float(power_line.voltage_level)
            features.append({
                "type": "Feature",
                "properties": properties,
                "geometry": None,
            })

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
            selectinload(Pole.connectivity_nodes).selectinload(ConnectivityNode.from_segments),
            selectinload(Pole.connectivity_nodes).selectinload(ConnectivityNode.to_segments),
            selectinload(Pole.position_points),
            selectinload(Pole.location).selectinload(Location.position_points)
        )
    )
    poles = result.scalars().all()
    
    # Для отпаечных опор: у каких уже есть хотя бы одна опора по отпайке (tap_pole_id = id отпаечной)
    tap_pole_ids_with_branch = {
        p.tap_pole_id for p in poles
        if getattr(p, "tap_pole_id", None) is not None
    }
    
    features = []
    for pole in poles:
        # CIM: координаты только из Location/PositionPoint
        longitude, latitude = _pole_coords_from_position_point(pole)
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
            line_id_val = getattr(pole, 'line_id', None)
            if line_id_val is None and pole.line is not None:
                line_id_val = getattr(pole.line, 'id', None)
            if line_id_val is not None:
                properties["line_id"] = int(line_id_val)
            if pole.line and pole.line.name:
                properties["power_line_name"] = str(pole.line.name)
            if pole.connectivity_node_id is not None:
                properties["connectivity_node_id"] = int(pole.connectivity_node_id)
            if pole.sequence_number is not None:
                properties["sequence_number"] = int(pole.sequence_number)
            # segment_id и segment_name для дерева: из ConnectivityNode -> AClineSegment (from/to)
            segment_id = None
            segment_name = None
            for cn in (pole.connectivity_nodes or []):
                for seg in (getattr(cn, "from_segments", None) or []) + (getattr(cn, "to_segments", None) or []):
                    if seg and getattr(seg, "id", None) is not None:
                        segment_id = int(seg.id)
                        segment_name = getattr(seg, "name", None)
                        break
                if segment_id is not None:
                    break
            if segment_id is not None:
                properties["segment_id"] = segment_id
                properties["acline_segment_id"] = segment_id
            if segment_name:
                properties["segment_name"] = _segment_name_to_short(str(segment_name)) or str(segment_name)
            if pole.material:
                properties["material"] = str(pole.material)
            if pole.year_installed is not None:
                properties["year_installed"] = int(pole.year_installed)
            if getattr(pole, "branch_type", None):
                properties["branch_type"] = str(pole.branch_type)
            if getattr(pole, "tap_pole_id", None) is not None:
                properties["tap_pole_id"] = int(pole.tap_pole_id)
            if getattr(pole, "tap_branch_index", None) is not None:
                properties["tap_branch_index"] = int(pole.tap_branch_index)
            if getattr(pole, "is_tap_pole", None) is True:
                properties["is_tap_pole"] = True
                # Оранжевый = отпайка не начата, зелёный = от отпаечной уже есть опоры
                properties["tap_branch_has_poles"] = pole.id in tap_pole_ids_with_branch

            # Карточка опоры (комментарий и вложения) — для панели свойств на карте
            cc = getattr(pole, "card_comment", None)
            if cc:
                properties["card_comment"] = str(cc)
            ca = getattr(pole, "card_comment_attachment", None)
            if ca:
                properties["card_comment_attachment"] = str(ca)

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
                properties["line_id"] = int(tap.line_id)
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
        .options(
            selectinload(Substation.voltage_levels),
            selectinload(Substation.location).selectinload(Location.position_points),
            selectinload(Substation.position_points),
        )
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
    """Получение границ всех данных для настройки карты (по CIM: из position_point)."""
    result = await db.execute(
        select(
            func.min(PositionPoint.y_position).label('min_lat'),
            func.max(PositionPoint.y_position).label('max_lat'),
            func.min(PositionPoint.x_position).label('min_lng'),
            func.max(PositionPoint.x_position).label('max_lng')
        ).select_from(PositionPoint)
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

@router.get("/equipment/geojson")
async def get_equipment_geojson(
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Оборудование на карте: точки между соседними опорами (как во Flutter).
    Каждая фича — Point с properties: icon (ключ: recloser|breaker|zn|disconnector|arrester),
    angle_rad, equipment_type, name, from_pole_id, to_pole_id, line_id.
    """
    try:
        return await _get_equipment_geojson_impl(db)
    except Exception as e:
        logger.exception("map/equipment/geojson: %s", e)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"map/equipment/geojson: {type(e).__name__}: {e}",
        ) from e


def _line_sort_key(p):
    """Сортировка опор: sequence_number, затем pole_number."""
    sn = getattr(p, "sequence_number", None)
    if sn is not None:
        return (0, sn, (p.pole_number or ""))
    return (1, 0, (p.pole_number or ""))


async def _get_equipment_geojson_impl(db: AsyncSession):
    result = await db.execute(
        select(PowerLine)
        .options(
            selectinload(PowerLine.poles).selectinload(Pole.position_points),
            selectinload(PowerLine.poles).selectinload(Pole.location).selectinload(Location.position_points),
            selectinload(PowerLine.poles).selectinload(Pole.equipment),
        )
    )
    power_lines = result.scalars().all()
    features: List[Dict[str, Any]] = []

    for power_line in power_lines:
        poles_list = list(power_line.poles or [])
        if len(poles_list) < 2:
            continue

        # Магистраль: опоры с tap_pole_id is None, сортировка по sequence_number
        main_poles = [p for p in poles_list if getattr(p, "tap_pole_id", None) is None]
        main_poles.sort(key=_line_sort_key)

        # Пары (предыдущая, текущая) для магистрали; оборудование на текущей опоре рисуем на пролёте к ней
        for i in range(len(main_poles) - 1):
            p1, p2 = main_poles[i], main_poles[i + 1]
            x1, y1 = _pole_coords_from_position_point(p1)
            x2, y2 = _pole_coords_from_position_point(p2)
            if x1 is None or y1 is None or x2 is None or y2 is None:
                continue
            try:
                x1, y1 = float(x1), float(y1)
                x2, y2 = float(x2), float(y2)
            except (TypeError, ValueError):
                continue
            eq_list = list(getattr(p2, "equipment", None) or [])
            visible = [e for e in eq_list if _equipment_icon_key(e.equipment_type, e.name) is not None]
            for j, e in enumerate(visible):
                icon_key = _equipment_icon_key(e.equipment_type, e.name)
                if not icon_key:
                    continue
                t = 0.8 if len(visible) == 1 else 0.6 + (0.3 * (j / max(1, len(visible) - 1)))
                lng = x1 + (x2 - x1) * t
                lat = y1 + (y2 - y1) * t
                angle_rad = math.atan2(y2 - y1, x2 - x1)
                features.append({
                    "type": "Feature",
                    "geometry": {"type": "Point", "coordinates": [lng, lat]},
                    "properties": {
                        "icon": icon_key,
                        "angle_rad": angle_rad,
                        "equipment_type": e.equipment_type,
                        "name": e.name or "",
                        "from_pole_id": p1.id,
                        "to_pole_id": p2.id,
                        "line_id": power_line.id,
                    },
                })

        # Отпайки: для каждой отпаечной опоры X цепочка [X, опоры с tap_pole_id=X]
        tap_pole_ids = {getattr(p, "tap_pole_id", None) for p in poles_list if getattr(p, "tap_pole_id", None) is not None}
        tap_poles_by_id = {p.id: p for p in poles_list}
        for tpid in tap_pole_ids:
            tap_pole = tap_poles_by_id.get(tpid)
            if not tap_pole:
                continue
            branch_poles = [p for p in poles_list if getattr(p, "tap_pole_id", None) == tpid]
            branch_poles.sort(key=_line_sort_key)
            chain = [tap_pole] + branch_poles
            for i in range(len(chain) - 1):
                p1, p2 = chain[i], chain[i + 1]
                x1, y1 = _pole_coords_from_position_point(p1)
                x2, y2 = _pole_coords_from_position_point(p2)
                if x1 is None or y1 is None or x2 is None or y2 is None:
                    continue
                try:
                    x1, y1 = float(x1), float(y1)
                    x2, y2 = float(x2), float(y2)
                except (TypeError, ValueError):
                    continue
                eq_list = list(getattr(p2, "equipment", None) or [])
                visible = [e for e in eq_list if _equipment_icon_key(e.equipment_type, e.name) is not None]
                for j, e in enumerate(visible):
                    icon_key = _equipment_icon_key(e.equipment_type, e.name)
                    if not icon_key:
                        continue
                    t = 0.8 if len(visible) == 1 else 0.6 + (0.3 * (j / max(1, len(visible) - 1)))
                    lng = x1 + (x2 - x1) * t
                    lat = y1 + (y2 - y1) * t
                    angle_rad = math.atan2(y2 - y1, x2 - x1)
                    features.append({
                        "type": "Feature",
                        "geometry": {"type": "Point", "coordinates": [lng, lat]},
                        "properties": {
                            "icon": icon_key,
                            "angle_rad": angle_rad,
                            "equipment_type": e.equipment_type,
                            "name": e.name or "",
                            "from_pole_id": p1.id,
                            "to_pole_id": p2.id,
                            "line_id": power_line.id,
                        },
                    })

    return {"type": "FeatureCollection", "features": features}


@router.get("/spans/geojson")
async def get_spans_geojson(
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение пролётов в формате GeoJSON"""
    from app.models.power_line import Span
    from app.models.cim_line_structure import ConnectivityNode

    result = await db.execute(
        select(Span)
        .options(
            selectinload(Span.from_connectivity_node).selectinload(ConnectivityNode.pole).selectinload(Pole.position_points),
            selectinload(Span.to_connectivity_node).selectinload(ConnectivityNode.pole).selectinload(Pole.position_points),
            selectinload(Span.line),
            selectinload(Span.line_section).selectinload(LineSection.acline_segment)
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
            
            # Fallback для начальной точки (узел без опоры — подстанция: координаты в x_position, y_position)
            if from_longitude is None or from_latitude is None:
                from_longitude = getattr(span.from_connectivity_node, 'longitude', None) or getattr(span.from_connectivity_node, 'x_position', None)
                from_latitude = getattr(span.from_connectivity_node, 'latitude', None) or getattr(span.from_connectivity_node, 'y_position', None)
            
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
            
            # Fallback для конечной точки (узел без опоры — подстанция: координаты в x_position, y_position)
            if to_longitude is None or to_latitude is None:
                to_longitude = getattr(span.to_connectivity_node, 'longitude', None) or getattr(span.to_connectivity_node, 'x_position', None)
                to_latitude = getattr(span.to_connectivity_node, 'latitude', None) or getattr(span.to_connectivity_node, 'y_position', None)
            
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
                
                # Получаем acline_segment_id и название участка через line_section
                acline_segment_id = None
                segment_name = None
                segment_branch_type = None
                segment_tap_pole_id = None
                segment_is_tap = None
                if span.line_section and span.line_section.acline_segment:
                    seg = span.line_section.acline_segment
                    acline_segment_id = seg.id
                    segment_name = getattr(seg, "name", None)
                    segment_branch_type = getattr(seg, "branch_type", None)
                    segment_tap_pole_id = getattr(seg, "tap_pole_id", None)
                    if getattr(seg, "is_tap", None) is not None:
                        segment_is_tap = bool(seg.is_tap)
                
                feature = {
                    "type": "Feature",
                    "properties": {
                        "id": int(span.id),
                        "mrid": str(span.mrid),
                        "span_number": str(span.span_number),
                        "segment_name": _segment_name_to_short(str(segment_name)) if segment_name else None,
                        "length": float(span.length) if span.length is not None else None,
                        "conductor_type": str(span.conductor_type) if span.conductor_type else None,
                        "conductor_material": str(span.conductor_material) if span.conductor_material else None,
                        "conductor_section": str(span.conductor_section) if span.conductor_section else None,
                        "tension": float(span.tension) if span.tension is not None else None,
                        "sag": float(span.sag) if span.sag is not None else None,
                        "line_id": int(getattr(span, 'line_id', None)) if getattr(span, 'line_id', None) is not None else None,
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
                if segment_branch_type:
                    feature["properties"]["branch_type"] = str(segment_branch_type)
                if segment_tap_pole_id is not None:
                    feature["properties"]["tap_pole_id"] = int(segment_tap_pole_id)
                if span.line and getattr(span.line, "voltage_level", None) is not None:
                    feature["properties"]["voltage_level"] = float(span.line.voltage_level)
                if segment_is_tap is not None:
                    feature["properties"]["segment_is_tap"] = segment_is_tap
                features.append(feature)
    
    return {
        "type": "FeatureCollection",
        "features": features
    }
