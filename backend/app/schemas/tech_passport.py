from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, ConfigDict, Field, model_validator

OBJECT_TYPES = frozenset({"power_line", "pole", "substation"})


class TechPassportCreate(BaseModel):
    object_type: str
    object_id: Optional[int] = None
    object_mrid: Optional[str] = None
    title: Optional[str] = Field(None, max_length=500)
    stp_reference: Optional[str] = Field(None, max_length=500)
    manual_sections: Optional[Dict[str, Any]] = None

    @model_validator(mode="after")
    def validate_refs(self) -> TechPassportCreate:
        ot = (self.object_type or "").strip().lower()
        if ot not in OBJECT_TYPES:
            raise ValueError("object_type должен быть: power_line, pole или substation")
        self.object_type = ot
        if self.object_id is None and not (self.object_mrid and str(self.object_mrid).strip()):
            raise ValueError("Укажите object_id или object_mrid")
        return self


class TechPassportListItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    mrid: str
    title: str
    object_type: str
    object_mrid: str
    object_id: Optional[int] = None
    stp_reference: Optional[str] = None
    created_at: Optional[datetime] = None


class PassportSectionRow(BaseModel):
    label: str
    value: Any = None


class PassportSectionTable(BaseModel):
    title: str
    columns: List[str] = Field(default_factory=list)
    rows: List[Dict[str, Any]] = Field(default_factory=list)


class PassportSection(BaseModel):
    id: str
    title: str
    rows: List[PassportSectionRow] = Field(default_factory=list)
    tables: List[PassportSectionTable] = Field(default_factory=list)


class TechPassportDetail(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    mrid: str
    title: str
    object_type: str
    object_mrid: str
    object_id: Optional[int] = None
    stp_reference: Optional[str] = None
    snapshot_json: Dict[str, Any]
    manual_sections: Optional[Dict[str, Any]] = None
    sections: List[PassportSection] = Field(default_factory=list)
    created_at: Optional[datetime] = None


class TechPassportListResponse(BaseModel):
    items: List[TechPassportListItem]
    total: int
