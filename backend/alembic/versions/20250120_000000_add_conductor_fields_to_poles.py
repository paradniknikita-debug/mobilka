"""add_conductor_fields_to_poles

Revision ID: 20250120_000000
Revises: 20241220_000000
Create Date: 2025-01-20 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '20250120_000000'
down_revision = '20241220_000000'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Добавляем поля марки провода в таблицу poles
    op.add_column('poles', sa.Column('conductor_type', sa.String(length=50), nullable=True))
    op.add_column('poles', sa.Column('conductor_material', sa.String(length=50), nullable=True))
    op.add_column('poles', sa.Column('conductor_section', sa.String(length=20), nullable=True))


def downgrade() -> None:
    # Удаляем поля марки провода из таблицы poles
    op.drop_column('poles', 'conductor_section')
    op.drop_column('poles', 'conductor_material')
    op.drop_column('poles', 'conductor_type')

