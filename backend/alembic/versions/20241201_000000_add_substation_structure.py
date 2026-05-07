"""add_substation_structure

Revision ID: 20241201_000000
Revises: None (base revision for recreate_db.py)
Create Date: 2024-12-01 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy import inspect

# revision identifiers, used by Alembic.
revision = '20241201_000000'
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    existing_tables = inspector.get_table_names()

    # Колонка is_tap_pole для модели Pole — добавляем при первом запуске, если таблица уже есть (recreate_db и т.п.)
    if 'pole' in existing_tables:
        cols = [c['name'] for c in inspector.get_columns('pole')]
        if 'is_tap_pole' not in cols:
            op.add_column('pole', sa.Column('is_tap_pole', sa.Boolean(), nullable=False, server_default=sa.text('false')))

    # voltage_levels ссылается на подстанции — создаём только если есть таблица подстанций
    substation_table = 'substations' if 'substations' in existing_tables else ('substation' if 'substation' in existing_tables else None)
    if not substation_table:
        return  # подстанций нет (база пустая или другая цепь миграций) — не создаём эти таблицы

    # Создание таблицы voltage_levels
    if 'voltage_levels' not in existing_tables:
        op.create_table(
            'voltage_levels',
            sa.Column('id', sa.Integer(), nullable=False),
            sa.Column('mrid', sa.String(length=36), nullable=False),
            sa.Column('substation_id', sa.Integer(), nullable=False),
            sa.Column('name', sa.String(length=100), nullable=False),
            sa.Column('code', sa.String(length=20), nullable=False),
            sa.Column('nominal_voltage', sa.Float(), nullable=False),
            sa.Column('high_voltage_limit', sa.Float(), nullable=True),
            sa.Column('low_voltage_limit', sa.Float(), nullable=True),
            sa.Column('description', sa.Text(), nullable=True),
            sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
            sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
            sa.ForeignKeyConstraint(['substation_id'], [f'{substation_table}.id'], ),
            sa.PrimaryKeyConstraint('id')
        )
        op.create_index(op.f('ix_voltage_levels_id'), 'voltage_levels', ['id'], unique=False)
        op.create_index(op.f('ix_voltage_levels_mrid'), 'voltage_levels', ['mrid'], unique=True)
        print("Таблица 'voltage_levels' создана")
    
    # Создание таблицы bays
    if 'bays' not in existing_tables:
        op.create_table(
            'bays',
            sa.Column('id', sa.Integer(), nullable=False),
            sa.Column('mrid', sa.String(length=36), nullable=False),
            sa.Column('voltage_level_id', sa.Integer(), nullable=False),
            sa.Column('name', sa.String(length=100), nullable=False),
            sa.Column('bay_number', sa.String(length=20), nullable=False),
            sa.Column('bay_type', sa.String(length=50), nullable=False),
            sa.Column('description', sa.Text(), nullable=True),
            sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
            sa.ForeignKeyConstraint(['voltage_level_id'], ['voltage_levels.id'], ),
            sa.PrimaryKeyConstraint('id')
        )
        op.create_index(op.f('ix_bays_id'), 'bays', ['id'], unique=False)
        op.create_index(op.f('ix_bays_mrid'), 'bays', ['mrid'], unique=True)
        print("Таблица 'bays' создана")
    
    # Создание таблицы busbar_sections
    if 'busbar_sections' not in existing_tables:
        op.create_table(
            'busbar_sections',
            sa.Column('id', sa.Integer(), nullable=False),
            sa.Column('mrid', sa.String(length=36), nullable=False),
            sa.Column('bay_id', sa.Integer(), nullable=False),
            sa.Column('name', sa.String(length=100), nullable=False),
            sa.Column('section_number', sa.Integer(), nullable=False),
            sa.Column('nominal_current', sa.Float(), nullable=True),
            sa.Column('description', sa.Text(), nullable=True),
            sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
            sa.ForeignKeyConstraint(['bay_id'], ['bays.id'], ),
            sa.PrimaryKeyConstraint('id')
        )
        op.create_index(op.f('ix_busbar_sections_id'), 'busbar_sections', ['id'], unique=False)
        op.create_index(op.f('ix_busbar_sections_mrid'), 'busbar_sections', ['mrid'], unique=True)
        print("Таблица 'busbar_sections' создана")
    
    # Создание таблицы conducting_equipment
    if 'conducting_equipment' not in existing_tables:
        op.create_table(
            'conducting_equipment',
            sa.Column('id', sa.Integer(), nullable=False),
            sa.Column('mrid', sa.String(length=36), nullable=False),
            sa.Column('bay_id', sa.Integer(), nullable=False),
            sa.Column('equipment_type', sa.String(length=50), nullable=False),
            sa.Column('name', sa.String(length=100), nullable=False),
            sa.Column('manufacturer', sa.String(length=100), nullable=True),
            sa.Column('model', sa.String(length=100), nullable=True),
            sa.Column('serial_number', sa.String(length=100), nullable=True),
            sa.Column('specifications', JSONB(), nullable=True),
            sa.Column('installation_date', sa.DateTime(), nullable=True),
            sa.Column('last_maintenance_date', sa.DateTime(), nullable=True),
            sa.Column('next_maintenance_date', sa.DateTime(), nullable=True),
            sa.Column('status', sa.String(length=20), server_default='active', nullable=True),
            sa.Column('notes', sa.Text(), nullable=True),
            sa.Column('created_by', sa.Integer(), nullable=False),
            sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
            sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
            sa.ForeignKeyConstraint(['bay_id'], ['bays.id'], ),
            sa.ForeignKeyConstraint(['created_by'], ['users.id'], ),
            sa.PrimaryKeyConstraint('id')
        )
        op.create_index(op.f('ix_conducting_equipment_id'), 'conducting_equipment', ['id'], unique=False)
        op.create_index(op.f('ix_conducting_equipment_mrid'), 'conducting_equipment', ['mrid'], unique=True)
        print("Таблица 'conducting_equipment' создана")
    
    # Создание таблицы protection_equipment
    if 'protection_equipment' not in existing_tables:
        op.create_table(
            'protection_equipment',
            sa.Column('id', sa.Integer(), nullable=False),
            sa.Column('mrid', sa.String(length=36), nullable=False),
            sa.Column('bay_id', sa.Integer(), nullable=False),
            sa.Column('name', sa.String(length=100), nullable=False),
            sa.Column('protection_type', sa.String(length=50), nullable=False),
            sa.Column('manufacturer', sa.String(length=100), nullable=True),
            sa.Column('model', sa.String(length=100), nullable=True),
            sa.Column('serial_number', sa.String(length=100), nullable=True),
            sa.Column('specifications', JSONB(), nullable=True),
            sa.Column('installation_date', sa.DateTime(), nullable=True),
            sa.Column('status', sa.String(length=20), server_default='active', nullable=True),
            sa.Column('notes', sa.Text(), nullable=True),
            sa.Column('created_by', sa.Integer(), nullable=False),
            sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
            sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
            sa.ForeignKeyConstraint(['bay_id'], ['bays.id'], ),
            sa.ForeignKeyConstraint(['created_by'], ['users.id'], ),
            sa.PrimaryKeyConstraint('id')
        )
        op.create_index(op.f('ix_protection_equipment_id'), 'protection_equipment', ['id'], unique=False)
        op.create_index(op.f('ix_protection_equipment_mrid'), 'protection_equipment', ['mrid'], unique=True)
        print("Таблица 'protection_equipment' создана")


def downgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    existing_tables = inspector.get_table_names()
    
    # Удаление таблиц в обратном порядке (сначала дочерние)
    if 'protection_equipment' in existing_tables:
        op.drop_index(op.f('ix_protection_equipment_mrid'), table_name='protection_equipment')
        op.drop_index(op.f('ix_protection_equipment_id'), table_name='protection_equipment')
        op.drop_table('protection_equipment')
        print("Таблица 'protection_equipment' удалена")
    
    if 'conducting_equipment' in existing_tables:
        op.drop_index(op.f('ix_conducting_equipment_mrid'), table_name='conducting_equipment')
        op.drop_index(op.f('ix_conducting_equipment_id'), table_name='conducting_equipment')
        op.drop_table('conducting_equipment')
        print("Таблица 'conducting_equipment' удалена")
    
    if 'busbar_sections' in existing_tables:
        op.drop_index(op.f('ix_busbar_sections_mrid'), table_name='busbar_sections')
        op.drop_index(op.f('ix_busbar_sections_id'), table_name='busbar_sections')
        op.drop_table('busbar_sections')
        print("Таблица 'busbar_sections' удалена")
    
    if 'bays' in existing_tables:
        op.drop_index(op.f('ix_bays_mrid'), table_name='bays')
        op.drop_index(op.f('ix_bays_id'), table_name='bays')
        op.drop_table('bays')
        print("Таблица 'bays' удалена")
    
    if 'voltage_levels' in existing_tables:
        op.drop_index(op.f('ix_voltage_levels_mrid'), table_name='voltage_levels')
        op.drop_index(op.f('ix_voltage_levels_id'), table_name='voltage_levels')
        op.drop_table('voltage_levels')
        print("Таблица 'voltage_levels' удалена")


