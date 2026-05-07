"""equipment: CIM-поля для разъединителя (description, nameplate, PSR subtype, установка)

Revision ID: 20260428_100000
Revises: 20260427_181500
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = "20260428_100000"
down_revision = "20260427_181500"
branch_labels = None
depends_on = None


def _col_exists(table: str, col: str) -> bool:
    bind = op.get_bind()
    insp = inspect(bind)
    return any(c["name"] == col for c in insp.get_columns(table))


def upgrade() -> None:
    if not _col_exists("equipment", "identified_object_description"):
        op.add_column(
            "equipment",
            sa.Column("identified_object_description", sa.String(255), nullable=True),
        )
    if not _col_exists("equipment", "nameplate"):
        op.add_column("equipment", sa.Column("nameplate", sa.String(255), nullable=True))
    if not _col_exists("equipment", "psr_subtype"):
        op.add_column("equipment", sa.Column("psr_subtype", sa.String(40), nullable=True))
    if not _col_exists("equipment", "installation_display_name"):
        op.add_column(
            "equipment",
            sa.Column("installation_display_name", sa.String(255), nullable=True),
        )


def downgrade() -> None:
    for col in (
        "installation_display_name",
        "psr_subtype",
        "nameplate",
        "identified_object_description",
    ):
        if _col_exists("equipment", col):
            op.drop_column("equipment", col)
