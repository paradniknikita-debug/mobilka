from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.core.security import get_current_active_user
from app.models.user import User
from app.models.substation import (
    Substation,
    VoltageLevel,
    Bay,
    BusbarSection,
    ConductingEquipment,
    ProtectionEquipment
)
from app.models.location import Location, PositionPoint, LocationType
from app.schemas.substation import (
    SubstationCreate,
    SubstationResponse,
    SubstationResponseWithStructure,
    VoltageLevelCreate,
    VoltageLevelResponse,
    BayCreate,
    BayResponse,
    BusbarSectionCreate,
    BusbarSectionResponse,
    ConductingEquipmentCreate,
    ConductingEquipmentResponse,
    ProtectionEquipmentCreate,
    ProtectionEquipmentResponse
)
from app.models.base import generate_mrid
from app.models.branch import Branch

router = APIRouter()

# ===== ENDPOINTS ДЛЯ ПОДСТАНЦИЙ =====

@router.post("", response_model=SubstationResponse)
async def create_substation(
    substation_data: SubstationCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Создание новой подстанции"""
    
    # Проверяем уникальность диспетчерского наименования, если указано
    if substation_data.dispatcher_name and substation_data.dispatcher_name.strip():
        existing_dispatcher_name = await db.execute(
            select(Substation).where(Substation.dispatcher_name == substation_data.dispatcher_name.strip())
        )
        if existing_dispatcher_name.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Substation dispatcher name already exists"
            )

    # Создаем Location и PositionPoint если указаны координаты
    location_id = None
    if substation_data.latitude is not None and substation_data.longitude is not None:
        # Создаем Location
        db_location = Location(
            mrid=generate_mrid(),
            location_type=LocationType.POINT,
            address=substation_data.address,
            description=f"Location for substation {substation_data.name}"
        )
        db.add(db_location)
        await db.flush()  # Получаем ID location
        
        # Создаем PositionPoint
        db_position_point = PositionPoint(
            mrid=generate_mrid(),
            location_id=db_location.id,
            x_position=substation_data.longitude,
            y_position=substation_data.latitude,
            z_position=None
        )
        db.add(db_position_point)
        location_id = db_location.id
    
    # Создаем новую подстанцию (координаты только в Location/PositionPoint)
    substation_dict = substation_data.model_dump() if hasattr(substation_data, 'model_dump') else substation_data.dict()
    substation_dict['location_id'] = location_id
    substation_dict.pop('latitude', None)
    substation_dict.pop('longitude', None)
    # UID (mrid): передаём только если указан клиентом, иначе сработает default=generate_mrid
    if not substation_dict.get('mrid'):
        substation_dict.pop('mrid', None)
    # dispatcher_name может быть None
    if substation_dict.get('dispatcher_name') is not None and not str(substation_dict['dispatcher_name']).strip():
        substation_dict['dispatcher_name'] = None

    # branch_id: если таблица branches пуста или id нет — не задаём FK
    branch_id = substation_dict.get('branch_id')
    if branch_id is not None:
        branch_exists = await db.execute(select(Branch).where(Branch.id == branch_id))
        if not branch_exists.scalar_one_or_none():
            substation_dict['branch_id'] = None

    db_substation = Substation(**substation_dict)
    db.add(db_substation)
    await db.flush()  # получаем id до commit
    new_id = db_substation.id
    new_mrid = db_substation.mrid
    await db.commit()

    # Лёгкий запрос только нужных полей (без связей), чтобы не вызывать lazy load в async
    row = await db.execute(
        select(
            Substation.id,
            Substation.mrid,
            Substation.name,
            Substation.dispatcher_name,
            Substation.voltage_level,
            Substation.address,
            Substation.branch_id,
            Substation.description,
            Substation.connected_line_ids,
            Substation.is_active,
            Substation.created_at,
            Substation.updated_at,
        ).where(Substation.id == new_id)
    )
    one = row.one_or_none()
    if not one:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Substation not created")

    response_data = {
        "id": one.id,
        "mrid": one.mrid,
        "name": one.name,
        "dispatcher_name": one.dispatcher_name,
        "voltage_level": float(one.voltage_level),
        "latitude": substation_data.latitude if substation_data.latitude is not None else 0.0,
        "longitude": substation_data.longitude if substation_data.longitude is not None else 0.0,
        "address": one.address,
        "branch_id": one.branch_id,
        "description": one.description,
        "connected_line_ids": one.connected_line_ids,
        "is_active": one.is_active,
        "created_at": one.created_at,
        "updated_at": one.updated_at,
    }
    return SubstationResponse.model_validate(response_data)

@router.get("/", response_model=List[SubstationResponse])
async def get_substations(
    skip: int = 0,
    limit: int = 100,
    is_active: Optional[bool] = None,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение списка подстанций с фильтрацией"""
    
    query = select(Substation).options(
        selectinload(Substation.location).selectinload(Location.position_points)
    )
    
    # По умолчанию показываем только активные подстанции
    if is_active is not None:
        query = query.where(Substation.is_active == is_active)
    else:
        query = query.where(Substation.is_active == True)
    
    # Добавляем пагинацию
    query = query.offset(skip).limit(limit)
    
    result = await db.execute(query)
    substations = result.scalars().all()
    
    return substations

@router.get("/{substation_id}", response_model=SubstationResponse)
async def get_substation(
    substation_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение подстанции по ID"""
    
    result = await db.execute(
        select(Substation)
        .options(selectinload(Substation.location).selectinload(Location.position_points))
        .where(Substation.id == substation_id)
    )
    substation = result.scalar_one_or_none()
    
    if not substation:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Substation not found"
        )
    
    return substation

@router.put("/{substation_id}", response_model=SubstationResponse)
async def update_substation(
    substation_id: int,
    substation_data: SubstationCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Обновление подстанции"""
    result = await db.execute(
        select(Substation)
        .options(
            selectinload(Substation.location).selectinload(Location.position_points),
            selectinload(Substation.position_points),
        )
        .where(Substation.id == substation_id)
    )
    substation = result.scalar_one_or_none()

    if not substation:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Substation not found"
        )

    data = substation_data.model_dump() if hasattr(substation_data, "model_dump") else substation_data.dict()
    lat = data.get("latitude")
    lon = data.get("longitude")

    # Проверка уникальности диспетчерского наименования при изменении
    if substation.dispatcher_name != data.get("dispatcher_name"):
        if data.get("dispatcher_name") and str(data["dispatcher_name"]).strip():
            existing = await db.execute(
                select(Substation).where(Substation.dispatcher_name == data["dispatcher_name"].strip())
            )
            if existing.scalar_one_or_none():
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Substation dispatcher name already exists"
                )

    # Обновляем только поля, которые есть в модели (без latitude/longitude — они в Location/PositionPoint)
    for key in ("name", "dispatcher_name", "voltage_level", "address", "branch_id", "description", "mrid", "connected_line_ids"):
        if key in data and hasattr(substation, key):
            val = data[key]
            if key == "dispatcher_name" and val is not None and not str(val).strip():
                val = None
            setattr(substation, key, val)

    # Координаты: обновляем или создаём Location и PositionPoint
    if lat is not None and lon is not None:
        try:
            lat_f = float(lat)
            lon_f = float(lon)
        except (TypeError, ValueError):
            lat_f, lon_f = None, None
        if lat_f is not None and lon_f is not None:
            if substation.location_id:
                loc = await db.get(Location, substation.location_id)
                if loc:
                    pts = (await db.execute(
                        select(PositionPoint).where(PositionPoint.location_id == loc.id)
                    )).scalars().all()
                    if pts:
                        pts[0].x_position = lon_f
                        pts[0].y_position = lat_f
                    else:
                        pp = PositionPoint(
                            mrid=generate_mrid(),
                            location_id=loc.id,
                            x_position=lon_f,
                            y_position=lat_f,
                        )
                        db.add(pp)
                await db.flush()
            else:
                loc = Location(
                    mrid=generate_mrid(),
                    location_type=LocationType.POINT,
                    address=data.get("address"),
                    description=f"Location for substation {substation.name}",
                )
                db.add(loc)
                await db.flush()
                substation.location_id = loc.id
                pp = PositionPoint(
                    mrid=generate_mrid(),
                    location_id=loc.id,
                    x_position=lon_f,
                    y_position=lat_f,
                )
                db.add(pp)
                await db.flush()
    loc_id = getattr(substation, "location_id", None)
    await db.commit()

    # Ответ без lazy load: координаты из PositionPoint
    location_id = loc_id
    res_lat, res_lon = 0.0, 0.0
    if location_id:
        pp_result = await db.execute(
            select(PositionPoint).where(PositionPoint.location_id == location_id).limit(1)
        )
        pp_row = pp_result.scalar_one_or_none()
        if pp_row:
            res_lat = float(pp_row.y_position)
            res_lon = float(pp_row.x_position)
    if res_lat == 0.0 and res_lon == 0.0:
        direct_pp = await db.execute(select(PositionPoint).where(PositionPoint.substation_id == substation_id).limit(1))
        direct = direct_pp.scalar_one_or_none()
        if direct:
            res_lat = float(direct.y_position)
            res_lon = float(direct.x_position)

    row = await db.execute(
        select(
            Substation.id,
            Substation.mrid,
            Substation.name,
            Substation.dispatcher_name,
            Substation.voltage_level,
            Substation.address,
            Substation.branch_id,
            Substation.description,
            Substation.connected_line_ids,
            Substation.is_active,
            Substation.created_at,
            Substation.updated_at,
        ).where(Substation.id == substation_id)
    )
    one = row.one_or_none()
    if not one:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Substation not found after update")

    return SubstationResponse(
        id=one.id,
        mrid=one.mrid,
        name=one.name,
        dispatcher_name=one.dispatcher_name,
        voltage_level=float(one.voltage_level),
        latitude=res_lat,
        longitude=res_lon,
        address=one.address,
        branch_id=one.branch_id,
        description=one.description,
        connected_line_ids=one.connected_line_ids,
        is_active=one.is_active,
        created_at=one.created_at,
        updated_at=one.updated_at,
    )

