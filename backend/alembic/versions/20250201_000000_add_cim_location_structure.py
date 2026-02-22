"""Add CIM Location and PositionPoint structure

Revision ID: 20250201_000000
Revises: 20250131_000000
Create Date: 2025-02-01 00:00:00.000000

Поддерживаются имена таблиц: pole/poles, substation/substations, tap/taps.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = '20250201_000000'
down_revision = '20250131_000000'
branch_labels = None
depends_on = None


def _resolve_table(inspector, options):
    tables = inspector.get_table_names()
    for name in options:
        if name in tables:
            return name
    return None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    pole_t = _resolve_table(inspector, ('pole', 'poles'))
    substation_t = _resolve_table(inspector, ('substation', 'substations'))
    tap_t = _resolve_table(inspector, ('tap', 'taps'))

    # Таблица locations без enum (VARCHAR + CHECK), чтобы не зависеть от существующего locationtype в БД
    op.execute(sa.text("""
        CREATE TABLE IF NOT EXISTS locations (
            id SERIAL PRIMARY KEY,
            mrid VARCHAR(36) NOT NULL UNIQUE,
            location_type VARCHAR(20) NOT NULL DEFAULT 'point' CHECK (location_type IN ('point', 'line', 'area')),
            address TEXT,
            description TEXT,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
            updated_at TIMESTAMP WITH TIME ZONE
        )
    """))
    op.execute(sa.text("CREATE UNIQUE INDEX IF NOT EXISTS ix_locations_mrid ON locations (mrid)"))

    # Создаем таблицу position_points через IF NOT EXISTS (идемпотентно при любом порядке применения веток)
    op.execute(sa.text("""
        CREATE TABLE IF NOT EXISTS position_points (
            id SERIAL NOT NULL,
            mrid VARCHAR(36) NOT NULL,
            location_id INTEGER NOT NULL,
            x_position FLOAT NOT NULL,
            y_position FLOAT NOT NULL,
            z_position FLOAT,
            sequence_number INTEGER DEFAULT 1,
            description TEXT,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
            updated_at TIMESTAMP WITH TIME ZONE,
            PRIMARY KEY (id),
            FOREIGN KEY (location_id) REFERENCES locations (id),
            UNIQUE (mrid)
        )
    """))
    op.execute(sa.text("CREATE UNIQUE INDEX IF NOT EXISTS ix_position_points_mrid ON position_points (mrid)"))
    op.execute(sa.text("CREATE INDEX IF NOT EXISTS ix_position_points_location_id ON position_points (location_id)"))

    def _has_column(tbl, col):
        return col in [c['name'] for c in inspector.get_columns(tbl)]

    pole_mig = pole_t and not _has_column(pole_t, 'location_id')
    if pole_mig:
        op.add_column(pole_t, sa.Column('location_id', sa.Integer(), nullable=True))
        op.create_foreign_key('fk_poles_location', pole_t, 'locations', ['location_id'], ['id'])
        op.create_index(op.f('ix_poles_location_id'), pole_t, ['location_id'], unique=False)
        op.alter_column(pole_t, 'latitude', existing_type=sa.Float(), nullable=True)
        op.alter_column(pole_t, 'longitude', existing_type=sa.Float(), nullable=True)

    substation_mig = substation_t and not _has_column(substation_t, 'location_id')
    if substation_mig:
        op.add_column(substation_t, sa.Column('location_id', sa.Integer(), nullable=True))
        op.create_foreign_key('fk_substations_location', substation_t, 'locations', ['location_id'], ['id'])
        op.create_index(op.f('ix_substations_location_id'), substation_t, ['location_id'], unique=False)
        op.alter_column(substation_t, 'latitude', existing_type=sa.Float(), nullable=True)
        op.alter_column(substation_t, 'longitude', existing_type=sa.Float(), nullable=True)

    tap_mig = tap_t and not _has_column(tap_t, 'location_id')
    if tap_mig:
        op.add_column(tap_t, sa.Column('location_id', sa.Integer(), nullable=True))
        op.create_foreign_key('fk_taps_location', tap_t, 'locations', ['location_id'], ['id'])
        op.create_index(op.f('ix_taps_location_id'), tap_t, ['location_id'], unique=False)

    # Миграция данных: только если колонку только что добавили (избегаем дубликатов Location)
    if pole_t and pole_mig:
        op.execute(sa.text(
            "DO $mig$ DECLARE r RECORD; lid INT; BEGIN "
            "FOR r IN SELECT id, latitude, longitude FROM " + pole_t + " WHERE latitude IS NOT NULL AND longitude IS NOT NULL LOOP "
            "INSERT INTO locations (mrid, location_type, created_at) VALUES (gen_random_uuid()::text, 'point', NOW()) RETURNING id INTO lid; "
            "INSERT INTO position_points (mrid, location_id, x_position, y_position, created_at) VALUES (gen_random_uuid()::text, lid, r.longitude, r.latitude, NOW()); "
            "UPDATE " + pole_t + " SET location_id = lid WHERE id = r.id; END LOOP; END $mig$;"
        ))
    if substation_t and substation_mig:
        op.execute(sa.text(
            "DO $mig$ DECLARE r RECORD; lid INT; BEGIN "
            "FOR r IN SELECT id, latitude, longitude, address FROM " + substation_t + " WHERE latitude IS NOT NULL AND longitude IS NOT NULL LOOP "
            "INSERT INTO locations (mrid, location_type, address, created_at) VALUES (gen_random_uuid()::text, 'point', r.address, NOW()) RETURNING id INTO lid; "
            "INSERT INTO position_points (mrid, location_id, x_position, y_position, created_at) VALUES (gen_random_uuid()::text, lid, r.longitude, r.latitude, NOW()); "
            "UPDATE " + substation_t + " SET location_id = lid WHERE id = r.id; END LOOP; END $mig$;"
        ))
    if tap_t and tap_mig:
        op.execute(sa.text(
            "DO $mig$ DECLARE r RECORD; lid INT; BEGIN "
            "FOR r IN SELECT id, latitude, longitude FROM " + tap_t + " WHERE latitude IS NOT NULL AND longitude IS NOT NULL LOOP "
            "INSERT INTO locations (mrid, location_type, created_at) VALUES (gen_random_uuid()::text, 'point', NOW()) RETURNING id INTO lid; "
            "INSERT INTO position_points (mrid, location_id, x_position, y_position, created_at) VALUES (gen_random_uuid()::text, lid, r.longitude, r.latitude, NOW()); "
            "UPDATE " + tap_t + " SET location_id = lid WHERE id = r.id; END LOOP; END $mig$;"
        ))


def downgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    pole_t = _resolve_table(inspector, ('pole', 'poles'))
    substation_t = _resolve_table(inspector, ('substation', 'substations'))
    tap_t = _resolve_table(inspector, ('tap', 'taps'))

    if tap_t:
        op.drop_index(op.f('ix_taps_location_id'), table_name=tap_t)
        op.drop_constraint('fk_taps_location', tap_t, type_='foreignkey')
        op.drop_column(tap_t, 'location_id')
    if substation_t:
        op.drop_index(op.f('ix_substations_location_id'), table_name=substation_t)
        op.drop_constraint('fk_substations_location', substation_t, type_='foreignkey')
        op.drop_column(substation_t, 'location_id')
        op.alter_column(substation_t, 'longitude', existing_type=sa.Float(), nullable=False)
        op.alter_column(substation_t, 'latitude', existing_type=sa.Float(), nullable=False)
    if pole_t:
        op.drop_index(op.f('ix_poles_location_id'), table_name=pole_t)
        op.drop_constraint('fk_poles_location', pole_t, type_='foreignkey')
        op.drop_column(pole_t, 'location_id')
        op.alter_column(pole_t, 'longitude', existing_type=sa.Float(), nullable=False)
        op.alter_column(pole_t, 'latitude', existing_type=sa.Float(), nullable=False)

    existing_tables_d = inspector.get_table_names()
    if 'position_points' in existing_tables_d:
        op.drop_index(op.f('ix_position_points_location_id'), table_name='position_points')
        op.drop_index(op.f('ix_position_points_mrid'), table_name='position_points')
        op.drop_table('position_points')
    if 'locations' in existing_tables_d:
        op.drop_index(op.f('ix_locations_mrid'), table_name='locations')
        op.drop_table('locations')
    op.execute('DROP TYPE IF EXISTS locationtype')

