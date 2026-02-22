"""merge multiple heads (20241216_000000 and 20250221_600000)

Revision ID: 20250221_700000
Revises: 20241216_000000, 20250221_600000
Create Date: 2025-02-21 70:00:00.000000

Объединяет две ветки миграций в одну голову.
"""
from alembic import op


revision = "20250221_700000"
down_revision = ("20241216_000000", "20250221_600000")
branch_labels = None
depends_on = None


def upgrade():
    pass


def downgrade():
    pass
