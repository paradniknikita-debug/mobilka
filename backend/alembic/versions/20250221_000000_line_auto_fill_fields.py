"""line_auto_fill_fields

Revision ID: 20250221_000000
Revises: 20241216_100000
Create Date: 2025-02-21 00:00:00.000000

- Добавление is_tap_pole в poles (отпаечная опора — конец участка ACLineSegment)
- connectivity_node.pole_id nullable для узлов на подстанциях
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = '20250221_000000'
down_revision = '20241216_100000'
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    existing_tables = inspector.get_table_names()

    if 'poles' in existing_tables:
        cols = [c['name'] for c in inspector.get_columns('poles')]
        if 'is_tap_pole' not in cols:
            op.add_column('poles', sa.Column('is_tap_pole', sa.Boolean(), nullable=False, server_default=sa.text('false')))

    if 'connectivity_node' in existing_tables:
        op.alter_column(
            'connectivity_node',
            'pole_id',
            existing_type=sa.Integer(),
            nullable=True,
        )


def downgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    existing_tables = inspector.get_table_names()

    if 'connectivity_node' in existing_tables:
        op.alter_column(
            'connectivity_node',
            'pole_id',
            existing_type=sa.Integer(),
            nullable=False,
        )

    if 'poles' in existing_tables:
        cols = [c['name'] for c in inspector.get_columns('poles')]
        if 'is_tap_pole' in cols:
            op.drop_column('poles', 'is_tap_pole')
