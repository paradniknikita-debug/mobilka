"""add sync_client_mapping table for resolving client pole_id in later sync batches

Revision ID: 20250210_000000
Revises: 20250221_900000
Create Date: 2025-02-10

Маппинг (user_id, entity_type, client_id) -> server_id для опор и ЛЭП,
чтобы оборудование с pole_id=-34 могло быть записано, если опора уже была
создана в предыдущем пакете синхронизации.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import text
from sqlalchemy.exc import ProgrammingError


revision = "20250210_000000"
down_revision = "20250221_900000"
branch_labels = None
depends_on = None


def _table_exists(conn, table_name):
    r = conn.execute(text("""
        SELECT EXISTS (
            SELECT 1 FROM information_schema.tables
            WHERE table_schema = 'public' AND table_name = :t
        )
    """), {"t": table_name})
    return r.scalar()


def upgrade():
    conn = op.get_bind()
    if _table_exists(conn, "sync_client_mapping"):
        return
    try:
        op.create_table(
            "sync_client_mapping",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column("user_id", sa.Integer(), nullable=False),
            sa.Column("entity_type", sa.String(32), nullable=False),
            sa.Column("client_id", sa.Integer(), nullable=False),
            sa.Column("server_id", sa.Integer(), nullable=False),
        )
    except ProgrammingError as e:
        if "already exists" not in str(e.orig):
            raise
        return
    try:
        op.create_index("ix_sync_client_mapping_user_id", "sync_client_mapping", ["user_id"])
    except ProgrammingError as e:
        if "already exists" not in str(e.orig):
            raise
    try:
        op.create_unique_constraint(
            "uq_sync_client_mapping_user_entity_client",
            "sync_client_mapping",
            ["user_id", "entity_type", "client_id"],
        )
    except ProgrammingError as e:
        if "already exists" not in str(e.orig):
            raise


def downgrade():
    op.drop_table("sync_client_mapping")
