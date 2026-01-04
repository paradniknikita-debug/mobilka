"""
Скрипт для ручного применения миграции allow_multiple_connectivity_nodes_per_pole
"""
import asyncio
from sqlalchemy import text
from app.database import async_session_maker
from app.core.config import settings

async def apply_migration():
    async with async_session_maker() as session:
        try:
            # 1. Проверяем, существует ли таблица connectivity_nodes
            result = await session.execute(text("""
                SELECT EXISTS (
                    SELECT FROM information_schema.tables 
                    WHERE table_name = 'connectivity_nodes'
                );
            """))
            table_exists = result.scalar()
            
            if not table_exists:
                print("Таблица connectivity_nodes не существует. Пропускаем миграцию.")
                return
            
            # 2. Удаляем unique constraint с pole_id (если есть)
            result = await session.execute(text("""
                SELECT constraint_name 
                FROM information_schema.table_constraints 
                WHERE table_name = 'connectivity_nodes' 
                AND constraint_type = 'UNIQUE' 
                AND constraint_name LIKE '%pole_id%';
            """))
            constraints = result.fetchall()
            
            for constraint in constraints:
                constraint_name = constraint[0]
                await session.execute(text(f"ALTER TABLE connectivity_nodes DROP CONSTRAINT IF EXISTS {constraint_name};"))
                print(f"Удалён unique constraint '{constraint_name}' с pole_id")
            
            # 3. Проверяем, существует ли колонка power_line_id
            result = await session.execute(text("""
                SELECT EXISTS (
                    SELECT FROM information_schema.columns 
                    WHERE table_name = 'connectivity_nodes' 
                    AND column_name = 'power_line_id'
                );
            """))
            column_exists = result.scalar()
            
            if not column_exists:
                # Добавляем колонку как nullable
                await session.execute(text("""
                    ALTER TABLE connectivity_nodes 
                    ADD COLUMN power_line_id INTEGER;
                """))
                print("Добавлена колонка power_line_id")
                
                # Заполняем power_line_id из связанной опоры
                await session.execute(text("""
                    UPDATE connectivity_nodes
                    SET power_line_id = (
                        SELECT power_line_id
                        FROM poles
                        WHERE poles.id = connectivity_nodes.pole_id
                    )
                    WHERE power_line_id IS NULL;
                """))
                print("Заполнен power_line_id из опор")
                
                # Делаем колонку NOT NULL
                await session.execute(text("""
                    ALTER TABLE connectivity_nodes 
                    ALTER COLUMN power_line_id SET NOT NULL;
                """))
                print("Установлен NOT NULL для power_line_id")
                
                # Добавляем foreign key
                await session.execute(text("""
                    ALTER TABLE connectivity_nodes 
                    ADD CONSTRAINT fk_connectivity_nodes_power_line 
                    FOREIGN KEY (power_line_id) 
                    REFERENCES power_lines(id);
                """))
                print("Добавлен foreign key для power_line_id")
                
                # Создаём индекс
                await session.execute(text("""
                    CREATE INDEX IF NOT EXISTS ix_connectivity_nodes_power_line_id 
                    ON connectivity_nodes(power_line_id);
                """))
                print("Создан индекс для power_line_id")
            else:
                print("Колонка power_line_id уже существует")
            
            await session.commit()
            print("✅ Миграция успешно применена!")
            
        except Exception as e:
            await session.rollback()
            print(f"❌ Ошибка при применении миграции: {e}")
            raise

if __name__ == "__main__":
    asyncio.run(apply_migration())

