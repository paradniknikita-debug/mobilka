# ЛЭП Management System - Backend

FastAPI сервер для системы управления линиями электропередач.

## Технологии

- **Python 3.8+**
- **FastAPI** - современный веб-фреймворк для создания API
- **PostgreSQL** - реляционная база данных
- **SQLAlchemy** - ORM для работы с базой данных
- **Alembic** - миграции базы данных
- **Redis** - кэширование и очереди
- **JWT** - аутентификация

## Установка

### 1. Установка зависимостей

```bash
pip install -r requirements.txt
```

### 2. Настройка базы данных

Установите PostgreSQL и создайте базу данных:

```sql
CREATE DATABASE lepm_db;
CREATE USER lepm_user WITH PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE lepm_db TO lepm_user;
```

### 3. Настройка переменных окружения

Создайте файл `.env` на основе `env_example.txt`:

```bash
cp env_example.txt .env
```

Отредактируйте `.env` файл с вашими настройками:

```env
DATABASE_URL=postgresql://lepm_user:your_password@localhost/lepm_db
SECRET_KEY=your-secret-key-here-change-in-production
REDIS_URL=redis://localhost:6379
```

### Вложения опор (MinIO / S3)

Фото, аудио и видео карточки опоры сохраняются через `POST /api/v1/attachments/...`.  
Если заданы **`S3_ENDPOINT_URL`**, **`S3_ACCESS_KEY`**, **`S3_SECRET_KEY`**, **`S3_BUCKET_MEDIA`**, backend использует MinIO/S3. Иначе файлы пишутся в каталог `uploads/pole_attachments/` на диске backend.

**Режим development:** если `S3_ENDPOINT_URL` в `.env` не задан, подставляется **`http://127.0.0.1:9000`** и учётные данные **`minioadmin` / `minioadmin`** (как у MinIO по умолчанию), чтобы при запуске API на хосте и MinIO из `docker compose up minio` вложения сразу шли в S3. Отключить: **`DISABLE_LOCAL_MINIO=1`**.

При старте API в консоли печатается строка вида `OK: Вложения опор — MinIO/S3 (...)` или предупреждение про локальный диск.

При локальном **docker-compose** сервис **backend** получает **`S3_ENDPOINT_URL=http://minio:9000`** (из контейнера). MinIO поднимается на **9000** (API) и **9001** (консоль).

Если в логах контейнера **`No module named 'boto3'`**, образ собран без зависимостей (старый кэш). Пересоберите backend:  
`docker compose build --no-cache backend` затем `docker compose up -d backend`.

**Сборка образа:** в `Dockerfile` сначала копируется только `requirements.txt` и выполняется `pip install` — при изменении кода в `app/` слой с зависимостями берётся из кэша Docker и **не переустанавливает пакеты**. Дополнительно включён кэш pip (BuildKit). Имеет смысл включить: `DOCKER_BUILDKIT=1` (в Docker Desktop обычно уже включён). Файл **`.dockerignore`** уменьшает контекст сборки и исключает лишнее из слоя `COPY . .`.

### 4. Инициализация базы данных

```bash
# Создание миграций
alembic revision --autogenerate -m "Initial migration"

# Применение миграций
alembic upgrade head
```

После обновления кода, если API отвечает **500** на карту (`/api/v1/map/...`), `/power-lines`, `/equipment`, а в логах PostgreSQL — **нет колонки** в `pole` (например `structural_defect`), выполните **`alembic upgrade head`** из каталога `backend` с настроенным `DATABASE_URL`.

### 5. Запуск сервера

```bash
python run.py
```

### Быстрое создание пользователей (без SQL)

```bash
# Интерактивно (скрипт сам спросит недостающие поля)
python scripts/create_user.py

# Полностью через аргументы
python scripts/create_user.py --username ivan --password qwerty123 --role engineer --email ivan@example.com

# Обновить существующего пользователя
python scripts/create_user.py --username ivan --password newpass123 --role dispatcher --update-if-exists
```

Сервер будет доступен по адресу: `http://localhost:8000`

## API Endpoints

### Аутентификация
- `POST /api/v1/auth/login` - Вход в систему
- `POST /api/v1/auth/register` - Регистрация
- `GET /api/v1/auth/me` - Информация о текущем пользователе

### ЛЭП
- `GET /api/v1/power-lines` - Список ЛЭП
- `POST /api/v1/power-lines` - Создание ЛЭП
- `GET /api/v1/power-lines/{id}` - Детали ЛЭП
- `POST /api/v1/power-lines/{id}/towers` - Добавление опоры

### Опоры
- `GET /api/v1/towers` - Список опор
- `GET /api/v1/towers/{id}` - Детали опоры
- `POST /api/v1/towers/{id}/equipment` - Добавление оборудования

### Карта
- `GET /api/v1/map/power-lines/geojson` - ЛЭП в формате GeoJSON
- `GET /api/v1/map/towers/geojson` - Опоры в формате GeoJSON
- `GET /api/v1/map/bounds` - Границы данных

### Синхронизация
- `POST /api/v1/sync/upload` - Загрузка данных для синхронизации
- `GET /api/v1/sync/download` - Скачивание изменений
- `GET /api/v1/sync/schemas` - Получение схем данных

## Структура проекта

```
backend/
├── app/
│   ├── api/           # API endpoints
│   ├── core/          # Основные настройки
│   ├── models/        # Модели базы данных
│   ├── schemas/       # Pydantic схемы
│   ├── database.py    # Настройка БД
│   └── main.py        # Точка входа
├── alembic/           # Миграции БД
├── requirements.txt   # Зависимости Python
├── run.py            # Скрипт запуска
└── README.md
```

## Модели данных

### User (Пользователь)
- id, username, email, full_name
- hashed_password, role, branch_id
- is_active, is_superuser

### PowerLine (ЛЭП)
- id, name, code, voltage_level
- branch_id, created_by, status
- length, description

### Tower (Опора)
- id, power_line_id, tower_number
- latitude, longitude, tower_type
- height, material, condition

### Equipment (Оборудование)
- id, tower_id, equipment_type
- name, manufacturer, model
- serial_number, condition

## Разработка

### Добавление новых endpoints

1. Создайте модель в `app/models/`
2. Создайте схему в `app/schemas/`
3. Добавьте API endpoint в `app/api/v1/`
4. Подключите роутер в `app/main.py`

### Миграции базы данных

```bash
# Создание новой миграции
alembic revision --autogenerate -m "Description of changes"

# Применение миграций
alembic upgrade head

# Откат миграций
alembic downgrade -1
```

### Тестирование

```bash
# Запуск тестов
pytest

# С покрытием
pytest --cov=app
```

## Деплой

### Локальный сервер

```bash
python run.py
```

### Production с Gunicorn

```bash
pip install gunicorn
gunicorn app.main:app -w 4 -k uvicorn.workers.UvicornWorker
```

### Docker

```dockerfile
FROM python:3.9-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
CMD ["python", "run.py"]
```

## Мониторинг

- Health check: `GET /health`
- Метрики: доступны через Prometheus (если настроено)
- Логи: настраиваются через Python logging

## Безопасность

- JWT токены с истечением срока действия
- Валидация входных данных через Pydantic
- CORS настройки для мобильного приложения
- Хеширование паролей с bcrypt

