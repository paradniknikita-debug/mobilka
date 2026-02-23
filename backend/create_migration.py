"""
Скрипт для создания миграции Alembic
Использование: python create_migration.py "описание миграции"
"""
import sys
import os
from datetime import datetime

# Добавляем путь к проекту
sys.path.insert(0, os.path.dirname(__file__))

def create_migration_file(description: str):
    """Создает файл миграции с текущими изменениями"""
    
    # Генерируем revision ID (обычно это хеш, но для простоты используем timestamp)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    revision_id = f"{timestamp[:8]}_{timestamp[9:]}"
    
    # Создаем имя файла
    safe_description = description.lower().replace(" ", "_").replace("-", "_")
    filename = f"{revision_id}_{safe_description}.py"
    filepath = os.path.join("alembic", "versions", filename)
    
    # Определяем предыдущую ревизию (если есть миграции)
    versions_dir = os.path.join("alembic", "versions")
    existing_migrations = [f for f in os.listdir(versions_dir) if f.endswith(".py") and f != "__init__.py"]
    
    if existing_migrations:
        # Берем последнюю миграцию
        existing_migrations.sort()
        last_migration = existing_migrations[-1]
        # Извлекаем revision из имени файла (первые 17 символов обычно)
        down_revision = last_migration.split("_")[0] + "_" + last_migration.split("_")[1]
    else:
        down_revision = "None"
    
    # Содержимое миграции
    migration_content = f'''"""add_mrid_and_new_models

Revision ID: {revision_id}
Revises: {down_revision}
Create Date: {datetime.now().isoformat()}

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '{revision_id}'
down_revision = {f"'{down_revision}'" if down_revision != "None" else "None"}
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Создание таблицы geographic_regions
    op.create_table(
        'geographic_regions',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('mrid', sa.String(length=36), nullable=False),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('code', sa.String(length=20), nullable=False),
        sa.Column('region_type', sa.String(length=50), nullable=False),
        sa.Column('level', sa.Integer(), nullable=False),
        sa.Column('parent_id', sa.Integer(), nullable=True),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['parent_id'], ['geographic_regions.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_geographic_regions_code'), 'geographic_regions', ['code'], unique=True)
    op.create_index(op.f('ix_geographic_regions_id'), 'geographic_regions', ['id'], unique=False)
    op.create_index(op.f('ix_geographic_regions_mrid'), 'geographic_regions', ['mrid'], unique=True)
    
    # Добавление mrid во все существующие таблицы
    # PowerLine
    op.add_column('power_lines', sa.Column('mrid', sa.String(length=36), nullable=False, server_default=''))
    op.create_index(op.f('ix_power_lines_mrid'), 'power_lines', ['mrid'], unique=True)
    op.add_column('power_lines', sa.Column('region_id', sa.Integer(), nullable=True))
    op.create_foreign_key('fk_power_lines_region', 'power_lines', 'geographic_regions', ['region_id'], ['id'])
    
    # Tower
    op.add_column('towers', sa.Column('mrid', sa.String(length=36), nullable=False, server_default=''))
    op.create_index(op.f('ix_towers_mrid'), 'towers', ['mrid'], unique=True)
    
    # Substation
    op.add_column('substations', sa.Column('mrid', sa.String(length=36), nullable=False, server_default=''))
    op.create_index(op.f('ix_substations_mrid'), 'substations', ['mrid'], unique=True)
    op.add_column('substations', sa.Column('region_id', sa.Integer(), nullable=True))
    op.create_foreign_key('fk_substations_region', 'substations', 'geographic_regions', ['region_id'], ['id'])
    
    # Branch
    op.add_column('branches', sa.Column('mrid', sa.String(length=36), nullable=False, server_default=''))
    op.create_index(op.f('ix_branches_mrid'), 'branches', ['mrid'], unique=True)
    
    # Span
    op.add_column('spans', sa.Column('mrid', sa.String(length=36), nullable=False, server_default=''))
    op.create_index(op.f('ix_spans_mrid'), 'spans', ['mrid'], unique=True)
    
    # Tap
    op.add_column('taps', sa.Column('mrid', sa.String(length=36), nullable=False, server_default=''))
    op.create_index(op.f('ix_taps_mrid'), 'taps', ['mrid'], unique=True)
    
    # Equipment
    op.add_column('equipment', sa.Column('mrid', sa.String(length=36), nullable=False, server_default=''))
    op.create_index(op.f('ix_equipment_mrid'), 'equipment', ['mrid'], unique=True)
    
    # Генерируем UUID для существующих записей (если есть)
    op.execute("""
        UPDATE power_lines SET mrid = gen_random_uuid()::text WHERE mrid = '';
        UPDATE towers SET mrid = gen_random_uuid()::text WHERE mrid = '';
        UPDATE substations SET mrid = gen_random_uuid()::text WHERE mrid = '';
        UPDATE branches SET mrid = gen_random_uuid()::text WHERE mrid = '';
        UPDATE spans SET mrid = gen_random_uuid()::text WHERE mrid = '';
        UPDATE taps SET mrid = gen_random_uuid()::text WHERE mrid = '';
        UPDATE equipment SET mrid = gen_random_uuid()::text WHERE mrid = '';
    """)


def downgrade() -> None:
    # Удаление индексов и колонок mrid
    op.drop_index(op.f('ix_equipment_mrid'), table_name='equipment')
    op.drop_column('equipment', 'mrid')
    
    op.drop_index(op.f('ix_taps_mrid'), table_name='taps')
    op.drop_column('taps', 'mrid')
    
    op.drop_index(op.f('ix_spans_mrid'), table_name='spans')
    op.drop_column('spans', 'mrid')
    
    op.drop_index(op.f('ix_branches_mrid'), table_name='branches')
    op.drop_column('branches', 'mrid')
    
    op.drop_constraint('fk_substations_region', 'substations', type_='foreignkey')
    op.drop_column('substations', 'region_id')
    op.drop_index(op.f('ix_substations_mrid'), table_name='substations')
    op.drop_column('substations', 'mrid')
    
    op.drop_index(op.f('ix_towers_mrid'), table_name='towers')
    op.drop_column('towers', 'mrid')
    
    op.drop_constraint('fk_power_lines_region', 'power_lines', type_='foreignkey')
    op.drop_column('power_lines', 'region_id')
    op.drop_index(op.f('ix_power_lines_mrid'), table_name='power_lines')
    op.drop_column('power_lines', 'mrid')
    
    op.drop_index(op.f('ix_geographic_regions_mrid'), table_name='geographic_regions')
    op.drop_index(op.f('ix_geographic_regions_id'), table_name='geographic_regions')
    op.drop_index(op.f('ix_geographic_regions_code'), table_name='geographic_regions')
    op.drop_table('geographic_regions')
'''
    
    # Записываем файл
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(migration_content)
    
    print(f"✅ Миграция создана: {filepath}")
    print(f"   Revision: {revision_id}")
    print(f"   Down revision: {down_revision}")
    print(f"\n📝 Следующие шаги:")
    print(f"   1. Проверь файл миграции: {filepath}")
    print(f"   2. Примени миграцию: alembic upgrade head")
    print(f"   3. Или через Docker: docker compose exec backend alembic upgrade head")

if __name__ == "__main__":
    description = sys.argv[1] if len(sys.argv) > 1 else "add_mrid_and_new_models"
    create_migration_file(description)

