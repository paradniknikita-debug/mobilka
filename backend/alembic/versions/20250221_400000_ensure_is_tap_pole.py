"""ensure_is_tap_pole

Revision ID: 20250221_400000
Revises: 20251208_231206, 20250221_200000, 20250221_100000
Create Date: 2025-02-21 40:00:00.000000

Добавляет колонку is_tap_pole в таблицу pole, если её нет (идемпотентно).
Объединяет ветки миграций и устраняет UndefinedColumnError для pole.is_tap_pole.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = "20250221_400000"
down_revision = ("20251208_231206", "20250221_200000", "20250221_100000")
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    existing_tables = inspector.get_table_names()

    if "pole" in existing_tables:
        cols = [c["name"] for c in inspector.get_columns("pole")]
        if "is_tap_pole" not in cols:
            op.add_column(
                "pole",
                sa.Column("is_tap_pole", sa.Boolean(), nullable=False, server_default=sa.text("false")),
            )


def downgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    existing_tables = inspector.get_table_names()

    if "pole" in existing_tables:
        cols = [c["name"] for c in inspector.get_columns("pole")]
        if "is_tap_pole" in cols:
            op.drop_column("pole", "is_tap_pole")
