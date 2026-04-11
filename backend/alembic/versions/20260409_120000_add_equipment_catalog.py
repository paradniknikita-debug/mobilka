"""add equipment catalog and equipment.catalog_item_id

Revision ID: 20260409_120000
Revises: 20260308_100000
Create Date: 2026-04-09 12:00:00
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


# revision identifiers, used by Alembic.
revision = "20260409_120000"
down_revision = "20260308_100000"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    insp = inspect(bind)

    if not insp.has_table("equipment_catalog"):
        op.create_table(
            "equipment_catalog",
            sa.Column("id", sa.Integer(), primary_key=True, nullable=False),
            sa.Column("type_code", sa.String(length=50), nullable=False),
            sa.Column("brand", sa.String(length=100), nullable=False),
            sa.Column("model", sa.String(length=120), nullable=False),
            sa.Column("full_name", sa.String(length=255), nullable=True),
            sa.Column("voltage_kv", sa.Float(), nullable=True),
            sa.Column("current_a", sa.Float(), nullable=True),
            sa.Column("manufacturer", sa.String(length=120), nullable=True),
            sa.Column("country", sa.String(length=80), nullable=True),
            sa.Column("description", sa.Text(), nullable=True),
            sa.Column("attrs_json", sa.Text(), nullable=True),
            sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
            sa.Column("created_by", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        )

    existing_cat_ix = {ix["name"] for ix in insp.get_indexes("equipment_catalog")}
    for name, cols in (
        ("ix_equipment_catalog_id", ["id"]),
        ("ix_equipment_catalog_type_code", ["type_code"]),
        ("ix_equipment_catalog_brand", ["brand"]),
        ("ix_equipment_catalog_model", ["model"]),
    ):
        if name not in existing_cat_ix:
            op.create_index(name, "equipment_catalog", cols)
            existing_cat_ix.add(name)

    eq_cols = {c["name"] for c in insp.get_columns("equipment")}
    if "catalog_item_id" not in eq_cols:
        op.add_column("equipment", sa.Column("catalog_item_id", sa.Integer(), nullable=True))
    existing_eq_ix = {ix["name"] for ix in insp.get_indexes("equipment")}
    if "ix_equipment_catalog_item_id" not in existing_eq_ix:
        op.create_index("ix_equipment_catalog_item_id", "equipment", ["catalog_item_id"])
    fk_names = {c["name"] for c in insp.get_foreign_keys("equipment")}
    if "fk_equipment_catalog_item_id" not in fk_names:
        op.create_foreign_key(
            "fk_equipment_catalog_item_id",
            "equipment",
            "equipment_catalog",
            ["catalog_item_id"],
            ["id"],
        )


def downgrade() -> None:
    op.drop_constraint("fk_equipment_catalog_item_id", "equipment", type_="foreignkey")
    op.drop_index("ix_equipment_catalog_item_id", table_name="equipment")
    op.drop_column("equipment", "catalog_item_id")

    op.drop_index("ix_equipment_catalog_model", table_name="equipment_catalog")
    op.drop_index("ix_equipment_catalog_brand", table_name="equipment_catalog")
    op.drop_index("ix_equipment_catalog_type_code", table_name="equipment_catalog")
    op.drop_index("ix_equipment_catalog_id", table_name="equipment_catalog")
    op.drop_table("equipment_catalog")

