"""line_pole_mrid_and_rename

Revision ID: 20250221_200000
Revises: 20250221_000000
Create Date: 2025-02-21 20:00:00.000000

Для цепи без переименования (20241201 -> 20250221_000000): добавляет mrid/region_id
в power_lines, mrid в poles, переименовывает power_lines -> line, poles -> pole
(колонка power_line_id -> line_id), чтобы модель (__tablename__ = "line", "pole") работала.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import text


revision = "20250221_200000"
down_revision = "20250221_000000"
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
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = :t AND column_name = :c
        """), {"t": table_name, "c": column_name})
        return r.fetchone() is not None
    except Exception:
        return False


def _fk_names(conn, table_name, column_name):
    """Список имён FK-ограничений для колонки."""
    try:
        r = conn.execute(text("""
            SELECT tc.constraint_name FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
              ON tc.constraint_name = kcu.constraint_name AND tc.table_schema = kcu.table_schema
            WHERE tc.table_schema = 'public' AND tc.table_name = :t AND kcu.column_name = :c
              AND tc.constraint_type = 'FOREIGN KEY'
        """), {"t": table_name, "c": column_name})
        return [row[0] for row in r.fetchall()]
    except Exception:
        return []


def upgrade() -> None:
    conn = op.get_bind()

    # 1) Добавляем mrid/region_id в power_lines, затем переименовываем в line
    if _table_exists(conn, "power_lines") and not _table_exists(conn, "line"):
        if not _column_exists(conn, "power_lines", "mrid"):
            op.add_column(
                "power_lines",
                sa.Column("mrid", sa.String(36), nullable=False, server_default=sa.text("gen_random_uuid()::text")),
            )
            op.create_index("ix_power_lines_mrid", "power_lines", ["mrid"], unique=True)
        if not _column_exists(conn, "power_lines", "region_id"):
            op.add_column("power_lines", sa.Column("region_id", sa.Integer(), nullable=True))
        op.rename_table("power_lines", "line")

    # 2) Добавляем mrid в poles, переименовываем power_line_id -> line_id, poles -> pole
    if _table_exists(conn, "poles") and not _table_exists(conn, "pole"):
        if not _column_exists(conn, "poles", "mrid"):
            op.add_column(
                "poles",
                sa.Column("mrid", sa.String(36), nullable=False, server_default=sa.text("gen_random_uuid()::text")),
            )
            op.create_index("ix_poles_mrid", "poles", ["mrid"], unique=True)
        if _column_exists(conn, "poles", "power_line_id"):
            for fk in _fk_names(conn, "poles", "power_line_id"):
                try:
                    op.drop_constraint(fk, "poles", type_="foreignkey")
                except Exception:
                    pass
            op.alter_column(
                "poles", "power_line_id",
                new_column_name="line_id",
            )
            op.create_foreign_key("pole_line_id_fkey", "poles", "line", ["line_id"], ["id"])
        op.rename_table("poles", "pole")

    # 3) Если уже есть line/pole (другая цепь), только добавляем колонки при отсутствии
    for line_table in ("line",):
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

    for pole_table in ("pole",):
        if not _table_exists(conn, pole_table):
            continue
        if not _column_exists(conn, pole_table, "mrid"):
            op.add_column(
                pole_table,
                sa.Column("mrid", sa.String(36), nullable=False, server_default=sa.text("gen_random_uuid()::text")),
            )
            op.create_index(op.f(f"ix_{pole_table}_mrid"), pole_table, ["mrid"], unique=True)
        break


def downgrade() -> None:
    conn = op.get_bind()
    # Откат только удаление добавленных колонок; переименование line->power_lines, pole->poles не делаем
    for pole_table in ("pole",):
        if _table_exists(conn, pole_table) and _column_exists(conn, pole_table, "mrid"):
            try:
                op.drop_index(op.f(f"ix_{pole_table}_mrid"), table_name=pole_table)
            except Exception:
                pass
            op.drop_column(pole_table, "mrid")
        break
    for line_table in ("line",):
        if _table_exists(conn, line_table):
            if _column_exists(conn, line_table, "region_id"):
                op.drop_column(line_table, "region_id")
            if _column_exists(conn, line_table, "mrid"):
                try:
                    op.drop_index(op.f(f"ix_{line_table}_mrid"), table_name=line_table)
                except Exception:
                    pass
                op.drop_column(line_table, "mrid")
        break
