"""increase_span_number_length

Revision ID: 20241216_100000
Revises: 20241216_000000
Create Date: 2024-12-16 10:00:00.000000

Увеличение длины поля span_number с 20 до 100 символов для поддержки полных наименований пролётов
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

# revision identifiers, used by Alembic.
revision = '20241216_100000'
down_revision = '20241216_000000'
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    existing_tables = inspector.get_table_names()
    
    if 'spans' in existing_tables:
        existing_columns = [col['name'] for col in inspector.get_columns('spans')]
        
        if 'span_number' in existing_columns:
            # Увеличиваем длину поля span_number с 20 до 100
            op.alter_column('spans', 'span_number',
                          existing_type=sa.String(length=20),
                          type_=sa.String(length=100),
                          existing_nullable=False)
            print("✓ Увеличена длина поля span_number до 100 символов")


def downgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    existing_tables = inspector.get_table_names()
    
    if 'spans' in existing_tables:
        existing_columns = [col['name'] for col in inspector.get_columns('spans')]
        
        if 'span_number' in existing_columns:
            # Возвращаем длину обратно к 20 (но это может привести к обрезке данных!)
            op.alter_column('spans', 'span_number',
                          existing_type=sa.String(length=100),
                          type_=sa.String(length=20),
                          existing_nullable=False)
            print("⚠️  Длина поля span_number уменьшена до 20 символов (данные могут быть обрезаны!)")

