"""pole structural_defect and structural_defect_criticality

Revision ID: 20260410_140000
Revises: 20260409_120000
Create Date: 2026-04-10

Дефект конструкции опоры (отдельно от примечаний и дефектов оборудования).
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = "20260410_140000"
down_revision = "20260409_120000"
branch_labels = None
depends_on = None


def _col_exists(conn, table_name: str, column_name: str) -> bool:
    inspector = inspect(conn)
    if table_name not in inspector.get_table_names():
        return False
    return column_name in [c["name"] for c in inspector.get_columns(table_name)]


def upgrade() -> None:
    conn = op.get_bind()
    if "pole" not in inspect(conn).get_table_names():
        return
    if not _col_exists(conn, "pole", "structural_defect"):
        op.add_column("pole", sa.Column("structural_defect", sa.Text(), nullable=True))
    if not _col_exists(conn, "pole", "structural_defect_criticality"):
        op.add_column(
            "pole",
            sa.Column("structural_defect_criticality", sa.String(20), nullable=True),
        )


def downgrade() -> None:
    conn = op.get_bind()
    if "pole" not in inspect(conn).get_table_names():
        return
    if _col_exists(conn, "pole", "structural_defect_criticality"):
        op.drop_column("pole", "structural_defect_criticality")
    if _col_exists(conn, "pole", "structural_defect"):
        op.drop_column("pole", "structural_defect")
