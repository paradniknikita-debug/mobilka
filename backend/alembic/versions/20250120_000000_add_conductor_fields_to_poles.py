"""add_conductor_fields_to_poles

Revision ID: 20250120_000000
Revises: 20241220_000000
Create Date: 2025-01-20 00:00:00.000000

Добавляет поля conductor_* в таблицу опор (pole).
Идемпотентно: если таблицы pole нет, пропускаем.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = '20250120_000000'
down_revision = '20241220_000000'
branch_labels = None
depends_on = None

TABLE_POLE = 'pole'


def upgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    if TABLE_POLE not in inspector.get_table_names():
        return
    existing_columns = [col['name'] for col in inspector.get_columns(TABLE_POLE)]
    if 'conductor_type' not in existing_columns:
        op.add_column(TABLE_POLE, sa.Column('conductor_type', sa.String(length=50), nullable=True))
    if 'conductor_material' not in existing_columns:
        op.add_column(TABLE_POLE, sa.Column('conductor_material', sa.String(length=50), nullable=True))
    if 'conductor_section' not in existing_columns:
        op.add_column(TABLE_POLE, sa.Column('conductor_section', sa.String(length=20), nullable=True))


def downgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    if TABLE_POLE not in inspector.get_table_names():
        return
    cols = [c['name'] for c in inspector.get_columns(TABLE_POLE)]
    if 'conductor_section' in cols:
        op.drop_column(TABLE_POLE, 'conductor_section')
    if 'conductor_material' in cols:
        op.drop_column(TABLE_POLE, 'conductor_material')
    if 'conductor_type' in cols:
        op.drop_column(TABLE_POLE, 'conductor_type')

