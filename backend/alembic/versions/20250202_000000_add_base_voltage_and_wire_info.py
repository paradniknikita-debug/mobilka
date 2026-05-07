"""Add BaseVoltage and WireInfo CIM models

Revision ID: 20250202_000000
Revises: 20250201_000000
Create Date: 2025-02-02 00:00:00.000000

Поддерживаются имена таблиц: line/power_lines, acline_segment/acline_segments,
line_section/line_sections, voltage_level/voltage_levels.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = '20250202_000000'
down_revision = '20250201_000000'
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
    line_t = _resolve_table(inspector, ('line', 'power_lines'))
    acline_t = _resolve_table(inspector, ('acline_segment', 'acline_segments'))
    line_section_t = _resolve_table(inspector, ('line_section', 'line_sections'))
    voltage_level_t = _resolve_table(inspector, ('voltage_level', 'voltage_levels'))
    # Создаем таблицу base_voltages
    op.create_table(
        'base_voltages',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('mrid', sa.String(length=36), nullable=False),
        sa.Column('nominal_voltage', sa.Float(), nullable=False),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('code', sa.String(length=20), nullable=True),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('mrid'),
        sa.UniqueConstraint('nominal_voltage')
    )
    op.create_index(op.f('ix_base_voltages_mrid'), 'base_voltages', ['mrid'], unique=True)
    op.create_index(op.f('ix_base_voltages_code'), 'base_voltages', ['code'], unique=True)
    
    # Создаем таблицу wire_infos
    op.create_table(
        'wire_infos',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('mrid', sa.String(length=36), nullable=False),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('code', sa.String(length=20), nullable=True),
        sa.Column('material', sa.String(length=50), nullable=False),
        sa.Column('section', sa.Float(), nullable=False),
        sa.Column('number_of_strands', sa.Integer(), nullable=True),
        sa.Column('diameter', sa.Float(), nullable=True),
        sa.Column('r', sa.Float(), nullable=True),
        sa.Column('x', sa.Float(), nullable=True),
        sa.Column('b', sa.Float(), nullable=True),
        sa.Column('g', sa.Float(), nullable=True),
        sa.Column('breaking_load', sa.Float(), nullable=True),
        sa.Column('weight_per_length', sa.Float(), nullable=True),
        sa.Column('max_operating_temperature', sa.Float(), nullable=True),
        sa.Column('nominal_current', sa.Float(), nullable=True),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=True, server_default='true'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('mrid'),
        sa.UniqueConstraint('name')
    )
    op.create_index(op.f('ix_wire_infos_mrid'), 'wire_infos', ['mrid'], unique=True)
    op.create_index(op.f('ix_wire_infos_code'), 'wire_infos', ['code'], unique=True)
    
    if voltage_level_t:
        op.add_column(voltage_level_t, sa.Column('base_voltage_id', sa.Integer(), nullable=True))
        op.create_foreign_key('fk_voltage_levels_base_voltage', voltage_level_t, 'base_voltages', ['base_voltage_id'], ['id'])
        op.create_index(op.f('ix_voltage_levels_base_voltage_id'), voltage_level_t, ['base_voltage_id'], unique=False)

    if line_t:
        op.add_column(line_t, sa.Column('base_voltage_id', sa.Integer(), nullable=True))
        op.create_foreign_key('fk_power_lines_base_voltage', line_t, 'base_voltages', ['base_voltage_id'], ['id'])
        op.create_index(op.f('ix_power_lines_base_voltage_id'), line_t, ['base_voltage_id'], unique=False)

    if line_section_t:
        op.add_column(line_section_t, sa.Column('wire_info_id', sa.Integer(), nullable=True))
        op.create_foreign_key('fk_line_sections_wire_info', line_section_t, 'wire_infos', ['wire_info_id'], ['id'])
        op.create_index(op.f('ix_line_sections_wire_info_id'), line_section_t, ['wire_info_id'], unique=False)
        try:
            op.alter_column(line_section_t, 'conductor_type', existing_type=sa.String(length=50), nullable=True)
            op.alter_column(line_section_t, 'conductor_section', existing_type=sa.String(length=20), nullable=True)
        except Exception:
            pass  # колонки могут отсутствовать

    if acline_t:
        op.add_column(acline_t, sa.Column('wire_info_id', sa.Integer(), nullable=True))
        op.create_foreign_key('fk_acline_segments_wire_info', acline_t, 'wire_infos', ['wire_info_id'], ['id'])
        op.create_index(op.f('ix_acline_segments_wire_info_id'), acline_t, ['wire_info_id'], unique=False)
    
    # Заполняем базовые уровни напряжения (уникальные code для каждого nominal_voltage)
    op.execute("""
        INSERT INTO base_voltages (mrid, nominal_voltage, name, code, description, created_at)
        VALUES 
            (gen_random_uuid()::text, 0.4, 'Низкое напряжение', 'LV', 'Низкое напряжение 0.4 кВ', NOW()),
            (gen_random_uuid()::text, 10.0, 'Среднее напряжение', 'MV', 'Среднее напряжение 10 кВ', NOW()),
            (gen_random_uuid()::text, 35.0, 'Высокое напряжение', 'HV35', 'Высокое напряжение 35 кВ', NOW()),
            (gen_random_uuid()::text, 110.0, 'Высокое напряжение', 'HV110', 'Высокое напряжение 110 кВ', NOW()),
            (gen_random_uuid()::text, 220.0, 'Сверхвысокое напряжение', 'EHV220', 'Сверхвысокое напряжение 220 кВ', NOW()),
            (gen_random_uuid()::text, 330.0, 'Сверхвысокое напряжение', 'EHV330', 'Сверхвысокое напряжение 330 кВ', NOW()),
            (gen_random_uuid()::text, 500.0, 'Сверхвысокое напряжение', 'EHV500', 'Сверхвысокое напряжение 500 кВ', NOW()),
            (gen_random_uuid()::text, 750.0, 'Ультравысокое напряжение', 'UHV', 'Ультравысокое напряжение 750 кВ', NOW())
        ON CONFLICT (nominal_voltage) DO NOTHING;
    """)


def downgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    line_t = _resolve_table(inspector, ('line', 'power_lines'))
    acline_t = _resolve_table(inspector, ('acline_segment', 'acline_segments'))
    line_section_t = _resolve_table(inspector, ('line_section', 'line_sections'))
    voltage_level_t = _resolve_table(inspector, ('voltage_level', 'voltage_levels'))

    if acline_t:
        op.drop_index(op.f('ix_acline_segments_wire_info_id'), table_name=acline_t)
        op.drop_constraint('fk_acline_segments_wire_info', acline_t, type_='foreignkey')
        op.drop_column(acline_t, 'wire_info_id')
    if line_section_t:
        try:
            op.alter_column(line_section_t, 'conductor_section', existing_type=sa.String(length=20), nullable=False)
            op.alter_column(line_section_t, 'conductor_type', existing_type=sa.String(length=50), nullable=False)
        except Exception:
            pass
        op.drop_index(op.f('ix_line_sections_wire_info_id'), table_name=line_section_t)
        op.drop_constraint('fk_line_sections_wire_info', line_section_t, type_='foreignkey')
        op.drop_column(line_section_t, 'wire_info_id')
    if line_t:
        op.drop_index(op.f('ix_power_lines_base_voltage_id'), table_name=line_t)
        op.drop_constraint('fk_power_lines_base_voltage', line_t, type_='foreignkey')
        op.drop_column(line_t, 'base_voltage_id')
    if voltage_level_t:
        op.drop_index(op.f('ix_voltage_levels_base_voltage_id'), table_name=voltage_level_t)
        op.drop_constraint('fk_voltage_levels_base_voltage', voltage_level_t, type_='foreignkey')
        op.drop_column(voltage_level_t, 'base_voltage_id')
    
    # Удаляем таблицы
    op.drop_index(op.f('ix_wire_infos_code'), table_name='wire_infos')
    op.drop_index(op.f('ix_wire_infos_mrid'), table_name='wire_infos')
    op.drop_table('wire_infos')
    
    op.drop_index(op.f('ix_base_voltages_code'), table_name='base_voltages')
    op.drop_index(op.f('ix_base_voltages_mrid'), table_name='base_voltages')
    op.drop_table('base_voltages')

