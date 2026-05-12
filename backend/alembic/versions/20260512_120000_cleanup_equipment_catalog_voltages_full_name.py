"""Удаление марок 12/17.5/24 кВ; нормализация full_name (без дублирования марки).

Revision ID: 20260512_120000
Revises: 20260505_181500, 20260511_200000
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = "20260512_120000"
down_revision = ("20260505_181500", "20260511_200000")
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    insp = inspect(bind)
    if not insp.has_table("equipment_catalog"):
        return

    op.execute(
        sa.text(
            """
            UPDATE equipment
            SET catalog_item_id = NULL
            WHERE catalog_item_id IN (
                SELECT id FROM equipment_catalog
                WHERE voltage_kv IN (12, 17.5, 24)
            )
            """
        )
    )
    op.execute(
        sa.text(
            """
            DELETE FROM equipment_catalog
            WHERE voltage_kv IN (12, 17.5, 24)
            """
        )
    )
    op.execute(
        sa.text(
            """
            UPDATE equipment_catalog
            SET full_name = CASE
              WHEN NULLIF(TRIM(brand), '') IS NULL OR NULLIF(TRIM(model), '') IS NULL THEN full_name
              WHEN LOWER(TRIM(model)) = LOWER(TRIM(brand)) THEN TRIM(model)
              WHEN starts_with(LOWER(TRIM(model)), LOWER(TRIM(brand)) || '-') THEN TRIM(model)
              WHEN starts_with(LOWER(TRIM(model)), LOWER(TRIM(brand)) || ' ') THEN TRIM(model)
              ELSE TRIM(brand) || ' ' || TRIM(model)
            END
            """
        )
    )


def downgrade() -> None:
    # Данные каталога и ссылки не восстанавливаем
    pass
