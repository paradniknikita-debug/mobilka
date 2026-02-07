"""Add BaseVoltage and WireInfo CIM models

Revision ID: 20250202_000000
Revises: 20250201_000000
Create Date: 2025-02-02 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '20250202_000000'
down_revision = '20250201_000000'
branch_labels = None
depends_on = None


def upgrade() -> None:
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
    
    # Добавляем base_voltage_id в voltage_levels
    op.add_column('voltage_levels', sa.Column('base_voltage_id', sa.Integer(), nullable=True))
    op.create_foreign_key('fk_voltage_levels_base_voltage', 'voltage_levels', 'base_voltages', ['base_voltage_id'], ['id'])
    op.create_index(op.f('ix_voltage_levels_base_voltage_id'), 'voltage_levels', ['base_voltage_id'], unique=False)
    
    # Добавляем base_voltage_id в power_lines
    op.add_column('power_lines', sa.Column('base_voltage_id', sa.Integer(), nullable=True))
    op.create_foreign_key('fk_power_lines_base_voltage', 'power_lines', 'base_voltages', ['base_voltage_id'], ['id'])
    op.create_index(op.f('ix_power_lines_base_voltage_id'), 'power_lines', ['base_voltage_id'], unique=False)
    
    # Добавляем wire_info_id в line_sections
    op.add_column('line_sections', sa.Column('wire_info_id', sa.Integer(), nullable=True))
    op.create_foreign_key('fk_line_sections_wire_info', 'line_sections', 'wire_infos', ['wire_info_id'], ['id'])
    op.create_index(op.f('ix_line_sections_wire_info_id'), 'line_sections', ['wire_info_id'], unique=False)
    
    # Делаем поля в line_sections nullable для обратной совместимости
    op.alter_column('line_sections', 'conductor_type', existing_type=sa.String(length=50), nullable=True)
    op.alter_column('line_sections', 'conductor_section', existing_type=sa.String(length=20), nullable=True)
    
    # Добавляем wire_info_id в acline_segments
    op.add_column('acline_segments', sa.Column('wire_info_id', sa.Integer(), nullable=True))
    op.create_foreign_key('fk_acline_segments_wire_info', 'acline_segments', 'wire_infos', ['wire_info_id'], ['id'])
    op.create_index(op.f('ix_acline_segments_wire_info_id'), 'acline_segments', ['wire_info_id'], unique=False)
    
    # Заполняем базовые уровни напряжения
    op.execute("""
        INSERT INTO base_voltages (mrid, nominal_voltage, name, code, description, created_at)
        VALUES 
            (gen_random_uuid()::text, 0.4, 'Низкое напряжение', 'LV', 'Низкое напряжение 0.4 кВ', NOW()),
            (gen_random_uuid()::text, 10.0, 'Среднее напряжение', 'MV', 'Среднее напряжение 10 кВ', NOW()),
            (gen_random_uuid()::text, 35.0, 'Высокое напряжение', 'HV', 'Высокое напряжение 35 кВ', NOW()),
            (gen_random_uuid()::text, 110.0, 'Высокое напряжение', 'HV', 'Высокое напряжение 110 кВ', NOW()),
            (gen_random_uuid()::text, 220.0, 'Сверхвысокое напряжение', 'EHV', 'Сверхвысокое напряжение 220 кВ', NOW()),
            (gen_random_uuid()::text, 330.0, 'Сверхвысокое напряжение', 'EHV', 'Сверхвысокое напряжение 330 кВ', NOW()),
            (gen_random_uuid()::text, 500.0, 'Сверхвысокое напряжение', 'EHV', 'Сверхвысокое напряжение 500 кВ', NOW()),
            (gen_random_uuid()::text, 750.0, 'Ультравысокое напряжение', 'UHV', 'Ультравысокое напряжение 750 кВ', NOW())
        ON CONFLICT (nominal_voltage) DO NOTHING;
    """)


def downgrade() -> None:
    # Удаляем связи
    op.drop_index(op.f('ix_acline_segments_wire_info_id'), table_name='acline_segments')
    op.drop_constraint('fk_acline_segments_wire_info', 'acline_segments', type_='foreignkey')
    op.drop_column('acline_segments', 'wire_info_id')
    
    # Восстанавливаем NOT NULL для line_sections
    op.alter_column('line_sections', 'conductor_section', existing_type=sa.String(length=20), nullable=False)
    op.alter_column('line_sections', 'conductor_type', existing_type=sa.String(length=50), nullable=False)
    
    op.drop_index(op.f('ix_line_sections_wire_info_id'), table_name='line_sections')
    op.drop_constraint('fk_line_sections_wire_info', 'line_sections', type_='foreignkey')
    op.drop_column('line_sections', 'wire_info_id')
    
    op.drop_index(op.f('ix_power_lines_base_voltage_id'), table_name='power_lines')
    op.drop_constraint('fk_power_lines_base_voltage', 'power_lines', type_='foreignkey')
    op.drop_column('power_lines', 'base_voltage_id')
    
    op.drop_index(op.f('ix_voltage_levels_base_voltage_id'), table_name='voltage_levels')
    op.drop_constraint('fk_voltage_levels_base_voltage', 'voltage_levels', type_='foreignkey')
    op.drop_column('voltage_levels', 'base_voltage_id')
    
    # Удаляем таблицы
    op.drop_index(op.f('ix_wire_infos_code'), table_name='wire_infos')
    op.drop_index(op.f('ix_wire_infos_mrid'), table_name='wire_infos')
    op.drop_table('wire_infos')
    
    op.drop_index(op.f('ix_base_voltages_code'), table_name='base_voltages')
    op.drop_index(op.f('ix_base_voltages_mrid'), table_name='base_voltages')
    op.drop_table('base_voltages')

