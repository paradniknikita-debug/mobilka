"""
add_equipment_direction_angle_if_missing

Revision ID: 20260226_300000
Revises: 20260226_200000
Create Date: 2026-02-26

Идемпотентно добавляет equipment.direction_angle, если колонки нет
(на случай, когда миграция 20260226_100000 не применялась к данной БД).
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = '20260226_300000'
down_revision = '20260226_200000'
branch_labels = None
depends_on = None


def _col_exists(conn, table_name: str, column_name: str) -> bool:
    inspector = inspect(conn)
    if table_name not in inspector.get_table_names():
        return False
    return column_name in [c["name"] for c in inspector.get_columns(table_name)]


def _table_exists(conn, name: str) -> bool:
    return name in inspect(conn).get_table_names()


def upgrade() -> None:
    conn = op.get_bind()
    if _table_exists(conn, 'equipment') and not _col_exists(conn, 'equipment', 'direction_angle'):
        op.add_column('equipment', sa.Column('direction_angle', sa.Float(), nullable=True))


def downgrade() -> None:
    conn = op.get_bind()
    if _table_exists(conn, 'equipment') and _col_exists(conn, 'equipment', 'direction_angle'):
        op.drop_column('equipment', 'direction_angle')
