import asyncio

from sqlalchemy import and_, func, select

from app.api.v1.equipment_catalog import _default_catalog_payloads
from app.database import AsyncSessionLocal
from app.models.equipment_catalog import EquipmentCatalogItem


async def main() -> None:
    defaults = _default_catalog_payloads()
    inserted = 0
    updated = 0

    async with AsyncSessionLocal() as db:
        for row in defaults:
            existing = (
                await db.execute(
                    select(EquipmentCatalogItem).where(
                        and_(
                            EquipmentCatalogItem.type_code == row["type_code"],
                            func.lower(EquipmentCatalogItem.brand)
                            == row["brand"].lower(),
                            func.lower(EquipmentCatalogItem.model)
                            == row["model"].lower(),
                        )
                    )
                )
            ).scalar_one_or_none()

            if existing:
                changed = False
                new_fn = row.get("full_name")
                if new_fn and getattr(existing, "full_name") != new_fn:
                    setattr(existing, "full_name", new_fn)
                    changed = True
                for field in (
                    "voltage_kv",
                    "current_a",
                    "manufacturer",
                    "country",
                    "description",
                    "attrs_json",
                ):
                    current_value = getattr(existing, field)
                    new_value = row.get(field)
                    is_empty = current_value is None or (
                        isinstance(current_value, str)
                        and not current_value.strip()
                    )
                    if is_empty and new_value is not None:
                        setattr(existing, field, new_value)
                        changed = True
                if changed:
                    updated += 1
                continue

            db.add(EquipmentCatalogItem(**row, created_by=None))
            inserted += 1

        await db.commit()

    print(
        {
            "inserted": inserted,
            "updated": updated,
            "total_defaults": len(defaults),
        }
    )


if __name__ == "__main__":
    asyncio.run(main())
