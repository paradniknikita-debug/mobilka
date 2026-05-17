"""Добавить equipment.card_comment и card_comment_attachment, если отсутствуют."""
import asyncio

from sqlalchemy import text

from app.database import engine


async def main() -> None:
    async with engine.begin() as conn:
        await conn.execute(
            text("ALTER TABLE equipment ADD COLUMN IF NOT EXISTS card_comment TEXT")
        )
        await conn.execute(
            text(
                "ALTER TABLE equipment ADD COLUMN IF NOT EXISTS card_comment_attachment TEXT"
            )
        )
        result = await conn.execute(
            text(
                """
                SELECT column_name
                FROM information_schema.columns
                WHERE table_schema = 'public'
                  AND table_name = 'equipment'
                  AND column_name IN ('card_comment', 'card_comment_attachment')
                ORDER BY column_name
                """
            )
        )
        cols = [row[0] for row in result.fetchall()]
    print("OK. equipment columns:", cols)


if __name__ == "__main__":
    asyncio.run(main())
