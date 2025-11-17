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

### 4. Инициализация базы данных

```bash
# Создание миграций
alembic revision --autogenerate -m "Initial migration"

# Применение миграций
alembic upgrade head
```

### 5. Запуск сервера

```bash
python run.py
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

