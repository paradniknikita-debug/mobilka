"""
Скрипт для массового импорта данных из Excel файлов
Использование: python import_from_excel.py <тип> <путь_к_файлу>

Типы:
- power-lines: Импорт ЛЭП
- poles: Импорт опор
- substations: Импорт подстанций
- equipment: Импорт оборудования
"""
import sys
import asyncio
import pandas as pd
from pathlib import Path

from app.database import AsyncSessionLocal
from app.models.power_line import PowerLine, Pole, Equipment
from app.models.substation import Substation
from app.models.geographic_region import GeographicRegion
from app.models.user import User
from sqlalchemy import select


async def get_or_create_region(session, region_code=None, region_name=None, region_id=None):
    """Получить или создать географический регион"""
    if region_id:
        region = await session.get(GeographicRegion, region_id)
        if region:
            return region_id
    
    if region_code:
        result = await session.execute(
            select(GeographicRegion).where(GeographicRegion.code == region_code)
        )
        region = result.scalar_one_or_none()
        if region:
            return region.id
    
    if region_code and region_name:
        new_region = GeographicRegion(
            code=region_code,
            name=region_name,
            region_type="РЭС",
            level=2
        )
        session.add(new_region)
        await session.flush()
        return new_region.id
    
    return None


async def get_first_user(session):
    """Получить первого пользователя для created_by"""
    result = await session.execute(select(User).limit(1))
    user = result.scalar_one_or_none()
    if not user:
        raise Exception("В базе данных нет пользователей. Создайте пользователя через API или seed_test_data.py")
    return user.id


async def import_power_lines(file_path: str):
    """Импорт ЛЭП из Excel"""
    df = pd.read_excel(file_path)
    
    required_columns = ['name', 'code', 'voltage_level']
    missing = [col for col in required_columns if col not in df.columns]
    if missing:
        print(f"❌ Отсутствуют обязательные колонки: {', '.join(missing)}")
        return
    
    async with AsyncSessionLocal() as session:
        try:
            user_id = await get_first_user(session)
            created = 0
            errors = []
            
            for idx, row in df.iterrows():
                try:
                    # Проверка уникальности
                    existing = await session.execute(
                        select(PowerLine).where(PowerLine.code == str(row['code']))
                    )
                    if existing.scalar_one_or_none():
                        errors.append(f"Строка {idx + 2}: ЛЭП с кодом '{row['code']}' уже существует")
                        continue
                    
                    # Регион
                    region_id = None
                    if 'region_code' in df.columns and pd.notna(row.get('region_code')):
                        region_id = await get_or_create_region(
                            session,
                            region_code=str(row['region_code']),
                            region_name=str(row.get('region_name', ''))
                        )
                    
                    # Создание ЛЭП
                    power_line = PowerLine(
                        name=str(row['name']),
                        code=str(row['code']),
                        voltage_level=float(row['voltage_level']),
                        length=float(row['length']) if pd.notna(row.get('length')) else None,
                        region_id=region_id,
                        status=str(row.get('status', 'active')),
                        description=str(row['description']) if pd.notna(row.get('description')) else None,
                        created_by=user_id
                    )
                    session.add(power_line)
                    created += 1
                    print(f"✓ Строка {idx + 2}: Создана ЛЭП '{row['name']}'")
                    
                except Exception as e:
                    errors.append(f"Строка {idx + 2}: {str(e)}")
                    print(f"✗ Строка {idx + 2}: Ошибка - {str(e)}")
            
            await session.commit()
            print(f"\n✅ Импортировано {created} ЛЭП")
            if errors:
                print(f"⚠️ Ошибки ({len(errors)}):")
                for error in errors[:10]:  # Показываем первые 10 ошибок
                    print(f"  - {error}")
                if len(errors) > 10:
                    print(f"  ... и ещё {len(errors) - 10} ошибок")
                    
        except Exception as e:
            await session.rollback()
            print(f"❌ Критическая ошибка: {str(e)}")