@router.delete("/{substation_id}")
async def delete_substation(
    substation_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Удаление подстанции (мягкое удаление - деактивация)"""
    
    result = await db.execute(
        select(Substation).where(Substation.id == substation_id)
    )
    substation = result.scalar_one_or_none()
    
    if not substation:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Substation not found"
        )
    
    # Мягкое удаление - деактивируем
    substation.is_active = False
    await db.commit()
    
    return {"message": "Substation deactivated successfully"}

# ===== ENDPOINTS ДЛЯ УРОВНЕЙ НАПРЯЖЕНИЯ =====

@router.get("/{substation_id}/voltage-levels", response_model=List[VoltageLevelResponse])
async def get_voltage_levels(
    substation_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение списка уровней напряжения подстанции"""
    
    # Проверяем существование подстанции
    substation = await db.get(Substation, substation_id)
    if not substation:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Substation not found"
        )
    
    result = await db.execute(
        select(VoltageLevel)
        .where(VoltageLevel.substation_id == substation_id)
        .options(selectinload(VoltageLevel.bays))
    )
    voltage_levels = result.scalars().all()
    
    return voltage_levels

@router.post("/{substation_id}/voltage-levels", response_model=VoltageLevelResponse)
async def create_voltage_level(
    substation_id: int,
    voltage_level_data: VoltageLevelCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Создание уровня напряжения для подстанции"""
    
    # Проверяем существование подстанции
    substation = await db.get(Substation, substation_id)
    if not substation:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Substation not found"
        )
    
    # Генерируем mRID если не указан
    mrid = voltage_level_data.mrid if voltage_level_data.mrid else generate_mrid()
    
    # Проверяем уникальность mRID
    existing_mrid = await db.execute(
        select(VoltageLevel).where(VoltageLevel.mrid == mrid)
    )
    if existing_mrid.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="VoltageLevel with this mRID already exists"
        )
    
    # Создаем уровень напряжения
    db_voltage_level = VoltageLevel(
        **voltage_level_data.dict(exclude={'mrid'}),
        substation_id=substation_id,
        mrid=mrid
    )
    db.add(db_voltage_level)
    await db.commit()
    await db.refresh(db_voltage_level)
    
    return db_voltage_level

@router.get("/voltage-levels/{voltage_level_id}", response_model=VoltageLevelResponse)
async def get_voltage_level(
    voltage_level_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение уровня напряжения по ID"""
    
    result = await db.execute(
        select(VoltageLevel)
        .options(selectinload(VoltageLevel.bays))
        .where(VoltageLevel.id == voltage_level_id)
    )
    voltage_level = result.scalar_one_or_none()
    
    if not voltage_level:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="VoltageLevel not found"
        )
    
    return voltage_level

