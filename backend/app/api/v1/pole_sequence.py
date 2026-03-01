"""
API для управления последовательностью опор
"""
from typing import List, Optional
import logging
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from sqlalchemy.orm import selectinload
from pydantic import ValidationError
import math

logger = logging.getLogger(__name__)

from app.database import get_db
from app.core.security import get_current_active_user
from app.models.user import User
from app.models.power_line import Pole, PowerLine
from app.models.location import Location
from app.schemas.cim_line_structure import ConnectivityNodeResponse

router = APIRouter()


def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Расчёт расстояния между двумя точками (в метрах) по формуле Гаверсинуса"""
    R = 6371000  # Радиус Земли в метрах
    
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    
    a = math.sin(delta_phi / 2) ** 2 + \
        math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    
    return R * c


def find_nearest_pole(poles: List[Pole], current_pole: Pole, visited: set) -> Optional[Pole]:
    """Находит ближайшую непосещённую опору"""
    min_distance = float('inf')
    nearest = None
    
    for pole in poles:
        if pole.id in visited or pole.id == current_pole.id:
            continue
        
        distance = calculate_distance(
            current_pole.get_latitude(), current_pole.get_longitude(),
            pole.get_latitude(), pole.get_longitude(),
        )
        
        if distance < min_distance:
            min_distance = distance
            nearest = pole
    
    return nearest


@router.post("/power-lines/{power_line_id}/poles/auto-sequence")
async def auto_sequence_poles(
    power_line_id: int,
    start_pole_id: Optional[int] = None,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Автоматическое определение последовательности опор на основе координат
    
    Алгоритм:
    1. Начинаем с указанной опоры (или первой по номеру)
    2. Находим ближайшую непосещённую опору
    3. Повторяем до тех пор, пока все опоры не будут посещены
    """
    # Получаем все опоры линии
    result = await db.execute(
        select(Pole).where(Pole.line_id == power_line_id).order_by(Pole.pole_number)
    )
    poles = result.scalars().all()
    
    if not poles:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Опоры не найдены"
        )
    
    # Определяем начальную опору
    if start_pole_id:
        start_pole = next((p for p in poles if p.id == start_pole_id), None)
        if not start_pole:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Начальная опора не найдена"
            )
    else:
        # Берём первую опору по номеру
        start_pole = poles[0]
    
    # Строим последовательность
    sequence = [start_pole]
    visited = {start_pole.id}
    current_pole = start_pole
    
    while len(visited) < len(poles):
        nearest = find_nearest_pole(poles, current_pole, visited)
        if not nearest:
            break
        
        sequence.append(nearest)
        visited.add(nearest.id)
        current_pole = nearest
    
    # Обновляем sequence_number для всех опор
    for index, pole in enumerate(sequence, start=1):
        pole.sequence_number = index
    
    await db.commit()
    
    # Обновляем все опоры
    for pole in sequence:
        await db.refresh(pole)
    
    return {
        "message": f"Последовательность обновлена для {len(sequence)} опор",
        "sequence": [{"id": p.id, "pole_number": p.pole_number, "sequence": p.sequence_number} for p in sequence]
    }


@router.put("/power-lines/{power_line_id}/poles/sequence")
async def update_pole_sequence(
    power_line_id: int,
    pole_sequence: List[int],  # Список ID опор в нужном порядке
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Ручное обновление последовательности опор
    
    Принимает список ID опор в нужном порядке
    """
    # Проверяем существование линии
    power_line = await db.get(PowerLine, power_line_id)
    if not power_line:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Линия не найдена"
        )
    
    # Проверяем, что все опоры принадлежат этой линии
    result = await db.execute(
        select(Pole).where(
            Pole.line_id == power_line_id,
            Pole.id.in_(pole_sequence)
        )
    )
    poles = {p.id: p for p in result.scalars().all()}
    
    if len(poles) != len(pole_sequence):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Не все опоры принадлежат этой линии или некоторые опоры не найдены"
        )
    
    # Обновляем sequence_number
    for sequence_number, pole_id in enumerate(pole_sequence, start=1):
        if pole_id in poles:
            poles[pole_id].sequence_number = sequence_number
    
    await db.commit()
    
    return {
        "message": f"Последовательность обновлена для {len(pole_sequence)} опор",
        "sequence": [{"id": pid, "sequence": idx} for idx, pid in enumerate(pole_sequence, start=1)]
    }


@router.get("/power-lines/{power_line_id}/poles/sequence")
async def get_poles_sequence(
    power_line_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение опор линии, отсортированных по последовательности. Возвращает список опор для выбора в диалоге редактирования пролёта."""
    from app.api.v1.power_lines import fill_pole_coordinates
    from datetime import datetime, timezone

    result = await db.execute(
        select(Pole)
        .options(
            selectinload(Pole.connectivity_nodes),
            selectinload(Pole.position_points),
            selectinload(Pole.location).selectinload(Location.position_points),
        )
        .where(Pole.line_id == power_line_id)
        .order_by(Pole.sequence_number.asc().nulls_last(), Pole.pole_number.asc())
    )
    poles = result.scalars().all()

    out = []
    for pole in poles:
        fill_pole_coordinates(pole)
        mrid = getattr(pole, "mrid", None) or ""
        pole_number = getattr(pole, "pole_number", None) or ""
        pole_type = getattr(pole, "pole_type", None) or ""
        created_by = getattr(pole, "created_by", None) or 0
        _created_at = getattr(pole, "created_at", None)
        created_at = _created_at.isoformat() if hasattr(_created_at, "isoformat") else datetime.now(timezone.utc).isoformat()
        x_pos = getattr(pole, "x_position", None)
        y_pos = getattr(pole, "y_position", None)
        if x_pos is None:
            x_pos = 0.0
        if y_pos is None:
            y_pos = 0.0
        cn = pole.get_connectivity_node_for_line(power_line_id)
        cn_out = None
        cn_id = None
        if cn is not None and getattr(cn, "pole_id", None) is not None:
            try:
                cn_out = ConnectivityNodeResponse.model_validate(cn).model_dump()
                cn_id = cn.id
            except (ValidationError, TypeError):
                pass
        _updated_at = getattr(pole, "updated_at", None)
        updated_at = _updated_at.isoformat() if _updated_at and hasattr(_updated_at, "isoformat") else None
        out.append({
            "id": pole.id,
            "mrid": mrid,
            "line_id": pole.line_id,
            "connectivity_node_id": cn_id,
            "pole_number": pole_number,
            "pole_type": pole_type,
            "x_position": float(x_pos),
            "y_position": float(y_pos),
            "sequence_number": getattr(pole, "sequence_number", None),
            "height": getattr(pole, "height", None),
            "foundation_type": getattr(pole, "foundation_type", None),
            "material": getattr(pole, "material", None),
            "year_installed": getattr(pole, "year_installed", None),
            "condition": getattr(pole, "condition", None) or "good",
            "notes": getattr(pole, "notes", None),
            "conductor_type": getattr(pole, "conductor_type", None),
            "conductor_material": getattr(pole, "conductor_material", None),
            "conductor_section": getattr(pole, "conductor_section", None),
            "is_tap_pole": bool(getattr(pole, "is_tap_pole", False)),
            "branch_type": getattr(pole, "branch_type", None),
            "tap_pole_id": getattr(pole, "tap_pole_id", None),
            "created_by": created_by,
            "created_at": created_at,
            "updated_at": updated_at,
            "connectivity_node": cn_out,
        })
    return out
