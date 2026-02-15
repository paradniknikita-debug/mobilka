"""remove_duplicate_tables_and_refactor_position_point

Revision ID: 9b9109e2a50c
Revises: 051d1d1d39df
Create Date: 2026-02-08 15:11:43.306726

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import text


# revision identifiers, used by Alembic.
revision = '9b9109e2a50c'
down_revision = '051d1d1d39df'
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


def upgrade() -> None:
    conn = op.get_bind()
    
    # 1. Удаляем дубликат position_points (если есть данные, переносим в position_point)
    if _table_exists(conn, 'position_points'):
        count = _get_table_count(conn, 'position_points')
        if count > 0:
            # Переносим данные из position_points в position_point
            try:
                conn.execute(text("""
                    INSERT INTO position_point (mrid, location_id, x_position, y_position, z_position, sequence_number, description, created_at, updated_at)
                    SELECT mrid, location_id, x_position, y_position, z_position, sequence_number, description, created_at, updated_at
                    FROM position_points
                    ON CONFLICT (mrid) DO NOTHING
                """))
                conn.commit()
                print(f"Migrated {count} records from position_points to position_point")
            except Exception as e:
                print(f"Warning: Could not migrate position_points: {e}")
                conn.rollback()
        
        # Удаляем старую таблицу
        try:
            conn.execute(text('DROP TABLE IF EXISTS position_points CASCADE'))
            conn.commit()
            print("Dropped duplicate table position_points")
        except Exception as e:
            print(f"Warning: Could not drop position_points: {e}")
            conn.rollback()
    
    # 2. Удаляем дубликат substations (если есть данные, переносим в substation)
    if _table_exists(conn, 'substations'):
        count = _get_table_count(conn, 'substations')
        if count > 0:
            # Проверяем, есть ли записи в substation
            substation_count = _get_table_count(conn, 'substation')
            if substation_count == 0:
                # Переносим данные из substations в substation
                try:
                    # Получаем список колонок
                    result = conn.execute(text("""
                        SELECT column_name 
                        FROM information_schema.columns 
                        WHERE table_name = 'substations' 
                        AND table_schema = 'public'
                        ORDER BY ordinal_position
                    """))
                    columns = [row[0] for row in result.fetchall()]
                    
                    # Формируем INSERT
                    select_cols = [f'"{col}"' for col in columns]
                    insert_cols = [f'"{col}"' for col in columns]
                    
                    insert_sql = f"""
                        INSERT INTO substation ({', '.join(insert_cols)})
                        SELECT {', '.join(select_cols)}
                        FROM substations
                        ON CONFLICT (id) DO NOTHING
                    """
                    conn.execute(text(insert_sql))
                    conn.commit()
                    print(f"Migrated {count} records from substations to substation")
                except Exception as e:
                    print(f"Warning: Could not migrate substations: {e}")
                    conn.rollback()
        
        # Удаляем старую таблицу
        try:
            conn.execute(text('DROP TABLE IF EXISTS substations CASCADE'))
            conn.commit()
            print("Dropped duplicate table substations")
        except Exception as e:
            print(f"Warning: Could not drop substations: {e}")
            conn.rollback()
    
    # 3. Изменяем структуру position_point для прямого хранения координат всех объектов
    # Добавляем полиморфные связи с объектами
    if _table_exists(conn, 'position_point'):
        # Проверяем, есть ли уже колонки для полиморфных связей
        result = conn.execute(text("""
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_name = 'position_point' 
            AND column_name IN ('pole_id', 'substation_id', 'tap_id', 'span_id')
        """))
        existing_cols = {row[0] for row in result.fetchall()}
        
        # Добавляем колонки для полиморфных связей
        if 'pole_id' not in existing_cols:
            try:
                op.add_column('position_point', sa.Column('pole_id', sa.Integer(), nullable=True))
                op.create_foreign_key('position_point_pole_id_fkey', 'position_point', 'pole', ['pole_id'], ['id'], ondelete='CASCADE')
                print("Added pole_id column to position_point")
            except Exception as e:
                print(f"Warning: Could not add pole_id: {e}")
        
        if 'substation_id' not in existing_cols:
            try:
                op.add_column('position_point', sa.Column('substation_id', sa.Integer(), nullable=True))
                op.create_foreign_key('position_point_substation_id_fkey', 'position_point', 'substation', ['substation_id'], ['id'], ondelete='CASCADE')
                print("Added substation_id column to position_point")
            except Exception as e:
                print(f"Warning: Could not add substation_id: {e}")
        
        if 'tap_id' not in existing_cols:
            try:
                op.add_column('position_point', sa.Column('tap_id', sa.Integer(), nullable=True))
                op.create_foreign_key('position_point_tap_id_fkey', 'position_point', 'tap', ['tap_id'], ['id'], ondelete='CASCADE')
                print("Added tap_id column to position_point")
            except Exception as e:
                print(f"Warning: Could not add tap_id: {e}")
        
        if 'span_id' not in existing_cols:
            try:
                op.add_column('position_point', sa.Column('span_id', sa.Integer(), nullable=True))
                op.create_foreign_key('position_point_span_id_fkey', 'position_point', 'span', ['span_id'], ['id'], ondelete='CASCADE')
                print("Added span_id column to position_point")
            except Exception as e:
                print(f"Warning: Could not add span_id: {e}")
        
        # Делаем location_id опциональным (так как теперь координаты могут храниться напрямую)
        try:
            op.alter_column('position_point', 'location_id', nullable=True)
            print("Made location_id nullable in position_point")
        except Exception as e:
            print(f"Warning: Could not make location_id nullable: {e}")
        
        # Создаём индексы для новых колонок
        try:
            op.create_index('ix_position_point_pole_id', 'position_point', ['pole_id'])
            op.create_index('ix_position_point_substation_id', 'position_point', ['substation_id'])
            op.create_index('ix_position_point_tap_id', 'position_point', ['tap_id'])
            op.create_index('ix_position_point_span_id', 'position_point', ['span_id'])
            print("Created indexes for position_point foreign keys")
        except Exception as e:
            print(f"Warning: Could not create indexes: {e}")
        
        # Коммитим изменения структуры перед переносом данных
        conn.commit()
        
        # Переносим координаты из объектов в position_point
        # Для poles
        try:
            conn.execute(text("""
                INSERT INTO position_point (mrid, pole_id, x_position, y_position, z_position, sequence_number, created_at, updated_at)
                SELECT 
                    gen_random_uuid()::text,
                    id,
                    longitude,
                    latitude,
                    NULL,
                    1,
                    created_at,
                    updated_at
                FROM pole
                WHERE latitude IS NOT NULL AND longitude IS NOT NULL
                AND NOT EXISTS (
                    SELECT 1 FROM position_point WHERE pole_id = pole.id
                )
            """))
            conn.commit()
            print("Migrated coordinates from poles to position_point")
        except Exception as e:
            print(f"Warning: Could not migrate pole coordinates: {e}")
            conn.rollback()
        
        # Для substations
        try:
            conn.execute(text("""
                INSERT INTO position_point (mrid, substation_id, x_position, y_position, z_position, sequence_number, created_at, updated_at)
                SELECT 
                    gen_random_uuid()::text,
                    id,
                    longitude,
                    latitude,
                    NULL,
                    1,
                    created_at,
                    updated_at
                FROM substation
                WHERE latitude IS NOT NULL AND longitude IS NOT NULL
                AND NOT EXISTS (
                    SELECT 1 FROM position_point WHERE substation_id = substation.id
                )
            """))
            conn.commit()
            print("Migrated coordinates from substations to position_point")
        except Exception as e:
            print(f"Warning: Could not migrate substation coordinates: {e}")
            conn.rollback()
        
        # Для taps
        try:
            # Проверяем, какие колонки есть в tap
            result = conn.execute(text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = 'tap' 
                AND table_schema = 'public'
            """))
            tap_columns = {row[0] for row in result.fetchall()}
            
            created_at_col = 'created_at' if 'created_at' in tap_columns else 'NULL'
            updated_at_col = 'updated_at' if 'updated_at' in tap_columns else 'NULL'
            
            conn.execute(text(f"""
                INSERT INTO position_point (mrid, tap_id, x_position, y_position, z_position, sequence_number, created_at, updated_at)
                SELECT 
                    gen_random_uuid()::text,
                    id,
                    longitude,
                    latitude,
                    NULL,
                    1,
                    {created_at_col},
                    {updated_at_col}
                FROM tap
                WHERE latitude IS NOT NULL AND longitude IS NOT NULL
                AND NOT EXISTS (
                    SELECT 1 FROM position_point WHERE tap_id = tap.id
                )
            """))
            conn.commit()
            print("Migrated coordinates from taps to position_point")
        except Exception as e:
            print(f"Warning: Could not migrate tap coordinates: {e}")
            conn.rollback()


def downgrade() -> None:
    conn = op.get_bind()
    
    # Удаляем полиморфные связи
    try:
        op.drop_index('ix_position_point_span_id', 'position_point')
        op.drop_index('ix_position_point_tap_id', 'position_point')
        op.drop_index('ix_position_point_substation_id', 'position_point')
        op.drop_index('ix_position_point_pole_id', 'position_point')
    except:
        pass
    
    try:
        op.drop_constraint('position_point_span_id_fkey', 'position_point', type_='foreignkey')
        op.drop_column('position_point', 'span_id')
    except:
        pass
    
    try:
        op.drop_constraint('position_point_tap_id_fkey', 'position_point', type_='foreignkey')
        op.drop_column('position_point', 'tap_id')
    except:
        pass
    
    try:
        op.drop_constraint('position_point_substation_id_fkey', 'position_point', type_='foreignkey')
        op.drop_column('position_point', 'substation_id')
    except:
        pass
    
    try:
        op.drop_constraint('position_point_pole_id_fkey', 'position_point', type_='foreignkey')
        op.drop_column('position_point', 'pole_id')
    except:
        pass
    
    try:
        op.alter_column('position_point', 'location_id', nullable=False)
    except:
        pass

