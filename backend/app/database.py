from sqlalchemy import create_engine, MetaData, text, select, and_, func
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
import asyncio
import logging

from app.core.config import settings

# Импорт всех моделей, чтобы они попали в Base.metadata до create_all/drop_all
def _import_models():
    from app import models  # noqa: F401

logger = logging.getLogger(__name__)

# Создание движка базы данных
# Для asyncpg отключаем SSL для внутреннего Docker соединения
database_url = settings.DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://")
# Если URL не содержит параметров SSL, добавляем отключение SSL
if "?" not in database_url:
    database_url += "?ssl=disable"
elif "ssl=" not in database_url:
    database_url += "&ssl=disable"

# Отладочный вывод для диагностики
print(f"DEBUG: Database URL будет использован: {database_url.split('@')[0].split('://')[0]}://****@{database_url.split('@')[1] if '@' in database_url else 'unknown'}")

# Настройка движка с таймаутами и пулом соединений
# Адаптивные настройки в зависимости от окружения
import os
is_docker = os.path.exists("/.dockerenv")  # Проверка, запущены ли в Docker

if is_docker:
    # Настройки для Docker (более производительные)
    pool_size = 5
    max_overflow = 10
    pool_recycle = 3600  # 1 час
    timeout = 10
else:
    # Настройки для Windows (более консервативные)
    pool_size = 1
    max_overflow = 0
    pool_recycle = 300  # 5 минут
    timeout = 30

engine = create_async_engine(
    database_url,
    echo=False,  # Отключаем echo для уменьшения логов
    pool_size=pool_size,
    max_overflow=max_overflow,
    pool_pre_ping=True,  # Проверка соединений перед использованием
    pool_recycle=pool_recycle,
    # Используем минимальные параметры для asyncpg
    connect_args={
        "timeout": timeout,
    }
)

# Создание сессии
AsyncSessionLocal = sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False
)


def _register_db_metrics_listeners() -> None:
    """Учёт commit'ов (записей в БД) для графика нагрузки в админ-панели."""
    from sqlalchemy import event
    from sqlalchemy.orm import Session

    from app.core.app_metrics import record_db_write

    @event.listens_for(Session, "after_commit")
    def _after_commit(_session) -> None:
        import asyncio

        try:
            loop = asyncio.get_running_loop()
            loop.create_task(record_db_write())
        except RuntimeError:
            pass


_register_db_metrics_listeners()

# Базовый класс для моделей
Base = declarative_base()

# Метаданные
metadata = MetaData()

async def get_db():
    """Получение сессии базы данных"""
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()


async def seed_default_equipment_catalog():
    """
    Идемпотентно заполняет equipment_catalog дефолтными марками и характеристиками.
    - Добавляет отсутствующие записи.
    - Для существующих заполняет только пустые поля характеристик.
    """
    from app.api.v1.equipment_catalog import _default_catalog_payloads
    from app.models.equipment_catalog import EquipmentCatalogItem

    defaults = _default_catalog_payloads()
    inserted = 0
    updated = 0

    async with AsyncSessionLocal() as db:
        for row in defaults:
            existing = (
                await db.execute(
                    select(EquipmentCatalogItem).where(
                        and_(
                            EquipmentCatalogItem.type_code == row["type_code"],
                            func.lower(EquipmentCatalogItem.brand) == row["brand"].lower(),
                            func.lower(EquipmentCatalogItem.model) == row["model"].lower(),
                        )
                    )
                )
            ).scalar_one_or_none()
            if existing:
                changed = False
                new_fn = row.get("full_name")
                if new_fn and getattr(existing, "full_name") != new_fn:
                    setattr(existing, "full_name", new_fn)
                    changed = True
                for field in (
                    "voltage_kv",
                    "current_a",
                    "manufacturer",
                    "country",
                    "description",
                    "attrs_json",
                ):
                    current_value = getattr(existing, field)
                    new_value = row.get(field)
                    is_empty = current_value is None or (
                        isinstance(current_value, str) and not current_value.strip()
                    )
                    if is_empty and new_value is not None:
                        setattr(existing, field, new_value)
                        changed = True
                if changed:
                    updated += 1
                continue
            db.add(EquipmentCatalogItem(**row, created_by=None))
            inserted += 1
        await db.commit()

    logger.info(
        "Seed equipment_catalog completed: inserted=%s, updated=%s, total_defaults=%s",
        inserted,
        updated,
        len(defaults),
    )


