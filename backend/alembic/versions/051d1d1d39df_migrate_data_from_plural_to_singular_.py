"""migrate_data_from_plural_to_singular_tables

Revision ID: 051d1d1d39df
Revises: b64942757d2c
Create Date: 2026-02-08 14:51:25.784933

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import text


# revision identifiers, used by Alembic.
revision = '051d1d1d39df'
down_revision = 'b64942757d2c'
branch_labels = None
depends_on = None


def _table_exists(conn, table_name):
    """Проверяет существование таблицы"""
    try:
        result = conn.execute(text("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_schema = 'public' 
                AND table_name = :table_name
            )
        """), {"table_name": table_name})
        return result.scalar()
    except:
        return False


def _get_table_count(conn, table_name):
    """Получает количество записей в таблице"""
    try:
        result = conn.execute(text(f"SELECT COUNT(*) FROM {table_name}"))
        return result.scalar() or 0
    except:
        return 0


def _has_foreign_keys(conn, table_name):
    """Проверяет, есть ли foreign keys, ссылающиеся на таблицу"""
    try:
        result = conn.execute(text("""
            SELECT COUNT(*) 
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu 
                ON tc.constraint_name = kcu.constraint_name
            WHERE tc.constraint_type = 'FOREIGN KEY' 
            AND kcu.referenced_table_name = :table_name
        """), {"table_name": table_name})
        return (result.scalar() or 0) > 0
    except:
        # Если запрос не работает, проверяем через pg_constraint
        try:
            result = conn.execute(text("""
                SELECT COUNT(*) 
                FROM pg_constraint 
                WHERE confrelid = :table_name::regclass
            """), {"table_name": table_name})
            return (result.scalar() or 0) > 0
        except:
            return False