@router.put("/voltage-levels/{voltage_level_id}", response_model=VoltageLevelResponse)
async def update_voltage_level(
    voltage_level_id: int,
    voltage_level_data: VoltageLevelCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Обновление уровня напряжения"""
    
    result = await db.execute(
        select(VoltageLevel).where(VoltageLevel.id == voltage_level_id)
    )
    voltage_level = result.scalar_one_or_none()
    
    if not voltage_level:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="VoltageLevel not found"
        )
    
    # Обновляем данные (исключаем mRID из обновления)
    update_data = voltage_level_data.dict(exclude={'mrid'})
    for field, value in update_data.items():
        setattr(voltage_level, field, value)
    
    await db.commit()
    await db.refresh(voltage_level)
    
    return voltage_level

@router.delete("/voltage-levels/{voltage_level_id}")
async def delete_voltage_level(
    voltage_level_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Удаление уровня напряжения"""
    
    result = await db.execute(
        select(VoltageLevel).where(VoltageLevel.id == voltage_level_id)
    )
    voltage_level = result.scalar_one_or_none()
    
    if not voltage_level:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="VoltageLevel not found"
        )
    
    await db.execute(delete(VoltageLevel).where(VoltageLevel.id == voltage_level_id))
    await db.commit()
    
    return {"message": "VoltageLevel deleted successfully"}

