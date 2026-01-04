"""allow_multiple_connectivity_nodes_per_pole

Revision ID: 20241216_000000
Revises: 20241215_100000
Create Date: 2024-12-16 00:00:00.000000

Разрешение нескольких ConnectivityNode на одной опоре для поддержки совместного подвеса:
- Удаление unique constraint с pole_id в connectivity_nodes
- Добавление power_line_id в connectivity_nodes для связи с линией
- Обновление существующих записей для установки power_line_id из связанной опоры
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

# revision identifiers, used by Alembic.
revision = '20241216_000000'
down_revision = '20241201_000000'  # Ссылаемся на последнюю применённую миграцию
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    existing_tables = inspector.get_table_names()
    
    if 'connectivity_nodes' in existing_tables:
        existing_columns = [col['name'] for col in inspector.get_columns('connectivity_nodes')]
        
        # 1. Удаляем unique constraint с pole_id (если есть)
        try:
            # Проверяем, есть ли unique constraint
            constraints = inspector.get_unique_constraints('connectivity_nodes')
            for constraint in constraints:
                if 'pole_id' in constraint['column_names']:
                    op.drop_constraint(constraint['name'], 'connectivity_nodes', type_='unique')
                    print(f"Удалён unique constraint '{constraint['name']}' с pole_id в connectivity_nodes")
        except Exception as e:
            print(f"Ошибка при удалении unique constraint: {e}")
        
        # 2. Добавляем power_line_id, если его нет
        if 'power_line_id' not in existing_columns:
            # Сначала добавляем колонку как nullable
            op.add_column('connectivity_nodes', sa.Column('power_line_id', sa.Integer(), nullable=True))
            
            # Заполняем power_line_id из связанной опоры для существующих записей
            op.execute("""
                UPDATE connectivity_nodes
                SET power_line_id = (
                    SELECT power_line_id
                    FROM poles
                    WHERE poles.id = connectivity_nodes.pole_id
                )
                WHERE power_line_id IS NULL;
            """)
            
            # Теперь делаем колонку NOT NULL
            op.alter_column('connectivity_nodes', 'power_line_id', nullable=False)
            
            # Добавляем foreign key constraint
            op.create_foreign_key(
                'fk_connectivity_nodes_power_line',
                'connectivity_nodes',
                'power_lines',
                ['power_line_id'],
                ['id']
            )
            
            # Создаём индекс для улучшения производительности
            op.create_index(
                'ix_connectivity_nodes_power_line_id',
                'connectivity_nodes',
                ['power_line_id']
            )
            
            print("Добавлена колонка 'power_line_id' в 'connectivity_nodes'")
        else:
            print("Колонка 'power_line_id' уже существует в 'connectivity_nodes'")


def downgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    existing_tables = inspector.get_table_names()
    
    if 'connectivity_nodes' in existing_tables:
        existing_columns = [col['name'] for col in inspector.get_columns('connectivity_nodes')]
        
        # 1. Удаляем power_line_id
        if 'power_line_id' in existing_columns:
            # Удаляем индекс
            try:
                op.drop_index('ix_connectivity_nodes_power_line_id', table_name='connectivity_nodes')
            except Exception:
                pass
            
            # Удаляем foreign key
            try:
                op.drop_constraint('fk_connectivity_nodes_power_line', 'connectivity_nodes', type_='foreignkey')
            except Exception:
                pass
            
            # Удаляем колонку
            op.drop_column('connectivity_nodes', 'power_line_id')
            print("Удалена колонка 'power_line_id' из 'connectivity_nodes'")
        
        # 2. Восстанавливаем unique constraint на pole_id
        try:
            op.create_unique_constraint('uq_connectivity_nodes_pole_id', 'connectivity_nodes', ['pole_id'])
            print("Восстановлен unique constraint на pole_id в connectivity_nodes")
        except Exception as e:
            print(f"Ошибка при восстановлении unique constraint: {e}")

