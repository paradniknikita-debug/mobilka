"""rename_power_line_id_to_line_id_in_pole

Revision ID: b64942757d2c
Revises: df0c351f69f8
Create Date: 2026-02-08 14:26:25.784933

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import text


# revision identifiers, used by Alembic.
revision = 'b64942757d2c'
down_revision = 'df0c351f69f8'
branch_labels = None
depends_on = None


def _column_exists(conn, table_name, column_name):
    """Проверяет существование колонки"""
    try:
        result = conn.execute(text("""
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_name = :table_name 
            AND column_name = :column_name
        """), {"table_name": table_name, "column_name": column_name})
        return result.fetchone() is not None
    except:
        return False


def _constraint_exists(conn, constraint_name, table_name):
    """Проверяет существование constraint"""
    try:
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
    
    # Переименовываем колонку power_line_id в line_id в таблице pole
    if _column_exists(conn, 'pole', 'power_line_id') and not _column_exists(conn, 'pole', 'line_id'):
        # Удаляем старый foreign key constraint
        try:
            if _constraint_exists(conn, 'pole_power_line_id_fkey', 'pole'):
                op.drop_constraint('pole_power_line_id_fkey', 'pole', type_='foreignkey')
        except:
            pass
        
        # Переименовываем колонку
        op.alter_column('pole', 'power_line_id', new_column_name='line_id')
        
        # Создаём новый foreign key constraint
        try:
            if not _constraint_exists(conn, 'pole_line_id_fkey', 'pole'):
                op.create_foreign_key('pole_line_id_fkey', 'pole', 'line', ['line_id'], ['id'])
        except:
            pass


def downgrade() -> None:
    conn = op.get_bind()
    
    # Переименовываем колонку line_id обратно в power_line_id в таблице pole
    if _column_exists(conn, 'pole', 'line_id') and not _column_exists(conn, 'pole', 'power_line_id'):
        # Удаляем новый foreign key constraint
        try:
            if _constraint_exists(conn, 'pole_line_id_fkey', 'pole'):
                op.drop_constraint('pole_line_id_fkey', 'pole', type_='foreignkey')
        except:
            pass
        
        # Переименовываем колонку
        op.alter_column('pole', 'line_id', new_column_name='power_line_id')
        
        # Создаём старый foreign key constraint
        try:
            if not _constraint_exists(conn, 'pole_power_line_id_fkey', 'pole'):
                op.create_foreign_key('pole_power_line_id_fkey', 'pole', 'line', ['power_line_id'], ['id'])
        except:
            pass