# ===== ENDPOINTS ДЛЯ ЯЧЕЕК (BAY) =====

@router.get("/voltage-levels/{voltage_level_id}/bays", response_model=List[BayResponse])
async def get_bays(
    voltage_level_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение списка ячеек уровня напряжения"""
    
    # Проверяем существование уровня напряжения
    voltage_level = await db.get(VoltageLevel, voltage_level_id)
    if not voltage_level:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="VoltageLevel not found"
        )
    
    result = await db.execute(
        select(Bay)
        .where(Bay.voltage_level_id == voltage_level_id)
        .options(
            selectinload(Bay.busbar_sections),
            selectinload(Bay.conducting_equipment),
            selectinload(Bay.protection_equipment)
        )
    )
    bays = result.scalars().all()
    
    return bays

@router.post("/voltage-levels/{voltage_level_id}/bays", response_model=BayResponse)
async def create_bay(
    voltage_level_id: int,
    bay_data: BayCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Создание ячейки для уровня напряжения"""
    
    # Проверяем существование уровня напряжения
    voltage_level = await db.get(VoltageLevel, voltage_level_id)
    if not voltage_level:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="VoltageLevel not found"
        )
    
    # Генерируем mRID если не указан
    mrid = bay_data.mrid if bay_data.mrid else generate_mrid()
    
    # Проверяем уникальность mRID
    existing_mrid = await db.execute(
        select(Bay).where(Bay.mrid == mrid)
    )
    if existing_mrid.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Bay with this mRID already exists"
        )
    
    # Создаем ячейку
    db_bay = Bay(
        **bay_data.dict(exclude={'mrid'}),
        voltage_level_id=voltage_level_id,
        mrid=mrid
    )
    db.add(db_bay)
    await db.commit()
    await db.refresh(db_bay)
    
    return db_bay

