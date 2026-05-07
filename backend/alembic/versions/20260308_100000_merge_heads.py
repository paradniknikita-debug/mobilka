"""
merge_heads_pole_card_and_substation

Revision ID: 20260308_100000
Revises: 20260308_000000, 20250302_300000
Create Date: 2026-03-08

Объединяет две головы: pole_card_and_equipment_defect и ensure_substation_x_y_position.
"""
from alembic import op
import sqlalchemy as sa


revision = '20260308_100000'
down_revision = ('20260308_000000', '20250302_300000')
branch_labels = None
depends_on = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
