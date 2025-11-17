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
    entity_type: str  # Тип сущности (power_line, tower, equipment, etc.)
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

# JSON Schema для валидации данных
POWER_LINE_SCHEMA = {
    "type": "object",
    "properties": {
        "id": {"type": "string"},
        "name": {"type": "string"},
        "code": {"type": "string"},
        "voltage_level": {"type": "number"},
        "length": {"type": "number"},
        "branch_id": {"type": "integer"},
        "status": {"type": "string"},
        "description": {"type": "string"},
        "created_at": {"type": "string", "format": "date-time"},
        "updated_at": {"type": "string", "format": "date-time"}
    },
    "required": ["name", "code", "voltage_level", "branch_id"]
}

TOWER_SCHEMA = {
    "type": "object",
    "properties": {
        "id": {"type": "string"},
        "power_line_id": {"type": "string"},
        "tower_number": {"type": "string"},
        "latitude": {"type": "number"},
        "longitude": {"type": "number"},
        "tower_type": {"type": "string"},
        "height": {"type": "number"},
        "foundation_type": {"type": "string"},
        "material": {"type": "string"},
        "year_installed": {"type": "integer"},
        "condition": {"type": "string"},
        "notes": {"type": "string"},
        "created_at": {"type": "string", "format": "date-time"}
    },
    "required": ["power_line_id", "tower_number", "latitude", "longitude", "tower_type"]
}

EQUIPMENT_SCHEMA = {
    "type": "object",
    "properties": {
        "id": {"type": "string"},
        "tower_id": {"type": "string"},
        "equipment_type": {"type": "string"},
        "name": {"type": "string"},
        "manufacturer": {"type": "string"},
        "model": {"type": "string"},
        "serial_number": {"type": "string"},
        "year_manufactured": {"type": "integer"},
        "installation_date": {"type": "string", "format": "date-time"},
        "condition": {"type": "string"},
        "notes": {"type": "string"}
    },
    "required": ["tower_id", "equipment_type", "name"]
}

# Схемы для всех типов сущностей
ENTITY_SCHEMAS = {
    "power_line": POWER_LINE_SCHEMA,
    "tower": TOWER_SCHEMA,
    "equipment": EQUIPMENT_SCHEMA,
    "span": {
        "type": "object",
        "properties": {
            "id": {"type": "string"},
            "power_line_id": {"type": "string"},
            "from_tower_id": {"type": "string"},
            "to_tower_id": {"type": "string"},
            "span_number": {"type": "string"},
            "length": {"type": "number"},
            "conductor_type": {"type": "string"},
            "conductor_material": {"type": "string"},
            "conductor_section": {"type": "string"},
            "tension": {"type": "number"},
            "sag": {"type": "number"},
            "notes": {"type": "string"}
        },
        "required": ["power_line_id", "from_tower_id", "to_tower_id", "span_number", "length"]
    },
    "tap": {
        "type": "object",
        "properties": {
            "id": {"type": "string"},
            "power_line_id": {"type": "string"},
            "tower_id": {"type": "string"},
            "tap_number": {"type": "string"},
            "tap_type": {"type": "string"},
            "voltage_level": {"type": "number"},
            "power_rating": {"type": "number"},
            "latitude": {"type": "number"},
            "longitude": {"type": "number"},
            "description": {"type": "string"}
        },
        "required": ["power_line_id", "tower_id", "tap_number", "tap_type", "voltage_level"]
    }
}