@router.get("/bays/{bay_id}", response_model=BayResponse)
async def get_bay(
    bay_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение ячейки по ID"""
    
    result = await db.execute(
        select(Bay)
        .options(
            selectinload(Bay.busbar_sections),
            selectinload(Bay.conducting_equipment),
            selectinload(Bay.protection_equipment)
        )
        .where(Bay.id == bay_id)
    )
    bay = result.scalar_one_or_none()
    
    if not bay:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bay not found"
        )
    
    return bay

@router.put("/bays/{bay_id}", response_model=BayResponse)
async def update_bay(
    bay_id: int,
    bay_data: BayCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Обновление ячейки"""
    
    result = await db.execute(
        select(Bay).where(Bay.id == bay_id)
    )
    bay = result.scalar_one_or_none()
    
    if not bay:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bay not found"
        )
    
    # Обновляем данные (исключаем mRID)
    update_data = bay_data.dict(exclude={'mrid'})
    for field, value in update_data.items():
        setattr(bay, field, value)
    
    await db.commit()
    await db.refresh(bay)
    
    return bay

@router.delete("/bays/{bay_id}")
async def delete_bay(
    bay_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Удаление ячейки"""
    
    result = await db.execute(
        select(Bay).where(Bay.id == bay_id)
    )
    bay = result.scalar_one_or_none()
    
    if not bay:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bay not found"
        )
    
    await db.execute(delete(Bay).where(Bay.id == bay_id))
    await db.commit()
    
    return {"message": "Bay deleted successfully"}

# ===== ENDPOINTS ДЛЯ СЕКЦИЙ ШИН =====

@router.get("/bays/{bay_id}/busbar-sections", response_model=List[BusbarSectionResponse])
async def get_busbar_sections(
    bay_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение списка секций шин ячейки"""
    
    # Проверяем существование ячейки
    bay = await db.get(Bay, bay_id)
    if not bay:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bay not found"
        )
    
    result = await db.execute(
        select(BusbarSection).where(BusbarSection.bay_id == bay_id)
    )
    busbar_sections = result.scalars().all()
    
    return busbar_sections

@router.post("/bays/{bay_id}/busbar-sections", response_model=BusbarSectionResponse)
async def create_busbar_section(
    bay_id: int,
    busbar_section_data: BusbarSectionCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Создание секции шин для ячейки"""
    
    # Проверяем существование ячейки
    bay = await db.get(Bay, bay_id)
    if not bay:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bay not found"
        )
    
    # Генерируем mRID если не указан
    mrid = busbar_section_data.mrid if busbar_section_data.mrid else generate_mrid()
    
    # Проверяем уникальность mRID
    existing_mrid = await db.execute(
        select(BusbarSection).where(BusbarSection.mrid == mrid)
    )
    if existing_mrid.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="BusbarSection with this mRID already exists"
        )
    
    # Создаем секцию шин
    db_busbar_section = BusbarSection(
        **busbar_section_data.dict(exclude={'mrid'}),
        bay_id=bay_id,
        mrid=mrid
    )
    db.add(db_busbar_section)
    await db.commit()
    await db.refresh(db_busbar_section)
    
    return db_busbar_section

@router.put("/busbar-sections/{busbar_section_id}", response_model=BusbarSectionResponse)
async def update_busbar_section(
    busbar_section_id: int,
    busbar_section_data: BusbarSectionCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Обновление секции шин"""
    
    result = await db.execute(
        select(BusbarSection).where(BusbarSection.id == busbar_section_id)
    )
    busbar_section = result.scalar_one_or_none()
    
    if not busbar_section:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="BusbarSection not found"
        )
    
    # Обновляем данные (исключаем mRID)
    update_data = busbar_section_data.dict(exclude={'mrid'})
    for field, value in update_data.items():
        setattr(busbar_section, field, value)
    
    await db.commit()
    await db.refresh(busbar_section)
    
    return busbar_section

