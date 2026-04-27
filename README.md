# ЛЭП Management System

Система управления линиями электропередач для мобильных устройств с веб-интерфейсом.

## ⚡ Быстрый старт

```bash
# 1. Клонируй репозиторий
git clone https://github.com/paradniknikita-debug/mobilka.git
cd mobilka

# 2. Запусти автоматическую настройку
# Windows:
setup.bat

# Mac/Linux:
chmod +x setup.sh && ./setup.sh

# 3. Готово! Открой https://localhost/docs
```

📖 **Подробная инструкция**: [QUICK_START.md](QUICK_START.md)

---

## Описание

Данное приложение предназначено для инженеров и диспетчеров, работающих с линиями электропередач. Позволяет:

- Создавать и управлять информацией о ЛЭП
- Фиксировать опоры с GPS координатами
- Добавлять информацию об оборудовании
- Отображать данные на карте
- Синхронизировать данные между устройствами
- Работать в офлайн режиме

## Архитектура

Проект состоит из трех приложений, работающих поверх общего API и общей предметной модели.
Частичное дублирование клиентской логики допустимо: это по сути одно приложение, но с разными UX-сценариями
и платформенными ограничениями Web и Mobile. При этом ключевые бизнес-правила (идентификаторы, статусы,
смысл полей API) должны оставаться консистентными.

Короткий архитектурный контракт: [ARCHITECTURE.md](ARCHITECTURE.md).

### Backend (Python FastAPI)
- **Расположение**: `backend/`
- **Технологии**: FastAPI, PostgreSQL, SQLAlchemy, Alembic
- **Функции**:
  - REST API для мобильного приложения
  - Аутентификация и авторизация
  - Tile сервер для карт
  - Синхронизация данных
  - Управление пользователями

### Mobile Frontend (Flutter)
- **Расположение**: `frontend/`
- **Технологии**: Flutter, Dart, Drift (SQLite), Riverpod
- **Функции**:
  - Мобильное приложение для Android/iOS
  - Локальная база данных
  - Офлайн работа
  - Синхронизация с сервером
  - Карты и GPS

### Web Frontend (Angular)
- **Расположение**: `web-frontend/`
- **Технологии**: Angular, TypeScript, Leaflet, Angular Material
- **Функции**:
  - Веб-интерфейс для диспетчера и оператора
  - Работа с картой и объектным деревом
  - Импорт/экспорт CIM
  - Журнал изменений и отчеты

## 🚀 Быстрый запуск (рекомендуется)

### Требования
- **Docker Desktop** (Windows/Mac) или **Docker + Docker Compose** (Linux)
- **Git**

### ⚡ Автоматическая настройка (3 шага)

1. **Клонируйте репозиторий**:
   ```bash
   git clone https://github.com/paradniknikita-debug/mobilka.git
   cd mobilka
   ```

2. **Запустите автоматическую настройку**:
   
   **Windows:**
   ```bash
   setup.bat
   ```
   
   **Mac/Linux:**
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```
   
   Скрипт автоматически:
   - ✅ Проверит наличие Docker
   - ✅ Создаст `.env` файл из примера
   - ✅ Сгенерирует SSL сертификаты
   - ✅ Запустит все сервисы через Docker
   - ✅ Применит миграции БД

3. **Проверьте работу**:
   - Backend API: https://localhost/api/v1/test
   - Swagger документация: https://localhost/docs
   - Health check: https://localhost/health
   
   ⚠️ **Важно**: Браузер покажет предупреждение о self-signed сертификате — это нормально для разработки. Нажмите **"Advanced"** → **"Proceed to localhost"**.

### 📱 Frontend (Flutter) - опционально

Если нужно запустить Flutter приложение:

```bash
cd frontend
flutter pub get
flutter run -d chrome  # или edge, или android
```

**Примечание**: Frontend уже настроен на работу с HTTPS через nginx. URL настраивается автоматически через `base_url_manager.dart`.

### 🔄 Повторный запуск

После первой настройки используйте:

**Windows:**
```bash
start.bat
```

**Mac/Linux:**
```bash
chmod +x start.sh
./start.sh
```

Или вручную:
```bash
docker compose up -d
```

### 📋 Что запускается?

После выполнения `setup.bat` или `setup.sh` поднимаются:
- **PostgreSQL** (порт 5432) - база данных
- **Redis** (порт 6379) - кэширование
- **Backend API** (FastAPI) - проксируется через nginx
- **Nginx** (порты 80, 443) - reverse proxy с HTTPS

### 🛑 Остановка

```bash
docker compose down
```

### 📖 Подробная документация

Смотри [QUICK_START.md](QUICK_START.md) для быстрого старта или читай дальше для детальной информации.

### Альтернативный запуск (без Docker)

Если не хотите использовать Docker, смотрите секцию ниже.

---

## Локальный запуск (без Docker)

### 1) Backend

Требования: Python 3.11+, PostgreSQL, Redis (опционально)

- Скопируйте env-пример:
  ```bash
  cd backend
  copy env_example.txt .env   # Windows
  cp env_example.txt .env     # Mac/Linux
  ```
- Отредактируйте `.env`:
  ```env
  DATABASE_URL=postgresql://postgres:postgres@localhost:5432/lepm_db
  REDIS_URL=redis://localhost:6379
  SECRET_KEY=dev_secret_key_change_me
  ```
- Установите зависимости:
  ```bash
  pip install -r requirements.txt
  ```
- Запустите сервер:
  ```bash
  uvicorn app.main:app --reload --host 0.0.0.0 --port 8000 --app-dir app
  ```
- Проверьте: `http://localhost:8000/health`

