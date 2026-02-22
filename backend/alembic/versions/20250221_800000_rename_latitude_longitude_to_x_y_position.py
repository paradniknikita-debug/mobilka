"""rename latitude/longitude to y_position/x_position in DB

Revision ID: 20250221_800000
Revises: 20250221_700000
Create Date: 2025-02-21 80:00:00.000000

Унификация координат: в БД везде x_position (долгота), y_position (широта).
Таблицы: pole, tap, substation, connectivity_node.
Поддерживаются варианты имён таблиц (pole/poles и т.д.).
"""
from alembic import op
from sqlalchemy import inspect, text


revision = "20250221_800000"
down_revision = "20250221_700000"
branch_labels = None
depends_on = None


# Таблицы с координатами для переименования (не position_points)
_COORDS_TABLES = ("pole", "poles", "tap", "taps", "substation", "substations", "connectivity_node", "connectivity_nodes")


def _tables_with_lat_lon(inspector):
    """Таблицы из _COORDS_TABLES, у которых есть latitude и longitude."""
    result = []
    for table in inspector.get_table_names():
        if table not in _COORDS_TABLES:
            continue
        cols = [c["name"] for c in inspector.get_columns(table)]
        if "latitude" in cols and "longitude" in cols:
            result.append(table)
    return result


def upgrade():
    conn = op.get_bind()
    inspector = inspect(conn)
    tables = _tables_with_lat_lon(inspector)
    for table in tables:
        op.execute(text(f'ALTER TABLE "{table}" RENAME COLUMN latitude TO y_position'))
        op.execute(text(f'ALTER TABLE "{table}" RENAME COLUMN longitude TO x_position'))


def downgrade():
    conn = op.get_bind()
    inspector = inspect(conn)
    for table in inspector.get_table_names():
        if table not in _COORDS_TABLES:
            continue
        cols = [c["name"] for c in inspector.get_columns(table)]
        if "y_position" in cols and "x_position" in cols:
            op.execute(text(f'ALTER TABLE "{table}" RENAME COLUMN y_position TO latitude'))
            op.execute(text(f'ALTER TABLE "{table}" RENAME COLUMN x_position TO longitude'))
