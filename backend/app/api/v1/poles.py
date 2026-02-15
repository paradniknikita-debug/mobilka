from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete, update
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.core.security import get_current_active_user
from app.models.user import User
from app.models.power_line import Pole, Equipment
from app.schemas.power_line import EquipmentCreate, EquipmentResponse, PoleResponse

router = APIRouter()

@router.get("/", response_model=List[PoleResponse])
async def get_all_poles(
    skip: int = 0,
    limit: int = 100,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение всех опор"""
    result = await db.execute(
        select(Pole)
        .options(
            selectinload(Pole.equipment),
            selectinload(Pole.position_points)  # Загружаем position_points для координат
        )
        .offset(skip)
        .limit(limit)
    )
    poles = result.scalars().all()
    
    # Заполняем координаты для каждой опоры
    from app.api.v1.power_lines import fill_pole_coordinates
    for pole in poles:
        fill_pole_coordinates(pole)
    
    return poles

@router.get("/{pole_id}", response_model=PoleResponse)
async def get_pole(
    pole_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение опоры по ID"""
    result = await db.execute(
        select(Pole)
        .options(
            selectinload(Pole.equipment),
            selectinload(Pole.position_points)  # Загружаем position_points для координат
        )
        .where(Pole.id == pole_id)
    )
    pole = result.scalar_one_or_none()
    if not pole:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pole not found"
        )
    
    # Заполняем координаты
    from app.api.v1.power_lines import fill_pole_coordinates
    fill_pole_coordinates(pole)
    
    return pole

