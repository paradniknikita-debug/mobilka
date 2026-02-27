from pydantic import BaseModel
from typing import Dict, Any, Optional, List
from datetime import datetime
from enum import Enum

class SyncAction(str, Enum):
    CREATE = "create"
    UPDATE = "update"
    DELETE = "delete"

class SyncStatus(str, Enum):
    PENDING = "pending"
    SYNCED = "synced"
    FAILED = "failed"

class SyncRecord(BaseModel):
    """Универсальная запись для синхронизации"""
    id: str  # Уникальный ID записи
    entity_type: str  # Тип сущности (power_line, pole, equipment, etc.)
    action: SyncAction
    data: Dict[str, Any]
    timestamp: datetime
    user_id: Optional[int] = None
    device_id: Optional[str] = None
    status: SyncStatus = SyncStatus.PENDING
    error_message: Optional[str] = None

class SyncBatch(BaseModel):
    """Пакет записей для синхронизации"""
    records: List[SyncRecord]
    batch_id: str
    timestamp: datetime

class SyncResponse(BaseModel):
    """Ответ на синхронизацию"""
    success: bool
    processed_count: int
    failed_count: int
    errors: List[Dict[str, Any]] = []
    batch_id: str
    timestamp: datetime
    # Маппинг локальных id → серверные (для обновления клиента: pole_server_id и сброса needsSync)
    id_mapping: Optional[Dict[str, Dict[str, int]]] = None  # {"pole": {"-34": 101}, "power_line": {"-5": 10}}

# JSON Schema для валидации данных
# branch_id и region_id не обязательны — мобильное приложение может создавать ЛЭП без филиала/региона
# mrid может быть null — сервер сгенерирует при создании
POWER_LINE_SCHEMA = {
    "type": "object",
    "properties": {
        "id": {"type": ["integer", "string"]},
        "mrid": {"type": ["string", "null"]},
        "name": {"type": "string"},
        "voltage_level": {"type": "number"},
        "length": {"type": ["number", "null"]},
        "region_id": {"type": ["integer", "null"]},
        "branch_id": {"type": ["integer", "null"]},
        "status": {"type": ["string", "null"]},
        "description": {"type": ["string", "null"]},
        "created_by": {"type": ["integer", "null"]},
        "created_at": {"type": ["string", "number"]},
        "updated_at": {"type": ["string", "number", "null"]}
    },
    "required": ["name", "voltage_level"]
}

POLE_SCHEMA = {
    "type": "object",
    "properties": {
        "id": {"type": ["integer", "string"]},
        "mrid": {"type": ["string", "null"]},
        "power_line_id": {"type": ["integer", "string"]},
        "pole_number": {"type": "string"},
        "x_position": {"type": ["number", "null"]},
        "y_position": {"type": ["number", "null"]},
        "latitude": {"type": ["number", "null"]},
        "longitude": {"type": ["number", "null"]},
        "pole_type": {"type": "string"},
        "height": {"type": ["number", "null"]},
        "foundation_type": {"type": ["string", "null"]},
        "material": {"type": ["string", "null"]},
        "year_installed": {"type": ["integer", "null"]},
        "condition": {"type": "string"},
        "notes": {"type": ["string", "null"]},
        "created_by": {"type": ["integer", "null"]},
        "created_at": {"type": ["string", "number"]},
        "updated_at": {"type": ["string", "number", "null"]}
    },
    "required": ["power_line_id", "pole_number", "pole_type"]
}

EQUIPMENT_SCHEMA = {
    "type": "object",
    "properties": {
        "id": {"type": ["integer", "string"]},
        "pole_id": {"type": ["integer", "string"]},
        "pole_server_id": {"type": ["integer", "null"]},  # опционально: серверный id опоры, если уже известен
        "equipment_type": {"type": "string"},
        "name": {"type": "string"},
        "manufacturer": {"type": ["string", "null"]},
        "model": {"type": ["string", "null"]},
        "serial_number": {"type": ["string", "null"]},
        "year_manufactured": {"type": ["integer", "null"]},
        "installation_date": {"type": ["string", "null"]},
        "condition": {"type": "string"},
        "notes": {"type": ["string", "null"]},
        "created_by": {"type": ["integer", "null"]},
        "created_at": {"type": ["string", "number", "null"]},
        "updated_at": {"type": ["string", "number", "null"]}
    },
    "required": ["pole_id", "equipment_type", "name"]
}

# Схемы для всех типов сущностей
ENTITY_SCHEMAS = {
    "power_line": POWER_LINE_SCHEMA,
    "pole": POLE_SCHEMA,
    "equipment": EQUIPMENT_SCHEMA,
    "span": {
        "type": "object",
        "properties": {
            "id": {"type": "string"},
            "line_id": {"type": "string"},  # Обновлено: power_line_id -> line_id
            "from_pole_id": {"type": "string"},
            "to_pole_id": {"type": "string"},
            "span_number": {"type": "string"},
            "length": {"type": "number"},
            "conductor_type": {"type": "string"},
            "conductor_material": {"type": "string"},
            "conductor_section": {"type": "string"},
            "tension": {"type": "number"},
            "sag": {"type": "number"},
            "sequence_number": {"type": "integer"},
            "notes": {"type": "string"}
        },
        "required": ["line_id", "from_pole_id", "to_pole_id", "span_number", "length"]
    },
    "tap": {
        "type": "object",
        "properties": {
            "id": {"type": "string"},
            "line_id": {"type": "string"},
            "pole_id": {"type": "string"},
            "tap_number": {"type": "string"},
            "tap_type": {"type": "string"},
            "voltage_level": {"type": "number"},
            "power_rating": {"type": "number"},
            "latitude": {"type": "number"},
            "longitude": {"type": "number"},
            "description": {"type": "string"}
        },
        "required": ["line_id", "pole_id", "tap_number", "tap_type", "voltage_level"]
    }
}
