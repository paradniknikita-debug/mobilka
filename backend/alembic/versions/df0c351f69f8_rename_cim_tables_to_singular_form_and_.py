"""Rename CIM tables to singular form and remove Mixin suffix

Revision ID: df0c351f69f8
Revises: 20250203_000000
Create Date: 2026-02-07 21:52:09.815851

Идемпотентно: поддерживаются уже переименованные таблицы (единственное число).
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import text

revision = 'df0c351f69f8'
down_revision = '20250203_000000'
branch_labels = None
depends_on = None


def _table_exists(conn, table_name):
    try:
        r = conn.execute(text("""
            SELECT EXISTS (
                SELECT 1 FROM information_schema.tables
                WHERE table_schema = 'public' AND table_name = :t
            )
        """), {"t": table_name})
        return r.scalar()
    except Exception:
        return False


def _resolve_table(conn, *candidates):
    """Возвращает первое существующее имя таблицы из списка или None."""
    for name in candidates:
        if _table_exists(conn, name):
            return name
    return None


def _column_exists(conn, table_name, column_name):
    try:
        r = conn.execute(text("""
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = :t AND column_name = :c
        """), {"t": table_name, "c": column_name})
        return r.fetchone() is not None
    except Exception:
        return False


def _constraint_exists(conn, constraint_name, table_name):
    try:
        r = conn.execute(text("""
            SELECT 1 FROM information_schema.table_constraints
            WHERE table_schema = 'public' AND table_name = :t AND constraint_name = :c
            AND constraint_type = 'FOREIGN KEY'
        """), {"t": table_name, "c": constraint_name})
        return r.fetchone() is not None
    except Exception:
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
    
    # Обновляем foreign keys в таблицах, ссылающихся на location (pole/poles, tap/taps, substation/substations)
    for table in [_resolve_table(conn, 'poles', 'pole'), _resolve_table(conn, 'taps', 'tap'), _resolve_table(conn, 'substations', 'substation')]:
        if not table or not _table_exists(conn, 'location'):
            continue
        constraint_name = f'{table}_location_id_fkey'
        if _constraint_exists(conn, constraint_name, table):
            op.drop_constraint(constraint_name, table, type_='foreignkey')
        if not _constraint_exists(conn, constraint_name, table):
            try:
                op.create_foreign_key(constraint_name, table, 'location', ['location_id'], ['id'])
            except Exception:
                pass
    
    # 2. Переименовываем base_voltage и wire_info (независимые)
    if _table_exists(conn, 'base_voltages') and not _table_exists(conn, 'base_voltage'):
        op.rename_table('base_voltages', 'base_voltage')
    if _table_exists(conn, 'wire_infos') and not _table_exists(conn, 'wire_info'):
        op.rename_table('wire_infos', 'wire_info')
    
    # 3. Переименовываем power_lines -> line (основная таблица)
    constraints_to_drop_line = [
        (('poles', 'pole'), 'poles_power_line_id_fkey', 'pole_power_line_id_fkey'),
        (('spans', 'span'), 'spans_power_line_id_fkey', 'spans_power_line_id_fkey'),
        (('taps', 'tap'), 'taps_power_line_id_fkey', 'taps_power_line_id_fkey'),
        (('connections',), 'connections_power_line_id_fkey', None),
        (('line_segments', 'line_section'), 'line_segments_power_line_id_fkey', None),
        (('acline_segments', 'acline_segment'), 'fk_acline_segments_power_line', None),
        (('connectivity_nodes', 'connectivity_node'), 'fk_connectivity_nodes_power_line', None),
    ]
    for candidates, c1, c2 in constraints_to_drop_line:
        table = _resolve_table(conn, *candidates)
        if not table:
            continue
        for c in (c1, c2):
            if c and _constraint_exists(conn, c, table):
                op.drop_constraint(c, table, type_='foreignkey')
                break

    if _table_exists(conn, 'power_lines') and not _table_exists(conn, 'line'):
        op.rename_table('power_lines', 'line')

    # Переименовываем колонку power_line_id -> line_id только если она есть
    line_related = [
        _resolve_table(conn, 'poles', 'pole'),
        _resolve_table(conn, 'spans', 'span'),
        _resolve_table(conn, 'taps', 'tap'),
        _resolve_table(conn, 'connections'),
        _resolve_table(conn, 'line_segments', 'line_section'),
        _resolve_table(conn, 'acline_segments', 'acline_segment'),
        _resolve_table(conn, 'connectivity_nodes', 'connectivity_node'),
    ]
    for table in line_related:
        if table and _table_exists(conn, 'line') and _column_exists(conn, table, 'power_line_id'):
            op.alter_column(table, 'power_line_id', new_column_name='line_id')

    # Создаём новые foreign key constraints на line
    if _table_exists(conn, 'line'):
        fk_line = [
            (_resolve_table(conn, 'poles', 'pole'), 'poles_line_id_fkey', 'pole_line_id_fkey'),
            (_resolve_table(conn, 'spans', 'span'), 'spans_line_id_fkey', None),
            (_resolve_table(conn, 'taps', 'tap'), 'taps_line_id_fkey', 'tap_line_id_fkey'),
            (_resolve_table(conn, 'connections'), 'connections_line_id_fkey', None),
            (_resolve_table(conn, 'line_segments', 'line_section'), 'line_segments_line_id_fkey', 'line_section_line_id_fkey'),
            (_resolve_table(conn, 'acline_segments', 'acline_segment'), 'acline_segments_line_id_fkey', 'acline_segment_line_id_fkey'),
            (_resolve_table(conn, 'connectivity_nodes', 'connectivity_node'), 'connectivity_nodes_line_id_fkey', 'connectivity_node_line_id_fkey'),
        ]
        for table, cname_plural, cname_singular in fk_line:
            if not table:
                continue
            cname = f'{table}_line_id_fkey'
            if _constraint_exists(conn, cname, table):
                continue
            try:
                op.create_foreign_key(cname, table, 'line', ['line_id'], ['id'])
            except Exception:
                pass
    
    # 4. Переименовываем substations -> substation
    for table in [_resolve_table(conn, 'connections'), _resolve_table(conn, 'voltage_levels', 'voltage_level'), _resolve_table(conn, 'connectivity_nodes', 'connectivity_node')]:
        if not table:
            continue
        for c in ('connections_substation_id_fkey', 'voltage_levels_substation_id_fkey', 'voltage_level_substation_id_fkey', 'fk_connectivity_nodes_substation_id', 'connectivity_nodes_substation_id_fkey', 'connectivity_node_substation_id_fkey'):
            if _constraint_exists(conn, c, table):
                op.drop_constraint(c, table, type_='foreignkey')
                break

    if _table_exists(conn, 'substations') and not _table_exists(conn, 'substation'):
        op.rename_table('substations', 'substation')

    if _table_exists(conn, 'substation'):
        for table in [_resolve_table(conn, 'connections'), _resolve_table(conn, 'voltage_levels', 'voltage_level'), _resolve_table(conn, 'connectivity_nodes', 'connectivity_node')]:
            if not table:
                continue
            cname = f'{table}_substation_id_fkey'
            if _constraint_exists(conn, cname, table):
                continue
            try:
                op.create_foreign_key(cname, table, 'substation', ['substation_id'], ['id'])
            except Exception:
                pass
    
    # 5. Переименовываем voltage_levels -> voltage_level
    bays_t = _resolve_table(conn, 'bays', 'bay')
    if bays_t and _constraint_exists(conn, f'{bays_t}_voltage_level_id_fkey', bays_t):
        op.drop_constraint(f'{bays_t}_voltage_level_id_fkey', bays_t, type_='foreignkey')

    if _table_exists(conn, 'voltage_levels') and not _table_exists(conn, 'voltage_level'):
        op.rename_table('voltage_levels', 'voltage_level')

    if bays_t and _table_exists(conn, 'voltage_level') and not _constraint_exists(conn, f'{bays_t}_voltage_level_id_fkey', bays_t):
        try:
            op.create_foreign_key(f'{bays_t}_voltage_level_id_fkey', bays_t, 'voltage_level', ['voltage_level_id'], ['id'])
        except Exception:
            pass
    
    # 6. Переименовываем connectivity_nodes -> connectivity_node
    for tbl, const in [
        (('terminals', 'terminal'), 'terminals_connectivity_node_id_fkey'),
        (('spans', 'span'), 'fk_spans_from_node'),
        (('spans', 'span'), 'fk_spans_to_node'),
        (('acline_segments', 'acline_segment'), 'fk_acline_segments_from_node'),
        (('acline_segments', 'acline_segment'), 'fk_acline_segments_to_node'),
        (('poles', 'pole'), 'fk_poles_connectivity_node'),
        (('connectivity_nodes', 'connectivity_node'), 'connectivity_nodes_pole_id_fkey'),
    ]:
        table = _resolve_table(conn, *tbl)
        if table and _constraint_exists(conn, const, table):
            op.drop_constraint(const, table, type_='foreignkey')

    if _table_exists(conn, 'connectivity_nodes') and not _table_exists(conn, 'connectivity_node'):
        op.rename_table('connectivity_nodes', 'connectivity_node')

    if _table_exists(conn, 'connectivity_node'):
        pole_t = _resolve_table(conn, 'poles', 'pole')
        for table, col in [
            (_resolve_table(conn, 'terminals', 'terminal'), 'connectivity_node_id'),
            (_resolve_table(conn, 'spans', 'span'), 'from_connectivity_node_id'),
            (_resolve_table(conn, 'spans', 'span'), 'to_connectivity_node_id'),
            (_resolve_table(conn, 'acline_segments', 'acline_segment'), 'from_connectivity_node_id'),
            (_resolve_table(conn, 'acline_segments', 'acline_segment'), 'to_connectivity_node_id'),
            (pole_t, 'connectivity_node_id'),
        ]:
            if not table:
                continue
            cname = f'{table}_{col}_fkey' if col != 'connectivity_node_id' else f'{table}_connectivity_node_id_fkey'
            if _constraint_exists(conn, cname, table):
                continue
            try:
                op.create_foreign_key(cname, table, 'connectivity_node', [col], ['id'])
            except Exception:
                pass
        if pole_t and not _constraint_exists(conn, 'connectivity_node_pole_id_fkey', 'connectivity_node'):
            try:
                op.create_foreign_key('connectivity_node_pole_id_fkey', 'connectivity_node', 'pole', ['pole_id'], ['id'])
            except Exception:
                pass
    
    # 7. Переименовываем terminals -> terminal
    acline_t = _resolve_table(conn, 'acline_segments', 'acline_segment')
    if acline_t and _constraint_exists(conn, 'fk_acline_segments_to_terminal', acline_t):
        op.drop_constraint('fk_acline_segments_to_terminal', acline_t, type_='foreignkey')

    if _table_exists(conn, 'terminals') and not _table_exists(conn, 'terminal'):
        op.rename_table('terminals', 'terminal')

    if acline_t and _table_exists(conn, 'terminal') and not _constraint_exists(conn, f'{acline_t}_to_terminal_id_fkey', acline_t):
        try:
            op.create_foreign_key(f'{acline_t}_to_terminal_id_fkey', acline_t, 'terminal', ['to_terminal_id'], ['id'])
        except Exception:
            pass

    # 8. Переименовываем acline_segments -> acline_segment
    for tbl in [_resolve_table(conn, 'line_segments', 'line_section'), _resolve_table(conn, 'line_sections', 'line_section'), _resolve_table(conn, 'terminals', 'terminal')]:
        if not tbl:
            continue
        c = f'{tbl}_acline_segment_id_fkey'
        if _constraint_exists(conn, c, tbl):
            op.drop_constraint(c, tbl, type_='foreignkey')

    if _table_exists(conn, 'acline_segments') and not _table_exists(conn, 'acline_segment'):
        op.rename_table('acline_segments', 'acline_segment')

    if _table_exists(conn, 'acline_segment'):
        for tbl in [_resolve_table(conn, 'line_segments', 'line_section'), _resolve_table(conn, 'line_sections', 'line_section'), _resolve_table(conn, 'terminals', 'terminal')]:
            if not tbl:
                continue
            cname = f'{tbl}_acline_segment_id_fkey'
            if _constraint_exists(conn, cname, tbl):
                continue
            try:
                op.create_foreign_key(cname, tbl, 'acline_segment', ['acline_segment_id'], ['id'])
            except Exception:
                pass

    # 9. Переименовываем line_sections -> line_section
    span_t = _resolve_table(conn, 'spans', 'span')
    if span_t and _constraint_exists(conn, 'fk_spans_line_section', span_t):
        op.drop_constraint('fk_spans_line_section', span_t, type_='foreignkey')

    if _table_exists(conn, 'line_sections') and not _table_exists(conn, 'line_section'):
        op.rename_table('line_sections', 'line_section')

    if span_t and _table_exists(conn, 'line_section') and not _constraint_exists(conn, f'{span_t}_line_section_id_fkey', span_t):
        try:
            op.create_foreign_key(f'{span_t}_line_section_id_fkey', span_t, 'line_section', ['line_section_id'], ['id'])
        except Exception:
            pass

    # 10. Переименовываем bays -> bay
    for tbl in [_resolve_table(conn, 'busbar_sections', 'busbar_section'), _resolve_table(conn, 'conducting_equipment'), _resolve_table(conn, 'protection_equipment'), _resolve_table(conn, 'terminals', 'terminal')]:
        if not tbl:
            continue
        c = f'{tbl}_bay_id_fkey'
        if _constraint_exists(conn, c, tbl):
            try:
                op.drop_constraint(c, tbl, type_='foreignkey')
            except Exception:
                pass

    if _table_exists(conn, 'bays') and not _table_exists(conn, 'bay'):
        op.rename_table('bays', 'bay')

    if _table_exists(conn, 'bay'):
        for tbl in [_resolve_table(conn, 'busbar_sections', 'busbar_section'), _resolve_table(conn, 'conducting_equipment'), _resolve_table(conn, 'protection_equipment'), _resolve_table(conn, 'terminals', 'terminal')]:
            if not tbl:
                continue
            cname = f'{tbl}_bay_id_fkey'
            if _constraint_exists(conn, cname, tbl):
                continue
            try:
                op.create_foreign_key(cname, tbl, 'bay', ['bay_id'], ['id'])
            except Exception:
                pass
    
    # 11. Переименовываем busbar_sections -> busbar_section
    if _table_exists(conn, 'busbar_sections') and not _table_exists(conn, 'busbar_section'):
        op.rename_table('busbar_sections', 'busbar_section')
    
    # 12. Переименовываем poles -> pole
    for tbl, const in [
        (('connectivity_nodes', 'connectivity_node'), 'connectivity_node_pole_id_fkey'),
        (('spans', 'span'), 'spans_from_pole_id_fkey'),
        (('spans', 'span'), 'spans_to_pole_id_fkey'),
        (('taps', 'tap'), 'taps_pole_id_fkey'),
        (('equipment',), 'equipment_pole_id_fkey'),
    ]:
        table = _resolve_table(conn, *tbl)
        if table and _constraint_exists(conn, const, table):
            try:
                op.drop_constraint(const, table, type_='foreignkey')
            except Exception:
                pass

    if _table_exists(conn, 'poles') and not _table_exists(conn, 'pole'):
        op.rename_table('poles', 'pole')

    pole_t = _resolve_table(conn, 'poles', 'pole')
    if pole_t and _column_exists(conn, pole_t, 'power_line_id'):
        op.alter_column(pole_t, 'power_line_id', new_column_name='line_id')

    if _table_exists(conn, 'pole'):
        for table, col in [
            (_resolve_table(conn, 'connectivity_nodes', 'connectivity_node'), 'pole_id'),
            (_resolve_table(conn, 'spans', 'span'), 'from_pole_id'),
            (_resolve_table(conn, 'spans', 'span'), 'to_pole_id'),
            (_resolve_table(conn, 'taps', 'tap'), 'pole_id'),
            (_resolve_table(conn, 'equipment'), 'pole_id'),
        ]:
            if not table:
                continue
            cname = f'{table}_{col}_fkey' if col != 'pole_id' else f'{table}_pole_id_fkey'
            if _constraint_exists(conn, cname, table):
                continue
            try:
                op.create_foreign_key(cname, table, 'pole', [col], ['id'])
            except Exception:
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
    
    # Переименовываем колонки line_id -> power_line_id обратно
    for table in [_resolve_table(conn, 'poles', 'pole'), _resolve_table(conn, 'spans', 'span'), _resolve_table(conn, 'taps', 'tap'),
                  _resolve_table(conn, 'connections'), _resolve_table(conn, 'line_segments', 'line_section'),
                  _resolve_table(conn, 'acline_segments', 'acline_segment'), _resolve_table(conn, 'connectivity_nodes', 'connectivity_node')]:
        if table and _column_exists(conn, table, 'line_id'):
            try:
                op.alter_column(table, 'line_id', new_column_name='power_line_id')
            except Exception:
                pass
