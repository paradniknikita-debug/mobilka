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


def _col_exists(conn, table: str, column: str) -> bool:
    import sqlalchemy as sa

    r = conn.execute(
        sa.text(
            "SELECT 1 FROM information_schema.columns "
            "WHERE table_schema = 'public' AND table_name = :t AND column_name = :c"
        ),
        {"t": table, "c": column},
    )
    return r.scalar() is not None


def upgrade() -> None:
    conn = op.get_bind()
    if not _col_exists(conn, "users", "password_plain"):
        op.add_column("users", sa.Column("password_plain", sa.String(length=255), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "password_plain")
