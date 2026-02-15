"""
API для управления последовательностью опор
"""
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from sqlalchemy.orm import selectinload
import math

from app.database import get_db
from app.core.security import get_current_active_user
from app.models.user import User
from app.models.power_line import Pole, PowerLine
from app.schemas.power_line import PoleResponse

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
            current_pole.latitude, current_pole.longitude,
            pole.latitude, pole.longitude
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


@router.get("/power-lines/{power_line_id}/poles/sequence", response_model=List[PoleResponse])
async def get_poles_sequence(
    power_line_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение опор линии, отсортированных по последовательности"""
    from app.models.cim_line_structure import ConnectivityNode
    
    result = await db.execute(
        select(Pole)
        .options(selectinload(Pole.connectivity_nodes))
        .where(Pole.line_id == power_line_id)
        .order_by(Pole.sequence_number.asc().nullslast(), Pole.pole_number.asc())
    )
    poles = result.scalars().all()
    
    # Для обратной совместимости добавляем connectivity_node и connectivity_node_id
    # в каждый объект Pole перед сериализацией
    for pole in poles:
        # Находим ConnectivityNode для этой линии
        cn = pole.get_connectivity_node_for_line(power_line_id)
        # Устанавливаем как обычные атрибуты для Pydantic сериализации
        setattr(pole, 'connectivity_node', cn)
        setattr(pole, 'connectivity_node_id', cn.id if cn else None)
    
    return poles

