from typing import List, Dict, Any, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_, func, delete
from sqlalchemy.orm import selectinload
from datetime import datetime, timezone, timedelta
import uuid

from app.database import get_db
from app.core.security import get_current_active_user
from app.models.user import User
from app.models.power_line import PowerLine, Pole, Equipment
from app.models.substation import Substation, VoltageLevel, Bay, ConductingEquipment, ProtectionEquipment
from app.schemas.sync import SyncBatch, SyncResponse, SyncRecord, SyncStatus, SyncAction, ENTITY_SCHEMAS
from app.schemas.power_line import PowerLineCreate, PoleCreate, EquipmentCreate
from app.models.base import generate_mrid
import jsonschema

router = APIRouter()

@router.post("/upload", response_model=SyncResponse)
async def upload_sync_batch(
    batch: SyncBatch,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Загрузка пакета данных для синхронизации"""
    
    processed_count = 0
    failed_count = 0
    errors = []
    
    for record in batch.records:
        try:
            # Валидация схемы данных
            if record.entity_type in ENTITY_SCHEMAS:
                schema = ENTITY_SCHEMAS[record.entity_type]
                jsonschema.validate(record.data, schema)
            
            # Здесь должна быть логика обработки каждой записи
            # В зависимости от action (create/update/delete) и entity_type
            await process_sync_record(record, current_user, db)
            
            processed_count += 1
            record.status = SyncStatus.SYNCED
            
        except Exception as e:
            failed_count += 1
            record.status = SyncStatus.FAILED
            record.error_message = str(e)
            errors.append({
                "record_id": record.id,
                "error": str(e)
            })
    
    return SyncResponse(
        success=failed_count == 0,
        processed_count=processed_count,
        failed_count=failed_count,
        errors=errors,
        batch_id=batch.batch_id,
        timestamp=datetime.utcnow()
    )

@router.get("/download")
async def download_sync_data(
    last_sync: Optional[str] = Query(None, description="ISO 8601 timestamp последней синхронизации"),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Скачивание изменений с сервера с момента last_sync"""
    
    # Парсим last_sync или используем время 24 часа назад
    if last_sync:
        try:
            last_sync_dt = datetime.fromisoformat(last_sync.replace('Z', '+00:00'))
        except:
            last_sync_dt = datetime.now(timezone.utc) - timedelta(hours=24)
    else:
        last_sync_dt = datetime.now(timezone.utc) - timedelta(hours=24)
    
    records = []
    
    # Получаем измененные ЛЭП
    power_lines_result = await db.execute(
        select(PowerLine)
        .where(
            or_(
                PowerLine.created_at >= last_sync_dt,
                PowerLine.updated_at >= last_sync_dt
            )
        )
    )
    power_lines = power_lines_result.scalars().all()
    for pl in power_lines:
        records.append({
            "id": str(uuid.uuid4()),
            "entity_type": "power_line",
            "action": "create" if pl.created_at >= last_sync_dt else "update",
            "data": {
                "id": pl.id,
                "mrid": pl.mrid,
                "name": pl.name,
                "code": pl.code,
                "voltage_level": pl.voltage_level,
                "length": pl.length,
                "region_id": pl.region_id,
                "branch_id": pl.branch_id,
                "status": pl.status,
                "description": pl.description,
                "created_by": pl.created_by,
                "created_at": pl.created_at.isoformat() if pl.created_at else None,
                "updated_at": pl.updated_at.isoformat() if pl.updated_at else None,
            },
            "timestamp": (pl.updated_at or pl.created_at).isoformat() if (pl.updated_at or pl.created_at) else datetime.now(timezone.utc).isoformat(),
        })
    
    # Получаем измененные опоры
    poles_result = await db.execute(
        select(Pole)
        .where(
            or_(
                Pole.created_at >= last_sync_dt,
                Pole.updated_at >= last_sync_dt
            )
        )
    )
    poles = poles_result.scalars().all()
    for pole in poles:
        records.append({
            "id": str(uuid.uuid4()),
            "entity_type": "pole",
            "action": "create" if pole.created_at >= last_sync_dt else "update",
            "data": {
                "id": pole.id,
                "mrid": pole.mrid,
                "power_line_id": pole.line_id,
                "pole_number": pole.pole_number,
                "latitude": pole.latitude,
                "longitude": pole.longitude,
                "pole_type": pole.pole_type,
                "height": pole.height,
                "foundation_type": pole.foundation_type,
                "material": pole.material,
                "year_installed": pole.year_installed,
                "condition": pole.condition,
                "notes": pole.notes,
                "created_by": pole.created_by,
                "created_at": pole.created_at.isoformat() if pole.created_at else None,
                "updated_at": pole.updated_at.isoformat() if pole.updated_at else None,
            },
            "timestamp": (pole.updated_at or pole.created_at).isoformat() if (pole.updated_at or pole.created_at) else datetime.now(timezone.utc).isoformat(),
        })
    
    # Получаем измененное оборудование
    equipment_result = await db.execute(
        select(Equipment)
        .where(
            or_(
                Equipment.created_at >= last_sync_dt,
                Equipment.updated_at >= last_sync_dt
            )
        )
    )
    equipment_list = equipment_result.scalars().all()
    for eq in equipment_list:
        records.append({
            "id": str(uuid.uuid4()),
            "entity_type": "equipment",
            "action": "create" if eq.created_at >= last_sync_dt else "update",
            "data": {
                "id": eq.id,
                "mrid": eq.mrid,
                "pole_id": eq.pole_id,
                "equipment_type": eq.equipment_type,
                "name": eq.name,
                "manufacturer": eq.manufacturer,
                "model": eq.model,
                "serial_number": eq.serial_number,
                "year_manufactured": eq.year_manufactured,
                "installation_date": eq.installation_date.isoformat() if eq.installation_date else None,
                "condition": eq.condition,
                "notes": eq.notes,
                "created_by": eq.created_by,
                "created_at": eq.created_at.isoformat() if eq.created_at else None,
                "updated_at": eq.updated_at.isoformat() if eq.updated_at else None,
            },
            "timestamp": (eq.updated_at or eq.created_at).isoformat() if (eq.updated_at or eq.created_at) else datetime.now(timezone.utc).isoformat(),
        })
    
    return {
        "records": records,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "count": len(records)
    }

async def process_sync_record(record: SyncRecord, user: User, db: AsyncSession):
    """Обработка одной записи синхронизации"""
    
    data = record.data
    
    if record.entity_type == "power_line":
        if record.action == SyncAction.CREATE:
            # Проверяем, существует ли уже ЛЭП с таким ID или mRID
            existing = await db.execute(
                select(PowerLine).where(
                    or_(
                        PowerLine.id == data.get('id'),
                        PowerLine.mrid == data.get('mrid')
                    )
                )
            )
            existing_pl = existing.scalar_one_or_none()
            
            if existing_pl:
                # Если существует - обновляем
                for key, value in data.items():
                    if hasattr(existing_pl, key) and key not in ['id', 'mrid', 'created_at']:
                        setattr(existing_pl, key, value)
            else:
                # Создаем новую
                mrid = data.get('mrid') or generate_mrid()
                db_pl = PowerLine(
                    mrid=mrid,
                    name=data['name'],
                    code=data.get('code') or f"LEP-{mrid[:8].upper()}",
                    voltage_level=data.get('voltage_level'),
                    length=data.get('length'),
                    region_id=data.get('region_id'),
                    branch_id=data.get('branch_id'),
                    status=data.get('status', 'active'),
                    description=data.get('description'),
                    created_by=user.id
                )
                db.add(db_pl)
        
        elif record.action == SyncAction.UPDATE:
            # Обновление ЛЭП
            result = await db.execute(
                select(PowerLine).where(
                    or_(
                        PowerLine.id == data.get('id'),
                        PowerLine.mrid == data.get('mrid')
                    )
                )
            )
            pl = result.scalar_one_or_none()
            if pl:
                for key, value in data.items():
                    if hasattr(pl, key) and key not in ['id', 'mrid', 'created_at', 'created_by']:
                        setattr(pl, key, value)
            else:
                raise ValueError(f"PowerLine with id/mrid {data.get('id') or data.get('mrid')} not found")
        
        elif record.action == SyncAction.DELETE:
            # Удаление ЛЭП
            result = await db.execute(
                select(PowerLine).where(
                    or_(
                        PowerLine.id == data.get('id'),
                        PowerLine.mrid == data.get('mrid')
                    )
                )
            )
            pl = result.scalar_one_or_none()
            if pl:
                await db.execute(delete(PowerLine).where(PowerLine.id == pl.id))
            else:
                raise ValueError(f"PowerLine with id/mrid {data.get('id') or data.get('mrid')} not found")
    
    elif record.entity_type == "pole":
        if record.action == SyncAction.CREATE:
            # Проверяем существование
            existing = await db.execute(
                select(Pole).where(
                    or_(
                        Pole.id == data.get('id'),
                        Pole.mrid == data.get('mrid')
                    )
                )
            )
            existing_pole = existing.scalar_one_or_none()
            
            if existing_pole:
                # Обновляем
                for key, value in data.items():
                    if hasattr(existing_pole, key) and key not in ['id', 'mrid', 'created_at']:
                        setattr(existing_pole, key, value)
            else:
                # Создаем новую
                mrid = data.get('mrid') or generate_mrid()
                db_pole = Pole(
                    mrid=mrid,
                    line_id=data['power_line_id'],
                    pole_number=data['pole_number'],
                    latitude=data['latitude'],
                    longitude=data['longitude'],
                    pole_type=data['pole_type'],
                    height=data.get('height'),
                    foundation_type=data.get('foundation_type'),
                    material=data.get('material'),
                    year_installed=data.get('year_installed'),
                    condition=data.get('condition', 'good'),
                    notes=data.get('notes'),
                    created_by=user.id
                )
                db.add(db_pole)
        
        elif record.action == SyncAction.UPDATE:
            result = await db.execute(
                select(Pole).where(
                    or_(
                        Pole.id == data.get('id'),
                        Pole.mrid == data.get('mrid')
                    )
                )
            )
            pole = result.scalar_one_or_none()
            if pole:
                for key, value in data.items():
                    if hasattr(pole, key) and key not in ['id', 'mrid', 'created_at', 'created_by']:
                        setattr(pole, key, value)
            else:
                raise ValueError(f"Pole with id/mrid {data.get('id') or data.get('mrid')} not found")
        
        elif record.action == SyncAction.DELETE:
            result = await db.execute(
                select(Pole).where(
                    or_(
                        Pole.id == data.get('id'),
                        Pole.mrid == data.get('mrid')
                    )
                )
            )
            pole = result.scalar_one_or_none()
            if pole:
                from sqlalchemy import delete
                await db.execute(delete(Pole).where(Pole.id == pole.id))
            else:
                raise ValueError(f"Pole with id/mrid {data.get('id') or data.get('mrid')} not found")
    
    elif record.entity_type == "equipment":
        if record.action == SyncAction.CREATE:
            existing = await db.execute(
                select(Equipment).where(
                    or_(
                        Equipment.id == data.get('id'),
                        Equipment.mrid == data.get('mrid')
                    )
                )
            )
            existing_eq = existing.scalar_one_or_none()
            
            if existing_eq:
                for key, value in data.items():
                    if hasattr(existing_eq, key) and key not in ['id', 'mrid', 'created_at']:
                        setattr(existing_eq, key, value)
            else:
                mrid = data.get('mrid') or generate_mrid()
                db_eq = Equipment(
                    mrid=mrid,
                    pole_id=data['pole_id'],
                    equipment_type=data['equipment_type'],
                    name=data['name'],
                    manufacturer=data.get('manufacturer'),
                    model=data.get('model'),
                    serial_number=data.get('serial_number'),
                    year_manufactured=data.get('year_manufactured'),
                    installation_date=datetime.fromisoformat(data['installation_date']) if data.get('installation_date') else None,
                    condition=data.get('condition', 'good'),
                    notes=data.get('notes'),
                    created_by=user.id
                )
                db.add(db_eq)
        
        elif record.action == SyncAction.UPDATE:
            result = await db.execute(
                select(Equipment).where(
                    or_(
                        Equipment.id == data.get('id'),
                        Equipment.mrid == data.get('mrid')
                    )
                )
            )
            eq = result.scalar_one_or_none()
            if eq:
                for key, value in data.items():
                    if hasattr(eq, key) and key not in ['id', 'mrid', 'created_at', 'created_by']:
                        if key == 'installation_date' and value:
                            setattr(eq, key, datetime.fromisoformat(value))
                        else:
                            setattr(eq, key, value)
            else:
                raise ValueError(f"Equipment with id/mrid {data.get('id') or data.get('mrid')} not found")
        
        elif record.action == SyncAction.DELETE:
            result = await db.execute(
                select(Equipment).where(
                    or_(
                        Equipment.id == data.get('id'),
                        Equipment.mrid == data.get('mrid')
                    )
                )
            )
            eq = result.scalar_one_or_none()
            if eq:
                await db.execute(delete(Equipment).where(Equipment.id == eq.id))
            else:
                raise ValueError(f"Equipment with id/mrid {data.get('id') or data.get('mrid')} not found")
    
    await db.commit()

@router.get("/schema/{entity_type}")
async def get_entity_schema(entity_type: str):
    """Получение JSON схемы для типа сущности"""
    
    if entity_type not in ENTITY_SCHEMAS:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Schema for entity type '{entity_type}' not found"
        )
    
    return {
        "entity_type": entity_type,
        "schema": ENTITY_SCHEMAS[entity_type]
    }

@router.get("/schemas")
async def get_all_schemas():
    """Получение всех доступных схем"""
    
    return {
        "schemas": ENTITY_SCHEMAS
    }
