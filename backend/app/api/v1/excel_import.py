"""
API endpoints для массового импорта данных из Excel
"""
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
import pandas as pd
import io

from app.database import get_db
from app.core.security import get_current_active_user
from app.models.user import User
from app.models.power_line import PowerLine, Pole, Span, Tap, Equipment
from app.models.substation import Substation, Connection
from app.models.geographic_region import GeographicRegion
from app.schemas.power_line import PowerLineCreate, PoleCreate, SpanCreate, TapCreate, EquipmentCreate
from app.schemas.substation import SubstationCreate, ConnectionCreate

router = APIRouter(prefix="/import", tags=["import"])


async def get_or_create_region(
    db: AsyncSession, 
    region_code: str = None, 
    region_name: str = None,
    region_id: int = None
) -> int:
    """Получить или создать географический регион"""
    if region_id:
        region = await db.get(GeographicRegion, region_id)
        if region:
            return region_id
    
    if region_code:
        result = await db.execute(
            select(GeographicRegion).where(GeographicRegion.code == region_code)
        )
        region = result.scalar_one_or_none()
        if region:
            return region.id
    
    # Если регион не найден, создаём новый (уровень 2 = РЭС по умолчанию)
    if region_code and region_name:
        new_region = GeographicRegion(
            code=region_code,
            name=region_name,
            region_type="РЭС",
            level=2
        )
        db.add(new_region)
        await db.flush()
        return new_region.id
    
    return None


@router.post("/power-lines", response_model=dict)
async def import_power_lines(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Массовый импорт ЛЭП из Excel файла
    
    Формат Excel:
    - name: Название ЛЭП (обязательно)
    - code: Код ЛЭП (обязательно, уникальный)
    - voltage_level: Уровень напряжения, кВ (обязательно)
    - length: Длина, км (опционально)
    - region_code: Код географического региона (опционально)
    - region_name: Название географического региона (опционально)
    - status: Статус (active/inactive/maintenance, по умолчанию active)
    - description: Описание (опционально)
    """
    if not file.filename.endswith(('.xlsx', '.xls')):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Файл должен быть в формате Excel (.xlsx или .xls)"
        )
    
    try:
        contents = await file.read()
        df = pd.read_excel(io.BytesIO(contents))
        
        # Проверка обязательных колонок
        required_columns = ['name', 'code', 'voltage_level']
        missing_columns = [col for col in required_columns if col not in df.columns]
        if missing_columns:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Отсутствуют обязательные колонки: {', '.join(missing_columns)}"
            )
        
        created = 0
        errors = []
        
        for idx, row in df.iterrows():
            try:
                # Получаем или создаём регион
                region_id = None
                if 'region_code' in df.columns and pd.notna(row.get('region_code')):
                    region_id = await get_or_create_region(
                        db, 
                        region_code=str(row['region_code']),
                        region_name=str(row.get('region_name', ''))
                    )
                
                # Проверяем уникальность кода
                existing = await db.execute(
                    select(PowerLine).where(PowerLine.code == str(row['code']))
                )
                if existing.scalar_one_or_none():
                    errors.append(f"Строка {idx + 2}: ЛЭП с кодом '{row['code']}' уже существует")
                    continue
                
                # Создаём ЛЭП
                power_line = PowerLine(
                    name=str(row['name']),
                    code=str(row['code']),
                    voltage_level=float(row['voltage_level']),
                    length=float(row['length']) if pd.notna(row.get('length')) else None,
                    region_id=region_id,
                    status=str(row.get('status', 'active')),
                    description=str(row['description']) if pd.notna(row.get('description')) else None,
                    created_by=current_user.id
                )
                db.add(power_line)
                created += 1
                
            except Exception as e:
                errors.append(f"Строка {idx + 2}: {str(e)}")
        
        await db.commit()
        
        return {
            "message": f"Импортировано {created} ЛЭП",
            "created": created,
            "errors": errors if errors else None
        }
        
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Ошибка при импорте: {str(e)}"
        )


@router.post("/poles", response_model=dict)
async def import_poles(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Массовый импорт опор из Excel файла
    
    Формат Excel:
    - power_line_code: Код ЛЭП (обязательно)
    - pole_number: Номер опоры (обязательно)
    - latitude: Широта (обязательно)
    - longitude: Долгота (обязательно)
    - pole_type: Тип опоры (обязательно: анкерная, промежуточная, угловая и т.д.)
    - height: Высота, м (опционально)
    - foundation_type: Тип фундамента (опционально)
    - material: Материал (опционально: металл, железобетон, дерево)
    - year_installed: Год установки (опционально)
    - condition: Состояние (good/satisfactory/poor, по умолчанию good)
    - notes: Примечания (опционально)
    """
    if not file.filename.endswith(('.xlsx', '.xls')):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Файл должен быть в формате Excel (.xlsx или .xls)"
        )
    
    try:
        contents = await file.read()
        df = pd.read_excel(io.BytesIO(contents))
        
        required_columns = ['power_line_code', 'pole_number', 'latitude', 'longitude', 'pole_type']
        missing_columns = [col for col in required_columns if col not in df.columns]
        if missing_columns:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Отсутствуют обязательные колонки: {', '.join(missing_columns)}"
            )
        
        created = 0
        errors = []
        
        for idx, row in df.iterrows():
            try:
                # Находим ЛЭП по коду
                power_line_result = await db.execute(
                    select(PowerLine).where(PowerLine.code == str(row['power_line_code']))
                )
                power_line = power_line_result.scalar_one_or_none()
                
                if not power_line:
                    errors.append(f"Строка {idx + 2}: ЛЭП с кодом '{row['power_line_code']}' не найдена")
                    continue
                
                # Создаём опору
                pole = Pole(
                    line_id=power_line.id,
                    pole_number=str(row['pole_number']),
                    latitude=float(row['latitude']),
                    longitude=float(row['longitude']),
                    pole_type=str(row['pole_type']),
                    height=float(row['height']) if pd.notna(row.get('height')) else None,
                    foundation_type=str(row['foundation_type']) if pd.notna(row.get('foundation_type')) else None,
                    material=str(row['material']) if pd.notna(row.get('material')) else None,
                    year_installed=int(row['year_installed']) if pd.notna(row.get('year_installed')) else None,
                    condition=str(row.get('condition', 'good')),
                    notes=str(row['notes']) if pd.notna(row.get('notes')) else None,
                    created_by=current_user.id
                )
                db.add(pole)
                created += 1
                
            except Exception as e:
                errors.append(f"Строка {idx + 2}: {str(e)}")
        
        await db.commit()
        
        return {
            "message": f"Импортировано {created} опор",
            "created": created,
            "errors": errors if errors else None
        }
        
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Ошибка при импорте: {str(e)}"
        )