def upgrade() -> None:
    conn = op.get_bind()
    
    # Сначала переносим независимые таблицы (без foreign keys на другие таблицы)
    independent_migrations = [
        ('power_lines', 'line', []),  # Основная таблица, должна быть перенесена первой
        ('locations', 'location', []),
        ('base_voltages', 'base_voltage', []),
        ('wire_infos', 'wire_info', []),
        ('substations', 'substation', []),
    ]
    
    # Затем переносим зависимые таблицы
    # Словарь для переноса данных: (старая_таблица, новая_таблица, список_колонок_для_переименования)
    # Колонки переименовываются: power_line_id -> line_id
    dependent_migrations = [
        ('voltage_levels', 'voltage_level', []),
        ('bays', 'bay', []),
        ('busbar_sections', 'busbar_section', []),
        ('connectivity_nodes', 'connectivity_node', [('power_line_id', 'line_id')]),
        ('poles', 'pole', [('power_line_id', 'line_id')]),
        ('acline_segments', 'acline_segment', [('power_line_id', 'line_id')]),
        ('line_sections', 'line_section', []),
        ('spans', 'span', [('power_line_id', 'line_id')]),
        ('taps', 'tap', [('power_line_id', 'line_id')]),
        ('terminals', 'terminal', []),
    ]
    
    migrations = independent_migrations + dependent_migrations
    
    for old_table, new_table, column_renames in migrations:
        if not _table_exists(conn, old_table):
            print(f"Skipping {old_table} - table does not exist")
            continue
        
        old_count = _get_table_count(conn, old_table)
        if old_count == 0:
            # Старая таблица пустая, можно просто удалить с CASCADE
            try:
                conn.execute(text(f'DROP TABLE IF EXISTS "{old_table}" CASCADE'))
                conn.commit()
                print(f"Dropped empty table {old_table}")
            except Exception as e:
                print(f"Warning: Could not drop {old_table}: {e}")
                conn.rollback()
            continue
        
        if not _table_exists(conn, new_table):
            # Новая таблица не существует, просто переименовываем старую
            try:
                op.rename_table(old_table, new_table)
                print(f"Renamed {old_table} to {new_table}")
                
                # Переименовываем колонки если нужно
                for old_col, new_col in column_renames:
                    try:
                        op.alter_column(new_table, old_col, new_column_name=new_col)
                        print(f"Renamed column {old_col} to {new_col} in {new_table}")
                    except Exception as e:
                        print(f"Warning: Could not rename column {old_col} to {new_col} in {new_table}: {e}")
                continue
            except Exception as e:
                print(f"Warning: Could not rename {old_table} to {new_table}: {e}")
                continue
        
        new_count = _get_table_count(conn, new_table)
        if new_count > 0 and old_table != 'power_lines':
            # В новой таблице уже есть данные, пропускаем (кроме power_lines, где нужно дополнить)
            print(f"Warning: {new_table} already has {new_count} records, skipping {old_table}")
            continue
        
        # Переносим данные из старой таблицы в новую
        try:
            # Получаем список всех колонок из старой таблицы
            result = conn.execute(text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = :table_name 
                AND table_schema = 'public'
                ORDER BY ordinal_position
            """), {"table_name": old_table})
            old_columns = [row[0] for row in result.fetchall()]
            
            # Получаем список всех колонок из новой таблицы
            result = conn.execute(text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = :table_name 
                AND table_schema = 'public'
                ORDER BY ordinal_position
            """), {"table_name": new_table})
            new_columns = {row[0] for row in result.fetchall()}
            
            # Создаем mapping колонок (с учетом переименований)
            column_mapping = {}
            for col in old_columns:
                new_col = col
                for old_col, new_col_name in column_renames:
                    if col == old_col:
                        new_col = new_col_name
                        break
                column_mapping[col] = new_col
            
            # Фильтруем колонки, которые есть в обеих таблицах
            valid_columns = []
            for old_col, new_col in column_mapping.items():
                if new_col in new_columns:
                    valid_columns.append((old_col, new_col))
            
            if not valid_columns:
                print(f"Warning: No matching columns between {old_table} and {new_table}")
                continue
            
            # Формируем SQL для INSERT
            # Для power_lines нужно использовать ON CONFLICT, чтобы не дублировать существующие записи
            select_cols = []
            for old_col, new_col in valid_columns:
                # Обрабатываем NULL значения для power_line_id -> line_id
                if old_col == 'power_line_id' and new_col == 'line_id':
                    # Пропускаем записи с NULL или используем COALESCE для дефолтного значения
                    # Но лучше пропустить такие записи
                    select_cols.append(f'CASE WHEN "{old_col}" IS NOT NULL THEN "{old_col}" ELSE NULL END')
                else:
                    select_cols.append(f'"{old_col}"')
            
            insert_cols = [f'"{new_col}"' for _, new_col in valid_columns]
            
            # Для power_lines используем ON CONFLICT DO NOTHING
            if old_table == 'power_lines':
                insert_sql = f"""
                    INSERT INTO "{new_table}" ({', '.join(insert_cols)})
                    SELECT {', '.join(select_cols)}
                    FROM "{old_table}"
                    ON CONFLICT (id) DO NOTHING
                """
            else:
                # Для других таблиц фильтруем NULL значения в line_id
                where_clause = ""
                if 'power_line_id' in [col for col, _ in column_mapping.items()]:
                    where_clause = "WHERE power_line_id IS NOT NULL"
                
                insert_sql = f"""
                    INSERT INTO "{new_table}" ({', '.join(insert_cols)})
                    SELECT {', '.join(select_cols)}
                    FROM "{old_table}"
                    {where_clause}
                """
            
            conn.execute(text(insert_sql))
            conn.commit()
            
            migrated_count = _get_table_count(conn, new_table)
            print(f"Migrated {migrated_count} records from {old_table} to {new_table}")
            
            # Удаляем старую таблицу с CASCADE
            try:
                conn.execute(text(f'DROP TABLE IF EXISTS "{old_table}" CASCADE'))
                conn.commit()
                print(f"Dropped old table {old_table}")
            except Exception as e:
                print(f"Warning: Could not drop {old_table}: {e}")
                conn.rollback()
            
        except Exception as e:
            print(f"Error migrating {old_table} to {new_table}: {e}")
            import traceback
            traceback.print_exc()
            conn.rollback()
            continue
    
    # После переноса всех данных, удаляем оставшиеся старые таблицы с CASCADE
    # (если они пустые или данные уже перенесены)
    tables_to_cleanup = [
        'poles', 'spans', 'taps', 'connectivity_nodes', 'acline_segments',
        'line_sections', 'power_lines', 'substations', 'voltage_levels',
        'bays', 'busbar_sections', 'terminals', 'locations', 'base_voltages', 'wire_infos'
    ]
    
    for table_name in tables_to_cleanup:
        if _table_exists(conn, table_name):
            count = _get_table_count(conn, table_name)
            if count == 0:
                try:
                    # Проверяем, есть ли соответствующая новая таблица
                    singular_name = table_name.rstrip('s') if table_name.endswith('s') else table_name
                    if _table_exists(conn, singular_name):
                        # Удаляем старую таблицу с CASCADE
                        conn.execute(text(f'DROP TABLE IF EXISTS "{table_name}" CASCADE'))
                        conn.commit()
                        print(f"Cleaned up empty table {table_name}")
                except Exception as e:
                    print(f"Warning: Could not cleanup {table_name}: {e}")


def downgrade() -> None:
    # Откат не реализован, так как это миграция данных
    pass
