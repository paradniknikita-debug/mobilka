# ЛЭП Management System

Система управления линиями электропередач для мобильных устройств с веб-интерфейсом.

## Описание

Данное приложение предназначено для инженеров и диспетчеров, работающих с линиями электропередач. Позволяет:

- Создавать и управлять информацией о ЛЭП
- Фиксировать опоры с GPS координатами
- Добавлять информацию об оборудовании
- Отображать данные на карте
- Синхронизировать данные между устройствами
- Работать в офлайн режиме

## Архитектура

Проект разделен на две части:

### Backend (Python FastAPI)
- **Расположение**: `backend/`
- **Технологии**: FastAPI, PostgreSQL, SQLAlchemy, Alembic
- **Функции**:
  - REST API для мобильного приложения
  - Аутентификация и авторизация
  - Tile сервер для карт
  - Синхронизация данных
  - Управление пользователями

### Frontend (Flutter)
- **Расположение**: `frontend/`
- **Технологии**: Flutter, Dart, Drift (SQLite), Riverpod
- **Функции**:
  - Мобильное приложение для Android/iOS
  - Локальная база данных
  - Офлайн работа
  - Синхронизация с сервером
  - Карты и GPS

## Быстрый запуск через Docker (рекомендуется)

### Требования
- Docker Desktop (Windows/Mac) или Docker + Docker Compose (Linux)
- Git

### Шаги запуска:

1. **Клонируйте репозиторий**:
   ```bash
   git clone <your-repo-url>
   cd mobilka
   ```

2. **Подготовьте конфигурацию backend**:
   ```bash
   # Windows
   copy backend\env_example.txt backend\.env
   
   # Mac/Linux
   cp backend/env_example.txt backend/.env
   ```
   
   Отредактируйте `backend/.env`:
   ```env
   DATABASE_URL=postgresql://postgres:postgres@postgres:5432/lepm_db
   REDIS_URL=redis://redis:6379
   SECRET_KEY=your-secret-key-change-me
   ```

3. **Сгенерируйте SSL сертификаты для HTTPS** (один раз):
   ```bash
   # Windows (нужен OpenSSL, обычно уже установлен)
   nginx\generate-ssl.bat
   
   # Mac/Linux
   chmod +x nginx/generate-ssl.sh
   ./nginx/generate-ssl.sh
   ```

4. **Запустите все сервисы одним файлом**:
   ```bash
   docker compose up -d --build
   ```
   
   Это поднимет:
   - PostgreSQL (порт 5432)
   - Redis (порт 6379)
   - Backend API (внутренний, проксируется через nginx)
   - Nginx с HTTPS (порты 80 → редирект на 443, 443 → HTTPS)

5. **Проверьте работу**:
   - Backend API (через HTTPS): `https://localhost/api/v1/health`
   - Backend API (Swagger docs): `https://localhost/docs`
   - Health check: `https://localhost/health`

   ⚠️ Браузер покажет предупреждение о self-signed сертификате — это нормально для разработки. Нажмите "Advanced" → "Proceed to localhost".

6. **Frontend (Flutter)**:
   ```bash
   cd frontend
   flutter pub get
   flutter create .  # если web ещё не добавлен
   flutter run -d edge
   ```
   
   **Важно**: Обновите `frontend/lib/core/config/app_config.dart`:
   ```dart
   static String get baseUrl {
     if (kIsWeb) {
-      return 'http://localhost:8000';
+      return 'https://localhost';  // HTTPS через nginx
     }
     // ...
   }
   ```

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

Система использует универсальный JSON Schema для синхронизации данных между клиентом и сервером. Основные сущности:

- **PowerLine** - Линия электропередачи
- **Tower** - Опора
- **Equipment** - Оборудование
- **Span** - Пролёт
- **Tap** - Отпайка
- **Substation** - Подстанция
- **Branch** - Филиал

## Безопасность

- JWT токены для аутентификации
- HTTPS для передачи данных
- Шифрование паролей
- Роли пользователей (инженер, диспетчер, админ)

## Лицензия

Этот проект создан в образовательных целях.

## Контакты

Для вопросов и предложений обращайтесь к разработчику.
