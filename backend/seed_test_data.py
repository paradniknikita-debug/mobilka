"""
Скрипт для добавления тестовых данных в базу данных.

Использование:
    python seed_test_data.py

Или после пересоздания БД (recreate_db.py):
    python recreate_db.py
"""
import asyncio
import sys
import os
from datetime import datetime

# Добавляем путь к проекту
sys.path.insert(0, os.path.dirname(__file__))

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import AsyncSessionLocal, init_db
from app.models import (
    User,
    GeographicRegion,
    PowerLine,
    Pole,
    Substation,
    Branch,
)
from app.core.security import get_password_hash


async def create_test_data():
    """Создание тестовых данных."""

    # Инициализация БД (создание таблиц, если их нет)
    await init_db()

    async with AsyncSessionLocal() as session:
        try:
            # 1. Пользователь
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
                    role="admin",
                )
                session.add(user)
                await session.flush()
                print("[OK] Создан пользователь: admin / admin123")
            else:
                print("[i] Пользователь уже существует")

            # 2. Филиал
            result = await session.execute(select(Branch).where(Branch.code == "TEST_BRANCH"))
            branch = result.scalar_one_or_none()
            if not branch:
                branch = Branch(
                    name="Тестовый филиал",
                    code="TEST_BRANCH",
                    address="г. Минск, ул. Тестовая, 1",
                    is_active=True,
                )
                session.add(branch)
                await session.flush()
                print("[OK] Создан филиал: Тестовый филиал")

            # 3. Географическая иерархия
            result = await session.execute(
                select(GeographicRegion).where(GeographicRegion.code == "WORK_AREA_1")
            )
            root_region = result.scalar_one_or_none()
            if not root_region:
                root_region = GeographicRegion(
                    name="Рабочая область Минск",
                    code="WORK_AREA_1",
                    region_type="рабочая_область",
                    level=0,
                    parent_id=None,
                    description="Основная рабочая область для Минска",
                    is_active=True,
                )
                session.add(root_region)
                await session.flush()
                print("[OK] Создана рабочая область: Минск")

            result = await session.execute(
                select(GeographicRegion).where(GeographicRegion.code == "FES_1")
            )
            fes_region = result.scalar_one_or_none()
            if not fes_region:
                fes_region = GeographicRegion(
                    name="ФЭС Минская",
                    code="FES_1",
                    region_type="ФЭС",
                    level=1,
                    parent_id=root_region.id,
                    description="Федеральная энергосистема Минская",
                    is_active=True,
                )
                session.add(fes_region)
                await session.flush()
                print("[OK] Создана ФЭС: Минская")

            result = await session.execute(
                select(GeographicRegion).where(GeographicRegion.code == "RES_1")
            )
            res_region = result.scalar_one_or_none()
            if not res_region:
                res_region = GeographicRegion(
                    name="РЭС Минск-Запад",
                    code="RES_1",
                    region_type="РЭС",
                    level=2,
                    parent_id=fes_region.id,
                    description="Региональная энергосистема Минск-Запад",
                    is_active=True,
                )
                session.add(res_region)
                await session.flush()
                print("[OK] Создан РЭС: Минск-Запад")

            # 4. Подстанция (координаты в x_position = долгота, y_position = широта)
            result = await session.execute(
                select(Substation).where(Substation.dispatcher_name == "SUB_110_1")
            )
            substation = result.scalar_one_or_none()
            if not substation:
                substation = Substation(
                    name="Подстанция 110/10 кВ №1",
                    dispatcher_name="SUB_110_1",
                    voltage_level=110.0,
                    y_position=53.9045,   # широта
                    x_position=27.5615,   # долгота
                    address="г. Минск, ул. Подстанционная, 1",
                    region_id=res_region.id,
                    branch_id=branch.id if branch else None,
                    description="Тестовая подстанция 110 кВ",
                    is_active=True,
                )
                session.add(substation)
                await session.flush()
                print("[OK] Создана подстанция: Подстанция 110/10 кВ №1")

            
            await session.commit()
            print("\n[OK] Все тестовые данные успешно добавлены!")
            print("\nСтруктура данных:")
            print("   - 1 пользователь (admin / admin123)")
            print("   - 1 рабочая область, 1 ФЭС, 1 РЭС")
            print("   - 1 подстанция")

        except Exception as e:
            await session.rollback()
            print(f"[FAIL] Ошибка при создании тестовых данных: {e}")
            raise


if __name__ == "__main__":
    print("Начинаю создание тестовых данных...\n")
    asyncio.run(create_test_data())
