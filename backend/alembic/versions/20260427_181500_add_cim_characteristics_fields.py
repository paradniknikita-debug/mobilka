"""add cim characteristics fields

Revision ID: 20260427_181500
Revises: 20260410_140000
Create Date: 2026-04-27 18:15:00
"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "20260427_181500"
down_revision = "20260410_140000"
branch_labels = None
depends_on = None


def _column_names(table_name: str) -> set[str]:
    bind = op.get_bind()
    insp = sa.inspect(bind)
    return {c["name"] for c in insp.get_columns(table_name)}


def upgrade() -> None:
    eq_cols = _column_names("equipment")
    if "rated_current" not in eq_cols:
        op.add_column("equipment", sa.Column("rated_current", sa.Float(), nullable=True))
    if "i_th" not in eq_cols:
        op.add_column("equipment", sa.Column("i_th", sa.Float(), nullable=True))
    if "ip_max" not in eq_cols:
        op.add_column("equipment", sa.Column("ip_max", sa.Float(), nullable=True))
    if "t_th" not in eq_cols:
        op.add_column("equipment", sa.Column("t_th", sa.Float(), nullable=True))
    if "normal_open" not in eq_cols:
        op.add_column("equipment", sa.Column("normal_open", sa.Boolean(), nullable=True))
    if "retained" not in eq_cols:
        op.add_column("equipment", sa.Column("retained", sa.Boolean(), nullable=True))

    seg_cols = _column_names("acline_segment")
    if "r0" not in seg_cols:
        op.add_column("acline_segment", sa.Column("r0", sa.Float(), nullable=True))
    if "x0" not in seg_cols:
        op.add_column("acline_segment", sa.Column("x0", sa.Float(), nullable=True))
    if "bch" not in seg_cols:
        op.add_column("acline_segment", sa.Column("bch", sa.Float(), nullable=True))
    if "b0ch" not in seg_cols:
        op.add_column("acline_segment", sa.Column("b0ch", sa.Float(), nullable=True))
    if "gch" not in seg_cols:
        op.add_column("acline_segment", sa.Column("gch", sa.Float(), nullable=True))
    if "g0ch" not in seg_cols:
        op.add_column("acline_segment", sa.Column("g0ch", sa.Float(), nullable=True))
    if "i_th" not in seg_cols:
        op.add_column("acline_segment", sa.Column("i_th", sa.Float(), nullable=True))
    if "t_th" not in seg_cols:
        op.add_column("acline_segment", sa.Column("t_th", sa.Float(), nullable=True))
    if "sections" not in seg_cols:
        op.add_column("acline_segment", sa.Column("sections", sa.Integer(), nullable=True))
    if "short_circuit_end_temperature" not in seg_cols:
        op.add_column("acline_segment", sa.Column("short_circuit_end_temperature", sa.Float(), nullable=True))
    if "is_jumper" not in seg_cols:
        op.add_column("acline_segment", sa.Column("is_jumper", sa.Boolean(), nullable=True))


def downgrade() -> None:
    seg_cols = _column_names("acline_segment")
    for col in [
        "is_jumper",
        "short_circuit_end_temperature",
        "sections",
        "t_th",
        "i_th",
        "g0ch",
        "gch",
        "b0ch",
        "bch",
        "x0",
        "r0",
    ]:
        if col in seg_cols:
            op.drop_column("acline_segment", col)

    eq_cols = _column_names("equipment")
    for col in ["retained", "normal_open", "t_th", "ip_max", "i_th", "rated_current"]:
        if col in eq_cols:
            op.drop_column("equipment", col)
