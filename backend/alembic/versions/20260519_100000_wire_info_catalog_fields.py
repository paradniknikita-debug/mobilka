"""wire_info: thermal fields, voltage_kv, in_service

Revision ID: 20260519_100000
Revises: 20260514_101000
Create Date: 2026-05-19
"""
from alembic import op
import sqlalchemy as sa

revision = "20260519_100000"
down_revision = "20260514_101000"
branch_labels = None
depends_on = None


def _col_exists(conn, table: str, column: str) -> bool:
    r = conn.execute(
        sa.text(
            """
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = :t AND column_name = :c
            """
        ),
        {"t": table, "c": column},
    )
    return r.scalar() is not None


def upgrade() -> None:
    conn = op.get_bind()
    if not _col_exists(conn, "wire_info", "i_th"):
        op.add_column("wire_info", sa.Column("i_th", sa.Float(), nullable=True))
    if not _col_exists(conn, "wire_info", "ip_max"):
        op.add_column("wire_info", sa.Column("ip_max", sa.Float(), nullable=True))
    if not _col_exists(conn, "wire_info", "t_th"):
        op.add_column("wire_info", sa.Column("t_th", sa.Float(), nullable=True))
    if not _col_exists(conn, "wire_info", "voltage_kv"):
        op.add_column("wire_info", sa.Column("voltage_kv", sa.Float(), nullable=True))
    if not _col_exists(conn, "wire_info", "in_service"):
        op.add_column(
            "wire_info",
            sa.Column("in_service", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        )


def downgrade() -> None:
    for col in ("in_service", "voltage_kv", "t_th", "ip_max", "i_th"):
        op.drop_column("wire_info", col)
