# Руководство по работе с миграциями Alembic

## Что такое миграции?

**Миграции** — это способ управлять изменениями структуры базы данных версионированно. Вместо того чтобы вручную изменять таблицы в БД, мы создаем файлы миграций, которые описывают, какие изменения нужно применить.

## Структура Alembic

```
backend/
├── alembic.ini          # Конфигурация Alembic
├── alembic/
│   ├── env.py          # Настройка окружения (подключение к БД, импорт моделей)
│   ├── script.py.mako  # Шаблон для создания файлов миграций
│   └── versions/       # Папка с файлами миграций
│       └── 20241116_170000_add_mrid_and_new_models.py
```

## Как работает миграция

### 1. Создание миграции

**Автоматическое создание (рекомендуется):**
```bash
cd backend
alembic revision --autogenerate -m "описание изменений"
```

Alembic сравнивает текущие модели SQLAlchemy с текущей структурой БД и автоматически генерирует миграцию.

**Ручное создание:**
```bash
alembic revision -m "описание изменений"
```

Создается пустой файл миграции, который нужно заполнить вручную.

### 2. Структура файла миграции

Каждый файл миграции содержит:

```python
"""add_mrid_and_new_models

Revision ID: 20241116_170000
Revises: None  # ID предыдущей миграции
Create Date: 2024-11-16 17:00:00
"""

from alembic import op
import sqlalchemy as sa

revision = '20241116_170000'
down_revision = None  # или '20241115_120000'
branch_labels = None
depends_on = None

def upgrade() -> None:
    # Код для применения изменений
    op.create_table(...)
    op.add_column(...)

def downgrade() -> None:
    # Код для отката изменений (обратные операции)
    op.drop_table(...)
    op.drop_column(...)
```

### 3. Применение миграций

**Применить все миграции до последней:**
```bash
alembic upgrade head
```

**Применить конкретную миграцию:**
```bash
alembic upgrade 20241116_170000
```

**Применить следующую миграцию:**
```bash
alembic upgrade +1
```

### 4. Откат миграций

**Откатить последнюю миграцию:**
```bash
alembic downgrade -1
```

**Откатить до конкретной миграции:**
```bash
alembic downgrade 20241115_120000
```

**Откатить все миграции:**
```bash
alembic downgrade base
```

### 5. Просмотр истории миграций

**Текущая версия:**
```bash
alembic current
```

**История миграций:**
```bash
alembic history
```

**Показать SQL без выполнения:**
```bash
alembic upgrade head --sql
```

## Работа с Docker

Если база данных запущена в Docker:

```bash
# Применить миграции
docker compose exec backend alembic upgrade head

# Создать новую миграцию
docker compose exec backend alembic revision --autogenerate -m "описание"

# Просмотреть текущую версию
docker compose exec backend alembic current
```

## Важные моменты

### 1. Всегда проверяй автогенерированные миграции

Alembic может не заметить некоторые изменения:
- Переименование колонок (он создаст новую и удалит старую)
- Изменение типов данных (может потерять данные)
- Сложные изменения индексов

**Решение:** Всегда проверяй файл миграции перед применением!

### 2. Не редактируй примененные миграции

Если миграция уже применена к БД, не редактируй её файл. Вместо этого создай новую миграцию.

### 3. Резервное копирование перед миграциями

Перед применением миграций на production всегда делай бэкап БД:
```bash
pg_dump -U postgres lepm_db > backup.sql
```

### 4. Генерация UUID для существующих записей

В нашей миграции мы используем PostgreSQL функцию `gen_random_uuid()`:
```sql
UPDATE power_lines SET mrid = gen_random_uuid()::text WHERE mrid = '';
```

Это безопасно, так как выполняется только для записей с пустым mrid.

## Примеры операций

### Добавление колонки
```python
def upgrade():
    op.add_column('power_lines', sa.Column('new_field', sa.String(100), nullable=True))

def downgrade():
    op.drop_column('power_lines', 'new_field')
```

### Создание таблицы
```python
def upgrade():
    op.create_table(
        'new_table',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('name', sa.String(100), nullable=False),
    )

def downgrade():
    op.drop_table('new_table')
```

### Создание индекса
```python
def upgrade():
    op.create_index('ix_power_lines_name', 'power_lines', ['name'])

def downgrade():
    op.drop_index('ix_power_lines_name', table_name='power_lines')
```

### Создание внешнего ключа
```python
def upgrade():
    op.create_foreign_key(
        'fk_power_lines_region',
        'power_lines', 'geographic_regions',
        ['region_id'], ['id']
    )

def downgrade():
    op.drop_constraint('fk_power_lines_region', 'power_lines', type_='foreignkey')
```

## Что делает наша текущая миграция

1. **Создает таблицу `geographic_regions`** — для географической иерархии
2. **Создает таблицу `acline_segments`** — для сегментов линий
3. **Создает промежуточную таблицу `line_segments`** — для связи many-to-many
4. **Добавляет поле `mrid`** во все существующие таблицы
5. **Добавляет поле `region_id`** в `power_lines` и `substations`
6. **Добавляет поле `segment_id`** в `towers`
7. **Генерирует UUID** для всех существующих записей

## Следующие шаги

После применения миграции:
1. Проверь, что все таблицы созданы: `\dt` в psql
2. Проверь, что все индексы созданы: `\di` в psql
3. Добавь тестовые данные
4. Протестируй работу приложения

