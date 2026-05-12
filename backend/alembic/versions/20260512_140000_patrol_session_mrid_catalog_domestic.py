"""patrol_sessions.mrid; удаление марок каталога не BY/RU.

Revision ID: 20260512_140000
Revises: 20260512_120000
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = "20260512_140000"
down_revision = "20260512_120000"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    insp = inspect(bind)

    if insp.has_table("patrol_sessions"):
        cols = {c["name"] for c in insp.get_columns("patrol_sessions")}
        if "mrid" not in cols:
            op.add_column("patrol_sessions", sa.Column("mrid", sa.String(length=36), nullable=True))
            op.execute(
                sa.text("UPDATE patrol_sessions SET mrid = gen_random_uuid()::text WHERE mrid IS NULL")
            )
            op.alter_column("patrol_sessions", "mrid", nullable=False)
            op.create_index("ix_patrol_sessions_mrid", "patrol_sessions", ["mrid"], unique=True)

    if insp.has_table("equipment_catalog"):
        op.execute(
            sa.text(
                """
                UPDATE equipment
                SET catalog_item_id = NULL
                WHERE catalog_item_id IN (
                    SELECT id FROM equipment_catalog
                    WHERE country IS NOT NULL
                    AND upper(trim(country)) NOT IN ('BY', 'RU')
                )
                """
            )
        )
        op.execute(
            sa.text(
                """
                DELETE FROM equipment_catalog
                WHERE country IS NOT NULL
                AND upper(trim(country)) NOT IN ('BY', 'RU')
                """
            )
        )


def downgrade() -> None:
    bind = op.get_bind()
    insp = inspect(bind)
    if insp.has_table("patrol_sessions"):
        cols = {c["name"] for c in insp.get_columns("patrol_sessions")}
        if "mrid" in cols:
            op.drop_index("ix_patrol_sessions_mrid", table_name="patrol_sessions")
            op.drop_column("patrol_sessions", "mrid")
