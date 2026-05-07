"""
add_connectivity_node_is_virtual_and_equipment_id

Revision ID: 20260226_400000
Revises: 20260226_300000
Create Date: 2026-02-26

Идемпотентно добавляет connectivity_node.is_virtual и connectivity_node.equipment_id,
если миграция 20260226_100000 не применялась к данной БД.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = '20260226_400000'
down_revision = '20260226_300000'
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
    for tbl in ('connectivity_node', 'connectivity_nodes'):
        if not _table_exists(conn, tbl):
            continue
        if not _col_exists(conn, tbl, 'is_virtual'):
            op.add_column(tbl, sa.Column('is_virtual', sa.Boolean(), nullable=False, server_default=sa.false()))
        if not _col_exists(conn, tbl, 'equipment_id'):
            op.add_column(tbl, sa.Column('equipment_id', sa.Integer(), nullable=True))
            op.create_foreign_key(
                'fk_connectivity_node_equipment',
                tbl, 'equipment',
                ['equipment_id'], ['id'],
            )
        break


def downgrade() -> None:
    conn = op.get_bind()
    for tbl in ('connectivity_node', 'connectivity_nodes'):
        if not _table_exists(conn, tbl):
            continue
        if _col_exists(conn, tbl, 'equipment_id'):
            try:
                op.drop_constraint('fk_connectivity_node_equipment', tbl, type_='foreignkey')
            except Exception:
                pass
            op.drop_column(tbl, 'equipment_id')
        if _col_exists(conn, tbl, 'is_virtual'):
            op.drop_column(tbl, 'is_virtual')
        break