@router.post("/substations", response_model=dict)
async def import_substations(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Массовый импорт подстанций из Excel файла
    
    Формат Excel:
    - name: Название подстанции (обязательно)
    - code: Код подстанции (обязательно, уникальный)
    - voltage_level: Уровень напряжения, кВ (обязательно)
    - latitude: Широта (обязательно)
    - longitude: Долгота (обязательно)
    - address: Адрес (опционально)
    - region_code: Код географического региона (опционально)
    - region_name: Название географического региона (опционально)
    - description: Описание (опционально)
    """
    if not file.filename.endswith(('.xlsx', '.xls')):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Файл должен быть в формате Excel (.xlsx или .xls)"
        )
    
    try:
        contents = await file.read()
        df = pd.read_excel(io.BytesIO(contents))
        
        required_columns = ['name', 'code', 'voltage_level', 'latitude', 'longitude']
        missing_columns = [col for col in required_columns if col not in df.columns]
        if missing_columns:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Отсутствуют обязательные колонки: {', '.join(missing_columns)}"
            )
        
        created = 0
        errors = []
        
        for idx, row in df.iterrows():
            try:
                # Проверяем уникальность кода
                existing = await db.execute(
                    select(Substation).where(Substation.dispatcher_name == str(row['dispatcher_name']))
                )
                if existing.scalar_one_or_none():
                    errors.append(f"Строка {idx + 2}: Подстанция с кодом '{row['code']}' уже существует")
                    continue
                
                # Получаем или создаём регион
                region_id = None
                if 'region_code' in df.columns and pd.notna(row.get('region_code')):
                    region_id = await get_or_create_region(
                        db, 
                        region_code=str(row['region_code']),
                        region_name=str(row.get('region_name', ''))
                    )
                
                # Создаём подстанцию (модель использует dispatcher_name, не code)
                substation = Substation(
                    name=str(row['name']),
                    dispatcher_name=str(row.get('dispatcher_name') or row.get('code', '')),
                    voltage_level=float(row['voltage_level']),
                    latitude=float(row['latitude']),
                    longitude=float(row['longitude']),
                    address=str(row['address']) if pd.notna(row.get('address')) else None,
                    region_id=region_id,
                    description=str(row['description']) if pd.notna(row.get('description')) else None,
                    is_active=True
                )
                db.add(substation)
                created += 1
                
            except Exception as e:
                errors.append(f"Строка {idx + 2}: {str(e)}")
        
        await db.commit()
        
        return {
            "message": f"Импортировано {created} подстанций",
            "created": created,
            "errors": errors if errors else None
        }
        
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Ошибка при импорте: {str(e)}"
        )


@router.post("/equipment", response_model=dict)
async def import_equipment(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Массовый импорт оборудования из Excel файла
    
    Формат Excel:
    - power_line_code: Код ЛЭП (обязательно)
    - pole_number: Номер опоры (обязательно)
    - equipment_type: Тип оборудования (обязательно: изолятор, разрядник, грозозащитный трос и т.д.)
    - name: Название (обязательно)
    - manufacturer: Производитель (опционально)
    - model: Модель (опционально)
    - serial_number: Серийный номер (опционально)
    - year_manufactured: Год изготовления (опционально)
    - condition: Состояние (good/satisfactory/poor, по умолчанию good)
    - notes: Примечания (опционально)
    """
    if not file.filename.endswith(('.xlsx', '.xls')):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Файл должен быть в формате Excel (.xlsx или .xls)"
        )
    
    try:
        contents = await file.read()
        df = pd.read_excel(io.BytesIO(contents))
        
        required_columns = ['power_line_code', 'pole_number', 'equipment_type', 'name']
        missing_columns = [col for col in required_columns if col not in df.columns]
        if missing_columns:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Отсутствуют обязательные колонки: {', '.join(missing_columns)}"
            )
        
        created = 0
        errors = []
        
        for idx, row in df.iterrows():
            try:
                # Находим ЛЭП и опору
                power_line_result = await db.execute(
                    select(PowerLine).where(PowerLine.code == str(row['power_line_code']))
                )
                power_line = power_line_result.scalar_one_or_none()
                
                if not power_line:
                    errors.append(f"Строка {idx + 2}: ЛЭП с кодом '{row['power_line_code']}' не найдена")
                    continue
                
                pole_result = await db.execute(
                    select(Pole).where(
                        Pole.line_id == power_line.id,
                        Pole.pole_number == str(row['pole_number'])
                    )
                )
                pole = pole_result.scalar_one_or_none()
                
                if not pole:
                    errors.append(f"Строка {idx + 2}: Опора '{row['pole_number']}' не найдена в ЛЭП '{row['power_line_code']}'")
                    continue
                
                # Создаём оборудование
                equipment = Equipment(
                    pole_id=pole.id,
                    equipment_type=str(row['equipment_type']),
                    name=str(row['name']),
                    manufacturer=str(row['manufacturer']) if pd.notna(row.get('manufacturer')) else None,
                    model=str(row['model']) if pd.notna(row.get('model')) else None,
                    serial_number=str(row['serial_number']) if pd.notna(row.get('serial_number')) else None,
                    year_manufactured=int(row['year_manufactured']) if pd.notna(row.get('year_manufactured')) else None,
                    condition=str(row.get('condition', 'good')),
                    notes=str(row['notes']) if pd.notna(row.get('notes')) else None,
                    created_by=current_user.id
                )
                db.add(equipment)
                created += 1
                
            except Exception as e:
                errors.append(f"Строка {idx + 2}: {str(e)}")
        
        await db.commit()
        
        return {
            "message": f"Импортировано {created} единиц оборудования",
            "created": created,
            "errors": errors if errors else None
        }
        
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Ошибка при импорте: {str(e)}"
        )

