"""add_pole_sequence_number

Revision ID: 20241215_100000
Revises: 20241215_000000
Create Date: 2024-12-15 10:00:00.000000

Добавление поля sequence_number в таблицу poles для контроля последовательности опор
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

# revision identifiers, used by Alembic.
revision = '20241215_100000'
down_revision = '20241215_000000'
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    existing_tables = inspector.get_table_names()
    
    if 'poles' in existing_tables:
        existing_columns = [col['name'] for col in inspector.get_columns('poles')]
        
        if 'sequence_number' not in existing_columns:
            op.add_column('poles', sa.Column('sequence_number', sa.Integer(), nullable=True))
            op.create_index('ix_poles_sequence_number', 'poles', ['sequence_number'])
            print("Добавлена колонка 'sequence_number' в 'poles'")


def downgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    existing_tables = inspector.get_table_names()
    
    if 'poles' in existing_tables:
        existing_columns = [col['name'] for col in inspector.get_columns('poles')]
        
        if 'sequence_number' in existing_columns:
            op.drop_index('ix_poles_sequence_number', table_name='poles')
            op.drop_column('poles', 'sequence_number')
            print("Удалена колонка 'sequence_number' из 'poles'")

