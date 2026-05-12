"""Учётная копия пароля для панели администратора.

Revision ID: 20260512_160000
Revises: 20260512_150000
"""

from alembic import op
import sqlalchemy as sa

revision = "20260512_160000"
down_revision = "20260512_150000"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("password_plain", sa.String(length=255), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "password_plain")
