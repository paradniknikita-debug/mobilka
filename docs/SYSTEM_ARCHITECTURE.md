# Архитектура системы ЛЭП Management System

## Общая архитектура системы

Система представляет собой полнофункциональное приложение для управления линиями электропередач с поддержкой веб и мобильных интерфейсов, работающее в офлайн-режиме с синхронизацией данных.

## Компоненты системы

### 1. Клиентские приложения

#### Web Frontend (Angular)
- **Технологии**: Angular 17, TypeScript, Angular Material, Leaflet
- **Функции**: 
  - Визуализация ЛЭП на карте
  - Управление объектами (опоры, линии, подстанции)
  - Дерево объектов в сайдбаре
  - Аутентификация через JWT

#### Mobile Frontend (Flutter)
- **Технологии**: Flutter, Dart, Drift (SQLite), Riverpod
- **Функции**:
  - Мобильное приложение для Android/iOS
  - Офлайн работа с локальной БД
  - GPS навигация
  - Синхронизация с сервером

### 2. Backend сервер

#### FastAPI Backend
- **Технологии**: Python 3.11+, FastAPI, SQLAlchemy, Alembic, asyncpg
- **API Endpoints**:
  - `/api/v1/auth/*` - Аутентификация и авторизация
  - `/api/v1/power-lines/*` - Управление ЛЭП
  - `/api/v1/poles/*` - Управление опорами
  - `/api/v1/substations/*` - Управление подстанциями
  - `/api/v1/equipment/*` - Управление оборудованием
  - `/api/v1/map/*` - GeoJSON данные для карты
  - `/api/v1/sync/*` - Синхронизация данных
  - `/api/v1/excel-import/*` - Импорт из Excel

### 3. База данных

#### PostgreSQL
- **Технологии**: PostgreSQL 15, PostGIS (для геоданных)
- **Модели данных**:
  - PowerLine (ЛЭП)
  - Pole (Опоры)
  - Substation (Подстанции)
  - Equipment (Оборудование)
  - Branch (Филиалы)
  - User (Пользователи)
  - AClineSegment (Сегменты линий)

### 4. Кэширование

#### Redis
- **Функции**: Кэширование часто запрашиваемых данных
- **Использование**: Опционально, система работает без Redis

### 5. Reverse Proxy

#### Nginx
- **Функции**:
  - SSL/TLS терминация (HTTPS)
  - Проксирование запросов к backend
  - Статические файлы
  - Health checks

### 6. Контейнеризация

#### Docker & Docker Compose
- **Сервисы**:
  - PostgreSQL контейнер
  - Redis контейнер
  - Backend контейнер
  - Nginx контейнер
- **Сеть**: Изолированная Docker сеть `lepm_network`

## Потоки данных

### 1. Аутентификация
```
User → Web/Mobile Frontend → HTTPS → Nginx → Backend → PostgreSQL
                                                      ↓
User ← JWT Token ← Backend ← Nginx ← HTTPS ← Frontend
```

### 2. Просмотр карты
```
Frontend → GET /api/v1/map/poles/geojson → Nginx → Backend
                                                      ↓
                                    PostgreSQL (PostGIS запрос)
                                                      ↓
Frontend ← GeoJSON ← Backend ← Nginx ← JSON Response
```

### 3. Синхронизация (Mobile)
```
Mobile App (Offline) → Local SQLite (Drift)
                           ↓ (когда есть интернет)
Mobile App → POST /api/v1/sync → Backend → PostgreSQL
                           ↓
Mobile App ← Updated Data ← Backend ← PostgreSQL
```

### 4. Создание объекта
```
User → Frontend → POST /api/v1/poles → Nginx → Backend
                                              ↓
                                    Validation (Pydantic)
                                              ↓
                                    PostgreSQL (SQLAlchemy)
                                              ↓
User ← Created Object ← Backend ← Nginx ← JSON Response
```

## Слои архитектуры

### Backend (FastAPI)
```
┌─────────────────────────────────┐
│   API Layer (FastAPI Routes)    │
│   - auth.py, poles.py, etc.      │
└──────────────┬──────────────────┘
               ↓
┌─────────────────────────────────┐
│   Business Logic Layer          │
│   - Валидация, обработка        │
└──────────────┬──────────────────┘
               ↓
┌─────────────────────────────────┐
│   Data Access Layer (SQLAlchemy)│
│   - Models, ORM queries         │
└──────────────┬──────────────────┘
               ↓
┌─────────────────────────────────┐
│   Database (PostgreSQL)         │
│   - Tables, Indexes, PostGIS   │
└─────────────────────────────────┘
```

### Frontend (Angular)
```
┌─────────────────────────────────┐
│   Presentation Layer            │
│   - Components, Templates       │
└──────────────┬──────────────────┘
               ↓
┌─────────────────────────────────┐
│   Service Layer                 │
│   - MapService, ApiService      │
└──────────────┬──────────────────┘
               ↓
┌─────────────────────────────────┐
│   HTTP Layer                    │
│   - HttpClient, Interceptors    │
└──────────────┬──────────────────┘
               ↓
┌─────────────────────────────────┐
│   Backend API (HTTPS)           │
└─────────────────────────────────┘
```

## Безопасность

1. **HTTPS**: Все соединения через SSL/TLS
2. **JWT Authentication**: Токены для аутентификации
3. **CORS**: Настроен для безопасных доменов
4. **Password Hashing**: bcrypt для паролей
5. **SQL Injection Protection**: SQLAlchemy ORM

## Масштабируемость

- **Горизонтальное масштабирование**: Backend может быть запущен в нескольких экземплярах
- **Кэширование**: Redis для снижения нагрузки на БД
- **Connection Pooling**: SQLAlchemy connection pool
- **Async I/O**: FastAPI async для высокой производительности

## Развертывание

### Docker Compose
- Все сервисы в контейнерах
- Автоматическая настройка сети
- Health checks
- Volume для данных БД

### Порты
- **80**: HTTP (редирект на HTTPS)
- **443**: HTTPS (Nginx)
- **8000**: Backend API (прямой доступ, опционально)
- **5433**: PostgreSQL (для внешних инструментов)

## Мониторинг

- Health check endpoint: `/health`
- API документация: `/docs` (Swagger)
- Логирование через Python logging
- Docker logs для всех сервисов