async def seed_default_line_conductor_catalog():
    """
    Идемпотентно заполняет line_conductor_catalog марками из CSV файла в корне проекта.
    """
    from app.api.v1.line_conductor_catalog import load_defaults_from_csv
    from app.models.line_conductor_catalog import LineConductorCatalogItem

    defaults = load_defaults_from_csv()
    if not defaults:
        logger.warning("CSV со справочником проводов не найден или пуст, seed line_conductor_catalog пропущен")
        return

    inserted = 0
    updated = 0
    async with AsyncSessionLocal() as db:
        for row in defaults:
            mark = (row.get("mark") or "").strip()
            voltage_kv = row.get("voltage_kv")
            if not mark or voltage_kv is None:
                continue
            existing = (
                await db.execute(
                    select(LineConductorCatalogItem).where(
                        and_(
                            func.lower(LineConductorCatalogItem.mark) == mark.lower(),
                            LineConductorCatalogItem.voltage_kv == float(voltage_kv),
                        )
                    )
                )
            ).scalar_one_or_none()
            if existing:
                if not existing.is_active:
                    existing.is_active = True
                    updated += 1
                continue
            db.add(
                LineConductorCatalogItem(
                    mark=mark,
                    voltage_kv=float(voltage_kv),
                    is_active=True,
                )
            )
            inserted += 1
        await db.commit()

    logger.info(
        "Seed line_conductor_catalog completed: inserted=%s, updated=%s, total_defaults=%s",
        inserted,
        updated,
        len(defaults),
    )


async def seed_default_wire_info_catalog():
    """Идемпотентно заполняет wire_info типовыми марками АС (r/x/b на 1 км)."""
    from app.core.wire_info_catalog import ensure_wire_info_catalog_seeded

    async with AsyncSessionLocal() as db:
        inserted = await ensure_wire_info_catalog_seeded(db)
        await db.commit()
    logger.info("Seed wire_info completed: inserted=%s", inserted)


