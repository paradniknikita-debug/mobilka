"""Три роли: admin, passport_clerk, field_engineer; миграция engineer/dispatcher.

Revision ID: 20260511_200000
Revises: 20260511_100000
"""

from typing import Optional

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = "20260511_200000"
down_revision = "20260511_100000"
branch_labels = None
depends_on = None


def _col_type_length(table: str, col: str) -> Optional[int]:
    bind = op.get_bind()
    insp = inspect(bind)
    for c in insp.get_columns(table):
        if c["name"] == col:
            t = c["type"]
            if hasattr(t, "length") and t.length is not None:
                return int(t.length)
    return None


def upgrade() -> None:
    len_role = _col_type_length("users", "role")
    if len_role is not None and len_role < 40:
        op.alter_column(
            "users",
            "role",
            existing_type=sa.String(length=len_role),
            type_=sa.String(length=40),
            existing_nullable=True,
        )

    op.execute(
        sa.text(
            """
            UPDATE users SET role = CASE LOWER(TRIM(role))
                WHEN 'dispatcher' THEN 'passport_clerk'
                WHEN 'engineer' THEN 'field_engineer'
                WHEN 'admin' THEN 'admin'
                WHEN 'passport_clerk' THEN 'passport_clerk'
                WHEN 'field_engineer' THEN 'field_engineer'
                ELSE 'field_engineer'
            END
            """
        )
    )
    op.execute(
        sa.text(
            """
            UPDATE users SET role = 'admin'
            WHERE is_superuser = true OR LOWER(TRIM(username)) = 'admin'
            """
        )
    )


def downgrade() -> None:
    op.execute(
        sa.text(
            """
            UPDATE users SET role = CASE role
                WHEN 'passport_clerk' THEN 'dispatcher'
                WHEN 'field_engineer' THEN 'engineer'
                WHEN 'admin' THEN 'admin'
                ELSE 'engineer'
            END
            """
        )
    )
    op.alter_column(
        "users",
        "role",
        existing_type=sa.String(length=40),
        type_=sa.String(length=20),
        existing_nullable=True,
    )
