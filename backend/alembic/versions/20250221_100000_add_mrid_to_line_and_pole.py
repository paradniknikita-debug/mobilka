"""add_mrid_to_line_and_pole

Revision ID: 20250221_100000
Revises: 9b9109e2a50c
Create Date: 2025-02-21 10:00:00.000000

Добавляет mrid и region_id в таблицу ЛЭП (line/power_lines) и mrid в таблицу опор (pole/poles),
если колонок ещё нет — для совместимости с API после переименования таблиц.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import text


revision = "20250221_100000"
down_revision = "9b9109e2a50c"
branch_labels = None
depends_on = None


def _table_exists(conn, table_name):
    try:
        r = conn.execute(text("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables
                WHERE table_schema = 'public' AND table_name = :t
            )
        """), {"t": table_name})
        return r.scalar()
    except Exception:
        return False


def _column_exists(conn, table_name, column_name):
    try:
        r = conn.execute(text("""
            SELECT column_name FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = :t AND column_name = :c
        """), {"t": table_name, "c": column_name})
        return r.fetchone() is not None
    except Exception:
        return False


def upgrade() -> None:
    conn = op.get_bind()

    for line_table in ("line", "power_lines"):
        if not _table_exists(conn, line_table):
            continue
        if not _column_exists(conn, line_table, "mrid"):
            op.add_column(
                line_table,
                sa.Column("mrid", sa.String(36), nullable=False, server_default=sa.text("gen_random_uuid()::text")),
            )
            op.create_index(op.f(f"ix_{line_table}_mrid"), line_table, ["mrid"], unique=True)
        if not _column_exists(conn, line_table, "region_id"):
            op.add_column(line_table, sa.Column("region_id", sa.Integer(), nullable=True))
        break

    if _table_exists(conn, "pole"):
        if not _column_exists(conn, "pole", "mrid"):
            op.add_column(
                "pole",
                sa.Column("mrid", sa.String(36), nullable=False, server_default=sa.text("gen_random_uuid()::text")),
            )
            op.create_index(op.f("ix_pole_mrid"), "pole", ["mrid"], unique=True)
        if not _column_exists(conn, "pole", "is_tap_pole"):
            op.add_column(
                "pole",
                sa.Column("is_tap_pole", sa.Boolean(), nullable=False, server_default=sa.text("false")),
            )


def downgrade() -> None:
    conn = op.get_bind()

    if _table_exists(conn, "pole"):
        if _column_exists(conn, "pole", "is_tap_pole"):
            op.drop_column("pole", "is_tap_pole")
        if _column_exists(conn, "pole", "mrid"):
            op.drop_index(op.f("ix_pole_mrid"), table_name="pole")
            op.drop_column("pole", "mrid")

    for line_table in ("line", "power_lines"):
        if not _table_exists(conn, line_table):
            continue
        if _column_exists(conn, line_table, "region_id"):
            op.drop_column(line_table, "region_id")
        if _column_exists(conn, line_table, "mrid"):
            op.drop_index(op.f(f"ix_{line_table}_mrid"), table_name=line_table)
            op.drop_column(line_table, "mrid")
        break
