# Проблема 502 Bad Gateway и Docker сети

## Суть проблемы

**502 Bad Gateway** от nginx означал, что:
1. ✅ Nginx успешно принял HTTPS запрос
2. ❌ Nginx не смог подключиться к backend для проксирования
3. ❌ Backend не запускался из-за ошибки подключения к БД

## Корневая причина

В `docker-compose.yml` были **разные Docker сети**:
- `backend` и `nginx` → в сети `lepm_network` ✅
- `postgres` и `redis` → в **дефолтной сети** ❌

### Почему это критично?

Docker использует **DNS-резолюцию по именам сервисов** внутри одной сети:
- Внутри `lepm_network`: `backend` может найти `postgres` → ❌ НЕТ (postgres в другой сети!)
- Внутри `lepm_network`: `nginx` может найти `backend` → ✅ ДА

**Ошибка:** `socket.gaierror: [Errno -5] No address associated with hostname`
→ Backend искал хост `postgres`, но не мог его найти, т.к. они в разных сетях.

## Что было сделано для решения

### 1. Добавлены все сервисы в одну сеть

```yaml
postgres:
  networks:
    - lepm_network  # ← ДОБАВЛЕНО

redis:
  networks:
    - lepm_network  # ← ДОБАВЛЕНО

backend:
  networks:
    - lepm_network  # ← УЖЕ БЫЛО

nginx:
  networks:
    - lepm_network  # ← УЖЕ БЫЛО
```

### 2. Отключён SSL для asyncpg

Внутри Docker сети PostgreSQL не требует SSL, но asyncpg пытался его использовать:

```python
# backend/app/database.py
database_url = settings.DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://")
if "?" not in database_url:
    database_url += "?ssl=disable"  # ← ДОБАВЛЕНО
```

### 3. Исправлена конфигурация nginx

- Убран `upstream` с портом (nginx не позволяет порты в upstream)
- Обновлён синтаксис `http2`: `listen 443 ssl http2;` → `listen 443 ssl;` + `http2 on;`

## Как решать подобные проблемы в будущем

### Шаг 1: Проверь логи
```powershell
docker compose logs backend --tail 50
docker compose logs nginx --tail 20
```

**Ищи ошибки:**
- `Name or service not known` → Проблема с DNS (сеть)
- `No address associated with hostname` → Не может найти хост (сеть/DNS)
- `Connection refused` → Порт закрыт или сервис не запущен
- `502 Bad Gateway` → Nginx не может достучаться до backend

### Шаг 2: Проверь сети Docker
```powershell
docker network ls
docker network inspect mobilka_lepm_network
```

**Что проверить:**
- Все контейнеры в одной сети?
- Правильные ли имена сервисов?

### Шаг 3: Проверь доступность сервисов
```powershell
# Проверка статуса всех контейнеров
docker compose ps

# Проверка переменных окружения
docker compose exec backend env | findstr DATABASE_URL

# Тест подключения (если есть сетевые утилиты)
docker compose exec backend nc -zv postgres 5432
```

### Шаг 4: Типичные решения

1. **Все сервисы в одной сети** → добавь `networks: - lepm_network` всем сервисам
2. **Проверь depends_on** → backend должен ждать готовности postgres/redis
3. **Проверь DATABASE_URL** → должно быть `postgres:5432`, а не `localhost:5432`
4. **Проверь healthcheck** → postgres должен быть `healthy` перед запуском backend

## Чеклист для диагностики

- [ ] Все сервисы в одной Docker сети?
- [ ] DATABASE_URL использует имя сервиса, а не localhost?
- [ ] Healthcheck показывает `healthy` для postgres/redis?
- [ ] Backend успешно запустился (нет ошибок в логах)?
- [ ] Nginx может подключиться к backend:8000?
- [ ] SSL сертификаты сгенерированы и доступны nginx?

## Полезные команды

```powershell
# Перезапуск всех сервисов
docker compose down
docker compose up -d --build

# Перезапуск конкретного сервиса
docker compose restart backend

# Просмотр логов в реальном времени
docker compose logs -f backend

# Проверка сетей
docker network inspect mobilka_lepm_network | findstr Containers

# Тест подключения из контейнера
docker compose exec backend python -c "import socket; print(socket.gethostbyname('postgres'))"
```

