"""
Скрипт для создания участка линии для ЛЭП Минск-Западная
"""
import asyncio
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy import select
from app.models.power_line import PowerLine, Pole
from app.models.acline_segment import AClineSegment
from app.models.user import User
from app.core.config import settings

async def create_segment_for_minsk_zapadnaya():
    """Создание участка линии для ЛЭП Минск-Западная"""
    engine = create_async_engine(settings.DATABASE_URL)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    
    async with async_session() as session:
        # Находим ЛЭП Минск-Западная
        result = await session.execute(
            select(PowerLine).where(PowerLine.name.like('%Минск-Западная%'))
        )
        power_line = result.scalar_one_or_none()
        
        if not power_line:
            print("❌ ЛЭП Минск-Западная не найдена")
            return
        
        print(f"✅ Найдена ЛЭП: {power_line.name} (ID: {power_line.id})")
        
        # Находим опоры этой ЛЭП
        result = await session.execute(
            select(Pole).where(Pole.power_line_id == power_line.id).order_by(Pole.id)
        )
        poles = result.scalars().all()
        
        if len(poles) < 2:
            print("❌ Недостаточно опор для создания участка (нужно минимум 2)")
            return
        
        print(f"✅ Найдено опор: {len(poles)}")
        
        # Находим первого пользователя для created_by
        result = await session.execute(select(User).limit(1))
        user = result.scalar_one_or_none()
        
        if not user:
            print("❌ Пользователь не найден")
            return
        
        # Проверяем, существует ли уже участок
        result = await session.execute(
            select(AClineSegment).where(AClineSegment.code == "SEG_MINSK_ZAPADNAYA_1")
        )
        existing_segment = result.scalar_one_or_none()
        
        if existing_segment:
            print(f"✅ Участок уже существует: {existing_segment.name}")
            # Обновляем связи опор с участком
            for pole in poles[:3]:  # Связываем первые 3 опоры с участком
                pole.segment_id = existing_segment.id
            await session.commit()
            print(f"✅ Обновлены связи опор с участком")
            return
        
        # Создаем участок линии
        segment = AClineSegment(
            name="Участок 1: Минск-Западная",
            code="SEG_MINSK_ZAPADNAYA_1",
            voltage_level=power_line.voltage_level,
            length=10.5,  # км
            conductor_type="АС-150",
            conductor_material="алюминий",
            conductor_section="150",
            start_pole_id=poles[0].id if poles else None,
            end_pole_id=poles[-1].id if poles else None,
            r=0.21,  # Ом/км
            x=0.42,  # Ом/км
            description="Участок линии Минск-Западная",
            created_by=user.id
        )
        session.add(segment)
        await session.flush()
        
        # Связываем участок с ЛЭП (many-to-many)
        from sqlalchemy import text
        await session.execute(
            text("INSERT INTO line_segments (power_line_id, acline_segment_id) VALUES (:line_id, :seg_id) ON CONFLICT DO NOTHING"),
            {"line_id": power_line.id, "seg_id": segment.id}
        )
        
        # Связываем опоры с участком
        for pole in poles[:3]:  # Связываем первые 3 опоры с участком
            pole.segment_id = segment.id
        
        await session.commit()
        print(f"✅ Создан участок: {segment.name} (ID: {segment.id})")
        print(f"✅ Связано опор с участком: 3")

if __name__ == "__main__":
    asyncio.run(create_segment_for_minsk_zapadnaya())