@router.delete("/busbar-sections/{busbar_section_id}")
async def delete_busbar_section(
    busbar_section_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Удаление секции шин"""
    
    result = await db.execute(
        select(BusbarSection).where(BusbarSection.id == busbar_section_id)
    )
    busbar_section = result.scalar_one_or_none()
    
    if not busbar_section:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="BusbarSection not found"
        )
    
    await db.execute(delete(BusbarSection).where(BusbarSection.id == busbar_section_id))
    await db.commit()
    
    return {"message": "BusbarSection deleted successfully"}

# ===== ENDPOINTS ДЛЯ ПРОВОДЯЩЕГО ОБОРУДОВАНИЯ =====

@router.get("/bays/{bay_id}/equipment", response_model=List[ConductingEquipmentResponse])
async def get_conducting_equipment(
    bay_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение списка проводящего оборудования ячейки"""
    
    # Проверяем существование ячейки
    bay = await db.get(Bay, bay_id)
    if not bay:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bay not found"
        )
    
    result = await db.execute(
        select(ConductingEquipment).where(ConductingEquipment.bay_id == bay_id)
    )
    equipment = result.scalars().all()
    
    return equipment

@router.get("/substations/{substation_id}/equipment", response_model=List[ConductingEquipmentResponse])
async def get_substation_equipment(
    substation_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение всего проводящего оборудования подстанции"""
    
    # Проверяем существование подстанции
    substation = await db.get(Substation, substation_id)
    if not substation:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Substation not found"
        )
    
    # Получаем все ячейки подстанции через уровни напряжения
    result = await db.execute(
        select(ConductingEquipment)
        .join(Bay)
        .join(VoltageLevel)
        .where(VoltageLevel.substation_id == substation_id)
    )
    equipment = result.scalars().all()
    
    return equipment

@router.post("/bays/{bay_id}/equipment", response_model=ConductingEquipmentResponse)
async def create_conducting_equipment(
    bay_id: int,
    equipment_data: ConductingEquipmentCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Создание проводящего оборудования для ячейки"""
    
    # Проверяем существование ячейки
    bay = await db.get(Bay, bay_id)
    if not bay:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bay not found"
        )
    
    # Генерируем mRID если не указан
    mrid = equipment_data.mrid if equipment_data.mrid else generate_mrid()
    
    # Проверяем уникальность mRID
    existing_mrid = await db.execute(
        select(ConductingEquipment).where(ConductingEquipment.mrid == mrid)
    )
    if existing_mrid.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="ConductingEquipment with this mRID already exists"
        )
    
    # Создаем оборудование
    db_equipment = ConductingEquipment(
        **equipment_data.dict(exclude={'mrid'}),
        bay_id=bay_id,
        mrid=mrid,
        created_by=current_user.id
    )
    db.add(db_equipment)
    await db.commit()
    await db.refresh(db_equipment)
    
    return db_equipment

@router.get("/equipment/{equipment_id}", response_model=ConductingEquipmentResponse)
async def get_conducting_equipment_by_id(
    equipment_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение проводящего оборудования по ID"""
    
    result = await db.execute(
        select(ConductingEquipment).where(ConductingEquipment.id == equipment_id)
    )
    equipment = result.scalar_one_or_none()
    
    if not equipment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="ConductingEquipment not found"
        )
    
    return equipment

@router.put("/equipment/{equipment_id}", response_model=ConductingEquipmentResponse)
async def update_conducting_equipment(
    equipment_id: int,
    equipment_data: ConductingEquipmentCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Обновление проводящего оборудования"""
    
    result = await db.execute(
        select(ConductingEquipment).where(ConductingEquipment.id == equipment_id)
    )
    equipment = result.scalar_one_or_none()
    
    if not equipment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="ConductingEquipment not found"
        )
    
    # Обновляем данные (исключаем mRID)
    update_data = equipment_data.dict(exclude={'mrid'})
    for field, value in update_data.items():
        setattr(equipment, field, value)
    
    await db.commit()
    await db.refresh(equipment)
    
    return equipment

