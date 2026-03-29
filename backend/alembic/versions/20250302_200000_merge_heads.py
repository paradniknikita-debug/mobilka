"""merge heads: 20250210 and 20250302_100000

Revision ID: 20250302_200000
Revises: 20250210_000000, 20250302_100000
Create Date: 2025-03-02

Объединяет две ветки миграций в одну голову.
"""
from alembic import op

revision = "20250302_200000"
down_revision = ("20250210_000000", "20250302_100000")
branch_labels = None
depends_on = None


def upgrade():
    pass


def downgrade():
    pass
