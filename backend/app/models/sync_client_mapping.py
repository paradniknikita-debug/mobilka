"""Маппинг локальных (клиентских) id на серверные для синхронизации.

Используется при upload: опоры создаются в одном пакете, оборудование — в другом.
Оборудование приходит с pole_id=-34 (локальный id); по этой таблице находим server_id опоры.
"""
from sqlalchemy import Column, Integer, String, UniqueConstraint
from app.database import Base


class SyncClientMapping(Base):
    __tablename__ = "sync_client_mapping"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=False, index=True)
    entity_type = Column(String(32), nullable=False)  # 'pole', 'power_line'
    client_id = Column(Integer, nullable=False)  # локальный id (может быть < 0)
    server_id = Column(Integer, nullable=False)

    __table_args__ = (
        UniqueConstraint("user_id", "entity_type", "client_id", name="uq_sync_client_mapping_user_entity_client"),
    )
