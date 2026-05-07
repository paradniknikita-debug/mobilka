"""drop line_segments table (redundant: use AClineSegment.line_id FK)

Revision ID: 20250221_900000
Revises: 20250221_800000
Create Date: 2025-02-21 90:00:00.000000

Таблица line_segments дублировала связь Line ↔ AClineSegment.
Связь уже задаётся через AClineSegment.line_id (FK на line.id).
"""
from alembic import op
from sqlalchemy import inspect


revision = "20250221_900000"
down_revision = "20250221_800000"
branch_labels = None
depends_on = None


def upgrade():
    conn = op.get_bind()
    inspector = inspect(conn)
    if "line_segments" in inspector.get_table_names():
        op.drop_table("line_segments")


def downgrade():
    # Восстанавливать M2M таблицу не будем — связь по line_id достаточна
    pass
