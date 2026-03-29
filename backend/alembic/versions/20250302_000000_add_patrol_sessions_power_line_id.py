"""add power_line_id to patrol_sessions

Revision ID: 20250302_000000
Revises: 20250221_900000
Create Date: 2025-03-02

Таблица patrol_sessions может существовать без колонки power_line_id.
Добавляем колонку или создаём таблицу с полной схемой.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = "20250302_000000"
down_revision = "20250221_900000"
branch_labels = None
depends_on = None


def _table_exists(conn, name):
    return name in inspect(conn).get_table_names()


def _column_exists(conn, table, column):
    if not _table_exists(conn, table):
        return False
    cols = [c["name"] for c in inspect(conn).get_columns(table)]
    return column in cols


def upgrade() -> None:
    conn = op.get_bind()
    line_t = "line" if _table_exists(conn, "line") else None

    if not _table_exists(conn, "patrol_sessions"):
        if not _table_exists(conn, "users") or not line_t:
            return
        op.create_table(
            "patrol_sessions",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("user_id", sa.Integer(), nullable=False),
            sa.Column("power_line_id", sa.Integer(), nullable=False),
            sa.Column("note", sa.Text(), nullable=True),
            sa.Column("started_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=True),
            sa.Column("ended_at", sa.DateTime(timezone=True), nullable=True),
            sa.ForeignKeyConstraint(["user_id"], ["users.id"], ),
            sa.ForeignKeyConstraint(["power_line_id"], [f"{line_t}.id"], ),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index(op.f("ix_patrol_sessions_id"), "patrol_sessions", ["id"], unique=False)
        return

    if _column_exists(conn, "patrol_sessions", "power_line_id"):
        return

    if not line_t:
        return

    op.add_column(
        "patrol_sessions",
        sa.Column("power_line_id", sa.Integer(), nullable=True),
    )
    op.create_foreign_key(
        "patrol_sessions_power_line_id_fkey",
        "patrol_sessions",
        "line",
        ["power_line_id"],
        ["id"],
    )
    op.create_index(
        op.f("ix_patrol_sessions_power_line_id"),
        "patrol_sessions",
        ["power_line_id"],
        unique=False,
    )
    # Колонка nullable для существующих строк; новые сессии заполняют power_line_id в приложении.


def downgrade() -> None:
    conn = op.get_bind()
    if not _table_exists(conn, "patrol_sessions"):
        return
    if not _column_exists(conn, "patrol_sessions", "power_line_id"):
        return
    op.drop_index(op.f("ix_patrol_sessions_power_line_id"), table_name="patrol_sessions")
    op.drop_constraint("patrol_sessions_power_line_id_fkey", "patrol_sessions", type_="foreignkey")
    op.drop_column("patrol_sessions", "power_line_id")
