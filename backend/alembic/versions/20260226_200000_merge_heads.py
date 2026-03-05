"""
merge_heads_20260226

Revision ID: 20260226_200000
Revises: 20250210_000000, 20260226_100000
Create Date: 2026-02-26

Объединяет две ветки: sync_client_mapping и cn_is_virtual_and_equipment_direction.
"""
from alembic import op
import sqlalchemy as sa


revision = '20260226_200000'
down_revision = ('20250210_000000', '20260226_100000')
branch_labels = None
depends_on = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