async def init_db():
    """Инициализация базы данных с обработкой ошибок"""
    import asyncpg
    from urllib.parse import urlparse
    
    max_retries = 3
    retry_delay = 2  # секунды
    
    # Парсим URL для получения параметров подключения
    # Используем более надежный способ парсинга
    db_url = settings.DATABASE_URL
    parsed = urlparse(db_url)
    
    db_host = parsed.hostname or "localhost"
    # Важно: проверяем порт из URL, если не указан - используем 5433 (наш Docker порт)
    db_port = parsed.port if parsed.port else (5433 if "5433" in db_url else 5432)
    db_user = parsed.username or "postgres"
    db_password = parsed.password or ""
    db_name = parsed.path.lstrip("/") or "lepm_db"
    
    # Дополнительная проверка: если в URL явно указан 5433, используем его
    if ":5433" in db_url:
        db_port = 5433
    elif ":5432" in db_url:
        db_port = 5432
    
    # Маскируем пароль в URL для вывода
    safe_url = settings.DATABASE_URL
    if "@" in safe_url:
        parts = safe_url.split("@")
        if ":" in parts[0]:
            user_pass = parts[0].split(":")
            if len(user_pass) >= 2:
                safe_url = f"{user_pass[0]}:****@{parts[1]}"
    
    print(f"Попытка подключения к базе данных: {safe_url}")
    print(f"DEBUG: Параметры подключения - host={db_host}, port={db_port}, db={db_name}, user={db_user}")
    
    # Пробуем использовать прямое подключение через asyncpg для инициализации
    # Это обходит проблемы SQLAlchemy с asyncpg на Windows
    for attempt in range(max_retries):
        try:
            # Прямое подключение через asyncpg для проверки
            conn = await asyncpg.connect(
                host=db_host,
                port=db_port,
                user=db_user,
                password=db_password,
                database=db_name,
                timeout=10
            )
            
            # Проверяем подключение
            version = await conn.fetchval("SELECT version()")
            print(f"DEBUG: Подключение успешно, версия PostgreSQL: {version[:50]}...")
            
            # Закрываем прямое подключение
            await conn.close()
            
            # Подтягиваем все модели в метаданные (для drop_all/create_all)
            _import_models()

            # Теперь используем SQLAlchemy для создания таблиц
            async with engine.begin() as conn:
                if getattr(settings, "RECREATE_DB", False):
                    logger.warning("RECREATE_DB=1: удаляем все таблицы и создаём заново по моделям.")
                    print("WARNING: RECREATE_DB=1 — пересоздаём все таблицы (данные будут удалены).")
                    print("         После первого запуска снимите RECREATE_DB (или поставьте 0), чтобы не сносить БД при каждом старте.")
                    # Циклы FK (pole ↔ connectivity_node и др.) не дают drop_all — дропаем через CASCADE
                    for table in Base.metadata.tables.values():
                        await conn.execute(text(f'DROP TABLE IF EXISTS "{table.name}" CASCADE'))
                    for legacy in ("line_segments", "line_segment", "acline_segments", "connections"):
                        await conn.execute(text(f'DROP TABLE IF EXISTS "{legacy}" CASCADE'))
                await conn.run_sync(Base.metadata.create_all)
                # Обеспечиваем наличие колонок при донакатке схемы (миграции + create_all)
                await conn.execute(text("""
                    DO $$
                    BEGIN
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'pole')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'pole' AND column_name = 'is_tap_pole')
                        THEN
                            ALTER TABLE pole ADD COLUMN is_tap_pole BOOLEAN NOT NULL DEFAULT false;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'substation')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'substation' AND column_name = 'connected_line_ids')
                        THEN
                            ALTER TABLE substation ADD COLUMN connected_line_ids INTEGER[];
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'patrol_sessions')
                           AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'patrol_sessions' AND column_name = 'power_line_id')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'patrol_sessions' AND column_name = 'line_id')
                        THEN
                            ALTER TABLE patrol_sessions RENAME COLUMN power_line_id TO line_id;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'pole')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'pole' AND column_name = 'tap_branch_index')
                        THEN
                            ALTER TABLE pole ADD COLUMN tap_branch_index INTEGER;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'line')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'line' AND column_name = 'substation_start_id')
                        THEN
                            ALTER TABLE "line" ADD COLUMN substation_start_id INTEGER NULL REFERENCES substation(id);
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'line')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'line' AND column_name = 'substation_end_id')
                        THEN
                            ALTER TABLE "line" ADD COLUMN substation_end_id INTEGER NULL REFERENCES substation(id);
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'acline_segment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'acline_segment' AND column_name = 'to_substation_id')
                        THEN
                            ALTER TABLE acline_segment ADD COLUMN to_substation_id INTEGER NULL REFERENCES substation(id);
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'equipment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'equipment' AND column_name = 'direction_angle')
                        THEN
                            ALTER TABLE equipment ADD COLUMN direction_angle DOUBLE PRECISION NULL;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'connectivity_node')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'connectivity_node' AND column_name = 'is_virtual')
                        THEN
                            ALTER TABLE connectivity_node ADD COLUMN is_virtual BOOLEAN NOT NULL DEFAULT false;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'connectivity_node')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'connectivity_node' AND column_name = 'equipment_id')
                        THEN
                            ALTER TABLE connectivity_node ADD COLUMN equipment_id INTEGER NULL REFERENCES equipment(id);
                        END IF;
                        -- Обновляем существующие ConnectivityNode: для обочных опор (не отпаечных) помечаем узлы как виртуальные.
                        -- Отпаечные опоры (is_tap_pole = true) и узлы подстанций (pole_id IS NULL) остаются реальными.
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'connectivity_node')
                           AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'connectivity_node' AND column_name = 'is_virtual')
                           AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'pole')
                        THEN
                            UPDATE connectivity_node AS cn
                            SET is_virtual = true
                            FROM pole AS p
                            WHERE cn.pole_id = p.id
                              AND (p.is_tap_pole IS NULL OR p.is_tap_pole = false);
                        END IF;
                        -- Карточка опоры (комментарий и вложения) и дефекты оборудования
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'pole')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'pole' AND column_name = 'card_comment')
                        THEN
                            ALTER TABLE pole ADD COLUMN card_comment TEXT;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'pole')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'pole' AND column_name = 'card_comment_attachment')
                        THEN
                            ALTER TABLE pole ADD COLUMN card_comment_attachment TEXT;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'equipment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'equipment' AND column_name = 'defect')
                        THEN
                            ALTER TABLE equipment ADD COLUMN defect TEXT;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'equipment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'equipment' AND column_name = 'criticality')
                        THEN
                            ALTER TABLE equipment ADD COLUMN criticality VARCHAR(20);
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'equipment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'equipment' AND column_name = 'defect_attachment')
                        THEN
                            ALTER TABLE equipment ADD COLUMN defect_attachment TEXT;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'equipment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'equipment' AND column_name = 'card_comment')
                        THEN
                            ALTER TABLE equipment ADD COLUMN card_comment TEXT;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'equipment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'equipment' AND column_name = 'card_comment_attachment')
                        THEN
                            ALTER TABLE equipment ADD COLUMN card_comment_attachment TEXT;
                        END IF;
                        -- pole: дефект конструкции (миграция 20260410_140000)
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'pole')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'pole' AND column_name = 'structural_defect')
                        THEN
                            ALTER TABLE pole ADD COLUMN structural_defect TEXT;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'pole')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'pole' AND column_name = 'structural_defect_criticality')
                        THEN
                            ALTER TABLE pole ADD COLUMN structural_defect_criticality VARCHAR(20);
                        END IF;
                        -- equipment: электрические поля и CIM для разъединителя (20260427 + 20260428)
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'equipment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'equipment' AND column_name = 'rated_current')
                        THEN
                            ALTER TABLE equipment ADD COLUMN rated_current DOUBLE PRECISION;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'equipment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'equipment' AND column_name = 'i_th')
                        THEN
                            ALTER TABLE equipment ADD COLUMN i_th DOUBLE PRECISION;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'equipment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'equipment' AND column_name = 'ip_max')
                        THEN
                            ALTER TABLE equipment ADD COLUMN ip_max DOUBLE PRECISION;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'equipment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'equipment' AND column_name = 't_th')
                        THEN
                            ALTER TABLE equipment ADD COLUMN t_th DOUBLE PRECISION;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'equipment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'equipment' AND column_name = 'normal_open')
                        THEN
                            ALTER TABLE equipment ADD COLUMN normal_open BOOLEAN;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'equipment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'equipment' AND column_name = 'retained')
                        THEN
                            ALTER TABLE equipment ADD COLUMN retained BOOLEAN;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'equipment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'equipment' AND column_name = 'identified_object_description')
                        THEN
                            ALTER TABLE equipment ADD COLUMN identified_object_description VARCHAR(255);
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'equipment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'equipment' AND column_name = 'nameplate')
                        THEN
                            ALTER TABLE equipment ADD COLUMN nameplate VARCHAR(255);
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'equipment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'equipment' AND column_name = 'psr_subtype')
                        THEN
                            ALTER TABLE equipment ADD COLUMN psr_subtype VARCHAR(40);
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'equipment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'equipment' AND column_name = 'installation_display_name')
                        THEN
                            ALTER TABLE equipment ADD COLUMN installation_display_name VARCHAR(255);
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'equipment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'equipment' AND column_name = 'tm_code')
                        THEN
                            ALTER TABLE equipment ADD COLUMN tm_code VARCHAR(100);
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'equipment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'equipment' AND column_name = 'object_subtype')
                        THEN
                            ALTER TABLE equipment ADD COLUMN object_subtype VARCHAR(100);
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'equipment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'equipment' AND column_name = 'pole_count')
                        THEN
                            ALTER TABLE equipment ADD COLUMN pole_count INTEGER;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'equipment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'equipment' AND column_name = 'parent_object_ref')
                        THEN
                            ALTER TABLE equipment ADD COLUMN parent_object_ref VARCHAR(255);
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'equipment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'equipment' AND column_name = 'parent_main_equipment_pole_ref')
                        THEN
                            ALTER TABLE equipment ADD COLUMN parent_main_equipment_pole_ref VARCHAR(255);
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'equipment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'equipment' AND column_name = 'nominal_voltage_kv')
                        THEN
                            ALTER TABLE equipment ADD COLUMN nominal_voltage_kv DOUBLE PRECISION;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'equipment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'equipment' AND column_name = 'nominal_breaking_current_ka')
                        THEN
                            ALTER TABLE equipment ADD COLUMN nominal_breaking_current_ka DOUBLE PRECISION;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'equipment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'equipment' AND column_name = 'own_trip_time_sec')
                        THEN
                            ALTER TABLE equipment ADD COLUMN own_trip_time_sec DOUBLE PRECISION;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'equipment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'equipment' AND column_name = 'emergency_current_a')
                        THEN
                            ALTER TABLE equipment ADD COLUMN emergency_current_a DOUBLE PRECISION;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'equipment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'equipment' AND column_name = 'continuous_current_a')
                        THEN
                            ALTER TABLE equipment ADD COLUMN continuous_current_a DOUBLE PRECISION;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'equipment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'equipment' AND column_name = 'arrester_type')
                        THEN
                            ALTER TABLE equipment ADD COLUMN arrester_type VARCHAR(40);
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'equipment')
                           AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'equipment_catalog')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'equipment' AND column_name = 'catalog_item_id')
                        THEN
                            ALTER TABLE equipment ADD COLUMN catalog_item_id INTEGER NULL REFERENCES equipment_catalog(id);
                        END IF;
                        -- acline_segment: доп. RLC и т.п. (20260427_181500)
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'acline_segment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'acline_segment' AND column_name = 'r0')
                        THEN
                            ALTER TABLE acline_segment ADD COLUMN r0 DOUBLE PRECISION;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'acline_segment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'acline_segment' AND column_name = 'x0')
                        THEN
                            ALTER TABLE acline_segment ADD COLUMN x0 DOUBLE PRECISION;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'acline_segment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'acline_segment' AND column_name = 'bch')
                        THEN
                            ALTER TABLE acline_segment ADD COLUMN bch DOUBLE PRECISION;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'acline_segment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'acline_segment' AND column_name = 'b0ch')
                        THEN
                            ALTER TABLE acline_segment ADD COLUMN b0ch DOUBLE PRECISION;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'acline_segment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'acline_segment' AND column_name = 'gch')
                        THEN
                            ALTER TABLE acline_segment ADD COLUMN gch DOUBLE PRECISION;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'acline_segment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'acline_segment' AND column_name = 'g0ch')
                        THEN
                            ALTER TABLE acline_segment ADD COLUMN g0ch DOUBLE PRECISION;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'acline_segment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'acline_segment' AND column_name = 'i_th')
                        THEN
                            ALTER TABLE acline_segment ADD COLUMN i_th DOUBLE PRECISION;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'acline_segment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'acline_segment' AND column_name = 't_th')
                        THEN
                            ALTER TABLE acline_segment ADD COLUMN t_th DOUBLE PRECISION;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'acline_segment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'acline_segment' AND column_name = 'sections')
                        THEN
                            ALTER TABLE acline_segment ADD COLUMN sections INTEGER;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'acline_segment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'acline_segment' AND column_name = 'short_circuit_end_temperature')
                        THEN
                            ALTER TABLE acline_segment ADD COLUMN short_circuit_end_temperature DOUBLE PRECISION;
                        END IF;
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'acline_segment')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'acline_segment' AND column_name = 'is_jumper')
                        THEN
                            ALTER TABLE acline_segment ADD COLUMN is_jumper BOOLEAN DEFAULT false;
                        END IF;
                        -- users: учётная копия пароля для админ-панели (alembic 20260512_160000)
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users')
                           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'password_plain')
                        THEN
                            ALTER TABLE users ADD COLUMN password_plain VARCHAR(255) NULL;
                        END IF;
                    END $$;
                """))
                await conn.execute(text('CREATE INDEX IF NOT EXISTS idx_line_substation_start_id ON "line"(substation_start_id)'))
                await conn.execute(text('CREATE INDEX IF NOT EXISTS idx_line_substation_end_id ON "line"(substation_end_id)'))
                await conn.execute(text("""
                    DO $$
                    BEGIN
                        IF EXISTS (
                            SELECT 1 FROM information_schema.columns
                            WHERE table_schema = 'public' AND table_name = 'equipment' AND column_name = 'catalog_item_id'
                        ) THEN
                            CREATE INDEX IF NOT EXISTS ix_equipment_catalog_item_id ON equipment(catalog_item_id);
                        END IF;
                    END $$;
                """))
                # Обеспечиваем наличие колонок координат в substation (x_position = долгота, y_position = широта)
                await conn.execute(text("""
                    DO $$
                    BEGIN
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'substation') THEN
                            IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'substation' AND column_name = 'y_position') THEN
                                ALTER TABLE substation ADD COLUMN y_position DOUBLE PRECISION;
                            END IF;
                            IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'substation' AND column_name = 'x_position') THEN
                                ALTER TABLE substation ADD COLUMN x_position DOUBLE PRECISION;
                            END IF;
                        END IF;
                    END $$;
                """))
                await conn.execute(text("""
                    DO $$
                    BEGIN
                        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'wire_info') THEN
                            IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'wire_info' AND column_name = 'i_th') THEN
                                ALTER TABLE wire_info ADD COLUMN i_th DOUBLE PRECISION;
                            END IF;
                            IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'wire_info' AND column_name = 'ip_max') THEN
                                ALTER TABLE wire_info ADD COLUMN ip_max DOUBLE PRECISION;
                            END IF;
                            IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'wire_info' AND column_name = 't_th') THEN
                                ALTER TABLE wire_info ADD COLUMN t_th DOUBLE PRECISION;
                            END IF;
                            IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'wire_info' AND column_name = 'voltage_kv') THEN
                                ALTER TABLE wire_info ADD COLUMN voltage_kv DOUBLE PRECISION;
                            END IF;
                            IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'wire_info' AND column_name = 'in_service') THEN
                                ALTER TABLE wire_info ADD COLUMN in_service BOOLEAN NOT NULL DEFAULT true;
                            END IF;
                        END IF;
                    END $$;
                """))
            
            logger.info("База данных успешно инициализирована")
            await seed_default_equipment_catalog()
            await seed_default_line_conductor_catalog()
            await seed_default_wire_info_catalog()
            return
            
        except Exception as e:
            error_type = type(e).__name__
            error_message = str(e)
            
            if attempt < max_retries - 1:
                logger.warning(f"WARNING: Попытка подключения к БД {attempt + 1}/{max_retries} не удалась: {error_type}: {error_message}. Повтор через {retry_delay} сек...")
                print(f"WARNING: Попытка подключения к БД {attempt + 1}/{max_retries} не удалась: {error_type}: {error_message}. Повтор через {retry_delay} сек...")
                await asyncio.sleep(retry_delay)
            else:
                # Извлекаем информацию о хосте и порте из URL
                db_info = f"{db_host}:{db_port}/{db_name}"
                
                error_msg = (
                    f"\nERROR: Не удалось подключиться к базе данных после {max_retries} попыток.\n"
                    f"Тип ошибки: {error_type}\n"
                    f"Сообщение: {error_message}\n"
                    f"Адрес БД: {db_info}\n\n"
                    f"Проверьте:\n"
                    f"  1. Запущен ли PostgreSQL сервер\n"
                    f"  2. Правильность DATABASE_URL в настройках (app/core/config.py или .env файл)\n"
                    f"  3. Доступность базы данных по указанному адресу\n"
                    f"  4. Правильность имени базы данных, пользователя и пароля\n"
                    f"  5. Если используете Docker, проверьте, что контейнер PostgreSQL запущен\n"
                )
                logger.error(error_msg)
                print(error_msg)
                raise ConnectionError(f"Не удалось подключиться к базе данных: {error_message}") from e
