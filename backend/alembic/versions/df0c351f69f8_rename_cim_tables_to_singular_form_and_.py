"""Rename CIM tables to singular form and remove Mixin suffix

Revision ID: df0c351f69f8
Revises: 20250203_000000
Create Date: 2026-02-07 21:52:09.815851

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = 'df0c351f69f8'
down_revision = '20250203_000000'
branch_labels = None
depends_on = None


def _table_exists(conn, table_name):
    """Проверяет существование таблицы"""
    from sqlalchemy import text
    try:
        result = conn.execute(text("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_schema = 'public' 
                AND table_name = :table_name
            )
        """), {"table_name": table_name})
        return result.scalar()
    except:
        return False


def _constraint_exists(conn, constraint_name, table_name):
    """Проверяет существование constraint"""
    from sqlalchemy import inspect, text
    try:
        # Используем прямой SQL запрос для проверки constraint
        result = conn.execute(text("""
            SELECT constraint_name 
            FROM information_schema.table_constraints 
            WHERE table_name = :table_name 
            AND constraint_name = :constraint_name
            AND constraint_type = 'FOREIGN KEY'
        """), {"table_name": table_name, "constraint_name": constraint_name})
        return result.fetchone() is not None
    except:
        return False


def upgrade() -> None:
    conn = op.get_bind()
    
    # 1. Переименовываем location и position_point (независимые)
    if _table_exists(conn, 'locations') and not _table_exists(conn, 'location'):
        op.rename_table('locations', 'location')
    if _table_exists(conn, 'position_points') and not _table_exists(conn, 'position_point'):
        op.rename_table('position_points', 'position_point')
    
    # Обновляем foreign keys для location (проверяем существование constraint)
    try:
        position_table = 'position_point' if _table_exists(conn, 'position_point') else 'position_points'
        if _table_exists(conn, position_table):
            try:
                if _constraint_exists(conn, 'position_points_location_id_fkey', position_table):
                    op.drop_constraint('position_points_location_id_fkey', position_table, type_='foreignkey')
            except:
                try:
                    if _constraint_exists(conn, 'position_point_location_id_fkey', position_table):
                        op.drop_constraint('position_point_location_id_fkey', position_table, type_='foreignkey')
                except:
                    pass
            
            if _table_exists(conn, 'position_point') and _table_exists(conn, 'location'):
                if not _constraint_exists(conn, 'position_point_location_id_fkey', 'position_point'):
                    try:
                        op.create_foreign_key('position_point_location_id_fkey', 'position_point', 'location', ['location_id'], ['id'])
                    except:
                        pass
    except Exception as e:
        print(f"Warning: Error updating position_point foreign keys: {e}")
        pass
    
    # Обновляем foreign keys в других таблицах, ссылающихся на location
    for table in ['poles', 'taps', 'substations']:
        if _table_exists(conn, table):
            constraint_name = f'{table}_location_id_fkey'
            try:
                if _constraint_exists(conn, constraint_name, table):
                    op.drop_constraint(constraint_name, table, type_='foreignkey')
            except:
                pass
            if _table_exists(conn, 'location'):
                if not _constraint_exists(conn, constraint_name, table):
                    try:
                        op.create_foreign_key(constraint_name, table, 'location', ['location_id'], ['id'])
                    except:
                        pass
    
    # 2. Переименовываем base_voltage и wire_info (независимые)
    if _table_exists(conn, 'base_voltages') and not _table_exists(conn, 'base_voltage'):
        op.rename_table('base_voltages', 'base_voltage')
    if _table_exists(conn, 'wire_infos') and not _table_exists(conn, 'wire_info'):
        op.rename_table('wire_infos', 'wire_info')
    
    # 3. Переименовываем power_lines -> line (основная таблица)
    # Сначала удаляем старые foreign key constraints
    constraints_to_drop = [
        ('poles', 'poles_power_line_id_fkey'),
        ('spans', 'spans_power_line_id_fkey'),
        ('taps', 'taps_power_line_id_fkey'),
        ('connections', 'connections_power_line_id_fkey'),
        ('line_segments', 'line_segments_power_line_id_fkey'),
        ('acline_segments', 'fk_acline_segments_power_line'),
        ('connectivity_nodes', 'fk_connectivity_nodes_power_line'),
    ]
    
    for table, constraint in constraints_to_drop:
        if _table_exists(conn, table) and _constraint_exists(conn, constraint, table):
            op.drop_constraint(constraint, table, type_='foreignkey')
    
    # Переименовываем таблицу
    if _table_exists(conn, 'power_lines') and not _table_exists(conn, 'line'):
        op.rename_table('power_lines', 'line')
    
    # Переименовываем колонки
    if _table_exists(conn, 'line'):
        for table in ['poles', 'spans', 'taps', 'connections', 'line_segments', 'acline_segments', 'connectivity_nodes']:
            if _table_exists(conn, table):
                try:
                    op.alter_column(table, 'power_line_id', new_column_name='line_id')
                except:
                    pass  # Колонка уже переименована или не существует
    
    # Создаём новые foreign key constraints
    if _table_exists(conn, 'line'):
        fk_mappings = [
            ('poles', 'poles_line_id_fkey', 'line_id'),
            ('spans', 'spans_line_id_fkey', 'line_id'),
            ('taps', 'taps_line_id_fkey', 'line_id'),
            ('connections', 'connections_line_id_fkey', 'line_id'),
            ('line_segments', 'line_segments_line_id_fkey', 'line_id'),
            ('acline_segments', 'acline_segments_line_id_fkey', 'line_id'),
            ('connectivity_nodes', 'connectivity_nodes_line_id_fkey', 'line_id'),
        ]
        
        for table, constraint_name, column_name in fk_mappings:
            if _table_exists(conn, table) and not _constraint_exists(conn, constraint_name, table):
                try:
                    op.create_foreign_key(constraint_name, table, 'line', [column_name], ['id'])
                except:
                    pass
    
    # 4. Переименовываем substations -> substation
    constraints_to_drop = [
        ('connections', 'connections_substation_id_fkey'),
        ('voltage_levels', 'voltage_levels_substation_id_fkey'),
        ('connectivity_nodes', 'fk_connectivity_nodes_substation_id'),
    ]
    
    for table, constraint in constraints_to_drop:
        if _table_exists(conn, table) and _constraint_exists(conn, constraint, table):
            op.drop_constraint(constraint, table, type_='foreignkey')
    
    if _table_exists(conn, 'substations') and not _table_exists(conn, 'substation'):
        op.rename_table('substations', 'substation')
    
    if _table_exists(conn, 'substation'):
        fk_mappings = [
            ('connections', 'connections_substation_id_fkey', 'substation_id'),
            ('voltage_levels', 'voltage_levels_substation_id_fkey', 'substation_id'),
            ('connectivity_nodes', 'connectivity_nodes_substation_id_fkey', 'substation_id'),
        ]
        
        for table, constraint_name, column_name in fk_mappings:
            if _table_exists(conn, table) and not _constraint_exists(conn, constraint_name, table):
                try:
                    op.create_foreign_key(constraint_name, table, 'substation', [column_name], ['id'])
                except:
                    pass
    
    # 5. Переименовываем voltage_levels -> voltage_level
    if _table_exists(conn, 'bays') and _constraint_exists(conn, 'bays_voltage_level_id_fkey', 'bays'):
        op.drop_constraint('bays_voltage_level_id_fkey', 'bays', type_='foreignkey')
    
    if _table_exists(conn, 'voltage_levels') and not _table_exists(conn, 'voltage_level'):
        op.rename_table('voltage_levels', 'voltage_level')
    
    if _table_exists(conn, 'bays') and _table_exists(conn, 'voltage_level'):
        if not _constraint_exists(conn, 'bays_voltage_level_id_fkey', 'bays'):
            op.create_foreign_key('bays_voltage_level_id_fkey', 'bays', 'voltage_level', ['voltage_level_id'], ['id'])
    
    # 6. Переименовываем connectivity_nodes -> connectivity_node
    constraints_to_drop = [
        ('terminals', 'terminals_connectivity_node_id_fkey'),
        ('spans', 'fk_spans_from_node'),
        ('spans', 'fk_spans_to_node'),
        ('acline_segments', 'fk_acline_segments_from_node'),
        ('acline_segments', 'fk_acline_segments_to_node'),
        ('poles', 'fk_poles_connectivity_node'),
        ('connectivity_nodes', 'connectivity_nodes_pole_id_fkey'),
    ]
    
    for table, constraint in constraints_to_drop:
        if _table_exists(conn, table) and _constraint_exists(conn, constraint, table):
            op.drop_constraint(constraint, table, type_='foreignkey')
    
    if _table_exists(conn, 'connectivity_nodes') and not _table_exists(conn, 'connectivity_node'):
        op.rename_table('connectivity_nodes', 'connectivity_node')
    
    if _table_exists(conn, 'connectivity_node'):
        fk_mappings = [
            ('terminals', 'terminals_connectivity_node_id_fkey', 'connectivity_node_id'),
            ('spans', 'spans_from_connectivity_node_id_fkey', 'from_connectivity_node_id'),
            ('spans', 'spans_to_connectivity_node_id_fkey', 'to_connectivity_node_id'),
            ('acline_segments', 'acline_segments_from_connectivity_node_id_fkey', 'from_connectivity_node_id'),
            ('acline_segments', 'acline_segments_to_connectivity_node_id_fkey', 'to_connectivity_node_id'),
            ('poles', 'poles_connectivity_node_id_fkey', 'connectivity_node_id'),
            ('connectivity_node', 'connectivity_node_pole_id_fkey', 'pole_id'),
        ]
        
        for table, constraint_name, column_name in fk_mappings:
            if _table_exists(conn, table) and not _constraint_exists(conn, constraint_name, table):
                try:
                    if table == 'connectivity_node':
                        op.create_foreign_key(constraint_name, table, 'pole', [column_name], ['id'])
                    else:
                        op.create_foreign_key(constraint_name, table, 'connectivity_node', [column_name], ['id'])
                except:
                    pass
    
    # 7. Переименовываем terminals -> terminal
    if _table_exists(conn, 'acline_segments') and _constraint_exists(conn, 'fk_acline_segments_to_terminal', 'acline_segments'):
        op.drop_constraint('fk_acline_segments_to_terminal', 'acline_segments', type_='foreignkey')
    
    if _table_exists(conn, 'terminals') and not _table_exists(conn, 'terminal'):
        op.rename_table('terminals', 'terminal')
    
    if _table_exists(conn, 'acline_segments') and _table_exists(conn, 'terminal'):
        if not _constraint_exists(conn, 'acline_segments_to_terminal_id_fkey', 'acline_segments'):
            op.create_foreign_key('acline_segments_to_terminal_id_fkey', 'acline_segments', 'terminal', ['to_terminal_id'], ['id'])
    
    # 8. Переименовываем acline_segments -> acline_segment
    constraints_to_drop = [
        ('line_segments', 'line_segments_acline_segment_id_fkey'),
        ('line_sections', 'line_sections_acline_segment_id_fkey'),
        ('terminals', 'terminals_acline_segment_id_fkey'),
    ]
    
    for table, constraint in constraints_to_drop:
        if _table_exists(conn, table) and _constraint_exists(conn, constraint, table):
            op.drop_constraint(constraint, table, type_='foreignkey')
    
    if _table_exists(conn, 'acline_segments') and not _table_exists(conn, 'acline_segment'):
        op.rename_table('acline_segments', 'acline_segment')
    
    if _table_exists(conn, 'acline_segment'):
        fk_mappings = [
            ('line_segments', 'line_segments_acline_segment_id_fkey', 'acline_segment_id'),
            ('line_sections', 'line_sections_acline_segment_id_fkey', 'acline_segment_id'),
            ('terminal', 'terminal_acline_segment_id_fkey', 'acline_segment_id'),
        ]
        
        for table, constraint_name, column_name in fk_mappings:
            if _table_exists(conn, table) and not _constraint_exists(conn, constraint_name, table):
                try:
                    op.create_foreign_key(constraint_name, table, 'acline_segment', [column_name], ['id'])
                except:
                    pass
    
    # 9. Переименовываем line_sections -> line_section
    if _table_exists(conn, 'spans') and _constraint_exists(conn, 'fk_spans_line_section', 'spans'):
        op.drop_constraint('fk_spans_line_section', 'spans', type_='foreignkey')
    
    if _table_exists(conn, 'line_sections') and not _table_exists(conn, 'line_section'):
        op.rename_table('line_sections', 'line_section')
    
    if _table_exists(conn, 'spans') and _table_exists(conn, 'line_section'):
        if not _constraint_exists(conn, 'spans_line_section_id_fkey', 'spans'):
            op.create_foreign_key('spans_line_section_id_fkey', 'spans', 'line_section', ['line_section_id'], ['id'])
    
    # 10. Переименовываем bays -> bay
    constraints_to_drop = [
        ('busbar_sections', 'busbar_sections_bay_id_fkey'),
        ('conducting_equipment', 'conducting_equipment_bay_id_fkey'),
        ('protection_equipment', 'protection_equipment_bay_id_fkey'),
        ('terminals', 'terminals_bay_id_fkey'),
        ('terminal', 'terminals_bay_id_fkey'),
    ]
    
    for table, constraint in constraints_to_drop:
        if _table_exists(conn, table) and _constraint_exists(conn, constraint, table):
            try:
                op.drop_constraint(constraint, table, type_='foreignkey')
            except:
                pass
    
    if _table_exists(conn, 'bays') and not _table_exists(conn, 'bay'):
        op.rename_table('bays', 'bay')
    
    if _table_exists(conn, 'bay'):
        fk_mappings = [
            ('busbar_section', 'busbar_section_bay_id_fkey', 'bay_id'),
            ('busbar_sections', 'busbar_sections_bay_id_fkey', 'bay_id'),
            ('conducting_equipment', 'conducting_equipment_bay_id_fkey', 'bay_id'),
            ('protection_equipment', 'protection_equipment_bay_id_fkey', 'bay_id'),
            ('terminal', 'terminal_bay_id_fkey', 'bay_id'),
            ('terminals', 'terminals_bay_id_fkey', 'bay_id'),
        ]
        
        for table, constraint_name, column_name in fk_mappings:
            if _table_exists(conn, table) and not _constraint_exists(conn, constraint_name, table):
                try:
                    op.create_foreign_key(constraint_name, table, 'bay', [column_name], ['id'])
                except:
                    pass
    
    # 11. Переименовываем busbar_sections -> busbar_section
    if _table_exists(conn, 'busbar_sections') and not _table_exists(conn, 'busbar_section'):
        op.rename_table('busbar_sections', 'busbar_section')
    
    # 12. Переименовываем poles -> pole
    constraints_to_drop = [
        ('connectivity_node', 'connectivity_node_pole_id_fkey'),
        ('spans', 'spans_from_pole_id_fkey'),
        ('spans', 'spans_to_pole_id_fkey'),
        ('taps', 'taps_pole_id_fkey'),
        ('equipment', 'equipment_pole_id_fkey'),
    ]
    
    for table, constraint in constraints_to_drop:
        if _table_exists(conn, table) and _constraint_exists(conn, constraint, table):
            try:
                op.drop_constraint(constraint, table, type_='foreignkey')
            except:
                pass
    
    if _table_exists(conn, 'poles') and not _table_exists(conn, 'pole'):
        op.rename_table('poles', 'pole')
    
    # Переименовываем колонку power_line_id в line_id в таблице pole (если она ещё не переименована)
    if _table_exists(conn, 'pole'):
        try:
            # Проверяем, существует ли колонка power_line_id
            result = conn.execute(sa.text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = 'pole' 
                AND column_name = 'power_line_id'
            """))
            if result.fetchone():
                op.alter_column('pole', 'power_line_id', new_column_name='line_id')
        except Exception as e:
            print(f"Warning: Error renaming power_line_id to line_id in pole table: {e}")
            pass
    
    if _table_exists(conn, 'pole'):
        fk_mappings = [
            ('connectivity_node', 'connectivity_node_pole_id_fkey', 'pole_id'),
            ('spans', 'spans_from_pole_id_fkey', 'from_pole_id'),
            ('spans', 'spans_to_pole_id_fkey', 'to_pole_id'),
            ('taps', 'taps_pole_id_fkey', 'pole_id'),
            ('equipment', 'equipment_pole_id_fkey', 'pole_id'),
        ]
        
        for table, constraint_name, column_name in fk_mappings:
            if _table_exists(conn, table) and not _constraint_exists(conn, constraint_name, table):
                try:
                    op.create_foreign_key(constraint_name, table, 'pole', [column_name], ['id'])
                except:
                    pass


def downgrade() -> None:
    # Обратная операция - переименовываем обратно в множественное число
    conn = op.get_bind()
    
    if _table_exists(conn, 'pole') and not _table_exists(conn, 'poles'):
        op.rename_table('pole', 'poles')
    if _table_exists(conn, 'line_section') and not _table_exists(conn, 'line_sections'):
        op.rename_table('line_section', 'line_sections')
    if _table_exists(conn, 'acline_segment') and not _table_exists(conn, 'acline_segments'):
        op.rename_table('acline_segment', 'acline_segments')
    if _table_exists(conn, 'terminal') and not _table_exists(conn, 'terminals'):
        op.rename_table('terminal', 'terminals')
    if _table_exists(conn, 'connectivity_node') and not _table_exists(conn, 'connectivity_nodes'):
        op.rename_table('connectivity_node', 'connectivity_nodes')
    if _table_exists(conn, 'voltage_level') and not _table_exists(conn, 'voltage_levels'):
        op.rename_table('voltage_level', 'voltage_levels')
    if _table_exists(conn, 'substation') and not _table_exists(conn, 'substations'):
        op.rename_table('substation', 'substations')
    if _table_exists(conn, 'line') and not _table_exists(conn, 'power_lines'):
        op.rename_table('line', 'power_lines')
    if _table_exists(conn, 'wire_info') and not _table_exists(conn, 'wire_infos'):
        op.rename_table('wire_info', 'wire_infos')
    if _table_exists(conn, 'base_voltage') and not _table_exists(conn, 'base_voltages'):
        op.rename_table('base_voltage', 'base_voltages')
    if _table_exists(conn, 'position_point') and not _table_exists(conn, 'position_points'):
        op.rename_table('position_point', 'position_points')
    if _table_exists(conn, 'location') and not _table_exists(conn, 'locations'):
        op.rename_table('location', 'locations')
    
    # Переименовываем колонки обратно
    for table in ['poles', 'spans', 'taps', 'connections', 'line_segments', 'acline_segments', 'connectivity_nodes']:
        if _table_exists(conn, table):
            try:
                op.alter_column(table, 'line_id', new_column_name='power_line_id')
            except:
                pass
