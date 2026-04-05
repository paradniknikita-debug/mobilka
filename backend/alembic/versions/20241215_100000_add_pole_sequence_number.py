"""add_pole_sequence_number

Revision ID: 20241215_100000
Revises: 20241201_000000
Create Date: 2024-12-15 10:00:00.000000

Добавление поля sequence_number в таблицу опор. Поддерживаются имена: pole, poles.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = '20241215_100000'
down_revision = '20241201_000000'
branch_labels = None
depends_on = None

POLE_TABLE_OPTIONS = ('pole', 'poles')


def _pole_table(inspector):
    tables = inspector.get_table_names()
    for name in POLE_TABLE_OPTIONS:
        if name in tables:
            return name
    return None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    table = _pole_table(inspector)
    if not table:
        return
    existing_columns = [col['name'] for col in inspector.get_columns(table)]
    if 'sequence_number' not in existing_columns:
        op.add_column(table, sa.Column('sequence_number', sa.Integer(), nullable=True))
        op.create_index('ix_pole_sequence_number', table, ['sequence_number'])
        print(f"Добавлена колонка 'sequence_number' в '{table}'")


def downgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    table = _pole_table(inspector)
    if not table:
        return
    existing_columns = [col['name'] for col in inspector.get_columns(table)]
    if 'sequence_number' in existing_columns:
        op.drop_index('ix_pole_sequence_number', table_name=table)
        op.drop_column(table, 'sequence_number')
        print(f"Удалена колонка 'sequence_number' из '{table}'")

