"""Add CIM Location and PositionPoint structure

Revision ID: 20250201_000000
Revises: 20250131_000000
Create Date: 2025-02-01 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '20250201_000000'
down_revision = '20250131_000000'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Создаем enum для LocationType
    location_type_enum = postgresql.ENUM('point', 'line', 'area', name='locationtype', create_type=False)
    location_type_enum.create(op.get_bind(), checkfirst=True)
    
    # Создаем таблицу locations
    op.create_table(
        'locations',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('mrid', sa.String(length=36), nullable=False),
        sa.Column('location_type', location_type_enum, nullable=False, server_default='point'),
        sa.Column('address', sa.Text(), nullable=True),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('mrid')
    )
    op.create_index(op.f('ix_locations_mrid'), 'locations', ['mrid'], unique=True)
    
    # Создаем таблицу position_points
    op.create_table(
        'position_points',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('mrid', sa.String(length=36), nullable=False),
        sa.Column('location_id', sa.Integer(), nullable=False),
        sa.Column('x_position', sa.Float(), nullable=False),  # Долгота (longitude)
        sa.Column('y_position', sa.Float(), nullable=False),  # Широта (latitude)
        sa.Column('z_position', sa.Float(), nullable=True),   # Высота (altitude)
        sa.Column('sequence_number', sa.Integer(), nullable=True, server_default='1'),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['location_id'], ['locations.id'], ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('mrid')
    )
    op.create_index(op.f('ix_position_points_mrid'), 'position_points', ['mrid'], unique=True)
    op.create_index(op.f('ix_position_points_location_id'), 'position_points', ['location_id'], unique=False)
    
    # Добавляем location_id в poles
    op.add_column('poles', sa.Column('location_id', sa.Integer(), nullable=True))
    op.create_foreign_key('fk_poles_location', 'poles', 'locations', ['location_id'], ['id'])
    op.create_index(op.f('ix_poles_location_id'), 'poles', ['location_id'], unique=False)
    
    # Делаем latitude и longitude nullable в poles для миграции
    op.alter_column('poles', 'latitude', existing_type=sa.Float(), nullable=True)
    op.alter_column('poles', 'longitude', existing_type=sa.Float(), nullable=True)
    
    # Добавляем location_id в substations
    op.add_column('substations', sa.Column('location_id', sa.Integer(), nullable=True))
    op.create_foreign_key('fk_substations_location', 'substations', 'locations', ['location_id'], ['id'])
    op.create_index(op.f('ix_substations_location_id'), 'substations', ['location_id'], unique=False)
    
    # Делаем latitude и longitude nullable в substations для миграции
    op.alter_column('substations', 'latitude', existing_type=sa.Float(), nullable=True)
    op.alter_column('substations', 'longitude', existing_type=sa.Float(), nullable=True)
    
    # Добавляем location_id в taps
    op.add_column('taps', sa.Column('location_id', sa.Integer(), nullable=True))
    op.create_foreign_key('fk_taps_location', 'taps', 'locations', ['location_id'], ['id'])
    op.create_index(op.f('ix_taps_location_id'), 'taps', ['location_id'], unique=False)
    
    # Миграция данных: переносим координаты из старых полей в Location/PositionPoint
    # Для poles
    op.execute("""
        DO $$
        DECLARE
            pole_rec RECORD;
            loc_id INTEGER;
            pos_id INTEGER;
        BEGIN
            FOR pole_rec IN SELECT id, latitude, longitude FROM poles WHERE latitude IS NOT NULL AND longitude IS NOT NULL LOOP
                -- Создаем Location
                INSERT INTO locations (mrid, location_type, created_at)
                VALUES (gen_random_uuid()::text, 'point', NOW())
                RETURNING id INTO loc_id;
                
                -- Создаем PositionPoint
                INSERT INTO position_points (mrid, location_id, x_position, y_position, created_at)
                VALUES (gen_random_uuid()::text, loc_id, pole_rec.longitude, pole_rec.latitude, NOW());
                
                -- Обновляем pole
                UPDATE poles SET location_id = loc_id WHERE id = pole_rec.id;
            END LOOP;
        END $$;
    """)
    
    # Для substations
    op.execute("""
        DO $$
        DECLARE
            subst_rec RECORD;
            loc_id INTEGER;
        BEGIN
            FOR subst_rec IN SELECT id, latitude, longitude, address FROM substations WHERE latitude IS NOT NULL AND longitude IS NOT NULL LOOP
                -- Создаем Location
                INSERT INTO locations (mrid, location_type, address, created_at)
                VALUES (gen_random_uuid()::text, 'point', subst_rec.address, NOW())
                RETURNING id INTO loc_id;
                
                -- Создаем PositionPoint
                INSERT INTO position_points (mrid, location_id, x_position, y_position, created_at)
                VALUES (gen_random_uuid()::text, loc_id, subst_rec.longitude, subst_rec.latitude, NOW());
                
                -- Обновляем substation
                UPDATE substations SET location_id = loc_id WHERE id = subst_rec.id;
            END LOOP;
        END $$;
    """)
    
    # Для taps (если есть координаты)
    op.execute("""
        DO $$
        DECLARE
            tap_rec RECORD;
            loc_id INTEGER;
        BEGIN
            FOR tap_rec IN SELECT id, latitude, longitude FROM taps WHERE latitude IS NOT NULL AND longitude IS NOT NULL LOOP
                -- Создаем Location
                INSERT INTO locations (mrid, location_type, created_at)
                VALUES (gen_random_uuid()::text, 'point', NOW())
                RETURNING id INTO loc_id;
                
                -- Создаем PositionPoint
                INSERT INTO position_points (mrid, location_id, x_position, y_position, created_at)
                VALUES (gen_random_uuid()::text, loc_id, tap_rec.longitude, tap_rec.latitude, NOW());
                
                -- Обновляем tap
                UPDATE taps SET location_id = loc_id WHERE id = tap_rec.id;
            END LOOP;
        END $$;
    """)


def downgrade() -> None:
    # Удаляем location_id из таблиц
    op.drop_index(op.f('ix_taps_location_id'), table_name='taps')
    op.drop_constraint('fk_taps_location', 'taps', type_='foreignkey')
    op.drop_column('taps', 'location_id')
    
    op.drop_index(op.f('ix_substations_location_id'), table_name='substations')
    op.drop_constraint('fk_substations_location', 'substations', type_='foreignkey')
    op.drop_column('substations', 'location_id')
    
    # Восстанавливаем NOT NULL для координат
    op.alter_column('substations', 'longitude', existing_type=sa.Float(), nullable=False)
    op.alter_column('substations', 'latitude', existing_type=sa.Float(), nullable=False)
    
    op.drop_index(op.f('ix_poles_location_id'), table_name='poles')
    op.drop_constraint('fk_poles_location', 'poles', type_='foreignkey')
    op.drop_column('poles', 'location_id')
    
    # Восстанавливаем NOT NULL для координат
    op.alter_column('poles', 'longitude', existing_type=sa.Float(), nullable=False)
    op.alter_column('poles', 'latitude', existing_type=sa.Float(), nullable=False)
    
    # Удаляем таблицы
    op.drop_index(op.f('ix_position_points_location_id'), table_name='position_points')
    op.drop_index(op.f('ix_position_points_mrid'), table_name='position_points')
    op.drop_table('position_points')
    
    op.drop_index(op.f('ix_locations_mrid'), table_name='locations')
    op.drop_table('locations')
    
    # Удаляем enum
    op.execute('DROP TYPE IF EXISTS locationtype')

