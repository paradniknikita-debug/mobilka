"""rename_code_to_dispatcher_name

Revision ID: 20250131_000000
Revises: 20250120_000000
Create Date: 2025-01-31 00:00:00.000000

Переименование колонки code -> dispatcher_name в таблице подстанций.
Поддерживаются имена таблицы: substation (единственное число) и substations.
Идемпотентно: если таблицы нет — шаг пропускается.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = '20250131_000000'
down_revision = '20250120_000000'
branch_labels = None
depends_on = None

# Каноническое имя в моделях — единственное число
SUBSTATION_TABLE_OPTIONS = ('substation', 'substations')


def _substation_table(inspector):
    tables = inspector.get_table_names()
    for name in SUBSTATION_TABLE_OPTIONS:
        if name in tables:
            return name
    return None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    table = _substation_table(inspector)
    if not table:
        return
    existing_columns = [col['name'] for col in inspector.get_columns(table)]
    if 'code' in existing_columns and 'dispatcher_name' not in existing_columns:
        op.alter_column(table, 'code', new_column_name='dispatcher_name', existing_type=sa.String(length=20), existing_nullable=False)
    if 'dispatcher_name' in existing_columns:
        op.alter_column(table, 'dispatcher_name', type_=sa.String(length=100), existing_nullable=False)


def downgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    table = _substation_table(inspector)
    if not table:
        return
    existing_columns = [col['name'] for col in inspector.get_columns(table)]
    if 'dispatcher_name' in existing_columns:
        op.alter_column(table, 'dispatcher_name', new_column_name='code', existing_type=sa.String(length=100), existing_nullable=False)
    if 'code' in existing_columns:
        op.alter_column(table, 'code', type_=sa.String(length=20), existing_nullable=False)

