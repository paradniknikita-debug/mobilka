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
from app.models.branch import Branch
from app.models.power_line import PowerLine, Pole, Equipment
from app.models.substation import Substation, VoltageLevel, Bay, ConductingEquipment, ProtectionEquipment
from app.schemas.sync import SyncBatch, SyncResponse, SyncRecord, SyncStatus, SyncAction, ENTITY_SCHEMAS
from app.schemas.power_line import PowerLineCreate, PoleCreate, EquipmentCreate
from app.models.base import generate_mrid
import jsonschema
import logging

logger = logging.getLogger(__name__)
router = APIRouter()

def _order_for_sync(records: List[SyncRecord]) -> List[SyncRecord]:
    """Порядок: ЛЭП → опоры → оборудование (опоры ссылаются на ЛЭП, оборудование на опоры)."""
    order = {"power_line": 0, "pole": 1, "equipment": 2}
    return sorted(records, key=lambda r: (order.get(r.entity_type, 99), r.id))


def _ensure_utc(dt: Optional[datetime]) -> Optional[datetime]:
    """Приводит datetime к timezone-aware (UTC) для сравнения с last_sync_dt."""
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


@router.post("/upload", response_model=SyncResponse)
async def upload_sync_batch(
    batch: SyncBatch,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Загрузка пакета данных для синхронизации. ЛЭП создаются первыми, затем опоры с подстановкой server power_line_id."""
    
    processed_count = 0
    failed_count = 0
    errors = []
    # Маппинг локальных (отрицательных) id → серверные id после создания
    id_mapping: Dict[str, Dict[int, int]] = {"power_line": {}, "pole": {}}
    ordered = _order_for_sync(batch.records)
    
    logger.info("sync/upload: записей в пакете=%d, типы=%s", len(ordered), [f"{r.entity_type}:{r.action}" for r in ordered])
    for record in ordered:
        data_preview = f"id={record.data.get('id')}"
        if record.entity_type == "power_line":
            data_preview += f" name={record.data.get('name', '')!r}"
        elif record.entity_type == "pole":
            data_preview += f" power_line_id={record.data.get('power_line_id')} pole_number={record.data.get('pole_number', '')!r} lat={record.data.get('latitude')} lon={record.data.get('longitude')}"
        logger.info("sync/upload: обработка %s %s %s", record.entity_type, record.action, data_preview)
        try:
            data = record.data
            # Подстановка серверных id для опор и оборудования (локальные id отрицательные)
            if record.entity_type == "pole" and record.action == SyncAction.CREATE:
                pl_id = data.get("power_line_id")
                if isinstance(pl_id, int) and pl_id < 0 and pl_id in id_mapping["power_line"]:
                    data = {**data, "power_line_id": id_mapping["power_line"][pl_id]}
            elif record.entity_type == "equipment" and record.action == SyncAction.CREATE:
                pole_id = data.get("pole_id")
                if isinstance(pole_id, int) and pole_id < 0 and pole_id in id_mapping["pole"]:
                    data = {**data, "pole_id": id_mapping["pole"][pole_id]}
            record.data = data
            
            # Валидируем только create/update — для delete в data только id
            if record.entity_type in ENTITY_SCHEMAS and record.action != SyncAction.DELETE:
                schema = ENTITY_SCHEMAS[record.entity_type]
                jsonschema.validate(record.data, schema)
            
            # Savepoint: при ошибке откатываем только эту запись, не трогая сессию
            async with db.begin_nested():
                await process_sync_record(record, current_user, db, id_mapping)
            
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
            logger.warning("sync/upload: ошибка записи %s %s: %s", record.entity_type, record.id, e)
            # Не делаем db.rollback() — savepoint уже откатился, сессия остаётся в консистентном состоянии
    
    logger.info("sync/upload: итог processed=%d failed=%d errors=%s", processed_count, failed_count, errors)
    if failed_count == 0:
        await db.commit()
    else:
        await db.rollback()
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
    try:
        return await _download_sync_data_impl(last_sync, current_user, db)
    except Exception as e:
        logger.exception("sync/download: %s", e)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"sync/download: {type(e).__name__}: {e}",
        ) from e


async def _download_sync_data_impl(
    last_sync: Optional[str],
    current_user: User,
    db: AsyncSession,
):
    # Парсим last_sync или используем время 24 часа назад. Сдвиг на 60 сек назад,
    # чтобы не терять записи из-за разницы часов поясов или задержки коммита.
    if last_sync:
        try:
            s = last_sync.replace('Z', '+00:00').strip()
            parsed = datetime.fromisoformat(s) if ('+' in s or s.endswith('Z')) else datetime.fromisoformat(s + '+00:00')
            if parsed.tzinfo is None:
                parsed = parsed.replace(tzinfo=timezone.utc)
            last_sync_dt = parsed - timedelta(seconds=60)
        except Exception:
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
        pl_created = _ensure_utc(pl.created_at)
        pl_data = {
            "id": pl.id,
            "name": pl.name,
            "voltage_level": pl.voltage_level,
            "length": pl.length,
            "branch_id": getattr(pl, "branch_id", None),
            "status": pl.status,
            "description": pl.description,
            "created_by": pl.created_by,
            "created_at": pl.created_at.isoformat() if pl.created_at else None,
            "updated_at": pl.updated_at.isoformat() if pl.updated_at else None,
        }
        if getattr(pl, "mrid", None) is not None:
            pl_data["mrid"] = pl.mrid
        if getattr(pl, "region_id", None) is not None:
            pl_data["region_id"] = pl.region_id
        records.append({
            "id": str(uuid.uuid4()),
            "entity_type": "power_line",
            "action": "create" if (pl_created and pl_created >= last_sync_dt) else "update",
            "data": pl_data,
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
        pole_created = _ensure_utc(pole.created_at)
        pole_data = {
            "id": pole.id,
            "power_line_id": pole.line_id,
            "pole_number": pole.pole_number,
            "x_position": pole.x_position,
            "y_position": pole.y_position,
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
        }
        if getattr(pole, "mrid", None) is not None:
            pole_data["mrid"] = pole.mrid
        records.append({
            "id": str(uuid.uuid4()),
            "entity_type": "pole",
            "action": "create" if (pole_created and pole_created >= last_sync_dt) else "update",
            "data": pole_data,
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
        eq_created = _ensure_utc(eq.created_at)
        eq_data = {
            "id": eq.id,
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
        }
        if getattr(eq, "mrid", None) is not None:
            eq_data["mrid"] = eq.mrid
        records.append({
            "id": str(uuid.uuid4()),
            "entity_type": "equipment",
            "action": "create" if (eq_created and eq_created >= last_sync_dt) else "update",
            "data": eq_data,
            "timestamp": (eq.updated_at or eq.created_at).isoformat() if (eq.updated_at or eq.created_at) else datetime.now(timezone.utc).isoformat(),
        })
    
    return {
        "records": records,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "count": len(records)
    }

async def process_sync_record(
    record: SyncRecord, user: User, db: AsyncSession,
    id_mapping: Optional[Dict[str, Dict[int, int]]] = None
):
    """Обработка одной записи синхронизации. id_mapping заполняется при создании ЛЭП/опор с локальным (отрицательным) id."""
    id_mapping = id_mapping or {"power_line": {}, "pole": {}}
    data = record.data
    
    if record.entity_type == "power_line":
        if record.action == SyncAction.CREATE:
            client_id = data.get('id')
            conds = []
            if isinstance(client_id, int) and client_id > 0:
                conds.append(PowerLine.id == client_id)
            if data.get('mrid'):
                conds.append(PowerLine.mrid == data.get('mrid'))
            if not conds:
                existing_pl = None
            else:
                existing = await db.execute(select(PowerLine).where(or_(*conds)))
                existing_pl = existing.scalar_one_or_none()
            
            if existing_pl:
                for key, value in data.items():
                    if hasattr(existing_pl, key) and key not in ['id', 'mrid', 'created_at', 'code']:
                        setattr(existing_pl, key, value)
                if isinstance(client_id, int) and client_id < 0:
                    id_mapping["power_line"][client_id] = existing_pl.id
            else:
                mrid = data.get('mrid') or generate_mrid()
                voltage = data.get('voltage_level')
                voltage_level = float(voltage) if voltage is not None else 0.0
                branch_id = data.get('branch_id')
                if branch_id is not None and not isinstance(branch_id, int):
                    try:
                        branch_id = int(branch_id)
                    except (TypeError, ValueError):
                        branch_id = None
                if branch_id is not None:
                    branch_exists = await db.execute(select(Branch).where(Branch.id == branch_id))
                    if branch_exists.scalar_one_or_none() is None:
                        branch_id = None
                db_pl = PowerLine(
                    mrid=mrid,
                    name=data.get('name') or 'ЛЭП',
                    voltage_level=voltage_level,
                    length=float(data['length']) if data.get('length') is not None else None,
                    region_id=data.get('region_id'),
                    branch_id=branch_id,
                    status=data.get('status') or 'active',
                    description=data.get('description'),
                    created_by=user.id
                )
                db.add(db_pl)
                await db.flush()
                if isinstance(client_id, int) and client_id < 0:
                    id_mapping["power_line"][client_id] = db_pl.id
        
        elif record.action == SyncAction.UPDATE:
            # Обновление ЛЭП (если не найдена — уже удалена на сервере, пропускаем)
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
                    if hasattr(pl, key) and key not in ['id', 'mrid', 'created_at', 'created_by', 'code']:
                        setattr(pl, key, value)
            # иначе уже удалена — не ошибка
        
        elif record.action == SyncAction.DELETE:
            # Удаление ЛЭП (если не найдена — уже удалена, считаем успехом)
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
            client_id = data.get('id')
            if existing_pole:
                for key, value in data.items():
                    if hasattr(existing_pole, key) and key not in ['id', 'mrid', 'created_at']:
                        setattr(existing_pole, key, value)
                if isinstance(client_id, int) and client_id < 0:
                    id_mapping["pole"][client_id] = existing_pole.id
            else:
                client_id = data.get('id')
                mrid = data.get('mrid') or generate_mrid()
                lat = data.get('y_position') or data.get('latitude')
                lon = data.get('x_position') or data.get('longitude')
                y_pos = float(lat) if lat is not None else None
                x_pos = float(lon) if lon is not None else None
                db_pole = Pole(
                    mrid=mrid,
                    line_id=int(data['power_line_id']),
                    pole_number=data.get('pole_number') or '0',
                    y_position=y_pos,
                    x_position=x_pos,
                    pole_type=data.get('pole_type') or 'unknown',
                    height=float(data['height']) if data.get('height') is not None else None,
                    foundation_type=data.get('foundation_type'),
                    material=data.get('material'),
                    year_installed=int(data['year_installed']) if data.get('year_installed') is not None else None,
                    condition=data.get('condition') or 'good',
                    notes=data.get('notes'),
                    created_by=user.id
                )
                db.add(db_pole)
                await db.flush()
                if isinstance(client_id, int) and client_id < 0:
                    id_mapping["pole"][client_id] = db_pole.id
        
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
                # Нормализация координат: в БД только x_position, y_position
                upd = dict(data)
                if 'latitude' in upd and 'y_position' not in upd:
                    upd['y_position'] = upd['latitude']
                if 'longitude' in upd and 'x_position' not in upd:
                    upd['x_position'] = upd['longitude']
                for key in ['latitude', 'longitude']:
                    upd.pop(key, None)
                for key, value in upd.items():
                    if hasattr(pole, key) and key not in ['id', 'mrid', 'created_at', 'created_by']:
                        setattr(pole, key, value)
        
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
    
    # Коммит выполняет вызывающий код (upload_sync_batch) — один раз после всех записей

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
