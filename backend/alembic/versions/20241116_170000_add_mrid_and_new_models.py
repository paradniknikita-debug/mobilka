"""add_mrid_and_new_models

Revision ID: 20241116_170000
Revises: 
Create Date: 2024-11-16 17:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '20241116_170000'
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Проверяем существование таблиц перед созданием
    from sqlalchemy import inspect
    conn = op.get_bind()
    inspector = inspect(conn)
    existing_tables = inspector.get_table_names()
    
    # Создание таблицы geographic_regions (если не существует)
    if 'geographic_regions' not in existing_tables:
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
    
    # Создание таблицы acline_segments (если не существует)
    if 'acline_segments' not in existing_tables:
        # Проверяем, существует ли таблица users для внешнего ключа
        users_exists = 'users' in existing_tables
        towers_exists = 'towers' in existing_tables
        
        # Создаем таблицу БЕЗ внешних ключей (добавим их позже, если таблицы существуют)
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
            sa.Column('created_by', sa.Integer(), nullable=not users_exists),  # NOT NULL только если users существует
            sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
            sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
            sa.PrimaryKeyConstraint('id')
        )
        
        # Добавляем внешние ключи отдельно, если таблицы существуют
        if towers_exists:
            op.create_foreign_key('fk_acline_segments_start_tower', 'acline_segments', 'towers', ['start_tower_id'], ['id'])
            op.create_foreign_key('fk_acline_segments_end_tower', 'acline_segments', 'towers', ['end_tower_id'], ['id'])
        
        if users_exists:
            op.create_foreign_key('fk_acline_segments_created_by', 'acline_segments', 'users', ['created_by'], ['id'])
        
        op.create_index(op.f('ix_acline_segments_code'), 'acline_segments', ['code'], unique=True)
        op.create_index(op.f('ix_acline_segments_id'), 'acline_segments', ['id'], unique=False)
        op.create_index(op.f('ix_acline_segments_mrid'), 'acline_segments', ['mrid'], unique=True)
    
    # Создание промежуточной таблицы line_segments (если не существует)
    if 'line_segments' not in existing_tables:
        # Проверяем, что обе таблицы существуют (или будут созданы)
        power_lines_exists = 'power_lines' in existing_tables
        acline_segments_will_exist = 'acline_segments' in existing_tables or 'acline_segments' not in existing_tables  # Будет создана выше
        
        if power_lines_exists:
            # Создаем таблицу БЕЗ внешних ключей, добавим их позже
            op.create_table(
                'line_segments',
                sa.Column('power_line_id', sa.Integer(), nullable=False),
                sa.Column('acline_segment_id', sa.Integer(), nullable=False),
                sa.PrimaryKeyConstraint('power_line_id', 'acline_segment_id')
            )
            # Добавляем внешние ключи отдельно
            op.create_foreign_key('fk_line_segments_power_line', 'line_segments', 'power_lines', ['power_line_id'], ['id'])
            # acline_segments будет создана выше, если её нет
            op.create_foreign_key('fk_line_segments_acline_segment', 'line_segments', 'acline_segments', ['acline_segment_id'], ['id'])
    
    # Проверяем существование колонок перед добавлением
    def column_exists(table_name, column_name):
        if table_name not in existing_tables:
            return False
        columns = [col['name'] for col in inspector.get_columns(table_name)]
        return column_name in columns
    
    # Добавление mrid во все существующие таблицы
    # PowerLine
    if not column_exists('power_lines', 'mrid'):
        op.add_column('power_lines', sa.Column('mrid', sa.String(length=36), nullable=False, server_default=''))
        op.create_index(op.f('ix_power_lines_mrid'), 'power_lines', ['mrid'], unique=True)
    if not column_exists('power_lines', 'region_id'):
        op.add_column('power_lines', sa.Column('region_id', sa.Integer(), nullable=True))
        op.create_foreign_key('fk_power_lines_region', 'power_lines', 'geographic_regions', ['region_id'], ['id'])
    
    # Tower
    if not column_exists('towers', 'mrid'):
        op.add_column('towers', sa.Column('mrid', sa.String(length=36), nullable=False, server_default=''))
        op.create_index(op.f('ix_towers_mrid'), 'towers', ['mrid'], unique=True)
    if not column_exists('towers', 'segment_id'):
        op.add_column('towers', sa.Column('segment_id', sa.Integer(), nullable=True))
        op.create_foreign_key('fk_towers_segment', 'towers', 'acline_segments', ['segment_id'], ['id'])
    
    # Substation
    if not column_exists('substations', 'mrid'):
        op.add_column('substations', sa.Column('mrid', sa.String(length=36), nullable=False, server_default=''))
        op.create_index(op.f('ix_substations_mrid'), 'substations', ['mrid'], unique=True)
    if not column_exists('substations', 'region_id'):
        op.add_column('substations', sa.Column('region_id', sa.Integer(), nullable=True))
        op.create_foreign_key('fk_substations_region', 'substations', 'geographic_regions', ['region_id'], ['id'])
    
    # Branch
    if not column_exists('branches', 'mrid'):
        op.add_column('branches', sa.Column('mrid', sa.String(length=36), nullable=False, server_default=''))
        op.create_index(op.f('ix_branches_mrid'), 'branches', ['mrid'], unique=True)
    
    # Span
    if not column_exists('spans', 'mrid'):
        op.add_column('spans', sa.Column('mrid', sa.String(length=36), nullable=False, server_default=''))
        op.create_index(op.f('ix_spans_mrid'), 'spans', ['mrid'], unique=True)
    
    # Tap
    if not column_exists('taps', 'mrid'):
        op.add_column('taps', sa.Column('mrid', sa.String(length=36), nullable=False, server_default=''))
        op.create_index(op.f('ix_taps_mrid'), 'taps', ['mrid'], unique=True)
    
    # Equipment
    if not column_exists('equipment', 'mrid'):
        op.add_column('equipment', sa.Column('mrid', sa.String(length=36), nullable=False, server_default=''))
        op.create_index(op.f('ix_equipment_mrid'), 'equipment', ['mrid'], unique=True)
    
    # Connection
    if not column_exists('connections', 'mrid'):
        op.add_column('connections', sa.Column('mrid', sa.String(length=36), nullable=False, server_default=''))
        op.create_index(op.f('ix_connections_mrid'), 'connections', ['mrid'], unique=True)
    
    # Генерируем UUID для существующих записей (если есть)
    # Используем PostgreSQL функцию gen_random_uuid()
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
    # Проверяем существование таблиц и ограничений перед удалением
    from sqlalchemy import inspect
    conn = op.get_bind()
    inspector = inspect(conn)
    existing_tables = inspector.get_table_names()
    
    # Функция для проверки существования ограничения
    def constraint_exists(table_name, constraint_name):
        if table_name not in existing_tables:
            return False
        try:
            constraints = inspector.get_foreign_keys(table_name)
            return any(fk['name'] == constraint_name for fk in constraints)
        except:
            return False
    
    # Функция для проверки существования колонки
    def column_exists(table_name, column_name):
        if table_name not in existing_tables:
            return False
        try:
            columns = [col['name'] for col in inspector.get_columns(table_name)]
            return column_name in columns
        except:
            return False
    
    # Функция для проверки существования индекса
    def index_exists(table_name, index_name):
        if table_name not in existing_tables:
            return False
        try:
            indexes = [idx['name'] for idx in inspector.get_indexes(table_name)]
            return index_name in indexes
        except:
            return False
    
    # Удаление индексов и колонок mrid (с проверками)
    if column_exists('connections', 'mrid'):
        if index_exists('connections', 'ix_connections_mrid'):
            op.drop_index(op.f('ix_connections_mrid'), table_name='connections')
        op.drop_column('connections', 'mrid')
    
    if column_exists('equipment', 'mrid'):
        if index_exists('equipment', 'ix_equipment_mrid'):
            op.drop_index(op.f('ix_equipment_mrid'), table_name='equipment')
        op.drop_column('equipment', 'mrid')
    
    if column_exists('taps', 'mrid'):
        if index_exists('taps', 'ix_taps_mrid'):
            op.drop_index(op.f('ix_taps_mrid'), table_name='taps')
        op.drop_column('taps', 'mrid')
    
    if column_exists('spans', 'mrid'):
        if index_exists('spans', 'ix_spans_mrid'):
            op.drop_index(op.f('ix_spans_mrid'), table_name='spans')
        op.drop_column('spans', 'mrid')
    
    if column_exists('branches', 'mrid'):
        if index_exists('branches', 'ix_branches_mrid'):
            op.drop_index(op.f('ix_branches_mrid'), table_name='branches')
        op.drop_column('branches', 'mrid')
    
    # Substation
    if column_exists('substations', 'region_id'):
        if constraint_exists('substations', 'fk_substations_region'):
            op.drop_constraint('fk_substations_region', 'substations', type_='foreignkey')
        op.drop_column('substations', 'region_id')
    if column_exists('substations', 'mrid'):
        if index_exists('substations', 'ix_substations_mrid'):
            op.drop_index(op.f('ix_substations_mrid'), table_name='substations')
        op.drop_column('substations', 'mrid')
    
    # Tower
    if column_exists('towers', 'segment_id'):
        if constraint_exists('towers', 'fk_towers_segment'):
            op.drop_constraint('fk_towers_segment', 'towers', type_='foreignkey')
        op.drop_column('towers', 'segment_id')
    if column_exists('towers', 'mrid'):
        if index_exists('towers', 'ix_towers_mrid'):
            op.drop_index(op.f('ix_towers_mrid'), table_name='towers')
        op.drop_column('towers', 'mrid')
    
    # PowerLine
    if column_exists('power_lines', 'region_id'):
        if constraint_exists('power_lines', 'fk_power_lines_region'):
            op.drop_constraint('fk_power_lines_region', 'power_lines', type_='foreignkey')
        op.drop_column('power_lines', 'region_id')
    if column_exists('power_lines', 'mrid'):
        if index_exists('power_lines', 'ix_power_lines_mrid'):
            op.drop_index(op.f('ix_power_lines_mrid'), table_name='power_lines')
        op.drop_column('power_lines', 'mrid')
    
    # Удаление промежуточной таблицы
    if 'line_segments' in existing_tables:
        op.drop_table('line_segments')
    
    # Удаление таблиц
    if 'acline_segments' in existing_tables:
        if index_exists('acline_segments', 'ix_acline_segments_mrid'):
            op.drop_index(op.f('ix_acline_segments_mrid'), table_name='acline_segments')
        if index_exists('acline_segments', 'ix_acline_segments_id'):
            op.drop_index(op.f('ix_acline_segments_id'), table_name='acline_segments')
        if index_exists('acline_segments', 'ix_acline_segments_code'):
            op.drop_index(op.f('ix_acline_segments_code'), table_name='acline_segments')
        op.drop_table('acline_segments')
    
    if 'geographic_regions' in existing_tables:
        if index_exists('geographic_regions', 'ix_geographic_regions_mrid'):
            op.drop_index(op.f('ix_geographic_regions_mrid'), table_name='geographic_regions')
        if index_exists('geographic_regions', 'ix_geographic_regions_id'):
            op.drop_index(op.f('ix_geographic_regions_id'), table_name='geographic_regions')
        if index_exists('geographic_regions', 'ix_geographic_regions_code'):
            op.drop_index(op.f('ix_geographic_regions_code'), table_name='geographic_regions')
        op.drop_table('geographic_regions')

