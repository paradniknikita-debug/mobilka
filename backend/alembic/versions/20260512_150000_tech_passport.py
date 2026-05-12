"""Таблица tech_passport для сохранённых технических паспортов.

Revision ID: 20260512_150000
Revises: 20260512_140000
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "20260512_150000"
down_revision = "20260512_140000"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "tech_passport",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("mrid", sa.String(length=36), nullable=False),
        sa.Column("title", sa.String(length=500), nullable=False),
        sa.Column("object_type", sa.String(length=40), nullable=False),
        sa.Column("object_mrid", sa.String(length=36), nullable=False),
        sa.Column("object_id", sa.Integer(), nullable=True),
        sa.Column("snapshot_json", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("manual_sections", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("stp_reference", sa.String(length=500), nullable=True),
        sa.Column("created_by", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["created_by"], ["users.id"], name=op.f("fk_tech_passport_created_by_users")),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_tech_passport")),
    )
    op.create_index(op.f("ix_tech_passport_id"), "tech_passport", ["id"], unique=False)
    op.create_index(op.f("ix_tech_passport_mrid"), "tech_passport", ["mrid"], unique=True)
    op.create_index(op.f("ix_tech_passport_object_type"), "tech_passport", ["object_type"], unique=False)
    op.create_index(op.f("ix_tech_passport_object_mrid"), "tech_passport", ["object_mrid"], unique=False)
    op.create_index(op.f("ix_tech_passport_object_id"), "tech_passport", ["object_id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_tech_passport_object_id"), table_name="tech_passport")
    op.drop_index(op.f("ix_tech_passport_object_mrid"), table_name="tech_passport")
    op.drop_index(op.f("ix_tech_passport_object_type"), table_name="tech_passport")
    op.drop_index(op.f("ix_tech_passport_mrid"), table_name="tech_passport")
    op.drop_index(op.f("ix_tech_passport_id"), table_name="tech_passport")
    op.drop_table("tech_passport")
