"""
Скрипт для переноса данных из towers в poles и обновления всех внешних ключей
"""
import asyncio
from sqlalchemy import text
from app.database import async_session_maker

async def fix_towers_to_poles():
    """Переносит данные из towers в poles и обновляет все внешние ключи"""
    async with async_session_maker() as session:
        try:
            # 1. Проверяем, есть ли данные в towers
            result = await session.execute(text("SELECT COUNT(*) FROM towers"))
            towers_count = result.scalar()
            print(f"Найдено записей в towers: {towers_count}")
            
            if towers_count == 0:
                print("Таблица towers пуста, пропускаем перенос данных")
            else:
                # 2. Переносим данные из towers в poles
                print("Перенос данных из towers в poles...")
                await session.execute(text("""
                    INSERT INTO poles (
                        id, mrid, power_line_id, segment_id, 
                        pole_number, latitude, longitude, pole_type,
                        height, foundation_type, material, year_installed,
                        condition, notes, created_by, created_at, updated_at
                    )
                    SELECT 
                        id, mrid, power_line_id, segment_id,
                        tower_number, latitude, longitude, tower_type,
                        height, foundation_type, material, year_installed,
                        condition, notes, created_by, created_at, updated_at
                    FROM towers
                    ON CONFLICT (id) DO NOTHING
                """))
                print("Данные перенесены")
            
            # 3. Обновляем внешние ключи в spans
            print("Обновление внешних ключей в spans...")
            await session.execute(text("""
                UPDATE spans 
                SET from_pole_id = from_tower_id, to_pole_id = to_tower_id
                WHERE from_tower_id IS NOT NULL OR to_tower_id IS NOT NULL
            """))
            
            # 4. Обновляем внешние ключи в taps
            print("Обновление внешних ключей в taps...")
            await session.execute(text("""
                UPDATE taps 
                SET pole_id = tower_id
                WHERE tower_id IS NOT NULL
            """))
            
            # 5. Обновляем внешние ключи в equipment
            print("Обновление внешних ключей в equipment...")
            await session.execute(text("""
                UPDATE equipment 
                SET pole_id = tower_id
                WHERE tower_id IS NOT NULL
            """))
            
            # 6. Обновляем внешние ключи в acline_segments
            print("Обновление внешних ключей в acline_segments...")
            await session.execute(text("""
                UPDATE acline_segments 
                SET start_pole_id = start_tower_id, end_pole_id = end_tower_id
                WHERE start_tower_id IS NOT NULL OR end_tower_id IS NOT NULL
            """))
            
            await session.commit()
            print("✅ Все данные перенесены и внешние ключи обновлены!")
            
            # 7. Проверяем результат
            result = await session.execute(text("SELECT COUNT(*) FROM poles"))
            poles_count = result.scalar()
            print(f"Записей в poles: {poles_count}")
            
        except Exception as e:
            await session.rollback()
            print(f"❌ Ошибка: {e}")
            raise

if __name__ == "__main__":
    asyncio.run(fix_towers_to_poles())

