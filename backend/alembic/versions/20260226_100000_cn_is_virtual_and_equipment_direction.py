"""
cn_is_virtual_and_equipment_direction

Revision ID: 20260226_100000
Revises: 20260221_200000
Create Date: 2026-02-26

- connectivity_node: is_virtual (виртуальные CN не экспортируются в CIM; только отпаечные/ПС/оборудование — реальные)
- connectivity_node: equipment_id (nullable, для CN на оборудовании)
- equipment: direction_angle (градусы, направление от опоры для отрисовки)
- Данные: помечаем виртуальными CN у обочных опор (is_tap_pole = false)
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = '20260226_100000'
down_revision = '20260221_200000'
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

    # connectivity_node: is_virtual
    for t in ('connectivity_node', 'connectivity_nodes'):
        if _table_exists(conn, t) and not _col_exists(conn, t, 'is_virtual'):
            op.add_column(t, sa.Column('is_virtual', sa.Boolean(), nullable=False, server_default=sa.false()))
            break

    # connectivity_node: equipment_id
    for t in ('connectivity_node', 'connectivity_nodes'):
        if _table_exists(conn, t) and not _col_exists(conn, t, 'equipment_id'):
            op.add_column(t, sa.Column('equipment_id', sa.Integer(), nullable=True))
            op.create_foreign_key(
                'fk_connectivity_node_equipment',
                t, 'equipment',
                ['equipment_id'], ['id'],
            )
            break

    # equipment: direction_angle (градусы 0-360, направление от опоры)
    if _table_exists(conn, 'equipment') and not _col_exists(conn, 'equipment', 'direction_angle'):
        op.add_column('equipment', sa.Column('direction_angle', sa.Float(), nullable=True))

    # Данные: виртуальные CN только у обочных опор (не отпаечных)
    cn_table = 'connectivity_node' if _table_exists(conn, 'connectivity_node') else 'connectivity_nodes'
    if _table_exists(conn, cn_table) and _col_exists(conn, cn_table, 'is_virtual') and _col_exists(conn, cn_table, 'pole_id') and _table_exists(conn, 'pole'):
        op.execute(sa.text(
            "UPDATE " + cn_table + " cn SET is_virtual = true FROM pole p "
            "WHERE cn.pole_id = p.id AND (p.is_tap_pole IS NULL OR p.is_tap_pole = false)"
        ))


def downgrade() -> None:
    conn = op.get_bind()

    if _table_exists(conn, 'equipment') and _col_exists(conn, 'equipment', 'direction_angle'):
        op.drop_column('equipment', 'direction_angle')

    for t in ('connectivity_node', 'connectivity_nodes'):
        if _table_exists(conn, t):
            if _col_exists(conn, t, 'equipment_id'):
                fk = 'fk_connectivity_node_equipment'
                try:
                    op.drop_constraint(fk, t, type_='foreignkey')
                except Exception:
                    pass
                op.drop_column(t, 'equipment_id')
            if _col_exists(conn, t, 'is_virtual'):
                op.drop_column(t, 'is_virtual')
            break