@router.post("/{pole_id}/equipment", response_model=EquipmentResponse)
async def create_equipment(
    pole_id: int,
    equipment_data: EquipmentCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Добавление оборудования к опоре"""
    
    # Проверка существования опоры
    pole = await db.get(Pole, pole_id)
    if not pole:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pole not found"
        )
    
    db_equipment = Equipment(
        **equipment_data.dict(),
        pole_id=pole_id,
        created_by=current_user.id
    )
    db.add(db_equipment)
    await db.commit()
    await db.refresh(db_equipment)
    return db_equipment

@router.get("/{pole_id}/equipment", response_model=List[EquipmentResponse])
async def get_pole_equipment(
    pole_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение оборудования опоры"""
    result = await db.execute(
        select(Equipment).where(Equipment.pole_id == pole_id)
    )
    equipment = result.scalars().all()
    return equipment

@router.delete("/{pole_id}", status_code=status.HTTP_200_OK)
async def delete_pole(
    pole_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Удаление опоры"""
    import traceback
    
    try:
        print(f"DEBUG: Попытка удаления опоры {pole_id} пользователем {current_user.id}")
        
        # Проверяем существование опоры
        result = await db.execute(
            select(Pole).where(Pole.id == pole_id)
        )
        pole = result.scalar_one_or_none()
        
        if not pole:
            print(f"DEBUG: Опора {pole_id} не найдена")
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Pole not found"
            )
        
        print(f"DEBUG: Опора {pole_id} найдена: {pole.pole_number}")
        
        # Удаляем связанные объекты перед удалением опоры
        from app.models.cim_line_structure import ConnectivityNode
        from app.models.acline_segment import AClineSegment
        from app.models.power_line import Span
        
        # Получаем все ConnectivityNode для этой опоры (может быть несколько)
        connectivity_nodes_result = await db.execute(
            select(ConnectivityNode).where(ConnectivityNode.pole_id == pole_id)
        )
        connectivity_nodes = connectivity_nodes_result.scalars().all()
        
        print(f"DEBUG: Найдено ConnectivityNode для опоры: {len(connectivity_nodes)}")
        
        # Удаляем только Span и AClineSegment, которые напрямую связаны с удаляемой опорой
        # Это позволяет сохранить остальную структуру линии
        from app.models.cim_line_structure import LineSection
        
        for cn in connectivity_nodes:
            connectivity_node_id = cn.id
            print(f"DEBUG: Удаление объектов, связанных с ConnectivityNode {connectivity_node_id}")
            
            # Получаем AClineSegment, которые начинаются с этого ConnectivityNode
            # (нужно удалить их LineSection и Span перед удалением сегментов)
            acline_segments_from = await db.execute(
                select(AClineSegment).where(AClineSegment.from_connectivity_node_id == connectivity_node_id)
            )
            acline_segments_to_delete = list(acline_segments_from.scalars().all())
            
            # Для каждого AClineSegment удаляем связанные объекты в правильном порядке
            for acline_seg in acline_segments_to_delete:
                # Получаем все LineSection для этого AClineSegment
                line_sections_result = await db.execute(
                    select(LineSection).where(LineSection.acline_segment_id == acline_seg.id)
                )
                line_sections = list(line_sections_result.scalars().all())
                
                # Сначала удаляем все Span, которые ссылаются на эти LineSection
                for line_section in line_sections:
                    span_stmt = delete(Span).where(Span.line_section_id == line_section.id)
                    await db.execute(span_stmt)
                    print(f"DEBUG: Удалены Span для LineSection {line_section.id}")
                
                # Теперь можно безопасно удалить LineSection
                line_sections_stmt = delete(LineSection).where(LineSection.acline_segment_id == acline_seg.id)
                await db.execute(line_sections_stmt)
                print(f"DEBUG: Удалены LineSection для AClineSegment {acline_seg.id}")
            
            # Удаляем Span, которые начинаются или заканчиваются в этом узле
            # Это пролёты, которые напрямую связаны с удаляемой опорой
            span_from_stmt = delete(Span).where(Span.from_connectivity_node_id == connectivity_node_id)
            span_to_stmt = delete(Span).where(Span.to_connectivity_node_id == connectivity_node_id)
            await db.execute(span_from_stmt)
            await db.execute(span_to_stmt)
            print(f"DEBUG: Удалены Span, связанные с ConnectivityNode {connectivity_node_id}")
            
            # Удаляем AClineSegment, которые начинаются с этого ConnectivityNode
            # (from_connectivity_node_id нельзя обнулить, так как nullable=False)
            acline_from_stmt = delete(AClineSegment).where(AClineSegment.from_connectivity_node_id == connectivity_node_id)
            await db.execute(acline_from_stmt)
            print(f"DEBUG: Удалены AClineSegment, начинающиеся с ConnectivityNode {connectivity_node_id}")
            
            # Обнуляем to_connectivity_node_id в AClineSegment (если он ссылается на этот узел)
            # Это безопасно, так как to_connectivity_node_id nullable=True
            acline_to_update = update(AClineSegment).where(AClineSegment.to_connectivity_node_id == connectivity_node_id).values(to_connectivity_node_id=None)
            await db.execute(acline_to_update)
            print(f"DEBUG: Обнулены ссылки to_connectivity_node_id в AClineSegment")
        
        # Также удаляем Span, которые напрямую связаны с опорой (для обратной совместимости)
        span_from_pole_stmt = delete(Span).where(Span.from_pole_id == pole_id)
        span_to_pole_stmt = delete(Span).where(Span.to_pole_id == pole_id)
        await db.execute(span_from_pole_stmt)
        await db.execute(span_to_pole_stmt)
        print(f"DEBUG: Удалены Span, напрямую связанные с опорой {pole_id} (для обратной совместимости)")
        
        # ВАЖНО: Сначала обнуляем connectivity_node_id в опоре (если есть старое поле)
        # Это нужно сделать ПЕРЕД удалением ConnectivityNode, чтобы избежать foreign key violation
        if pole.connectivity_node_id:
            update_stmt = update(Pole).where(Pole.id == pole_id).values(connectivity_node_id=None)
            await db.execute(update_stmt)
            print(f"DEBUG: Обнулен connectivity_node_id для опоры {pole_id}")
        
        # Также обнуляем connectivity_node_id во всех опорах, которые могут ссылаться на удаляемые ConnectivityNode
        for cn in connectivity_nodes:
            connectivity_node_id = cn.id
            # Обнуляем connectivity_node_id во всех опорах, которые ссылаются на этот ConnectivityNode
            pole_update_stmt = update(Pole).where(Pole.connectivity_node_id == connectivity_node_id).values(connectivity_node_id=None)
            await db.execute(pole_update_stmt)
            print(f"DEBUG: Обнулен connectivity_node_id в опорах, ссылающихся на ConnectivityNode {connectivity_node_id}")
        
        # Теперь можно безопасно удалить ConnectivityNode
        if connectivity_nodes:
            connectivity_node_stmt = delete(ConnectivityNode).where(ConnectivityNode.pole_id == pole_id)
            await db.execute(connectivity_node_stmt)
            print(f"DEBUG: Удалены ConnectivityNode для опоры {pole_id}")
        
        # Удаляем опору используя правильный синтаксис SQLAlchemy 2.0 async
        stmt = delete(Pole).where(Pole.id == pole_id)
        await db.execute(stmt)
        await db.commit()
        
        print(f"DEBUG: Опора {pole_id} успешно удалена")
        return {
            "message": "Pole deleted successfully",
            "details": "Опора удалена. Пролёты и сегменты линий, напрямую связанные с этой опорой, также удалены. Остальная структура линии сохранена. При необходимости связи можно восстановить вручную."
        }
        
    except HTTPException:
        # Пробрасываем HTTP исключения как есть
        raise
    except Exception as e:
        # Логируем полную ошибку для отладки
        error_trace = traceback.format_exc()
        print(f"ERROR: Ошибка при удалении опоры {pole_id}: {e}")
        print(f"ERROR: Traceback:\n{error_trace}")
        
        # Откатываем транзакцию
        await db.rollback()
        
        # Возвращаем понятное сообщение об ошибке
        error_message = str(e)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Ошибка при удалении опоры: {error_message}"
        )

