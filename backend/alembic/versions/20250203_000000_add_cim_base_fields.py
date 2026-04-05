"""Add CIM base fields from Mixins

Revision ID: 20250203_000000
Revises: 20250202_000000
Create Date: 2025-02-03 00:00:00.000000

Поддерживаются имена таблиц: line/power_lines, substation/substations,
acline_segment/acline_segments, connectivity_node/connectivity_nodes.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = '20250203_000000'
down_revision = '20250202_000000'
branch_labels = None
depends_on = None


def _resolve_table(inspector, options):
    tables = inspector.get_table_names()
    for name in options:
        if name in tables:
            return name
    return None


def _has_column(inspector, table, col):
    if not table:
        return False
    return col in [c['name'] for c in inspector.get_columns(table)]


def upgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    line_t = _resolve_table(inspector, ('line', 'power_lines'))
    substation_t = _resolve_table(inspector, ('substation', 'substations'))
    acline_t = _resolve_table(inspector, ('acline_segment', 'acline_segments'))
    conn_node_t = _resolve_table(inspector, ('connectivity_node', 'connectivity_nodes'))

    if line_t and not _has_column(inspector, line_t, 'alias_name'):
        op.add_column(line_t, sa.Column('alias_name', sa.String(length=100), nullable=True))
    if line_t and not _has_column(inspector, line_t, 'parent_id'):
        op.add_column(line_t, sa.Column('parent_id', sa.Integer(), nullable=True))
    if substation_t and not _has_column(inspector, substation_t, 'alias_name'):
        op.add_column(substation_t, sa.Column('alias_name', sa.String(length=100), nullable=True))
    if substation_t and not _has_column(inspector, substation_t, 'parent_id'):
        op.add_column(substation_t, sa.Column('parent_id', sa.Integer(), nullable=True))
    if acline_t:
        if not _has_column(inspector, acline_t, 'alias_name'):
            op.add_column(acline_t, sa.Column('alias_name', sa.String(length=100), nullable=True))
        if not _has_column(inspector, acline_t, 'parent_id'):
            op.add_column(acline_t, sa.Column('parent_id', sa.Integer(), nullable=True))
        if not _has_column(inspector, acline_t, 'normally_in_service'):
            op.add_column(acline_t, sa.Column('normally_in_service', sa.Boolean(), nullable=True, server_default=sa.text('true')))
        if not _has_column(inspector, acline_t, 'phases'):
            op.add_column(acline_t, sa.Column('phases', sa.String(length=10), nullable=True))
    if conn_node_t and substation_t and not _has_column(inspector, conn_node_t, 'substation_id'):
        op.add_column(conn_node_t, sa.Column('substation_id', sa.Integer(), nullable=True))
        op.create_foreign_key(
            'fk_connectivity_nodes_substation_id',
            conn_node_t,
            substation_t,
            ['substation_id'],
            ['id'],
            ondelete='SET NULL'
        )
        op.create_index(op.f('ix_connectivity_nodes_substation_id'), conn_node_t, ['substation_id'], unique=False)


def downgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    conn_node_t = _resolve_table(inspector, ('connectivity_node', 'connectivity_nodes'))
    acline_t = _resolve_table(inspector, ('acline_segment', 'acline_segments'))
    substation_t = _resolve_table(inspector, ('substation', 'substations'))
    line_t = _resolve_table(inspector, ('line', 'power_lines'))

    if conn_node_t:
        indexes = [idx['name'] for idx in inspector.get_indexes(conn_node_t)]
        if 'ix_connectivity_nodes_substation_id' in indexes:
            op.drop_index(op.f('ix_connectivity_nodes_substation_id'), table_name=conn_node_t)
        fks = [fk['name'] for fk in inspector.get_foreign_keys(conn_node_t)]
        if 'fk_connectivity_nodes_substation_id' in fks:
            op.drop_constraint('fk_connectivity_nodes_substation_id', conn_node_t, type_='foreignkey')
        cols = [c['name'] for c in inspector.get_columns(conn_node_t)]
        if 'substation_id' in cols:
            op.drop_column(conn_node_t, 'substation_id')
    for table_name, drop_cols in [
        (acline_t, ['phases', 'normally_in_service', 'parent_id', 'alias_name']),
        (substation_t, ['parent_id', 'alias_name']),
        (line_t, ['parent_id', 'alias_name']),
    ]:
        if not table_name:
            continue
        existing_columns = [c['name'] for c in inspector.get_columns(table_name)]
        for col in drop_cols:
            if col in existing_columns:
                op.drop_column(table_name, col)
                existing_columns.remove(col)

