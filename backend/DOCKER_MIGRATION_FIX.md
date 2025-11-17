# Исправление проблем с миграциями в Docker

## Проблема 1: "Path doesn't exist: '/app/alembic'"

### Причина
Папка `alembic` не копируется в Docker образ или не существует в контейнере.

### Решение

1. **Проверь, что папка существует локально:**
   ```bash
   ls -la backend/alembic
   ```
   Должны быть файлы:
   - `env.py`
   - `script.py.mako`
   - `versions/` (папка с миграциями)

2. **Пересобери Docker образ:**
   ```bash
   docker compose build backend
   ```

3. **Проверь, что папка скопировалась в контейнер:**
   ```bash
   docker compose exec backend ls -la /app/alembic
   ```

4. **Если папки нет, проверь Dockerfile:**
   В `backend/Dockerfile` должна быть строка:
   ```dockerfile
   COPY . .
   ```
   Это копирует все файлы, включая папку `alembic`.

5. **Примени миграцию:**
   ```bash
   docker compose exec backend alembic upgrade head
   ```

## Проблема 2: Ошибка парсинга .env файла

### Причина
`SECRET_KEY` в `.env` файле содержит многострочное значение с символами `/`, которые парсер не может обработать.

### Решение

1. **Открой файл `backend/.env`** (или создай из `backend/env_example.txt`)

2. **Исправь формат SECRET_KEY:**

   **Вариант А: Оберни в кавычки (одна строка)**
   ```env
   SECRET_KEY="MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDPHCU2Pc1VSACh..."
   ```

   **Вариант Б: Используй простой ключ для разработки**
   ```env
   SECRET_KEY=dev-secret-key-change-in-production-12345
   ```

3. **Убедись, что нет лишних пробелов:**
   ```env
   # ❌ Неправильно (пробел после =)
   SECRET_KEY= "значение"
   
   # ✅ Правильно
   SECRET_KEY="значение"
   ```

4. **Проверь, что файл сохранен в правильной кодировке (UTF-8)**

## Проблема 3: "InterpolationSyntaxError: '%' must be followed by '%' or '('"

### Причина
В `alembic.ini` есть строка `version_num_format = %04d`, и ConfigParser интерпретирует `%` как начало интерполяции.

### Решение
Исправь строку 37 в `backend/alembic.ini`:
```ini
# ❌ Неправильно
version_num_format = %04d

# ✅ Правильно (экранируй % как %%)
version_num_format = %%04d
```

**Уже исправлено в файле!** Просто пересобери образ:
```bash
docker compose build backend
```

## Проблема 4: Alembic не находит модели

### Причина
В `alembic/env.py` не импортированы все модели.

### Решение

Проверь, что в `backend/alembic/env.py` есть импорты:
```python
from app.models import (
    User, PowerLine, Tower, Span, Tap, Equipment,
    Branch, Substation, Connection,
    GeographicRegion, AClineSegment
)
```

## Полная последовательность действий

```bash
# 1. Исправь .env файл (если есть проблема)
# Открой backend/.env и исправь SECRET_KEY

# 2. Пересобери образ
docker compose build backend

# 3. Запусти контейнеры
docker compose up -d

# 4. Проверь, что папка alembic существует в контейнере
docker compose exec backend ls -la /app/alembic

# 5. Примени миграцию
docker compose exec backend alembic upgrade head

# 6. Проверь текущую версию
docker compose exec backend alembic current

# 7. Добавь тестовые данные
docker compose exec backend python seed_test_data.py
```

## Альтернативный способ: выполнение миграции локально

Если проблемы с Docker продолжаются, можно выполнить миграцию локально:

```bash
cd backend

# 1. Убедись, что PostgreSQL запущен и доступен
# 2. Проверь DATABASE_URL в .env

# 3. Примени миграцию
alembic upgrade head

# 4. Добавь тестовые данные
python seed_test_data.py
```

**Важно:** Для локального выполнения нужен доступ к той же БД, что и в Docker (или измени `DATABASE_URL` в `.env`).

## Проверка после миграции

```bash
# Подключись к БД через Docker
docker compose exec postgres psql -U postgres -d lepm_db

# В psql выполни:
\dt                    # Список таблиц
SELECT * FROM geographic_regions;
SELECT * FROM acline_segments;
SELECT mrid FROM power_lines LIMIT 5;  # Проверь, что mrid заполнен
```

