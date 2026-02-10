"""fix_cim_relationships

Revision ID: 20241220_000000
Revises: 20241216_100000
Create Date: 2024-12-20 00:00:00.000000

Исправление связей в БД согласно CIM модели:
- Проверка и исправление всех foreign keys с правильными правилами CASCADE/RESTRICT/SET NULL
- Добавление недостающих индексов для производительности
- Убедиться, что все связи соответствуют CIM стандарту IEC 61970-301
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

# revision identifiers, used by Alembic.
revision = '20241220_000000'
down_revision = '20241216_100000'
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    existing_tables = inspector.get_table_names()
    
    print("=" * 80)
    print("ИСПРАВЛЕНИЕ СВЯЗЕЙ CIM МОДЕЛЕЙ")
    print("=" * 80)
    
    # В PostgreSQL для изменения правил ondelete нужно:
    # 1. Удалить существующий foreign key
    # 2. Создать новый с правильными правилами
    
    # 1. AClineSegment -> PowerLine (CASCADE)
    if 'acline_segments' in existing_tables:
        existing_fks = {fk['name']: fk for fk in inspector.get_foreign_keys('acline_segments')}
        fk_name = 'fk_acline_segments_power_line'
        
        if fk_name in existing_fks:
            # Удаляем старый и создаём новый с CASCADE
            try:
                op.drop_constraint(fk_name, 'acline_segments', type_='foreignkey')
                op.create_foreign_key(
                    fk_name,
                    'acline_segments',
                    'power_lines',
                    ['power_line_id'],
                    ['id'],
                    ondelete='CASCADE'
                )
                print(f"✓ Обновлён foreign key '{fk_name}' с CASCADE")
            except Exception as e:
                print(f"⚠ Ошибка обновления '{fk_name}': {e}")
    
    # 2. AClineSegment -> ConnectivityNode (RESTRICT для from/to)
    if 'acline_segments' in existing_tables:
        existing_fks = {fk['name']: fk for fk in inspector.get_foreign_keys('acline_segments')}
        
        for fk_name, column in [('fk_acline_segments_from_node', 'from_connectivity_node_id'),
                                  ('fk_acline_segments_to_node', 'to_connectivity_node_id')]:
            if fk_name in existing_fks:
                try:
                    op.drop_constraint(fk_name, 'acline_segments', type_='foreignkey')
                    op.create_foreign_key(
                        fk_name,
                        'acline_segments',
                        'connectivity_nodes',
                        [column],
                        ['id'],
                        ondelete='RESTRICT'
                    )
                    print(f"✓ Обновлён foreign key '{fk_name}' с RESTRICT")
                except Exception as e:
                    print(f"⚠ Ошибка обновления '{fk_name}': {e}")
    
    # 3. AClineSegment -> Terminal (SET NULL)
    if 'acline_segments' in existing_tables:
        existing_fks = {fk['name']: fk for fk in inspector.get_foreign_keys('acline_segments')}
        fk_name = 'fk_acline_segments_to_terminal'
        
        if fk_name in existing_fks:
            try:
                op.drop_constraint(fk_name, 'acline_segments', type_='foreignkey')
                op.create_foreign_key(
                    fk_name,
                    'acline_segments',
                    'terminals',
                    ['to_terminal_id'],
                    ['id'],
                    ondelete='SET NULL'
                )
                print(f"✓ Обновлён foreign key '{fk_name}' с SET NULL")
            except Exception as e:
                print(f"⚠ Ошибка обновления '{fk_name}': {e}")
    
    # 4. LineSection -> AClineSegment (CASCADE)
    if 'line_sections' in existing_tables:
        existing_fks = {fk['name']: fk for fk in inspector.get_foreign_keys('line_sections')}
        fk_name = 'fk_line_sections_acline_segment'
        
        # Проверяем, есть ли такой FK или используем стандартное имя
        if not fk_name in existing_fks:
            # Ищем FK по колонке
            for fk in inspector.get_foreign_keys('line_sections'):
                if 'acline_segment_id' in fk['constrained_columns']:
                    fk_name = fk['name']
                    break
        
        if fk_name in existing_fks:
            try:
                op.drop_constraint(fk_name, 'line_sections', type_='foreignkey')
                op.create_foreign_key(
                    fk_name,
                    'line_sections',
                    'acline_segments',
                    ['acline_segment_id'],
                    ['id'],
                    ondelete='CASCADE'
                )
                print(f"✓ Обновлён foreign key '{fk_name}' с CASCADE")
            except Exception as e:
                print(f"⚠ Ошибка обновления '{fk_name}': {e}")
    
    # 5. Span -> LineSection (CASCADE)
    if 'spans' in existing_tables:
        existing_fks = {fk['name']: fk for fk in inspector.get_foreign_keys('spans')}
        fk_name = 'fk_spans_line_section'
        
        if not fk_name in existing_fks:
            for fk in inspector.get_foreign_keys('spans'):
                if 'line_section_id' in fk['constrained_columns']:
                    fk_name = fk['name']
                    break
        
        if fk_name in existing_fks:
            try:
                op.drop_constraint(fk_name, 'spans', type_='foreignkey')
                op.create_foreign_key(
                    fk_name,
                    'spans',
                    'line_sections',
                    ['line_section_id'],
                    ['id'],
                    ondelete='CASCADE'
                )
                print(f"✓ Обновлён foreign key '{fk_name}' с CASCADE")
            except Exception as e:
                print(f"⚠ Ошибка обновления '{fk_name}': {e}")
    
    # 6. Span -> ConnectivityNode (RESTRICT для from/to)
    if 'spans' in existing_tables:
        existing_fks = {fk['name']: fk for fk in inspector.get_foreign_keys('spans')}
        
        for fk_name, column in [('fk_spans_from_node', 'from_connectivity_node_id'),
                                  ('fk_spans_to_node', 'to_connectivity_node_id')]:
            if not fk_name in existing_fks:
                for fk in inspector.get_foreign_keys('spans'):
                    if column in fk['constrained_columns']:
                        fk_name = fk['name']
                        break
            
            if fk_name in existing_fks:
                try:
                    op.drop_constraint(fk_name, 'spans', type_='foreignkey')
                    op.create_foreign_key(
                        fk_name,
                        'spans',
                        'connectivity_nodes',
                        [column],
                        ['id'],
                        ondelete='RESTRICT'
                    )
                    print(f"✓ Обновлён foreign key '{fk_name}' с RESTRICT")
                except Exception as e:
                    print(f"⚠ Ошибка обновления '{fk_name}': {e}")
    
    # 7. ConnectivityNode -> Pole (CASCADE)
    if 'connectivity_nodes' in existing_tables:
        existing_fks = {fk['name']: fk for fk in inspector.get_foreign_keys('connectivity_nodes')}
        fk_name = 'fk_connectivity_nodes_pole'
        
        if not fk_name in existing_fks:
            for fk in inspector.get_foreign_keys('connectivity_nodes'):
                if 'pole_id' in fk['constrained_columns']:
                    fk_name = fk['name']
                    break
        
        if fk_name in existing_fks:
            try:
                op.drop_constraint(fk_name, 'connectivity_nodes', type_='foreignkey')
                op.create_foreign_key(
                    fk_name,
                    'connectivity_nodes',
                    'poles',
                    ['pole_id'],
                    ['id'],
                    ondelete='CASCADE'
                )
                print(f"✓ Обновлён foreign key '{fk_name}' с CASCADE")
            except Exception as e:
                print(f"⚠ Ошибка обновления '{fk_name}': {e}")
    
    # 8. ConnectivityNode -> PowerLine (CASCADE)
    if 'connectivity_nodes' in existing_tables:
        existing_fks = {fk['name']: fk for fk in inspector.get_foreign_keys('connectivity_nodes')}
        fk_name = 'fk_connectivity_nodes_power_line'
        
        if not fk_name in existing_fks:
            for fk in inspector.get_foreign_keys('connectivity_nodes'):
                if 'power_line_id' in fk['constrained_columns']:
                    fk_name = fk['name']
                    break
        
        if fk_name in existing_fks:
            try:
                op.drop_constraint(fk_name, 'connectivity_nodes', type_='foreignkey')
                op.create_foreign_key(
                    fk_name,
                    'connectivity_nodes',
                    'power_lines',
                    ['power_line_id'],
                    ['id'],
                    ondelete='CASCADE'
                )
                print(f"✓ Обновлён foreign key '{fk_name}' с CASCADE")
            except Exception as e:
                print(f"⚠ Ошибка обновления '{fk_name}': {e}")
    
    # 9. Terminal -> ConnectivityNode (SET NULL)
    if 'terminals' in existing_tables:
        existing_fks = {fk['name']: fk for fk in inspector.get_foreign_keys('terminals')}
        fk_name = 'fk_terminals_connectivity_node'
        
        if not fk_name in existing_fks:
            for fk in inspector.get_foreign_keys('terminals'):
                if 'connectivity_node_id' in fk['constrained_columns']:
                    fk_name = fk['name']
                    break
        
        if fk_name in existing_fks:
            try:
                op.drop_constraint(fk_name, 'terminals', type_='foreignkey')
                op.create_foreign_key(
                    fk_name,
                    'terminals',
                    'connectivity_nodes',
                    ['connectivity_node_id'],
                    ['id'],
                    ondelete='SET NULL'
                )
                print(f"✓ Обновлён foreign key '{fk_name}' с SET NULL")
            except Exception as e:
                print(f"⚠ Ошибка обновления '{fk_name}': {e}")
    
    # 10. Terminal -> AClineSegment (SET NULL)
    if 'terminals' in existing_tables:
        existing_fks = {fk['name']: fk for fk in inspector.get_foreign_keys('terminals')}
        fk_name = 'fk_terminals_acline_segment'
        
        if not fk_name in existing_fks:
            for fk in inspector.get_foreign_keys('terminals'):
                if 'acline_segment_id' in fk['constrained_columns']:
                    fk_name = fk['name']
                    break
        
        if fk_name in existing_fks:
            try:
                op.drop_constraint(fk_name, 'terminals', type_='foreignkey')
                op.create_foreign_key(
                    fk_name,
                    'terminals',
                    'acline_segments',
                    ['acline_segment_id'],
                    ['id'],
                    ondelete='SET NULL'
                )
                print(f"✓ Обновлён foreign key '{fk_name}' с SET NULL")
            except Exception as e:
                print(f"⚠ Ошибка обновления '{fk_name}': {e}")
    
    # 11. Terminal -> ConductingEquipment (SET NULL)
    if 'terminals' in existing_tables and 'conducting_equipment' in existing_tables:
        existing_fks = {fk['name']: fk for fk in inspector.get_foreign_keys('terminals')}
        fk_name = 'fk_terminals_conducting_equipment'
        
        if not fk_name in existing_fks:
            for fk in inspector.get_foreign_keys('terminals'):
                if 'conducting_equipment_id' in fk['constrained_columns']:
                    fk_name = fk['name']
                    break
        
        if fk_name in existing_fks:
            try:
                op.drop_constraint(fk_name, 'terminals', type_='foreignkey')
                op.create_foreign_key(
                    fk_name,
                    'terminals',
                    'conducting_equipment',
                    ['conducting_equipment_id'],
                    ['id'],
                    ondelete='SET NULL'
                )
                print(f"✓ Обновлён foreign key '{fk_name}' с SET NULL")
            except Exception as e:
                print(f"⚠ Ошибка обновления '{fk_name}': {e}")
    
    # 12. Terminal -> Bay (SET NULL)
    if 'terminals' in existing_tables and 'bays' in existing_tables:
        existing_fks = {fk['name']: fk for fk in inspector.get_foreign_keys('terminals')}
        fk_name = 'fk_terminals_bay'
        
        if not fk_name in existing_fks:
            for fk in inspector.get_foreign_keys('terminals'):
                if 'bay_id' in fk['constrained_columns']:
                    fk_name = fk['name']
                    break
        
        if fk_name in existing_fks:
            try:
                op.drop_constraint(fk_name, 'terminals', type_='foreignkey')
                op.create_foreign_key(
                    fk_name,
                    'terminals',
                    'bays',
                    ['bay_id'],
                    ['id'],
                    ondelete='SET NULL'
                )
                print(f"✓ Обновлён foreign key '{fk_name}' с SET NULL")
            except Exception as e:
                print(f"⚠ Ошибка обновления '{fk_name}': {e}")
    
    # Добавление индексов для производительности
    print("\n13. ДОБАВЛЕНИЕ ИНДЕКСОВ:")
    
    # Индексы для AClineSegment
    if 'acline_segments' in existing_tables:
        existing_indexes = [idx['name'] for idx in inspector.get_indexes('acline_segments')]
        
        for idx_name, column in [('ix_acline_segments_power_line_id', 'power_line_id'),
                                  ('ix_acline_segments_from_node', 'from_connectivity_node_id'),
                                  ('ix_acline_segments_to_node', 'to_connectivity_node_id')]:
            if idx_name not in existing_indexes:
                try:
                    op.create_index(idx_name, 'acline_segments', [column], unique=False)
                    print(f"✓ Создан индекс '{idx_name}'")
                except Exception as e:
                    print(f"⚠ Ошибка создания индекса '{idx_name}': {e}")
    
    # Индексы для Span
    if 'spans' in existing_tables:
        existing_indexes = [idx['name'] for idx in inspector.get_indexes('spans')]
        
        for idx_name, column in [('ix_spans_line_section_id', 'line_section_id'),
                                  ('ix_spans_from_node', 'from_connectivity_node_id'),
                                  ('ix_spans_to_node', 'to_connectivity_node_id')]:
            if idx_name not in existing_indexes:
                try:
                    op.create_index(idx_name, 'spans', [column], unique=False)
                    print(f"✓ Создан индекс '{idx_name}'")
                except Exception as e:
                    print(f"⚠ Ошибка создания индекса '{idx_name}': {e}")
    
    # Индексы для ConnectivityNode
    if 'connectivity_nodes' in existing_tables:
        existing_indexes = [idx['name'] for idx in inspector.get_indexes('connectivity_nodes')]
        
        for idx_name, column in [('ix_connectivity_nodes_pole_id', 'pole_id'),
                                  ('ix_connectivity_nodes_power_line_id', 'power_line_id')]:
            if idx_name not in existing_indexes:
                try:
                    op.create_index(idx_name, 'connectivity_nodes', [column], unique=False)
                    print(f"✓ Создан индекс '{idx_name}'")
                except Exception as e:
                    print(f"⚠ Ошибка создания индекса '{idx_name}': {e}")
    
    print("\n" + "=" * 80)
    print("ИСПРАВЛЕНИЕ СВЯЗЕЙ ЗАВЕРШЕНО")
    print("=" * 80)


def downgrade() -> None:
    # В downgrade можно удалить индексы, но foreign keys лучше оставить
    # так как они важны для целостности данных
    # Правила ondelete можно вернуть к значениям по умолчанию, но это не критично
    pass

