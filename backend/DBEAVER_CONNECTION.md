# Подключение DBeaver к Docker PostgreSQL

## Проблема: DBeaver не видит тестовые данные

Если ты не видишь тестовые данные в DBeaver, скорее всего ты подключен к **локальной** базе данных, а не к той, что в Docker контейнере.

## Решение: Подключись к Docker PostgreSQL

**✅ Порт уже проброшен в `docker-compose.yml`!**

### Настройки подключения в DBeaver:

1. **Создай новое подключение PostgreSQL:**
   - Правый клик на "Databases" → **New** → **Database Connection**
   - Выбери **PostgreSQL**

2. **Заполни параметры:**
   - **Host:** `localhost` (или `127.0.0.1`)
   - **Port:** `5433` ⚠️ **ВАЖНО: Используй порт 5433, а не 5432!**
   - **Database:** `lepm_db`
   - **Username:** `postgres`
   - **Password:** `dragon167` (пароль из `config.py` и `docker-compose.yml`)

3. **Проверь подключение:**
   - Нажми **Test Connection**
   - Если всё ОК, нажми **OK**

4. **Обнови схему:**
   - После подключения: правый клик на базе → **Refresh** (или `F5`)
   - Таблицы должны появиться в `Databases` → `lepm_db` → `Schemas` → `public` → `Tables`

### ⚠️ ВАЖНО: Порт 5433 вместо 5432

**Почему 5433?** Порт 5432 может быть занят локальной PostgreSQL. Docker использует порт **5433** для внешних подключений, чтобы избежать конфликта.

Если порт не проброшен, добавь в `docker-compose.yml`:

```yaml
postgres:
  ports:
    - "5433:5432"  # Внешний порт 5433 → внутренний 5432
```

Затем перезапусти:
```bash
docker compose down postgres
docker compose up -d postgres
```

### Вариант 3: Проверь текущее подключение

1. **В DBeaver:**
   - Правый клик на подключении → **Edit Connection**
   - Проверь **Host** и **Port**
   - Проверь **Database name** (должно быть `lepm_db`)

2. **Проверь, какая БД используется:**
   ```sql
   -- В DBeaver выполни:
   SELECT current_database();
   SELECT version();
   ```

3. **Сравни с Docker:**
   ```bash
   docker compose exec postgres psql -U postgres -d lepm_db -c "SELECT current_database(), version();"
   ```

## Проверка данных

### В DBeaver выполни:

```sql
-- Проверь географические регионы
SELECT * FROM geographic_regions ORDER BY level, id;

-- Проверь наличие поля mrid
SELECT mrid, name, code FROM power_lines LIMIT 5;

-- Проверь связи
SELECT 
    pl.name as line_name,
    gr.name as region_name
FROM power_lines pl
LEFT JOIN geographic_regions gr ON pl.region_id = gr.id;

-- Проверь сегменты
SELECT 
    pl.name as line_name,
    seg.name as segment_name
FROM power_lines pl
JOIN line_segments ls ON pl.id = ls.power_line_id
JOIN acline_segments seg ON ls.acline_segment_id = seg.id;
```

### Если данных нет:

1. **Проверь, что миграция применена:**
   ```bash
   docker compose exec backend alembic current
   ```
   Должно показать: `20241116_170000 (head)`

2. **Проверь, что тестовые данные добавлены:**
   ```bash
   docker compose exec postgres psql -U postgres -d lepm_db -c "SELECT COUNT(*) FROM geographic_regions;"
   ```
   Должно быть: `3`

3. **Если данных нет, добавь их:**
   ```bash
   docker compose exec backend python seed_test_data.py
   ```

## Обновление схемы в DBeaver

Если подключение правильное, но таблицы не видны:

1. **Обнови схему:**
   - Правый клик на базе данных → **Refresh**
   - Или `F5`

2. **Проверь фильтры:**
   - Правый клик на базе → **Properties** → **Filters**
   - Убедись, что нет фильтров, скрывающих таблицы

3. **Проверь схему:**
   - В DBeaver таблицы должны быть в схеме `public`
   - Проверь: `public` → `Tables`

## ⚠️ "Datasource was invalidated" — что это значит?

**"Datasource was invalidated"** означает, что DBeaver обнаружил несоответствие между кэшированной схемой и реальной базой данных. Это часто происходит, когда:

1. **Подключен к другой базе данных** (локальной вместо Docker)
2. **Схема изменилась**, но DBeaver не обновил кэш
3. **Подключение потеряно** и DBeaver пытается переподключиться

### Решение:

1. **Удали старое подключение в DBeaver:**
   - Правый клик на подключении → **Delete**
   - Подтверди удаление

2. **Создай новое подключение с правильными параметрами:**
   - Host: `localhost`
   - Port: `5433` ⚠️ **НЕ 5432!**
   - Database: `lepm_db`
   - Username: `postgres`
   - Password: `dragon167`

3. **Проверь подключение:**
   - Нажми **Test Connection**
   - Если успешно, выполни: `SELECT current_database();` — должно вернуть `lepm_db`

4. **Обнови схему:**
   - Правый клик на базе → **Refresh** (F5)

## Типичные проблемы

### Проблема 1: "Connection refused"

**Причина:** PostgreSQL контейнер не запущен или порт не проброшен.

**Решение:**
```bash
docker compose ps postgres
docker compose up -d postgres
```

### Проблема 2: "Database does not exist"

**Причина:** Подключен к другой базе данных.

**Решение:** Проверь имя базы в настройках подключения DBeaver (`lepm_db`).

### Проблема 3: "Password authentication failed"

**Причина:** Неправильный пароль.

**Решение:** 
- Для Docker: `postgres` (из `docker-compose.yml`)
- Для локальной: проверь свой пароль

### Проблема 4: Видны старые таблицы без новых полей

**Причина:** DBeaver кэширует схему.

**Решение:**
1. Обнови схему: `F5` или правый клик → **Refresh**
2. Переподключись: правый клик → **Disconnect** → **Connect**

## Быстрая проверка

Выполни в DBeaver:

```sql
-- 1. Проверь текущую БД
SELECT current_database();

-- 2. Проверь таблицы
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;

-- 3. Проверь наличие новых полей
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'power_lines' 
AND column_name IN ('mrid', 'region_id');

-- 4. Проверь тестовые данные
SELECT COUNT(*) as regions_count FROM geographic_regions;
SELECT COUNT(*) as segments_count FROM acline_segments;
```

Если все запросы возвращают данные — подключение правильное! Если нет — проверь настройки подключения.

