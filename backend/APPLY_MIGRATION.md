# Инструкция по применению миграции и добавлению тестовых данных

## Шаг 1: Исправление проблем перед миграцией

### Проблема 1: Ошибка с .env файлом

Если видишь ошибку:
```
failed to read D:\Diplom\mobilka\backend\.env: line 9: unexpected character "/" in variable name
```

**Решение:**
1. Открой файл `backend/.env` (или создай его из `backend/env_example.txt`)
2. Убедись, что `SECRET_KEY` в **одной строке** и обернут в кавычки:
   ```env
   SECRET_KEY="MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDPHCU2Pc1VSACh..."
   ```
3. Или используй простой SECRET_KEY для разработки:
   ```env
   SECRET_KEY=dev-secret-key-change-in-production-12345
   ```

### Проблема 2: Папка alembic не найдена в Docker

Если видишь ошибку:
```
FAILED: Path doesn't exist: '/app/alembic'
```

**Решение:**
1. Убедись, что папка `backend/alembic` существует локально
2. Пересобери Docker образ, чтобы скопировать папку alembic:
   ```bash
   docker compose build backend
   ```

### Проблема 3: "InterpolationSyntaxError: '%' must be followed by '%' or '('"

Если видишь ошибку:
```
configparser.InterpolationSyntaxError: '%' must be followed by '%' or '(', found: '%04d'
```

**Решение:**
Это уже исправлено в `backend/alembic.ini` (строка 38: `version_num_format = %%04d`).
Просто пересобери образ:
```bash
docker compose build backend
```

## Шаг 2: Применение миграции

Миграция добавляет:
- Поле `mrid` (UUID) во все таблицы
- Таблицу `geographic_regions` (географическая иерархия)
- Таблицу `acline_segments` (сегменты линий)
- Промежуточную таблицу `line_segments` (many-to-many)
- Связи между таблицами

### Вариант 1: Через Docker (рекомендуется)

```bash
# 1. Пересобери образ (чтобы скопировать папку alembic)
docker compose build backend

# 2. Запусти контейнеры
docker compose up -d

# 3. Применить миграцию (рабочая директория в контейнере: /app)
docker compose exec backend alembic upgrade head

# 4. Проверить текущую версию
docker compose exec backend alembic current
```

**Важно:** Команда выполняется из рабочей директории `/app` внутри контейнера, где должен находиться файл `alembic.ini` и папка `alembic/`.

### Вариант 2: Локально

```bash
cd backend

# Убедись, что БД запущена и доступна
# Проверь DATABASE_URL в .env файле

# Применить миграцию
alembic upgrade head
```

### Что происходит при применении миграции?

1. Создаются новые таблицы (`geographic_regions`, `acline_segments`, `line_segments`)
2. Добавляется поле `mrid` во все существующие таблицы
3. Генерируются UUID для всех существующих записей (если они есть)
4. Добавляются внешние ключи и индексы

## Шаг 2: Добавление тестовых данных

После применения миграции добавь тестовые данные:

### Вариант 1: Через Docker

```bash
docker compose exec backend python seed_test_data.py
```

### Вариант 2: Локально

```bash
cd backend
python seed_test_data.py
```

### Что создается?

- **Пользователь**: `admin` / `admin123` (суперпользователь)
- **Географическая иерархия**:
  - Рабочая область "Минск" (уровень 0)
  - ФЭС "Минская" (уровень 1)
  - РЭС "Минск-Запад" (уровень 2)
- **Подстанция**: "Подстанция 110/10 кВ №1" (координаты Минска)
- **Линия**: "ЛЭП 110 кВ Минск-Западная" (25.5 км)
- **Опоры**: 4 опоры (T001-T004) вдоль линии
- **Сегменты**: 2 сегмента линии, связанные с опорами

## Шаг 3: Проверка данных

### Через psql (Docker)

```bash
docker compose exec postgres psql -U postgres -d lepm_db

# В psql:
\dt                    # Список таблиц
SELECT * FROM geographic_regions;
SELECT * FROM power_lines;
SELECT * FROM towers;
SELECT * FROM acline_segments;
```

### Через API

После запуска backend:

```bash
# Проверка health
curl https://localhost/api/v1/test

# Swagger документация
# Открой в браузере: https://localhost/docs
```

## Возможные проблемы

### Ошибка: "relation does not exist"

**Причина**: Таблицы еще не созданы.

**Решение**: 
1. Проверь, что миграция применена: `alembic current`
2. Если миграций нет, создай начальную: `alembic revision --autogenerate -m "Initial"`
3. Примени: `alembic upgrade head`

### Ошибка: "duplicate key value violates unique constraint"

**Причина**: Тестовые данные уже существуют.

**Решение**: Скрипт `seed_test_data.py` проверяет существование данных и не создает дубликаты. Если нужно пересоздать данные, сначала удали их вручную или откати миграцию и примени заново.

### Ошибка подключения к БД

**Причина**: Неправильный `DATABASE_URL` или БД не запущена.

**Решение**:
1. Проверь `.env` файл в `backend/`
2. Для Docker: убедись, что `postgres` сервис запущен: `docker compose ps`
3. Для локального: убедись, что PostgreSQL запущен и доступен

## Следующие шаги

После успешного применения миграции и добавления тестовых данных:

1. ✅ Проверь структуру БД
2. ✅ Проверь тестовые данные
3. ✅ Создай API endpoints для работы с новыми моделями
4. ✅ Создай UI компонент дерева объектов на фронтенде

## Полезные команды

```bash
# История миграций
alembic history

# Откат последней миграции
alembic downgrade -1

# Показать SQL без выполнения
alembic upgrade head --sql

# Создать новую миграцию (после изменения моделей)
alembic revision --autogenerate -m "описание изменений"
```