@router.delete("/equipment/{equipment_id}")
async def delete_conducting_equipment(
    equipment_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Удаление проводящего оборудования"""
    
    result = await db.execute(
        select(ConductingEquipment).where(ConductingEquipment.id == equipment_id)
    )
    equipment = result.scalar_one_or_none()
    
    if not equipment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="ConductingEquipment not found"
        )
    
    await db.execute(delete(ConductingEquipment).where(ConductingEquipment.id == equipment_id))
    await db.commit()
    
    return {"message": "ConductingEquipment deleted successfully"}

# ===== ENDPOINTS ДЛЯ ЗАЩИТНОГО ОБОРУДОВАНИЯ =====

@router.get("/bays/{bay_id}/protection", response_model=List[ProtectionEquipmentResponse])
async def get_protection_equipment(
    bay_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение списка защитного оборудования ячейки"""
    
    # Проверяем существование ячейки
    bay = await db.get(Bay, bay_id)
    if not bay:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bay not found"
        )
    
    result = await db.execute(
        select(ProtectionEquipment).where(ProtectionEquipment.bay_id == bay_id)
    )
    protection = result.scalars().all()
    
    return protection

@router.post("/bays/{bay_id}/protection", response_model=ProtectionEquipmentResponse)
async def create_protection_equipment(
    bay_id: int,
    protection_data: ProtectionEquipmentCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Создание защитного оборудования для ячейки"""
    
    # Проверяем существование ячейки
    bay = await db.get(Bay, bay_id)
    if not bay:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bay not found"
        )
    
    # Генерируем mRID если не указан
    mrid = protection_data.mrid if protection_data.mrid else generate_mrid()
    
    # Проверяем уникальность mRID
    existing_mrid = await db.execute(
        select(ProtectionEquipment).where(ProtectionEquipment.mrid == mrid)
    )
    if existing_mrid.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="ProtectionEquipment with this mRID already exists"
        )
    
    # Создаем защитное оборудование
    db_protection = ProtectionEquipment(
        **protection_data.dict(exclude={'mrid'}),
        bay_id=bay_id,
        mrid=mrid,
        created_by=current_user.id
    )
    db.add(db_protection)
    await db.commit()
    await db.refresh(db_protection)
    
    return db_protection

@router.put("/protection/{protection_id}", response_model=ProtectionEquipmentResponse)
async def update_protection_equipment(
    protection_id: int,
    protection_data: ProtectionEquipmentCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Обновление защитного оборудования"""
    
    result = await db.execute(
        select(ProtectionEquipment).where(ProtectionEquipment.id == protection_id)
    )
    protection = result.scalar_one_or_none()
    
    if not protection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="ProtectionEquipment not found"
        )
    
    # Обновляем данные (исключаем mRID)
    update_data = protection_data.dict(exclude={'mrid'})
    for field, value in update_data.items():
        setattr(protection, field, value)
    
    await db.commit()
    await db.refresh(protection)
    
    return protection

@router.delete("/protection/{protection_id}")
async def delete_protection_equipment(
    protection_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Удаление защитного оборудования"""
    
    result = await db.execute(
        select(ProtectionEquipment).where(ProtectionEquipment.id == protection_id)
    )
    protection = result.scalar_one_or_none()
    
    if not protection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="ProtectionEquipment not found"
        )
    
    await db.execute(delete(ProtectionEquipment).where(ProtectionEquipment.id == protection_id))
    await db.commit()
    
    return {"message": "ProtectionEquipment deleted successfully"}

# ===== ENDPOINT ДЛЯ ПОЛНОЙ СТРУКТУРЫ ПОДСТАНЦИИ =====

@router.get("/{substation_id}/structure", response_model=SubstationResponseWithStructure)
async def get_substation_structure(
    substation_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение полной иерархической структуры подстанции"""
    
    result = await db.execute(
        select(Substation)
        .options(
            selectinload(Substation.voltage_levels).selectinload(VoltageLevel.bays).selectinload(Bay.busbar_sections),
            selectinload(Substation.voltage_levels).selectinload(VoltageLevel.bays).selectinload(Bay.conducting_equipment),
            selectinload(Substation.voltage_levels).selectinload(VoltageLevel.bays).selectinload(Bay.protection_equipment)
        )
        .where(Substation.id == substation_id)
    )
    substation = result.scalar_one_or_none()
    
    if not substation:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Substation not found"
        )
    
    return substation
