"""
pole_card_comment_attachment_and_equipment_defect_criticality

Revision ID: 20260308_000000
Revises: 20260226_300000
Create Date: 2026-03-08

Добавляет в опору поля карточки (как во Flutter): комментарий и вложения.
Добавляет в оборудование поля дефект и критичность.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = '20260308_000000'
down_revision = '20260226_400000'
branch_labels = None
depends_on = None


def _col_exists(conn, table_name: str, column_name: str) -> bool:
    inspector = inspect(conn)
    if table_name not in inspector.get_table_names():
        return False
    return column_name in [c["name"] for c in inspector.get_columns(table_name)]


def _table_exists(conn, name: str) -> bool:
    return name in inspect(conn).get_table_names()


def upgrade() -> None:
    conn = op.get_bind()
    if _table_exists(conn, 'pole'):
        if not _col_exists(conn, 'pole', 'card_comment'):
            op.add_column('pole', sa.Column('card_comment', sa.Text(), nullable=True))
        if not _col_exists(conn, 'pole', 'card_comment_attachment'):
            op.add_column('pole', sa.Column('card_comment_attachment', sa.Text(), nullable=True))
    if _table_exists(conn, 'equipment'):
        if not _col_exists(conn, 'equipment', 'defect'):
            op.add_column('equipment', sa.Column('defect', sa.Text(), nullable=True))
        if not _col_exists(conn, 'equipment', 'criticality'):
            op.add_column('equipment', sa.Column('criticality', sa.String(20), nullable=True))


def downgrade() -> None:
    conn = op.get_bind()
    if _table_exists(conn, 'pole'):
        if _col_exists(conn, 'pole', 'card_comment_attachment'):
            op.drop_column('pole', 'card_comment_attachment')
        if _col_exists(conn, 'pole', 'card_comment'):
            op.drop_column('pole', 'card_comment')
    if _table_exists(conn, 'equipment'):
        if _col_exists(conn, 'equipment', 'criticality'):
            op.drop_column('equipment', 'criticality')
        if _col_exists(conn, 'equipment', 'defect'):
            op.drop_column('equipment', 'defect')
