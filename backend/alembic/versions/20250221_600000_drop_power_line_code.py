"""drop code column from line (PowerLine)

Revision ID: 20250221_600000
Revises: 20250221_500000
Create Date: 2025-02-21 60:00:00.000000

Удаляем поле code у ЛЭП — для идентификации достаточно mrid.
"""
from alembic import op
from sqlalchemy import text


revision = "20250221_600000"
down_revision = "20250221_500000"
branch_labels = None
depends_on = None


def _column_exists(conn, table_name, column_name):
    try:
        r = conn.execute(
            text(
                """
                SELECT column_name FROM information_schema.columns
                WHERE table_schema = 'public' AND table_name = :t AND column_name = :c
                """
            ),
            {"t": table_name, "c": column_name},
        )
        return r.fetchone() is not None
    except Exception:
        return False


def upgrade():
    conn = op.get_bind()
    if _column_exists(conn, "line", "code"):
        op.drop_column("line", "code")


def downgrade():
    op.add_column("line", op.Column("code", op.String(20), nullable=True))
    conn = op.get_bind()
    conn.execute(
        text("UPDATE line SET code = 'LEP-' || UPPER(SUBSTRING(mrid FROM 1 FOR 8)) WHERE code IS NULL")
    )
    op.alter_column("line", "code", nullable=False)
    op.create_index(op.f("ix_line_code"), "line", ["code"], unique=True)
