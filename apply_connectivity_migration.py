"""
Скрипт для применения миграции connectivity_nodes
"""
import asyncio
import sys
import os

# Добавляем путь к backend
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'backend'))

from sqlalchemy import text
from backend.app.database import async_session_maker

async def apply_migration():
    async with async_session_maker() as session:
        try:
            print("Применение миграции connectivity_nodes...")
            
            # 1. Удаляем unique constraint
            await session.execute(text("""
                ALTER TABLE connectivity_nodes 
                DROP CONSTRAINT IF EXISTS uq_connectivity_nodes_pole_id;
            """))
            await session.execute(text("""
                ALTER TABLE connectivity_nodes 
                DROP CONSTRAINT IF EXISTS connectivity_nodes_pole_id_key;
            """))
            print("✓ Удалены unique constraints")
            
            # 2. Проверяем существование колонки
            result = await session.execute(text("""
                SELECT EXISTS (
                    SELECT FROM information_schema.columns 
                    WHERE table_name = 'connectivity_nodes' 
                    AND column_name = 'power_line_id'
                );
            """))
            exists = result.scalar()
            
            if not exists:
                # Добавляем колонку
                await session.execute(text("""
                    ALTER TABLE connectivity_nodes 
                    ADD COLUMN power_line_id INTEGER;
                """))
                print("✓ Добавлена колонка power_line_id")
                
                # Заполняем из опор
                await session.execute(text("""
                    UPDATE connectivity_nodes
                    SET power_line_id = (
                        SELECT power_line_id
                        FROM poles
                        WHERE poles.id = connectivity_nodes.pole_id
                    )
                    WHERE power_line_id IS NULL;
                """))
                print("✓ Заполнен power_line_id")
                
                # NOT NULL
                await session.execute(text("""
                    ALTER TABLE connectivity_nodes 
                    ALTER COLUMN power_line_id SET NOT NULL;
                """))
                print("✓ Установлен NOT NULL")
                
                # Foreign key
                await session.execute(text("""
                    ALTER TABLE connectivity_nodes 
                    ADD CONSTRAINT fk_connectivity_nodes_power_line 
                    FOREIGN KEY (power_line_id) 
                    REFERENCES power_lines(id);
                """))
                print("✓ Добавлен foreign key")
                
                # Индекс
                await session.execute(text("""
                    CREATE INDEX IF NOT EXISTS ix_connectivity_nodes_power_line_id 
                    ON connectivity_nodes(power_line_id);
                """))
                print("✓ Создан индекс")
            else:
                print("✓ Колонка power_line_id уже существует")
            
            await session.commit()
            print("\n✅ Миграция успешно применена!")
            
        except Exception as e:
            await session.rollback()
            print(f"\n❌ Ошибка: {e}")
            import traceback
            traceback.print_exc()
            raise

if __name__ == "__main__":
    asyncio.run(apply_migration())

