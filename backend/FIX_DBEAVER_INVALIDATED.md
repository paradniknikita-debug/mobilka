# Исправление ошибки "Datasource was invalidated" в DBeaver

## Проблема

При проверке подключения в DBeaver появляется сообщение **"Datasource was invalidated"**, и вы не видите новые таблицы и данные (substations, geographic_regions, poles).

## Причина

DBeaver подключен к **другой базе данных**, скорее всего к локальной PostgreSQL на порту 5432, а не к Docker контейнеру на порту 5433.

## Решение

### Шаг 1: Убедись, что Docker PostgreSQL запущен

```bash
docker compose ps postgres
```

Должно показать статус `Up`. Если нет:
```bash
docker compose up -d postgres
```

### Шаг 2: Проверь, что порт 5433 проброшен

```bash
docker compose exec postgres psql -U postgres -d lepm_db -c "SELECT current_database();"
```

Должно вернуть `lepm_db`.

### Шаг 3: Удали старое подключение в DBeaver

1. В DBeaver: правый клик на подключении → **Delete**
2. Подтверди удаление

### Шаг 4: Создай новое подключение

1. Правый клик на "Databases" → **New** → **Database Connection**
2. Выбери **PostgreSQL**
3. Заполни параметры:
   - **Host:** `localhost`
   - **Port:** `5433` ⚠️ **ВАЖНО: Используй 5433, а не 5432!**
   - **Database:** `lepm_db`
   - **Username:** `postgres`
   - **Password:** `dragon167`

4. Нажми **Test Connection**
5. Если успешно → **OK**

### Шаг 5: Проверь подключение

Выполни в DBeaver:

```sql
-- Должно вернуть 'lepm_db'
SELECT current_database();

-- Должно показать все таблицы, включая poles, substations, geographic_regions
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;

-- Должно вернуть данные
SELECT COUNT(*) as poles_count FROM poles;
SELECT COUNT(*) as substations_count FROM substations;
SELECT COUNT(*) as geographic_regions_count FROM geographic_regions;
```

### Шаг 6: Обнови схему

Если таблицы не видны:
1. Правый клик на базе данных → **Refresh** (или F5)
2. Проверь: `Databases` → `lepm_db` → `Schemas` → `public` → `Tables`

## Проверка: какая база используется?

### В DBeaver выполни:

```sql
SELECT 
    current_database() as database_name,
    current_user as user_name,
    version() as postgres_version;
```

### В Docker выполни:

```bash
docker compose exec postgres psql -U postgres -d lepm_db -c "SELECT current_database(), current_user, version();"
```

**Результаты должны совпадать!** Если нет — DBeaver подключен к другой базе.

## Если проблема осталась

1. **Проверь, нет ли локальной PostgreSQL на порту 5432:**
   ```bash
   netstat -an | findstr :5432
   ```
   Если видишь `LISTENING` на `0.0.0.0:5432` — это может быть локальная PostgreSQL.

2. **Перезапусти Docker контейнер:**
   ```bash
   docker compose restart postgres
   ```

3. **Проверь логи PostgreSQL:**
   ```bash
   docker compose logs postgres
   ```

4. **Используй скрипт проверки:**
   ```bash
   check_dbeaver_connection.bat
   ```

## Быстрая проверка данных

```bash
# Проверка таблиц
docker compose exec postgres psql -U postgres -d lepm_db -c "\dt"

# Проверка данных
docker compose exec postgres psql -U postgres -d lepm_db -c "SELECT COUNT(*) FROM poles; SELECT COUNT(*) FROM substations; SELECT COUNT(*) FROM geographic_regions;"
```

Если данные есть в Docker, но не видны в DBeaver — проблема в настройках подключения DBeaver.

