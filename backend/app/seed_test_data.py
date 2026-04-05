"""
Скрипт для добавления тестовых данных в базу данных
Использование: python seed_test_data.py
"""
import asyncio
import sys
import os


# Добавляем путь к проекту
sys.path.insert(0, os.path.dirname(__file__))

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import AsyncSessionLocal, init_db
from app.core.security import get_password_hash
from app.models import (User, GeographicRegion, PowerLine, Pole, AClineSegment, Substation, Branch)
from app.models.location import PositionPoint
from app.models.base import generate_mrid



async def create_test_data():
    """Создание тестовых данных"""
    
    # Инициализация БД (создание таблиц, если их нет)
    await init_db()
    
    async with AsyncSessionLocal() as session:
        try:
            # 1. Создаем пользователя (если его нет)
            result = await session.execute(select(User).where(User.id == 1))
            user = result.scalar_one_or_none()
            if not user:
                user = User(
                    username="admin",
                    email="admin@example.com",
                    full_name="Администратор",
                    hashed_password=get_password_hash("admin123"),
                    is_active=True,
                    is_superuser=True,
                    role="admin"
                )
                session.add(user)
                await session.flush()  # Получаем ID пользователя
                print("✅ Создан пользователь: admin / admin123")
            else:
                print("ℹ️  Пользователь уже существует")
            
            # 2. Создаем Branch (для обратной совместимости)
            result = await session.execute(select(Branch).where(Branch.code == "TEST_BRANCH"))
            branch = result.scalar_one_or_none()
            if not branch:
                branch = Branch(
                    name="Тестовый филиал",
                    code="TEST_BRANCH",
                    address="г. Минск, ул. Тестовая, 1",
                    is_active=True
                )
                session.add(branch)
                await session.flush()
                print("✅ Создан филиал: Тестовый филиал")
            
            # 3. Создаем географическую иерархию
            # Рабочая область (корневой уровень)
            result = await session.execute(select(GeographicRegion).where(GeographicRegion.code == "WORK_AREA_1"))
            root_region = result.scalar_one_or_none()
            if not root_region:
                root_region = GeographicRegion(
                    name="Рабочая область Минск",
                    code="WORK_AREA_1",
                    region_type="рабочая_область",
                    level=0,
                    parent_id=None,
                    description="Основная рабочая область для Минска",
                    is_active=True
                )
                session.add(root_region)
                await session.flush()
                print("✅ Создана рабочая область: Минск")
            
            # ФЭС (уровень 1)
            result = await session.execute(select(GeographicRegion).where(GeographicRegion.code == "FES_1"))
            fes_region = result.scalar_one_or_none()
            if not fes_region:
                fes_region = GeographicRegion(
                    name="ФЭС Минская",
                    code="FES_1",
                    region_type="ФЭС",
                    level=1,
                    parent_id=root_region.id,
                    description="Федеральная энергосистема Минская",
                    is_active=True
                )
                session.add(fes_region)
                await session.flush()
                print("✅ Создана ФЭС: Минская")
            
            # РЭС (уровень 2)
            result = await session.execute(select(GeographicRegion).where(GeographicRegion.code == "RES_1"))
            res_region = result.scalar_one_or_none()
            if not res_region:
                res_region = GeographicRegion(
                    name="РЭС Минск-Запад",
                    code="RES_1",
                    region_type="РЭС",
                    level=2,
                    parent_id=fes_region.id,
                    description="Региональная энергосистема Минск-Запад",
                    is_active=True
                )
                session.add(res_region)
                await session.flush()
                print("✅ Создан РЭС: Минск-Запад")
            
            # 4. Создаем подстанцию (модель использует dispatcher_name, не code)
            result = await session.execute(select(Substation).where(Substation.dispatcher_name == "SUB_110_1"))
            substation = result.scalar_one_or_none()
            if not substation:
                substation = Substation(
                    name="Подстанция 110/10 кВ №1",
                    dispatcher_name="SUB_110_1",
                    voltage_level=110.0,
                    y_position=53.9045,
                    x_position=27.5615,
                    address="г. Минск, ул. Подстанционная, 1",
                    region_id=res_region.id,
                    branch_id=branch.id if branch else None,
                    description="Тестовая подстанция 110 кВ",
                    is_active=True
                )
                session.add(substation)
                await session.flush()
                print("✅ Создана подстанция: Подстанция 110/10 кВ №1")
            
            # 5. Создаем линию электропередачи
            result = await session.execute(select(PowerLine).where(PowerLine.name == "ЛЭП 110 кВ Минск-Западная"))
            power_line = result.scalar_one_or_none()
            if not power_line:
                from app.models.base import generate_mrid
                power_line = PowerLine(
                    mrid=generate_mrid(),
                    name="ЛЭП 110 кВ Минск-Западная",
                    voltage_level=110.0,
                    length=25.5,  # км
                    region_id=res_region.id,
                    branch_id=branch.id if branch else None,
                    created_by=user.id,
                    status="active",
                    description="Тестовая линия 110 кВ"
                )
                session.add(power_line)
                await session.flush()
                print("✅ Создана линия: ЛЭП 110 кВ Минск-Западная")
            
            # 6. Создаем опоры
            poles_data = [
                {
                    "pole_number": "001",
                    "y_position": 53.9045,
                    "x_position": 27.5615,
                    "pole_type": "анкерная",
                    "height": 25.0
                },
                {
                    "pole_number": "002",
                    "y_position": 53.9100,
                    "x_position": 27.5700,
                    "pole_type": "промежуточная",
                    "height": 23.0
                },
                {
                    "pole_number": "003",
                    "y_position": 53.9150,
                    "x_position": 27.5800,
                    "pole_type": "промежуточная",
                    "height": 23.0
                },
                {
                    "pole_number": "004",
                    "y_position": 53.9200,
                    "x_position": 27.5900,
                    "pole_type": "анкерная",
                    "height": 25.0
                },
            ]
            
            poles = []
            for i, pole_data in enumerate(poles_data):
                result = await session.execute(
                    select(Pole).where(
                        Pole.line_id == power_line.id,
                        Pole.pole_number == pole_data["pole_number"]
                    )
                )
                existing_pole = result.scalar_one_or_none()
                if not existing_pole:
                    pole = Pole(
                        line_id=power_line.id,
                        pole_number=pole_data["pole_number"],
                        pole_type=pole_data["pole_type"],
                        height=pole_data["height"],
                        material="металл",
                        foundation_type="железобетон",
                        year_installed=2020,
                        condition="good",
                        sequence_number=i + 1,
                        created_by=user.id
                    )
                    session.add(pole)
                    await session.flush()
                    pp = PositionPoint(
                        mrid=generate_mrid(),
                        y_position=pole_data["y_position"],
                        x_position=pole_data["x_position"],
                        pole_id=pole.id
                    )
                    session.add(pp)
                    poles.append(pole)
            
            await session.flush()
            print(f"✅ Создано опор: {len(poles)}")
            
            # 7. Сегменты линии (AClineSegment) — минимальное создание; полная топология через API.
            if len(poles) >= 2:
                result = await session.execute(select(AClineSegment).where(AClineSegment.line_id == power_line.id).limit(1))
                if result.scalar_one_or_none() is None:
                    seg_mrid = generate_mrid()
                    segment1 = AClineSegment(
                        mrid=seg_mrid,
                        name="Сегмент 1",
                        code=seg_mrid,
                        line_id=power_line.id,
                        voltage_level=110.0,
                        length=0.0,
                        sequence_number=1,
                        created_by=user.id,
                    )
                    session.add(segment1)
                    await session.flush()

            # Сохраняем все изменения
            await session.commit()
            print("\n✅ Все тестовые данные успешно добавлены!")
            print("\n📊 Структура данных:")
            print("   - 1 пользователь (admin/admin123)")
            print("   - 1 рабочая область")
            print("   - 1 ФЭС")
            print("   - 1 РЭС")
            print("   - 1 подстанция")
            print("   - 1 линия электропередачи")
            print("   - 4 опоры")
            
        except Exception as e:
            await session.rollback()
            print(f"❌ Ошибка при создании тестовых данных: {e}")
            raise


if __name__ == "__main__":
    print("🌱 Начинаю создание тестовых данных...\n")
    asyncio.run(create_test_data())

