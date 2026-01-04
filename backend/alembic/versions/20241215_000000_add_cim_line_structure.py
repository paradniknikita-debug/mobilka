"""add_cim_line_structure

Revision ID: 20241215_000000
Revises: 20241201_000000
Create Date: 2024-12-15 00:00:00.000000

Добавление CIM-совместимой структуры для линий электропередачи:
- ConnectivityNode (узлы соединения - опоры)
- Terminal (терминалы подключения)
- LineSection (секции линии - группа пролётов с одинаковыми параметрами)
- Обновление AClineSegment для поддержки отпаек
- Обновление Span для связи с LineSection
- Обновление Pole для связи с ConnectivityNode
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

# revision identifiers, used by Alembic.
revision = '20241215_000000'
down_revision = '20241201_000000'
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    existing_tables = inspector.get_table_names()
    
    # 1. Создание таблицы connectivity_nodes
    if 'connectivity_nodes' not in existing_tables:
        op.create_table(
            'connectivity_nodes',
            sa.Column('id', sa.Integer(), nullable=False),
            sa.Column('mrid', sa.String(length=36), nullable=False),
            sa.Column('name', sa.String(length=100), nullable=False),
            sa.Column('pole_id', sa.Integer(), nullable=False),
            sa.Column('latitude', sa.Float(), nullable=False),
            sa.Column('longitude', sa.Float(), nullable=False),
            sa.Column('description', sa.Text(), nullable=True),
            sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
            sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
            sa.ForeignKeyConstraint(['pole_id'], ['poles.id'], ),
            sa.PrimaryKeyConstraint('id'),
            sa.UniqueConstraint('pole_id')
        )
        op.create_index(op.f('ix_connectivity_nodes_id'), 'connectivity_nodes', ['id'], unique=False)
        op.create_index(op.f('ix_connectivity_nodes_mrid'), 'connectivity_nodes', ['mrid'], unique=True)
        print("Таблица 'connectivity_nodes' создана")
    
    # 2. Создание таблицы terminals
    if 'terminals' not in existing_tables:
        op.create_table(
            'terminals',
            sa.Column('id', sa.Integer(), nullable=False),
            sa.Column('mrid', sa.String(length=36), nullable=False),
            sa.Column('name', sa.String(length=100), nullable=True),
            sa.Column('connectivity_node_id', sa.Integer(), nullable=True),
            sa.Column('acline_segment_id', sa.Integer(), nullable=True),
            sa.Column('conducting_equipment_id', sa.Integer(), nullable=True),
            sa.Column('bay_id', sa.Integer(), nullable=True),
            sa.Column('sequence_number', sa.Integer(), nullable=True, server_default='1'),
            sa.Column('connection_direction', sa.String(length=20), nullable=False),
            sa.Column('description', sa.Text(), nullable=True),
            sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
            sa.ForeignKeyConstraint(['connectivity_node_id'], ['connectivity_nodes.id'], ),
            sa.ForeignKeyConstraint(['acline_segment_id'], ['acline_segments.id'], ),
            sa.ForeignKeyConstraint(['conducting_equipment_id'], ['conducting_equipment.id'], ),
            sa.ForeignKeyConstraint(['bay_id'], ['bays.id'], ),
            sa.PrimaryKeyConstraint('id')
        )
        op.create_index(op.f('ix_terminals_id'), 'terminals', ['id'], unique=False)
        op.create_index(op.f('ix_terminals_mrid'), 'terminals', ['mrid'], unique=True)
        print("Таблица 'terminals' создана")
    
    # 3. Создание таблицы line_sections
    if 'line_sections' not in existing_tables:
        op.create_table(
            'line_sections',
            sa.Column('id', sa.Integer(), nullable=False),
            sa.Column('mrid', sa.String(length=36), nullable=False),
            sa.Column('name', sa.String(length=100), nullable=False),
            sa.Column('acline_segment_id', sa.Integer(), nullable=False),
            sa.Column('conductor_type', sa.String(length=50), nullable=False),
            sa.Column('conductor_material', sa.String(length=50), nullable=True),
            sa.Column('conductor_section', sa.String(length=20), nullable=False),
            sa.Column('r', sa.Float(), nullable=True),
            sa.Column('x', sa.Float(), nullable=True),
            sa.Column('b', sa.Float(), nullable=True),
            sa.Column('g', sa.Float(), nullable=True),
            sa.Column('sequence_number', sa.Integer(), nullable=False, server_default='1'),
            sa.Column('total_length', sa.Float(), nullable=True),
            sa.Column('description', sa.Text(), nullable=True),
            sa.Column('created_by', sa.Integer(), nullable=False),
            sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
            sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
            sa.ForeignKeyConstraint(['acline_segment_id'], ['acline_segments.id'], ),
            sa.ForeignKeyConstraint(['created_by'], ['users.id'], ),
            sa.PrimaryKeyConstraint('id')
        )
        op.create_index(op.f('ix_line_sections_id'), 'line_sections', ['id'], unique=False)
        op.create_index(op.f('ix_line_sections_mrid'), 'line_sections', ['mrid'], unique=True)
        print("Таблица 'line_sections' создана")
    
    # 4. Обновление таблицы acline_segments
    # Добавляем поля для поддержки отпаек и ConnectivityNode
    if 'acline_segments' in existing_tables:
        # Проверяем существование колонок перед добавлением
        existing_columns = [col['name'] for col in inspector.get_columns('acline_segments')]
        
        if 'power_line_id' not in existing_columns:
            op.add_column('acline_segments', sa.Column('power_line_id', sa.Integer(), nullable=True))
            op.create_foreign_key('fk_acline_segments_power_line', 'acline_segments', 'power_lines', ['power_line_id'], ['id'])
            print("Добавлена колонка 'power_line_id' в 'acline_segments'")
        
        if 'is_tap' not in existing_columns:
            op.add_column('acline_segments', sa.Column('is_tap', sa.Boolean(), nullable=True, server_default='false'))
            print("Добавлена колонка 'is_tap' в 'acline_segments'")
        
        if 'tap_number' not in existing_columns:
            op.add_column('acline_segments', sa.Column('tap_number', sa.String(length=20), nullable=True))
            print("Добавлена колонка 'tap_number' в 'acline_segments'")
        
        if 'from_connectivity_node_id' not in existing_columns:
            op.add_column('acline_segments', sa.Column('from_connectivity_node_id', sa.Integer(), nullable=True))
            op.create_foreign_key('fk_acline_segments_from_node', 'acline_segments', 'connectivity_nodes', ['from_connectivity_node_id'], ['id'])
            print("Добавлена колонка 'from_connectivity_node_id' в 'acline_segments'")
        
        if 'to_connectivity_node_id' not in existing_columns:
            op.add_column('acline_segments', sa.Column('to_connectivity_node_id', sa.Integer(), nullable=True))
            op.create_foreign_key('fk_acline_segments_to_node', 'acline_segments', 'connectivity_nodes', ['to_connectivity_node_id'], ['id'])
            print("Добавлена колонка 'to_connectivity_node_id' в 'acline_segments'")
        
        if 'to_terminal_id' not in existing_columns:
            op.add_column('acline_segments', sa.Column('to_terminal_id', sa.Integer(), nullable=True))
            op.create_foreign_key('fk_acline_segments_to_terminal', 'acline_segments', 'terminals', ['to_terminal_id'], ['id'])
            print("Добавлена колонка 'to_terminal_id' в 'acline_segments'")
        
        if 'sequence_number' not in existing_columns:
            op.add_column('acline_segments', sa.Column('sequence_number', sa.Integer(), nullable=True, server_default='1'))
            print("Добавлена колонка 'sequence_number' в 'acline_segments'")
    
    # 5. Обновление таблицы spans
    # Добавляем связь с LineSection и ConnectivityNode
    if 'spans' in existing_tables:
        existing_columns = [col['name'] for col in inspector.get_columns('spans')]
        
        if 'line_section_id' not in existing_columns:
            op.add_column('spans', sa.Column('line_section_id', sa.Integer(), nullable=True))
            op.create_foreign_key('fk_spans_line_section', 'spans', 'line_sections', ['line_section_id'], ['id'])
            print("Добавлена колонка 'line_section_id' в 'spans'")
        
        if 'from_connectivity_node_id' not in existing_columns:
            op.add_column('spans', sa.Column('from_connectivity_node_id', sa.Integer(), nullable=True))
            op.create_foreign_key('fk_spans_from_node', 'spans', 'connectivity_nodes', ['from_connectivity_node_id'], ['id'])
            print("Добавлена колонка 'from_connectivity_node_id' в 'spans'")
        
        if 'to_connectivity_node_id' not in existing_columns:
            op.add_column('spans', sa.Column('to_connectivity_node_id', sa.Integer(), nullable=True))
            op.create_foreign_key('fk_spans_to_node', 'spans', 'connectivity_nodes', ['to_connectivity_node_id'], ['id'])
            print("Добавлена колонка 'to_connectivity_node_id' в 'spans'")
        
        if 'sequence_number' not in existing_columns:
            op.add_column('spans', sa.Column('sequence_number', sa.Integer(), nullable=True, server_default='1'))
            print("Добавлена колонка 'sequence_number' в 'spans'")
    
    # 6. Обновление таблицы poles
    # Добавляем связь с ConnectivityNode
    if 'poles' in existing_tables:
        existing_columns = [col['name'] for col in inspector.get_columns('poles')]
        
        if 'connectivity_node_id' not in existing_columns:
            op.add_column('poles', sa.Column('connectivity_node_id', sa.Integer(), nullable=True, unique=True))
            op.create_foreign_key('fk_poles_connectivity_node', 'poles', 'connectivity_nodes', ['connectivity_node_id'], ['id'])
            print("Добавлена колонка 'connectivity_node_id' в 'poles'")
    
    # 7. Обновление таблицы conducting_equipment для связи с terminals
    if 'conducting_equipment' in existing_tables:
        # Связь уже может быть через relationship, но проверим
        pass
    
    # 8. Обновление таблицы bays для связи с terminals
    if 'bays' in existing_tables:
        # Связь уже может быть через relationship, но проверим
        pass


def downgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    existing_tables = inspector.get_table_names()
    
    # Удаление в обратном порядке
    
    # 1. Удаление колонок из poles
    if 'poles' in existing_tables:
        existing_columns = [col['name'] for col in inspector.get_columns('poles')]
        if 'connectivity_node_id' in existing_columns:
            op.drop_constraint('fk_poles_connectivity_node', 'poles', type_='foreignkey')
            op.drop_column('poles', 'connectivity_node_id')
            print("Удалена колонка 'connectivity_node_id' из 'poles'")
    
    # 2. Удаление колонок из spans
    if 'spans' in existing_tables:
        existing_columns = [col['name'] for col in inspector.get_columns('spans')]
        if 'sequence_number' in existing_columns:
            op.drop_column('spans', 'sequence_number')
        if 'to_connectivity_node_id' in existing_columns:
            op.drop_constraint('fk_spans_to_node', 'spans', type_='foreignkey')
            op.drop_column('spans', 'to_connectivity_node_id')
        if 'from_connectivity_node_id' in existing_columns:
            op.drop_constraint('fk_spans_from_node', 'spans', type_='foreignkey')
            op.drop_column('spans', 'from_connectivity_node_id')
        if 'line_section_id' in existing_columns:
            op.drop_constraint('fk_spans_line_section', 'spans', type_='foreignkey')
            op.drop_column('spans', 'line_section_id')
        print("Удалены колонки из 'spans'")
    
    # 3. Удаление колонок из acline_segments
    if 'acline_segments' in existing_tables:
        existing_columns = [col['name'] for col in inspector.get_columns('acline_segments')]
        if 'sequence_number' in existing_columns:
            op.drop_column('acline_segments', 'sequence_number')
        if 'to_terminal_id' in existing_columns:
            op.drop_constraint('fk_acline_segments_to_terminal', 'acline_segments', type_='foreignkey')
            op.drop_column('acline_segments', 'to_terminal_id')
        if 'to_connectivity_node_id' in existing_columns:
            op.drop_constraint('fk_acline_segments_to_node', 'acline_segments', type_='foreignkey')
            op.drop_column('acline_segments', 'to_connectivity_node_id')
        if 'from_connectivity_node_id' in existing_columns:
            op.drop_constraint('fk_acline_segments_from_node', 'acline_segments', type_='foreignkey')
            op.drop_column('acline_segments', 'from_connectivity_node_id')
        if 'tap_number' in existing_columns:
            op.drop_column('acline_segments', 'tap_number')
        if 'is_tap' in existing_columns:
            op.drop_column('acline_segments', 'is_tap')
        if 'power_line_id' in existing_columns:
            op.drop_constraint('fk_acline_segments_power_line', 'acline_segments', type_='foreignkey')
            op.drop_column('acline_segments', 'power_line_id')
        print("Удалены колонки из 'acline_segments'")
    
    # 4. Удаление таблиц
    if 'line_sections' in existing_tables:
        op.drop_index(op.f('ix_line_sections_mrid'), table_name='line_sections')
        op.drop_index(op.f('ix_line_sections_id'), table_name='line_sections')
        op.drop_table('line_sections')
        print("Таблица 'line_sections' удалена")
    
    if 'terminals' in existing_tables:
        op.drop_index(op.f('ix_terminals_mrid'), table_name='terminals')
        op.drop_index(op.f('ix_terminals_id'), table_name='terminals')
        op.drop_table('terminals')
        print("Таблица 'terminals' удалена")
    
    if 'connectivity_nodes' in existing_tables:
        op.drop_index(op.f('ix_connectivity_nodes_mrid'), table_name='connectivity_nodes')
        op.drop_index(op.f('ix_connectivity_nodes_id'), table_name='connectivity_nodes')
        op.drop_table('connectivity_nodes')
        print("Таблица 'connectivity_nodes' удалена")

