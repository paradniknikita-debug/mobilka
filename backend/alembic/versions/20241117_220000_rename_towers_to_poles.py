"""rename_towers_to_poles

Revision ID: 20241117_220000
Revises: 20241116_170000
Create Date: 2024-11-17 22:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

# revision identifiers, used by Alembic.
revision = '20241117_220000'
down_revision = '20241116_170000'
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    existing_tables = inspector.get_table_names()
    
    # Проверяем, существует ли таблица towers
    if 'towers' not in existing_tables:
        print("Таблица 'towers' не существует, пропускаем переименование")
        return
    
    # Если таблица poles уже существует, пропускаем
    if 'poles' in existing_tables:
        print("Таблица 'poles' уже существует, пропускаем переименование")
        return
    
    # 1. Переименовываем таблицу towers -> poles
    op.rename_table('towers', 'poles')
    print("Таблица 'towers' переименована в 'poles'")
    
    # 2. Переименовываем все внешние ключи и индексы
    # Получаем все внешние ключи, которые ссылаются на towers
    foreign_keys = inspector.get_foreign_keys('poles')
    
    # 3. Обновляем внешние ключи в других таблицах, которые ссылаются на towers
    # Проверяем таблицу spans
    if 'spans' in existing_tables:
        # Получаем все внешние ключи для spans
        spans_fks = inspector.get_foreign_keys('spans')
        for fk in spans_fks:
            if 'tower' in fk['name'].lower() or ('from_tower_id' in fk['constrained_columns'] or 'to_tower_id' in fk['constrained_columns']):
                try:
                    op.drop_constraint(fk['name'], 'spans', type_='foreignkey')
                except:
                    pass
        # Переименовываем колонки
        try:
            op.alter_column('spans', 'from_tower_id', new_column_name='from_pole_id')
        except:
            pass
        try:
            op.alter_column('spans', 'to_tower_id', new_column_name='to_pole_id')
        except:
            pass
        # Создаем новые внешние ключи
        try:
            op.create_foreign_key('spans_from_pole_id_fkey', 'spans', 'poles', ['from_pole_id'], ['id'])
            op.create_foreign_key('spans_to_pole_id_fkey', 'spans', 'poles', ['to_pole_id'], ['id'])
        except:
            pass
        print("Обновлены внешние ключи в таблице 'spans'")
    
    # Проверяем таблицу taps
    if 'taps' in existing_tables:
        # Получаем все внешние ключи для taps
        taps_fks = inspector.get_foreign_keys('taps')
        for fk in taps_fks:
            if 'tower' in fk['name'].lower() or 'tower_id' in fk['constrained_columns']:
                try:
                    op.drop_constraint(fk['name'], 'taps', type_='foreignkey')
                except:
                    pass
        # Переименовываем колонку
        try:
            op.alter_column('taps', 'tower_id', new_column_name='pole_id')
        except:
            pass
        # Создаем новый внешний ключ
        try:
            op.create_foreign_key('taps_pole_id_fkey', 'taps', 'poles', ['pole_id'], ['id'])
        except:
            pass
        print("Обновлены внешние ключи в таблице 'taps'")
    
    # Проверяем таблицу equipment
    if 'equipment' in existing_tables:
        # Получаем все внешние ключи для equipment
        equipment_fks = inspector.get_foreign_keys('equipment')
        for fk in equipment_fks:
            if 'tower' in fk['name'].lower() or 'tower_id' in fk['constrained_columns']:
                try:
                    op.drop_constraint(fk['name'], 'equipment', type_='foreignkey')
                except:
                    pass
        # Переименовываем колонку
        try:
            op.alter_column('equipment', 'tower_id', new_column_name='pole_id')
        except:
            pass
        # Создаем новый внешний ключ
        try:
            op.create_foreign_key('equipment_pole_id_fkey', 'equipment', 'poles', ['pole_id'], ['id'])
        except:
            pass
        print("Обновлены внешние ключи в таблице 'equipment'")
    
    # Проверяем таблицу acline_segments
    if 'acline_segments' in existing_tables:
        # Получаем все внешние ключи для acline_segments
        acline_fks = inspector.get_foreign_keys('acline_segments')
        for fk in acline_fks:
            if 'tower' in fk['name'].lower() or ('start_tower_id' in fk['constrained_columns'] or 'end_tower_id' in fk['constrained_columns']):
                try:
                    op.drop_constraint(fk['name'], 'acline_segments', type_='foreignkey')
                except:
                    pass
        # Переименовываем колонки
        try:
            op.alter_column('acline_segments', 'start_tower_id', new_column_name='start_pole_id')
        except:
            pass
        try:
            op.alter_column('acline_segments', 'end_tower_id', new_column_name='end_pole_id')
        except:
            pass
        # Создаем новые внешние ключи
        try:
            op.create_foreign_key('fk_acline_segments_start_pole', 'acline_segments', 'poles', ['start_pole_id'], ['id'])
            op.create_foreign_key('fk_acline_segments_end_pole', 'acline_segments', 'poles', ['end_pole_id'], ['id'])
        except:
            pass
        print("Обновлены внешние ключи в таблице 'acline_segments'")
    
    # Переименовываем колонки в таблице poles (tower_number -> pole_number, tower_type -> pole_type)
    poles_columns = [col['name'] for col in inspector.get_columns('poles')]
    if 'tower_number' in poles_columns:
        op.alter_column('poles', 'tower_number', new_column_name='pole_number')
        print("Колонка 'tower_number' переименована в 'pole_number'")
    if 'tower_type' in poles_columns:
        op.alter_column('poles', 'tower_type', new_column_name='pole_type')
        print("Колонка 'tower_type' переименована в 'pole_type'")
    
    # Переименовываем индексы
    # Проверяем и переименовываем индексы на таблице poles
    indexes = inspector.get_indexes('poles')
    for index in indexes:
        if 'tower' in index['name'].lower():
            new_name = index['name'].replace('tower', 'pole').replace('Tower', 'Pole')
            try:
                op.execute(f'ALTER INDEX {index["name"]} RENAME TO {new_name}')
            except:
                pass


def downgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    existing_tables = inspector.get_table_names()
    
    # Проверяем, существует ли таблица poles
    if 'poles' not in existing_tables:
        print("Таблица 'poles' не существует, пропускаем откат")
        return
    
    # Если таблица towers уже существует, пропускаем
    if 'towers' in existing_tables:
        print("Таблица 'towers' уже существует, пропускаем откат")
        return
    
    # 1. Обновляем внешние ключи обратно
    # Проверяем таблицу spans
    if 'spans' in existing_tables:
        try:
            op.drop_constraint('spans_from_pole_id_fkey', 'spans', type_='foreignkey')
            op.drop_constraint('spans_to_pole_id_fkey', 'spans', type_='foreignkey')
            op.alter_column('spans', 'from_pole_id', new_column_name='from_tower_id')
            op.alter_column('spans', 'to_pole_id', new_column_name='to_tower_id')
            op.create_foreign_key('spans_from_tower_id_fkey', 'spans', 'poles', ['from_tower_id'], ['id'])
            op.create_foreign_key('spans_to_tower_id_fkey', 'spans', 'poles', ['to_tower_id'], ['id'])
        except:
            pass
    
    # Проверяем таблицу taps
    if 'taps' in existing_tables:
        try:
            op.drop_constraint('taps_pole_id_fkey', 'taps', type_='foreignkey')
            op.alter_column('taps', 'pole_id', new_column_name='tower_id')
            op.create_foreign_key('taps_tower_id_fkey', 'taps', 'poles', ['tower_id'], ['id'])
        except:
            pass
    
    # Проверяем таблицу equipment
    if 'equipment' in existing_tables:
        try:
            op.drop_constraint('equipment_pole_id_fkey', 'equipment', type_='foreignkey')
            op.alter_column('equipment', 'pole_id', new_column_name='tower_id')
            op.create_foreign_key('equipment_tower_id_fkey', 'equipment', 'poles', ['tower_id'], ['id'])
        except:
            pass
    
    # Проверяем таблицу acline_segments
    if 'acline_segments' in existing_tables:
        try:
            op.drop_constraint('fk_acline_segments_start_pole', 'acline_segments', type_='foreignkey')
            op.drop_constraint('fk_acline_segments_end_pole', 'acline_segments', type_='foreignkey')
            op.alter_column('acline_segments', 'start_pole_id', new_column_name='start_tower_id')
            op.alter_column('acline_segments', 'end_pole_id', new_column_name='end_tower_id')
            op.create_foreign_key('fk_acline_segments_start_tower', 'acline_segments', 'poles', ['start_tower_id'], ['id'])
            op.create_foreign_key('fk_acline_segments_end_tower', 'acline_segments', 'poles', ['end_tower_id'], ['id'])
        except:
            pass
    
    # 2. Переименовываем таблицу обратно
    op.rename_table('poles', 'towers')
    print("Таблица 'poles' переименована обратно в 'towers'")

