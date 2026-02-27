"""ensure connections has line_id column

Revision ID: 20250221_500000
Revises: 20250221_400000
Create Date: 2025-02-21 50:00:00.000000

Идемпотентно переименовывает power_line_id -> line_id в таблице connections,
если колонка ещё не переименована. Устраняет UndefinedColumnError при удалении ЛЭП
на серверах, где миграция df0c351f69f8 не переименовала колонку (например, из-за
другого имени FK или пропущенного шага).
"""
from alembic import op
from sqlalchemy import text


revision = "20250221_500000"
down_revision = "20250221_400000"
branch_labels = None
depends_on = None


def _table_exists(conn, table_name):
    try:
        r = conn.execute(
            text(
                """
            SELECT EXISTS (
                SELECT FROM information_schema.tables
                WHERE table_schema = 'public' AND table_name = :t
            )
        """
            ),
            {"t": table_name},
        )
        return r.scalar()
    except Exception:
        return False


def _column_exists(conn, table_name, column_name):
    try:
        r = conn.execute(
            text(
                """
            SELECT column_name
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = :t AND column_name = :c
        """
            ),
            {"t": table_name, "c": column_name},
        )
        return r.fetchone() is not None
    except Exception:
        return False


def _constraint_exists(conn, constraint_name, table_name):
    try:
        r = conn.execute(
            text(
                """
            SELECT constraint_name
            FROM information_schema.table_constraints
            WHERE table_schema = 'public' AND table_name = :t
              AND constraint_name = :cn AND constraint_type = 'FOREIGN KEY'
        """
            ),
            {"t": table_name, "cn": constraint_name},
        )
        return r.fetchone() is not None
    except Exception:
        return False


def upgrade() -> None:
    conn = op.get_bind()
    if not _table_exists(conn, "connections"):
        return
    if _column_exists(conn, "connections", "line_id"):
        return
    if not _column_exists(conn, "connections", "power_line_id"):
        return

    # Удаляем возможные FK на power_line_id (разные имена в разных миграциях)
    for fk_name in (
        "connections_power_line_id_fkey",
        "connections_line_id_fkey",
    ):
        if _constraint_exists(conn, fk_name, "connections"):
            op.drop_constraint(fk_name, "connections", type_="foreignkey")
            break

    op.alter_column(
        "connections",
        "power_line_id",
        new_column_name="line_id",
    )

    if _table_exists(conn, "line") and not _constraint_exists(
        conn, "connections_line_id_fkey", "connections"
    ):
        op.create_foreign_key(
            "connections_line_id_fkey",
            "connections",
            "line",
            ["line_id"],
            ["id"],
        )


def downgrade() -> None:
    conn = op.get_bind()
    if not _table_exists(conn, "connections") or not _column_exists(
        conn, "connections", "line_id"
    ):
        return

    if _constraint_exists(conn, "connections_line_id_fkey", "connections"):
        op.drop_constraint(
            "connections_line_id_fkey", "connections", type_="foreignkey"
        )
    op.alter_column(
        "connections",
        "line_id",
        new_column_name="power_line_id",
    )
    if _table_exists(conn, "line"):
        op.create_foreign_key(
            "connections_power_line_id_fkey",
            "connections",
            "line",
            ["power_line_id"],
            ["id"],
        )