async def import_poles(file_path: str):
    """Импорт опор из Excel"""
    df = pd.read_excel(file_path)
    
    required_columns = ['power_line_code', 'pole_number', 'latitude', 'longitude', 'pole_type']
    missing = [col for col in required_columns if col not in df.columns]
    if missing:
        print(f"❌ Отсутствуют обязательные колонки: {', '.join(missing)}")
        return
    
    async with AsyncSessionLocal() as session:
        try:
            user_id = await get_first_user(session)
            created = 0
            errors = []
            
            for idx, row in df.iterrows():
                try:
                    # Находим ЛЭП
                    power_line_result = await session.execute(
                        select(PowerLine).where(PowerLine.code == str(row['power_line_code']))
                    )
                    power_line = power_line_result.scalar_one_or_none()
                    
                    if not power_line:
                        errors.append(f"Строка {idx + 2}: ЛЭП '{row['power_line_code']}' не найдена")
                        continue
                    
                    # Создание опоры
                    pole = Pole(
                        line_id=power_line.id,
                        pole_number=str(row['pole_number']),
                        latitude=float(row['latitude']),
                        longitude=float(row['longitude']),
                        pole_type=str(row['pole_type']),
                        height=float(row['height']) if pd.notna(row.get('height')) else None,
                        foundation_type=str(row['foundation_type']) if pd.notna(row.get('foundation_type')) else None,
                        material=str(row['material']) if pd.notna(row.get('material')) else None,
                        year_installed=int(row['year_installed']) if pd.notna(row.get('year_installed')) else None,
                        condition=str(row.get('condition', 'good')),
                        notes=str(row['notes']) if pd.notna(row.get('notes')) else None,
                        created_by=user_id
                    )
                    session.add(pole)
                    created += 1
                    print(f"✓ Строка {idx + 2}: Создана опора '{row['pole_number']}'")
                    
                except Exception as e:
                    errors.append(f"Строка {idx + 2}: {str(e)}")
                    print(f"✗ Строка {idx + 2}: Ошибка - {str(e)}")
            
            await session.commit()
            print(f"\n✅ Импортировано {created} опор")
            if errors:
                print(f"⚠️ Ошибки ({len(errors)}):")
                for error in errors[:10]:
                    print(f"  - {error}")
                if len(errors) > 10:
                    print(f"  ... и ещё {len(errors) - 10} ошибок")
                    
        except Exception as e:
            await session.rollback()
            print(f"❌ Критическая ошибка: {str(e)}")


async def import_substations(file_path: str):
    """Импорт подстанций из Excel"""
    df = pd.read_excel(file_path)
    
    required_columns = ['name', 'code', 'voltage_level', 'latitude', 'longitude']
    missing = [col for col in required_columns if col not in df.columns]
    if missing:
        print(f"❌ Отсутствуют обязательные колонки: {', '.join(missing)}")
        return
    
    async with AsyncSessionLocal() as session:
        try:
            created = 0
            errors = []
            
            for idx, row in df.iterrows():
                try:
                    # Проверка уникальности
                    existing = await session.execute(
                        select(Substation).where(Substation.code == str(row['code']))
                    )
                    if existing.scalar_one_or_none():
                        errors.append(f"Строка {idx + 2}: Подстанция с кодом '{row['code']}' уже существует")
                        continue
                    
                    # Регион
                    region_id = None
                    if 'region_code' in df.columns and pd.notna(row.get('region_code')):
                        region_id = await get_or_create_region(
                            session,
                            region_code=str(row['region_code']),
                            region_name=str(row.get('region_name', ''))
                        )
                    
                    # Создание подстанции
                    substation = Substation(
                        name=str(row['name']),
                        code=str(row['code']),
                        voltage_level=float(row['voltage_level']),
                        latitude=float(row['latitude']),
                        longitude=float(row['longitude']),
                        address=str(row['address']) if pd.notna(row.get('address')) else None,
                        region_id=region_id,
                        description=str(row['description']) if pd.notna(row.get('description')) else None,
                        is_active=True
                    )
                    session.add(substation)
                    created += 1
                    print(f"✓ Строка {idx + 2}: Создана подстанция '{row['name']}'")
                    
                except Exception as e:
                    errors.append(f"Строка {idx + 2}: {str(e)}")
                    print(f"✗ Строка {idx + 2}: Ошибка - {str(e)}")
            
            await session.commit()
            print(f"\n✅ Импортировано {created} подстанций")
            if errors:
                print(f"⚠️ Ошибки ({len(errors)}):")
                for error in errors[:10]:
                    print(f"  - {error}")
                if len(errors) > 10:
                    print(f"  ... и ещё {len(errors) - 10} ошибок")
                    
        except Exception as e:
            await session.rollback()
            print(f"❌ Критическая ошибка: {str(e)}")


