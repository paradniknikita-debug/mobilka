# Диаграммы архитектуры проекта

## Общая архитектура системы

```
┌─────────────────────────────────────────────────────────┐
│                    Клиентское устройство                 │
│                                                          │
│  ┌──────────────────────────────────────────────┐     │
│  │         Flutter Frontend (Mobile/Web)         │     │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐     │     │
│  │  │   UI      │  │  State  │  │   HTTP  │     │     │
│  │  │ (Widgets) │→ │(Riverpod│→ │ (Dio)   │     │     │
│  │  └──────────┘  └──────────┘  └──────────┘     │     │
│  │                        ↓                      │     │
│  │  ┌────────────────────────────────────┐     │     │
│  │  │   Drift (SQLite) - Локальная БД    │     │     │
│  │  │   - Офлайн работа                  │     │     │
│  │  │   - Синхронизация с сервером       │     │     │
│  │  └────────────────────────────────────┘     │     │
│  └──────────────────────────────────────────────┘     │
│                        ↓ HTTPS                        │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│                   Nginx (Reverse Proxy)                 │
│  ┌──────────────────────────────────────────────────┐  │
│  │  HTTP (80) → HTTPS (443) редирект                │  │
│  │  SSL Termination                                 │  │
│  │  Security Headers (HSTS, X-Frame-Options)         │  │
│  └──────────────────────────────────────────────────┘  │
│                        ↓                                │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│              Docker Network (lepm_network)               │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │   Backend    │  │  PostgreSQL  │  │    Redis    │   │
│  │  (FastAPI)  │←→│   (БД)       │  │  (Кэш)      │   │
│  │  Port: 8000  │  │  Port: 5432  │  │  Port: 6379 │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
│                                                          │
│  ┌──────────────────────────────────────────────────┐ │
│  │  FastAPI Endpoints:                               │ │
│  │  - /api/v1/auth/* (аутентификация)               │ │
│  │  - /api/v1/power-lines/* (ЛЭП)                   │ │
│  │  - /api/v1/towers/* (Опоры)                      │ │
│  │  - /api/v1/map/* (Карта, GeoJSON)                │ │
│  │  - /api/v1/sync/* (Синхронизация)                 │ │
│  └──────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

---

## Поток данных (Data Flow)

### Сценарий: Синхронизация данных

```
1. Пользователь создаёт ЛЭП в приложении
   ↓
2. Сохранение в локальную БД (Drift/SQLite)
   ↓
3. Помечание для синхронизации (needsSync = true)
   ↓
4. При наличии интернета:
   ↓
5. Flutter → HTTPS → Nginx → Backend
   ↓
6. Backend сохраняет в PostgreSQL
   ↓
7. Помечание как синхронизированное
   ↓
8. Обратная синхронизация:
   Backend → Flutter (обновления с сервера)
   ↓
9. Обновление локальной БД
```

### Сценарий: Просмотр карты

```
1. Пользователь открывает карту
   ↓
2. Flutter запрашивает GeoJSON: GET /api/v1/map/power-lines/geojson
   ↓
3. HTTPS → Nginx (проверка SSL) → Backend
   ↓
4. Backend:
   - Проверка JWT токена
   - Запрос к PostgreSQL
   - Формирование GeoJSON
   ↓
5. Backend → Nginx → HTTPS → Flutter
   ↓
6. Flutter отображает ЛЭП на карте
```

---

## Docker Compose архитектура

```
docker-compose.yml
│
├── postgres (PostgreSQL 15)
│   ├── Network: lepm_network
│   ├── Volume: pgdata (persistent storage)
│   └── Healthcheck: pg_isready
│
├── redis (Redis 7)
│   ├── Network: lepm_network
│   └── Healthcheck: redis-cli ping
│
├── backend (FastAPI)
│   ├── Network: lepm_network
│   ├── Depends on: postgres (healthy), redis (healthy)
│   ├── Environment: DATABASE_URL, REDIS_URL
│   └── Expose: 8000 (только внутри сети)
│
└── nginx (Nginx Alpine)
    ├── Network: lepm_network
    ├── Depends on: backend
    ├── Ports: 80:80, 443:443 (публичные)
    ├── Volumes:
    │   ├── nginx.conf → /etc/nginx/nginx.conf
    │   └── ssl/ → /etc/nginx/ssl/
    └── Проксирование: → backend:8000
