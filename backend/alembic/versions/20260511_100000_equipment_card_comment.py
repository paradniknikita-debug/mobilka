"""equipment: card_comment и card_comment_attachment (карточка как у опоры)

Revision ID: 20260511_100000
Revises: 20260428_100000
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = "20260511_100000"
down_revision = "20260428_100000"
branch_labels = None
depends_on = None


def _col_exists(table: str, col: str) -> bool:
    bind = op.get_bind()
    insp = inspect(bind)
    return any(c["name"] == col for c in insp.get_columns(table))


def upgrade() -> None:
    if not _col_exists("equipment", "card_comment"):
        op.add_column("equipment", sa.Column("card_comment", sa.Text(), nullable=True))
    if not _col_exists("equipment", "card_comment_attachment"):
        op.add_column("equipment", sa.Column("card_comment_attachment", sa.Text(), nullable=True))


def downgrade() -> None:
    if _col_exists("equipment", "card_comment_attachment"):
        op.drop_column("equipment", "card_comment_attachment")
    if _col_exists("equipment", "card_comment"):
        op.drop_column("equipment", "card_comment")
