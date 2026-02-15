"""rename_code_to_dispatcher_name

Revision ID: 20250131_000000
Revises: 20250120_000000
Create Date: 2025-01-31 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '20250131_000000'
down_revision = '20250120_000000'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Переименовываем колонку code в dispatcher_name (с проверкой существования)
    from sqlalchemy import inspect
    conn = op.get_bind()
    inspector = inspect(conn)
    existing_columns = [col['name'] for col in inspector.get_columns('substations')]
    
    if 'code' in existing_columns and 'dispatcher_name' not in existing_columns:
        op.alter_column('substations', 'code', new_column_name='dispatcher_name', existing_type=sa.String(length=20), existing_nullable=False)
    # Увеличиваем длину поля для диспетчерского наименования
    op.alter_column('substations', 'dispatcher_name', type_=sa.String(length=100), existing_nullable=False)


def downgrade() -> None:
    # Возвращаем обратно
    op.alter_column('substations', 'dispatcher_name', new_column_name='code', existing_type=sa.String(length=100), existing_nullable=False)
    op.alter_column('substations', 'code', type_=sa.String(length=20), existing_nullable=False)

