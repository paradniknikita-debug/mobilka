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


def _safe_rename_table(conn, op, old_name, new_name):
    """Переименование таблицы без падения транзакции при ошибке."""
    if _table_exists(conn, old_name) and not _table_exists(conn, new_name):
        try:
            op.rename_table(old_name, new_name)
        except Exception as e:
            print(f"Warning: rename_table({old_name} -> {new_name}): {e}")


def _safe_drop_constraint(op, constraint_name, table_name, type_='foreignkey'):
    try:
        op.drop_constraint(constraint_name, table_name, type_=type_)
        return True
    except Exception as e:
        print(f"Warning: drop_constraint({constraint_name} on {table_name}): {e}")
        return False


def _safe_create_fk(op, constraint_name, table_name, referent_table, local_cols, remote_cols):
    try:
        op.create_foreign_key(constraint_name, table_name, referent_table, local_cols, remote_cols)
        return True
    except Exception as e:
        print(f"Warning: create_foreign_key({constraint_name}): {e}")
        return False


def _safe_alter_column(op, table_name, col_name, new_column_name):
    try:
        op.alter_column(table_name, col_name, new_column_name=new_column_name)
        return True
    except Exception as e:
        print(f"Warning: alter_column({table_name}.{col_name} -> {new_column_name}): {e}")
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
    _safe_rename_table(conn, op, 'locations', 'location')
    _safe_rename_table(conn, op, 'position_points', 'position_point')
    
    # Обновляем foreign keys для location (проверяем существование constraint)
    try:
        position_table = 'position_point' if _table_exists(conn, 'position_point') else 'position_points'
        if _table_exists(conn, position_table):
            if _constraint_exists(conn, 'position_points_location_id_fkey', position_table):
                _safe_drop_constraint(op, 'position_points_location_id_fkey', position_table)
            elif _constraint_exists(conn, 'position_point_location_id_fkey', position_table):
                _safe_drop_constraint(op, 'position_point_location_id_fkey', position_table)
            
            if _table_exists(conn, 'position_point') and _table_exists(conn, 'location'):
                if not _constraint_exists(conn, 'position_point_location_id_fkey', 'position_point'):
                    _safe_create_fk(op, 'position_point_location_id_fkey', 'position_point', 'location', ['location_id'], ['id'])
    except Exception as e:
        print(f"Warning: Error updating position_point foreign keys: {e}")
    
    # Обновляем foreign keys в таблицах, ссылающихся на location (pole/poles, tap/taps, substation/substations)
    for table in [_resolve_table(conn, 'poles', 'pole'), _resolve_table(conn, 'taps', 'tap'), _resolve_table(conn, 'substations', 'substation')]:
        if not table or not _table_exists(conn, 'location'):
            continue
        constraint_name = f'{table}_location_id_fkey'
        if _constraint_exists(conn, constraint_name, table):
            _safe_drop_constraint(op, constraint_name, table)
        if not _constraint_exists(conn, constraint_name, table):
            _safe_create_fk(op, constraint_name, table, 'location', ['location_id'], ['id'])
    
    # 2. Переименовываем base_voltage и wire_info (независимые)
    _safe_rename_table(conn, op, 'base_voltages', 'base_voltage')
    _safe_rename_table(conn, op, 'wire_infos', 'wire_info')
    
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
                _safe_drop_constraint(op, c, table)
                break

    _safe_rename_table(conn, op, 'power_lines', 'line')

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
            _safe_alter_column(op, table, 'power_line_id', 'line_id')

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
            # Создаём FK только если в таблице реально есть колонка line_id
            if not table or not _column_exists(conn, table, 'line_id'):
                continue
            cname = f'{table}_line_id_fkey'
            if _constraint_exists(conn, cname, table):
                continue
            _safe_create_fk(op, cname, table, 'line', ['line_id'], ['id'])
    
    # 4. Переименовываем substations -> substation
    for table in [_resolve_table(conn, 'connections'), _resolve_table(conn, 'voltage_levels', 'voltage_level'), _resolve_table(conn, 'connectivity_nodes', 'connectivity_node')]:
        if not table:
            continue
        for c in ('connections_substation_id_fkey', 'voltage_levels_substation_id_fkey', 'voltage_level_substation_id_fkey', 'fk_connectivity_nodes_substation_id', 'connectivity_nodes_substation_id_fkey', 'connectivity_node_substation_id_fkey'):
            if _constraint_exists(conn, c, table):
                _safe_drop_constraint(op, c, table)
                break

    _safe_rename_table(conn, op, 'substations', 'substation')

    if _table_exists(conn, 'substation'):
        for table in [_resolve_table(conn, 'connections'), _resolve_table(conn, 'voltage_levels', 'voltage_level'), _resolve_table(conn, 'connectivity_nodes', 'connectivity_node')]:
            if not table:
                continue
            cname = f'{table}_substation_id_fkey'
            if _constraint_exists(conn, cname, table):
                continue
            _safe_create_fk(op, cname, table, 'substation', ['substation_id'], ['id'])
    
    # 5. Переименовываем voltage_levels -> voltage_level
    bays_t = _resolve_table(conn, 'bays', 'bay')
    if bays_t and _constraint_exists(conn, f'{bays_t}_voltage_level_id_fkey', bays_t):
        _safe_drop_constraint(op, f'{bays_t}_voltage_level_id_fkey', bays_t)

    _safe_rename_table(conn, op, 'voltage_levels', 'voltage_level')

    if bays_t and _table_exists(conn, 'voltage_level') and not _constraint_exists(conn, f'{bays_t}_voltage_level_id_fkey', bays_t):
        _safe_create_fk(op, f'{bays_t}_voltage_level_id_fkey', bays_t, 'voltage_level', ['voltage_level_id'], ['id'])
    
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
            _safe_drop_constraint(op, const, table)

    _safe_rename_table(conn, op, 'connectivity_nodes', 'connectivity_node')

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
            _safe_create_fk(op, cname, table, 'connectivity_node', [col], ['id'])
        if pole_t and not _constraint_exists(conn, 'connectivity_node_pole_id_fkey', 'connectivity_node'):
            _safe_create_fk(op, 'connectivity_node_pole_id_fkey', 'connectivity_node', 'pole', ['pole_id'], ['id'])
    
    # 7. Переименовываем terminals -> terminal
    acline_t = _resolve_table(conn, 'acline_segments', 'acline_segment')
    if acline_t and _constraint_exists(conn, 'fk_acline_segments_to_terminal', acline_t):
        _safe_drop_constraint(op, 'fk_acline_segments_to_terminal', acline_t)

    _safe_rename_table(conn, op, 'terminals', 'terminal')

    if acline_t and _table_exists(conn, 'terminal') and not _constraint_exists(conn, f'{acline_t}_to_terminal_id_fkey', acline_t):
        _safe_create_fk(op, f'{acline_t}_to_terminal_id_fkey', acline_t, 'terminal', ['to_terminal_id'], ['id'])

    # 8. Переименовываем acline_segments -> acline_segment
    for tbl in [_resolve_table(conn, 'line_segments', 'line_section'), _resolve_table(conn, 'line_sections', 'line_section'), _resolve_table(conn, 'terminals', 'terminal')]:
        if not tbl:
            continue
        c = f'{tbl}_acline_segment_id_fkey'
        if _constraint_exists(conn, c, tbl):
            _safe_drop_constraint(op, c, tbl)

    _safe_rename_table(conn, op, 'acline_segments', 'acline_segment')

    if _table_exists(conn, 'acline_segment'):
        for tbl in [_resolve_table(conn, 'line_segments', 'line_section'), _resolve_table(conn, 'line_sections', 'line_section'), _resolve_table(conn, 'terminals', 'terminal')]:
            if not tbl:
                continue
            cname = f'{tbl}_acline_segment_id_fkey'
            if _constraint_exists(conn, cname, tbl):
                continue
            _safe_create_fk(op, cname, tbl, 'acline_segment', ['acline_segment_id'], ['id'])

    # 9. Переименовываем line_sections -> line_section
    span_t = _resolve_table(conn, 'spans', 'span')
    if span_t and _constraint_exists(conn, 'fk_spans_line_section', span_t):
        _safe_drop_constraint(op, 'fk_spans_line_section', span_t)

    _safe_rename_table(conn, op, 'line_sections', 'line_section')

    if span_t and _table_exists(conn, 'line_section') and not _constraint_exists(conn, f'{span_t}_line_section_id_fkey', span_t):
        _safe_create_fk(op, f'{span_t}_line_section_id_fkey', span_t, 'line_section', ['line_section_id'], ['id'])

    # 10. Переименовываем bays -> bay
    for tbl in [_resolve_table(conn, 'busbar_sections', 'busbar_section'), _resolve_table(conn, 'conducting_equipment'), _resolve_table(conn, 'protection_equipment'), _resolve_table(conn, 'terminals', 'terminal')]:
        if not tbl:
            continue
        c = f'{tbl}_bay_id_fkey'
        if _constraint_exists(conn, c, tbl):
            _safe_drop_constraint(op, c, tbl)

    _safe_rename_table(conn, op, 'bays', 'bay')

    if _table_exists(conn, 'bay'):
        for tbl in [_resolve_table(conn, 'busbar_sections', 'busbar_section'), _resolve_table(conn, 'conducting_equipment'), _resolve_table(conn, 'protection_equipment'), _resolve_table(conn, 'terminals', 'terminal')]:
            if not tbl:
                continue
            cname = f'{tbl}_bay_id_fkey'
            if _constraint_exists(conn, cname, tbl):
                continue
            _safe_create_fk(op, cname, tbl, 'bay', ['bay_id'], ['id'])
    
    # 11. Переименовываем busbar_sections -> busbar_section
    _safe_rename_table(conn, op, 'busbar_sections', 'busbar_section')
    
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
            _safe_drop_constraint(op, const, table)

    _safe_rename_table(conn, op, 'poles', 'pole')

    pole_t = _resolve_table(conn, 'poles', 'pole')
    if pole_t and _column_exists(conn, pole_t, 'power_line_id'):
        _safe_alter_column(op, pole_t, 'power_line_id', 'line_id')

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
            _safe_create_fk(op, cname, table, 'pole', [col], ['id'])


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
