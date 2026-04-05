"""add x_position, y_position to substation

Revision ID: 20250302_100000
Revises: 20250302_000000
Create Date: 2025-03-02

Координаты подстанции: x_position = долгота, y_position = широта.
Добавляем колонки сырым SQL (IF NOT EXISTS) для идемпотентности.
"""
from alembic import op
from sqlalchemy import inspect, text

revision = "20250302_100000"
down_revision = "20250302_000000"
branch_labels = None
depends_on = None


def _table_exists(conn, name):
    return name in inspect(conn).get_table_names()


def _column_exists(conn, table, column):
    if not _table_exists(conn, table):
        return False
    cols = [c["name"] for c in inspect(conn).get_columns(table)]
    return column in cols


def upgrade() -> None:
    conn = op.get_bind()
    for table in ("substation", "substations"):
        if not _table_exists(conn, table):
            continue
        if not _column_exists(conn, table, "y_position"):
            conn.execute(text(f'ALTER TABLE "{table}" ADD COLUMN y_position DOUBLE PRECISION'))
        if not _column_exists(conn, table, "x_position"):
            conn.execute(text(f'ALTER TABLE "{table}" ADD COLUMN x_position DOUBLE PRECISION'))
        break


def downgrade() -> None:
    conn = op.get_bind()
    for table in ("substation", "substations"):
        if not _table_exists(conn, table):
            continue
        if _column_exists(conn, table, "y_position"):
            op.drop_column(table, "y_position")
        if _column_exists(conn, table, "x_position"):
            op.drop_column(table, "x_position")
        break
