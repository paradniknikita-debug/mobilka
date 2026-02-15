"""Add CIM base fields from Mixins

Revision ID: 20250203_000000
Revises: 20250202_000000
Create Date: 2025-02-03 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '20250203_000000'
down_revision = '20250202_000000'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Добавляем поля из PowerSystemResourceMixin
    # alias_name и parent_id для power_lines
    op.add_column('power_lines', sa.Column('alias_name', sa.String(length=100), nullable=True))
    op.add_column('power_lines', sa.Column('parent_id', sa.Integer(), nullable=True))
    
    # alias_name и parent_id для substations
    op.add_column('substations', sa.Column('alias_name', sa.String(length=100), nullable=True))
    op.add_column('substations', sa.Column('parent_id', sa.Integer(), nullable=True))
    
    # alias_name и parent_id для acline_segments
    op.add_column('acline_segments', sa.Column('alias_name', sa.String(length=100), nullable=True))
    op.add_column('acline_segments', sa.Column('parent_id', sa.Integer(), nullable=True))
    
    # Добавляем поля из EquipmentMixin
    # normally_in_service для acline_segments
    op.add_column('acline_segments', sa.Column('normally_in_service', sa.Boolean(), nullable=True, server_default=sa.text('true')))
    
    # Добавляем поля из ConductingEquipmentMixin
    # phases для acline_segments
    op.add_column('acline_segments', sa.Column('phases', sa.String(length=10), nullable=True))
    
    # Добавляем substation_id для connectivity_nodes (для ConnectivityNode в подстанциях)
    op.add_column('connectivity_nodes', sa.Column('substation_id', sa.Integer(), nullable=True))
    op.create_foreign_key(
        'fk_connectivity_nodes_substation_id',
        'connectivity_nodes',
        'substations',
        ['substation_id'],
        ['id'],
        ondelete='SET NULL'
    )
    op.create_index(op.f('ix_connectivity_nodes_substation_id'), 'connectivity_nodes', ['substation_id'], unique=False)


def downgrade() -> None:
    # Удаляем индексы и внешние ключи
    from sqlalchemy import inspect
    conn = op.get_bind()
    inspector = inspect(conn)
    
    # Проверяем существование индекса перед удалением
    indexes = [idx['name'] for idx in inspector.get_indexes('connectivity_nodes')]
    if 'ix_connectivity_nodes_substation_id' in indexes:
        op.drop_index(op.f('ix_connectivity_nodes_substation_id'), table_name='connectivity_nodes')
    
    # Проверяем существование foreign key перед удалением
    fks = [fk['name'] for fk in inspector.get_foreign_keys('connectivity_nodes')]
    if 'fk_connectivity_nodes_substation_id' in fks:
        op.drop_constraint('fk_connectivity_nodes_substation_id', 'connectivity_nodes', type_='foreignkey')
    
    # Удаляем поля с проверкой существования
    for table_name in ['connectivity_nodes', 'acline_segments', 'substations', 'power_lines']:
        existing_columns = [col['name'] for col in inspector.get_columns(table_name)]
        
        if table_name == 'connectivity_nodes' and 'substation_id' in existing_columns:
            op.drop_column(table_name, 'substation_id')
        elif table_name == 'acline_segments':
            if 'phases' in existing_columns:
                op.drop_column(table_name, 'phases')
            if 'normally_in_service' in existing_columns:
                op.drop_column(table_name, 'normally_in_service')
            if 'parent_id' in existing_columns:
                op.drop_column(table_name, 'parent_id')
            if 'alias_name' in existing_columns:
                op.drop_column(table_name, 'alias_name')
        elif table_name in ['substations', 'power_lines']:
            if 'parent_id' in existing_columns:
                op.drop_column(table_name, 'parent_id')
            if 'alias_name' in existing_columns:
                op.drop_column(table_name, 'alias_name')