```

---

## Слои приложения (Backend)

```
┌─────────────────────────────────────┐
│         API Layer (FastAPI)        │
│  - Роутеры (app/api/v1/*.py)        │
│  - Валидация запросов (Pydantic)    │
│  - Аутентификация (JWT)             │
└──────────────────┬──────────────────┘
                   ↓
┌─────────────────────────────────────┐
│      Business Logic Layer           │
│  - Обработка бизнес-логики          │
│  - Валидация данных                 │
│  - Трансформация данных             │
└──────────────────┬──────────────────┘
                   ↓
┌─────────────────────────────────────┐
│      Data Access Layer              │
│  - SQLAlchemy ORM                   │
│  - Работа с БД                      │
│  - Модели данных                    │
└──────────────────┬──────────────────┘
                   ↓
┌─────────────────────────────────────┐
│         Database (PostgreSQL)       │
│  - Хранение данных                  │
│  - Индексы                          │
│  - Транзакции                       │
└─────────────────────────────────────┘
```

---

## Слои приложения (Frontend)

```
┌─────────────────────────────────────┐
│      Presentation Layer             │
│  - UI (Widgets)                     │
│  - Страницы (Pages)                 │
│  - Роутинг (GoRouter)               │
└──────────────────┬──────────────────┘
                   ↓
┌─────────────────────────────────────┐
│      State Management (Riverpod)    │
│  - Провайдеры                       │
│  - Состояние приложения             │
│  - Бизнес-логика в UI               │
└──────────────────┬──────────────────┘
                   ↓
┌─────────────────────────────────────┐
│      Services Layer                  │
│  - ApiService (HTTP клиент)         │
│  - AuthService                      │
│  - SyncService                      │
└──────────────────┬──────────────────┘
                   ↓
┌─────────────────────────────────────┐
│      Data Layer                      │
│  - Drift (SQLite) - Локальная БД    │
│  - SharedPreferences - Настройки    │
│  - SecureStorage - Токены           │
└─────────────────────────────────────┘
```

---

## Сценарий работы с ошибками

### Проблема: 502 Bad Gateway

```
Запрос: Frontend → HTTPS → Nginx
         ↓
    Nginx пытается проксировать → Backend:8000
         ↓
    Ошибка: Backend не отвечает или недоступен
         ↓
    Nginx возвращает 502 Bad Gateway
```

### Диагностика:

```
1. Проверка статуса контейнеров:
   docker compose ps
   → backend в статусе "Restarting" ❌

2. Проверка логов backend:
   docker compose logs backend
   → Ошибка: "Name or service not known" ❌

3. Проверка сетей:
   docker network inspect mobilka_lepm_network
   → postgres не в сети lepm_network ❌

4. Решение:
   → Добавить postgres в сеть lepm_network ✅
   → Перезапустить контейнеры ✅
```

---

## Технологический стек

```
┌─────────────────────────────────────────────────┐
│                    Frontend                      │
├─────────────────────────────────────────────────┤
│ Framework:      Flutter 3.0+                    │
│ Language:       Dart 3.0+                       │
│ State:          Riverpod 2.4+                   │
│ Navigation:     GoRouter 12.1+                  │
│ HTTP:           Dio 5.4 + Retrofit 4.0          │
│ Local DB:       Drift 2.14                       │
│ Maps:           Flutter Map 6.1                 │
│ Location:       Geolocator 10.1                  │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│                    Backend                       │
├─────────────────────────────────────────────────┤
│ Framework:      FastAPI 0.104                   │
│ Language:       Python 3.9+                     │
│ ORM:            SQLAlchemy 2.0 (async)          │
│ Validation:     Pydantic 2.5                    │
│ Auth:           Python-JOSE + Passlib           │
│ Migrations:     Alembic 1.12                     │
│ Cache:          Redis 5.0                       │
│ Async DB:       asyncpg 0.30                     │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│                Infrastructure                    │
├─────────────────────────────────────────────────┤
│ Orchestration:  Docker Compose                  │
│ Reverse Proxy:  Nginx Alpine                    │
│ Database:       PostgreSQL 15                   │
│ Cache:           Redis 7                         │
│ SSL:            Self-signed (dev)               │
└─────────────────────────────────────────────────┘
```

---

## Зависимости между компонентами

```
┌──────────┐
│ Frontend │
└────┬─────┘
     │ HTTPS
     ↓
┌──────────┐
│  Nginx   │ ────depends_on───→ ┌──────────┐
└────┬─────┘                    │ Backend  │
     │                          └────┬─────┘
     │ proxy_pass                    │
     ↓                               │ depends_on
┌──────────┐                         │
│ Backend  │ ────────────────────────┘
└────┬─────┘
     │
     ├──→ PostgreSQL (DATABASE_URL)
     │
     └──→ Redis (REDIS_URL)

Все в одной Docker сети: lepm_network
```

---

## Безопасность

```
┌────────────────────────────────────────────┐
│            Client (Browser)                │
│  ┌────────────────────────────────────┐   │
│  │  HTTPS (TLS 1.2/1.3)               │   │
│  │  Self-signed certificate           │   │
│  └────────────────────────────────────┘   │
└────────────────────┬───────────────────────┘
                     ↓
┌────────────────────────────────────────────┐
│            Nginx (SSL Termination)         │
│  ┌────────────────────────────────────┐   │
│  │  Security Headers:                  │   │
│  │  - HSTS                            │   │
│  │  - X-Frame-Options                 │   │
│  │  - X-Content-Type-Options          │   │
│  │  - X-XSS-Protection                │   │
│  └────────────────────────────────────┘   │
└────────────────────┬───────────────────────┘
                     ↓
┌────────────────────────────────────────────┐
│            Backend (FastAPI)                │
│  ┌────────────────────────────────────┐   │
│  │  JWT Authentication                 │   │
│  │  Password Hashing (bcrypt)          │   │
│  │  CORS Middleware                    │   │
│  │  Input Validation (Pydantic)        │   │
│  └────────────────────────────────────┘   │
└────────────────────────────────────────────┘
```

---

## Последовательность запуска

```
1. Docker Compose стартует
   ↓
2. postgres: запуск и инициализация БД
   ├── Healthcheck: проверка готовности
   └── Status: healthy ✅
   ↓
3. redis: запуск кэша
   ├── Healthcheck: ping
   └── Status: healthy ✅
   ↓
4. backend: ждёт готовности postgres и redis
   ├── Подключение к БД
   ├── Инициализация таблиц (Alembic)
   ├── Запуск FastAPI сервера
   └── Status: running ✅
   ↓
5. nginx: ждёт backend
   ├── Загрузка конфигурации
   ├── Проверка SSL сертификатов
   └── Status: running ✅
   ↓
6. Готово: все сервисы работают
   ├── HTTPS доступен на порту 443
   ├── HTTP редиректит на HTTPS
   └── API доступен через /api/v1/*
```

---

## Обмен данными между компонентами

### Request Flow (Запрос)

```
Frontend
  ↓ HTTP Request
  ↓ GET /api/v1/test
  ↓ Headers: Authorization: Bearer <token>
Nginx (443)
  ↓ SSL Termination
  ↓ Proxy to backend:8000
  ↓ Add headers: X-Forwarded-For, X-Real-IP
Backend
  ↓ Validate JWT token
  ↓ Process request
  ↓ Query PostgreSQL (if needed)
  ↓ Cache in Redis (if needed)
  ↓ Generate response
Backend
  ↑ JSON Response
  ↑ Status: 200 OK
Nginx
  ↑ Forward response
  ↑ SSL Encryption
Frontend
  ↑ Display result
```

---

## Ошибки и их обработка

```
┌────────────────────────────────────────┐
│        Тип ошибки                     │
├────────────────────────────────────────┤
│ 502 Bad Gateway                        │
│  ├─ Причина: Backend недоступен       │
│  ├─ Решение: Проверить логи backend  │
│  └─ Проверить: docker compose ps      │
├────────────────────────────────────────┤
│ 401 Unauthorized                       │
│  ├─ Причина: Нет/неверный JWT токен  │
│  ├─ Решение: Перелогиниться           │
│  └─ Проверить: Токен в заголовках     │
├────────────────────────────────────────┤
│ 404 Not Found                          │
│  ├─ Причина: Неверный URL             │
│  ├─ Решение: Проверить endpoint       │
│  └─ Проверить: Swagger docs           │
├────────────────────────────────────────┤
│ 500 Internal Server Error              │
│  ├─ Причина: Ошибка на backend        │
│  ├─ Решение: Проверить логи           │
│  └─ Проверить: docker compose logs    │
└────────────────────────────────────────┘
```

