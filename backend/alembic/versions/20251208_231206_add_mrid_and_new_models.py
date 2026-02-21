"""add_mrid_and_new_models

Revision ID: 20251208_231206
Revises: 20250221_000000
Create Date: 2025-12-08T23:12:06.693889

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '20251208_231206'
down_revision = '20250221_000000'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Создание таблицы geographic_regions
    op.create_table(
        'geographic_regions',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('mrid', sa.String(length=36), nullable=False),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('code', sa.String(length=20), nullable=False),
        sa.Column('region_type', sa.String(length=50), nullable=False),
        sa.Column('level', sa.Integer(), nullable=False),
        sa.Column('parent_id', sa.Integer(), nullable=True),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['parent_id'], ['geographic_regions.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_geographic_regions_code'), 'geographic_regions', ['code'], unique=True)
    op.create_index(op.f('ix_geographic_regions_id'), 'geographic_regions', ['id'], unique=False)
    op.create_index(op.f('ix_geographic_regions_mrid'), 'geographic_regions', ['mrid'], unique=True)
    
    # Создание таблицы acline_segments
    op.create_table(
        'acline_segments',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('mrid', sa.String(length=36), nullable=False),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('code', sa.String(length=20), nullable=False),
        sa.Column('voltage_level', sa.Float(), nullable=False),
        sa.Column('length', sa.Float(), nullable=False),
        sa.Column('conductor_type', sa.String(length=50), nullable=True),
        sa.Column('conductor_material', sa.String(length=50), nullable=True),
        sa.Column('conductor_section', sa.String(length=20), nullable=True),
        sa.Column('start_tower_id', sa.Integer(), nullable=True),
        sa.Column('end_tower_id', sa.Integer(), nullable=True),
        sa.Column('r', sa.Float(), nullable=True),
        sa.Column('x', sa.Float(), nullable=True),
        sa.Column('b', sa.Float(), nullable=True),
        sa.Column('g', sa.Float(), nullable=True),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('created_by', sa.Integer(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['created_by'], ['users.id'], ),
        sa.ForeignKeyConstraint(['end_tower_id'], ['towers.id'], ),
        sa.ForeignKeyConstraint(['start_tower_id'], ['towers.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_acline_segments_code'), 'acline_segments', ['code'], unique=True)
    op.create_index(op.f('ix_acline_segments_id'), 'acline_segments', ['id'], unique=False)
    op.create_index(op.f('ix_acline_segments_mrid'), 'acline_segments', ['mrid'], unique=True)
    
    # Создание промежуточной таблицы line_segments
    op.create_table(
        'line_segments',
        sa.Column('power_line_id', sa.Integer(), nullable=False),
        sa.Column('acline_segment_id', sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(['acline_segment_id'], ['acline_segments.id'], ),
        sa.ForeignKeyConstraint(['power_line_id'], ['power_lines.id'], ),
        sa.PrimaryKeyConstraint('power_line_id', 'acline_segment_id')
    )
    
    # Добавление mrid во все существующие таблицы
    # PowerLine
    op.add_column('power_lines', sa.Column('mrid', sa.String(length=36), nullable=False, server_default=''))
    op.create_index(op.f('ix_power_lines_mrid'), 'power_lines', ['mrid'], unique=True)
    op.add_column('power_lines', sa.Column('region_id', sa.Integer(), nullable=True))
    op.create_foreign_key('fk_power_lines_region', 'power_lines', 'geographic_regions', ['region_id'], ['id'])
    
    # Tower
    op.add_column('towers', sa.Column('mrid', sa.String(length=36), nullable=False, server_default=''))
    op.create_index(op.f('ix_towers_mrid'), 'towers', ['mrid'], unique=True)
    op.add_column('towers', sa.Column('segment_id', sa.Integer(), nullable=True))
    op.create_foreign_key('fk_towers_segment', 'towers', 'acline_segments', ['segment_id'], ['id'])
    
    # Substation
    op.add_column('substations', sa.Column('mrid', sa.String(length=36), nullable=False, server_default=''))
    op.create_index(op.f('ix_substations_mrid'), 'substations', ['mrid'], unique=True)
    op.add_column('substations', sa.Column('region_id', sa.Integer(), nullable=True))
    op.create_foreign_key('fk_substations_region', 'substations', 'geographic_regions', ['region_id'], ['id'])
    
    # Branch
    op.add_column('branches', sa.Column('mrid', sa.String(length=36), nullable=False, server_default=''))
    op.create_index(op.f('ix_branches_mrid'), 'branches', ['mrid'], unique=True)
    
    # Span
    op.add_column('spans', sa.Column('mrid', sa.String(length=36), nullable=False, server_default=''))
    op.create_index(op.f('ix_spans_mrid'), 'spans', ['mrid'], unique=True)
    
    # Tap
    op.add_column('taps', sa.Column('mrid', sa.String(length=36), nullable=False, server_default=''))
    op.create_index(op.f('ix_taps_mrid'), 'taps', ['mrid'], unique=True)
    
    # Equipment
    op.add_column('equipment', sa.Column('mrid', sa.String(length=36), nullable=False, server_default=''))
    op.create_index(op.f('ix_equipment_mrid'), 'equipment', ['mrid'], unique=True)
    
    # Connection
    op.add_column('connections', sa.Column('mrid', sa.String(length=36), nullable=False, server_default=''))
    op.create_index(op.f('ix_connections_mrid'), 'connections', ['mrid'], unique=True)
    
    # Генерируем UUID для существующих записей (если есть)
    # Это нужно сделать через SQL, так как Python функция не доступна в SQL
    op.execute("""
        UPDATE power_lines SET mrid = gen_random_uuid()::text WHERE mrid = '';
        UPDATE towers SET mrid = gen_random_uuid()::text WHERE mrid = '';
        UPDATE substations SET mrid = gen_random_uuid()::text WHERE mrid = '';
        UPDATE branches SET mrid = gen_random_uuid()::text WHERE mrid = '';
        UPDATE spans SET mrid = gen_random_uuid()::text WHERE mrid = '';
        UPDATE taps SET mrid = gen_random_uuid()::text WHERE mrid = '';
        UPDATE equipment SET mrid = gen_random_uuid()::text WHERE mrid = '';
        UPDATE connections SET mrid = gen_random_uuid()::text WHERE mrid = '';
    """)


def downgrade() -> None:
    # Удаление индексов и колонок mrid
    op.drop_index(op.f('ix_connections_mrid'), table_name='connections')
    op.drop_column('connections', 'mrid')
    
    op.drop_index(op.f('ix_equipment_mrid'), table_name='equipment')
    op.drop_column('equipment', 'mrid')
    
    op.drop_index(op.f('ix_taps_mrid'), table_name='taps')
    op.drop_column('taps', 'mrid')
    
    op.drop_index(op.f('ix_spans_mrid'), table_name='spans')
    op.drop_column('spans', 'mrid')
    
    op.drop_index(op.f('ix_branches_mrid'), table_name='branches')
    op.drop_column('branches', 'mrid')
    
    op.drop_constraint('fk_substations_region', 'substations', type_='foreignkey')
    op.drop_column('substations', 'region_id')
    op.drop_index(op.f('ix_substations_mrid'), table_name='substations')
    op.drop_column('substations', 'mrid')
    
    op.drop_constraint('fk_towers_segment', 'towers', type_='foreignkey')
    op.drop_column('towers', 'segment_id')
    op.drop_index(op.f('ix_towers_mrid'), table_name='towers')
    op.drop_column('towers', 'mrid')
    
    op.drop_constraint('fk_power_lines_region', 'power_lines', type_='foreignkey')
    op.drop_column('power_lines', 'region_id')
    op.drop_index(op.f('ix_power_lines_mrid'), table_name='power_lines')
    op.drop_column('power_lines', 'mrid')
    
    # Удаление промежуточной таблицы
    op.drop_table('line_segments')
    
    # Удаление таблиц
    op.drop_index(op.f('ix_acline_segments_mrid'), table_name='acline_segments')
    op.drop_index(op.f('ix_acline_segments_id'), table_name='acline_segments')
    op.drop_index(op.f('ix_acline_segments_code'), table_name='acline_segments')
    op.drop_table('acline_segments')
    
    op.drop_index(op.f('ix_geographic_regions_mrid'), table_name='geographic_regions')
    op.drop_index(op.f('ix_geographic_regions_id'), table_name='geographic_regions')
    op.drop_index(op.f('ix_geographic_regions_code'), table_name='geographic_regions')
    op.drop_table('geographic_regions')
