"""line/pole: add CIM-oriented fields

Revision ID: 20260505_181500
Revises: 20260428_100000
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = "20260505_181500"
down_revision = "20260428_100000"
branch_labels = None
depends_on = None


def _col_exists(table: str, col: str) -> bool:
    bind = op.get_bind()
    insp = inspect(bind)
    return any(c["name"] == col for c in insp.get_columns(table))


def upgrade() -> None:
    line_cols = (
        ("dispatcher_name", sa.String(255)),
        ("branch_name", sa.String(255)),
        ("region_name", sa.String(255)),
        ("region_uid", sa.String(36)),
        ("balance_ownership", sa.String(255)),
        ("parent_object_ref", sa.String(255)),
        ("alcs_ref", sa.String(255)),
    )
    for col_name, col_type in line_cols:
        if not _col_exists("line", col_name):
            op.add_column("line", sa.Column(col_name, col_type, nullable=True))

    if not _col_exists("pole", "construction"):
        op.add_column("pole", sa.Column("construction", sa.String(255), nullable=True))
    if not _col_exists("pole", "rated_voltage"):
        op.add_column("pole", sa.Column("rated_voltage", sa.Float(), nullable=True))

    # Default region UID for existing lines.
    op.execute(
        "UPDATE line SET region_uid = 'c3d4e5f6-7890-1234-cdef-345678901234' WHERE region_uid IS NULL"
    )


def downgrade() -> None:
    for col in (
        "alcs_ref",
        "parent_object_ref",
        "balance_ownership",
        "region_uid",
        "region_name",
        "branch_name",
        "dispatcher_name",
    ):
        if _col_exists("line", col):
            op.drop_column("line", col)
    for col in ("rated_voltage", "construction"):
        if _col_exists("pole", col):
            op.drop_column("pole", col)