### 2) Frontend (Flutter)

Требования: Flutter SDK (stable)

- Установите зависимости:
  ```bash
  cd frontend
  flutter pub get
  ```
- Добавьте web-поддержку (один раз):
  ```bash
  flutter create .
  ```
- Запустите (Web):
  ```bash
  flutter run -d edge   # или chrome
  ```

По умолчанию фронт для Web ходит на `http://localhost:8000` (см. `lib/core/config/app_config.dart`). Для Android-эмулятора используется `10.0.2.2:8000`.

### 3) Web Frontend (Angular)

Требования: Node.js 20+ и npm

- Установите зависимости:
  ```bash
  cd web-frontend
  npm install
  ```
- Запустите dev-сервер:
  ```bash
  npm start
  ```
- По умолчанию приложение поднимается на `http://localhost:4200`.

### Переменные и секреты

- Backend читает настройки из `.env` (см. `backend/env_example.txt`). Не коммитьте `.env` в репозиторий.
- В `backend/app/core/config.py` значения по умолчанию безопасные (без реальных паролей). Настоящие значения задавайте через `.env`.

### Зависимости

- Backend: версии зафиксированы в `backend/requirements.txt`.
- Frontend: управляется `pubspec.yaml`. При необходимости обновляйте пакетами `flutter pub upgrade`.

## API Документация

После запуска backend сервера, документация API доступна по адресу:
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

## Основные функции

### Для инженеров
- Создание новых ЛЭП
- Добавление опор с GPS координатами
- Фиксация оборудования на опорах
- Работа в офлайн режиме
- Синхронизация данных

### Для диспетчеров
- Просмотр всех ЛЭП на карте
- Мониторинг состояния оборудования
- Управление пользователями
- Аналитика и отчеты

## Структура данных

Система использует единый API-контракт и JSON Schema для синхронизации данных между клиентами и сервером. Основные сущности:

- **PowerLine** - Линия электропередачи
- **Tower** - Опора
- **Equipment** - Оборудование
- **Span** - Пролёт
- **Tap** - Отпайка
- **Substation** - Подстанция
- **Branch** - Филиал

### Канонические поля API

- Для идентификатора ЛЭП используем `line_id`.
- `power_line_id` допускается только как legacy-совместимость на переходный период.

## Безопасность

- JWT токены для аутентификации
- HTTPS для передачи данных
- Шифрование паролей
- Роли пользователей (инженер, диспетчер, админ)

## Требования

Подробный список требований смотри в [REQUIREMENTS.md](REQUIREMENTS.md).

## Полезные команды

### Docker

```bash
# Запуск всех сервисов
docker compose up -d

# Остановка всех сервисов
docker compose down

# Просмотр логов
docker compose logs -f

# Пересборка контейнеров
docker compose up -d --build

# Применение миграций БД
docker compose exec backend alembic upgrade head

# Добавление тестовых данных
docker compose exec backend python seed_test_data.py
```

### Frontend

```bash
# Установка зависимостей
cd frontend
flutter pub get

# Генерация кода (freezed, json_serializable)
flutter pub run build_runner build --delete-conflicting-outputs

# Запуск на веб
flutter run -d chrome

# Запуск на Android
flutter run -d android
```

## Структура проекта

```
mobilka/
├── backend/          # FastAPI backend
│   ├── app/         # Основной код приложения
│   ├── alembic/     # Миграции БД
│   └── requirements.txt
├── frontend/         # Flutter приложение (mobile)
│   └── lib/          # Dart код
├── web-frontend/     # Angular приложение (web)
│   └── src/          # TypeScript/HTML/CSS код
├── nginx/            # Nginx конфигурация
├── docker-compose.yml # Docker Compose конфигурация
├── setup.bat         # Автоматическая настройка (Windows)
├── setup.sh          # Автоматическая настройка (Linux/Mac)
├── start.bat         # Быстрый запуск (Windows)
└── start.sh          # Быстрый запуск (Linux/Mac)
```

## Полезные ссылки

- **Быстрый старт**: [QUICK_START.md](QUICK_START.md)
- **Требования**: [REQUIREMENTS.md](REQUIREMENTS.md)
- **Документация API**: https://localhost/docs (после запуска)

## Лицензия

Этот проект создан в образовательных целях.

## Контакты

Для вопросов и предложений обращайтесь к разработчику.
