# Решение проблем с Docker

## Проблема: Бэкенд не работает через Docker

### Проверка статуса

1. **Проверьте статус контейнеров:**
   ```bash
   docker ps --filter "name=lepm"
   ```

2. **Проверьте логи бэкенда:**
   ```bash
   docker logs lepm_backend --tail 50
   ```

3. **Проверьте логи nginx:**
   ```bash
   docker logs lepm_nginx --tail 20
   ```

### Важные моменты

#### 1. Порт 8000 не проброшен наружу

В `docker-compose.yml` порт 8000 только `expose`, но не проброшен наружу. Это сделано намеренно, так как доступ к API должен идти через nginx.

**Правильный способ доступа:**
- ✅ `http://localhost/api/v1/test` (через nginx)
- ✅ `http://localhost/docs` (документация API)
- ✅ `http://localhost/health` (health check)
- ❌ `http://localhost:8000` (не работает, порт не проброшен)

#### 2. Если нужно обращаться напрямую к backend

Если вам нужно обращаться напрямую к порту 8000, добавьте в `docker-compose.yml`:

```yaml
backend:
  ports:
    - "8000:8000"  # Добавьте эту строку
```

#### 3. Перезапуск контейнеров

Если бэкенд не работает, попробуйте перезапустить:

```bash
docker compose restart backend
```

Или пересобрать и перезапустить:

```bash
docker compose down
docker compose up -d --build
```

#### 4. Проверка подключения к базе данных

В Docker используется другой DATABASE_URL:
- Локально: `postgresql://postgres:dragon167@localhost:5433/lepm_db`
- В Docker: `postgresql://postgres:dragon167@postgres:5432/lepm_db`

Проверьте, что в `docker-compose.yml` правильно указан DATABASE_URL:

```yaml
environment:
  DATABASE_URL: postgresql://postgres:dragon167@postgres:5432/lepm_db
```

#### 5. Проверка сети Docker

Убедитесь, что все контейнеры в одной сети:

```bash
docker network inspect mobilka_lepm_network
```

Все контейнеры должны быть в списке.

### Тестирование API

1. **Через nginx (рекомендуется):**
   ```bash
   curl http://localhost/api/v1/test
   ```

2. **Health check:**
   ```bash
   curl http://localhost/health
   ```

3. **Документация:**
   Откройте в браузере: `http://localhost/docs`

### Частые проблемы

#### Проблема: "Connection refused" при обращении к API

**Решение:**
- Убедитесь, что обращаетесь через nginx: `http://localhost/api/...`
- Проверьте, что nginx запущен: `docker ps | grep nginx`
- Проверьте логи nginx: `docker logs lepm_nginx`

#### Проблема: "502 Bad Gateway"

**Решение:**
- Проверьте, что backend запущен: `docker ps | grep backend`
- Проверьте логи backend: `docker logs lepm_backend`
- Убедитесь, что backend может подключиться к БД

#### Проблема: Контейнер постоянно перезапускается

**Решение:**
- Проверьте логи: `docker logs lepm_backend`
- Проверьте, что DATABASE_URL правильный
- Убедитесь, что postgres контейнер здоров: `docker ps | grep postgres`

### Полная перезагрузка

Если ничего не помогает:

```bash
# Остановить все контейнеры
docker compose down

# Удалить volumes (ОСТОРОЖНО: удалит данные БД!)
# docker compose down -v

# Пересобрать и запустить
docker compose up -d --build

# Проверить логи
docker compose logs -f backend
```