async def import_equipment(file_path: str):
    """Импорт оборудования из Excel"""
    df = pd.read_excel(file_path)
    
    required_columns = ['power_line_code', 'pole_number', 'equipment_type', 'name']
    missing = [col for col in required_columns if col not in df.columns]
    if missing:
        print(f"❌ Отсутствуют обязательные колонки: {', '.join(missing)}")
        return
    
    async with AsyncSessionLocal() as session:
        try:
            user_id = await get_first_user(session)
            created = 0
            errors = []
            
            for idx, row in df.iterrows():
                try:
                    # Находим ЛЭП и опору
                    power_line_result = await session.execute(
                        select(PowerLine).where(PowerLine.code == str(row['power_line_code']))
                    )
                    power_line = power_line_result.scalar_one_or_none()
                    
                    if not power_line:
                        errors.append(f"Строка {idx + 2}: ЛЭП '{row['power_line_code']}' не найдена")
                        continue
                    
                    pole_result = await session.execute(
                        select(Pole).where(
                            Pole.line_id == power_line.id,
                            Pole.pole_number == str(row['pole_number'])
                        )
                    )
                    pole = pole_result.scalar_one_or_none()
                    
                    if not pole:
                        errors.append(f"Строка {idx + 2}: Опора '{row['pole_number']}' не найдена")
                        continue
                    
                    # Создание оборудования
                    equipment = Equipment(
                        pole_id=pole.id,
                        equipment_type=str(row['equipment_type']),
                        name=str(row['name']),
                        manufacturer=str(row['manufacturer']) if pd.notna(row.get('manufacturer')) else None,
                        model=str(row['model']) if pd.notna(row.get('model')) else None,
                        serial_number=str(row['serial_number']) if pd.notna(row.get('serial_number')) else None,
                        year_manufactured=int(row['year_manufactured']) if pd.notna(row.get('year_manufactured')) else None,
                        condition=str(row.get('condition', 'good')),
                        notes=str(row['notes']) if pd.notna(row.get('notes')) else None,
                        created_by=user_id
                    )
                    session.add(equipment)
                    created += 1
                    print(f"✓ Строка {idx + 2}: Создано оборудование '{row['name']}'")
                    
                except Exception as e:
                    errors.append(f"Строка {idx + 2}: {str(e)}")
                    print(f"✗ Строка {idx + 2}: Ошибка - {str(e)}")
            
            await session.commit()
            print(f"\n✅ Импортировано {created} единиц оборудования")
            if errors:
                print(f"⚠️ Ошибки ({len(errors)}):")
                for error in errors[:10]:
                    print(f"  - {error}")
                if len(errors) > 10:
                    print(f"  ... и ещё {len(errors) - 10} ошибок")
                    
        except Exception as e:
            await session.rollback()
            print(f"❌ Критическая ошибка: {str(e)}")


async def main():
    if len(sys.argv) < 3:
        print("Использование: python import_from_excel.py <тип> <путь_к_файлу>")
        print("\nТипы:")
        print("  power-lines  - Импорт ЛЭП")
        print("  poles        - Импорт опор")
        print("  substations  - Импорт подстанций")
        print("  equipment    - Импорт оборудования")
        sys.exit(1)
    
    import_type = sys.argv[1]
    file_path = sys.argv[2]
    
    if not Path(file_path).exists():
        print(f"❌ Файл не найден: {file_path}")
        sys.exit(1)
    
    print(f"📂 Импорт из файла: {file_path}")
    print(f"📋 Тип: {import_type}\n")
    
    if import_type == "power-lines":
        await import_power_lines(file_path)
    elif import_type == "poles":
        await import_poles(file_path)
    elif import_type == "substations":
        await import_substations(file_path)
    elif import_type == "equipment":
        await import_equipment(file_path)
    else:
        print(f"❌ Неизвестный тип: {import_type}")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())

