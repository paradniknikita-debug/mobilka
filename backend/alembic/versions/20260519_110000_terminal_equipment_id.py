"""terminal.equipment_id — связь терминала с оборудованием на опоре

Revision ID: 20260519_110000
Revises: 20260519_100000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "20260519_110000"
down_revision: Union[str, None] = "20260519_100000"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _col_exists(conn, table: str, col: str) -> bool:
    from sqlalchemy import inspect

    return col in {c["name"] for c in inspect(conn).get_columns(table)}


def upgrade() -> None:
    conn = op.get_bind()
    if not _col_exists(conn, "terminal", "equipment_id"):
        op.add_column("terminal", sa.Column("equipment_id", sa.Integer(), nullable=True))
        op.create_foreign_key(
            "terminal_equipment_id_fkey",
            "terminal",
            "equipment",
            ["equipment_id"],
            ["id"],
            ondelete="CASCADE",
        )
        op.create_index("ix_terminal_equipment_id", "terminal", ["equipment_id"])


def downgrade() -> None:
    conn = op.get_bind()
    if _col_exists(conn, "terminal", "equipment_id"):
        op.drop_index("ix_terminal_equipment_id", table_name="terminal")
        op.drop_constraint("terminal_equipment_id_fkey", "terminal", type_="foreignkey")
        op.drop_column("terminal", "equipment_id")
