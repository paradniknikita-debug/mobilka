"""
add_equipment_location_and_coords

Revision ID: 20260221_200000
Revises: 20251208_231206
Create Date: 2026-02-21

Идемпотентно: колонки добавляются только при их отсутствии.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = '20260221_200000'
down_revision = '20251208_231206'
branch_labels = None
depends_on = None


def _col_exists(conn, table_name: str, column_name: str) -> bool:
    """Проверить существование колонки в таблице."""
    inspector = inspect(conn)
    if table_name not in inspector.get_table_names():
        return False
    return column_name in [c["name"] for c in inspector.get_columns(table_name)]


def upgrade() -> None:
    conn = op.get_bind()
    tables = inspect(conn).get_table_names()

    if 'equipment' not in tables:
        return

    # location_id для связи с Location
    if not _col_exists(conn, 'equipment', 'location_id'):
        op.add_column(
            'equipment',
            sa.Column('location_id', sa.Integer(), nullable=True),
        )
        op.create_foreign_key(
            'fk_equipment_location',
            'equipment',
            'location',
            ['location_id'],
            ['id'],
        )

    # y_position / x_position – координаты для оборудования (CIM: x = долгота, y = широта)
    if not _col_exists(conn, 'equipment', 'y_position'):
        op.add_column('equipment', sa.Column('y_position', sa.Float(), nullable=True))
    if not _col_exists(conn, 'equipment', 'x_position'):
        op.add_column('equipment', sa.Column('x_position', sa.Float(), nullable=True))


def downgrade() -> None:
    conn = op.get_bind()
    tables = inspect(conn).get_table_names()
    if 'equipment' not in tables:
        return

    # Удаляем связи и колонки, если есть
    inspector = inspect(conn)
    fk_names = [fk['name'] for fk in inspector.get_foreign_keys('equipment')]
    if 'fk_equipment_location' in fk_names:
        op.drop_constraint('fk_equipment_location', 'equipment', type_='foreignkey')

    if _col_exists(conn, 'equipment', 'location_id'):
        op.drop_column('equipment', 'location_id')
    if _col_exists(conn, 'equipment', 'y_position'):
        op.drop_column('equipment', 'y_position')
    if _col_exists(conn, 'equipment', 'x_position'):
        op.drop_column('equipment', 'x_position')

