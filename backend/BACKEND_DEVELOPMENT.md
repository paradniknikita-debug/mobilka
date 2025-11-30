# Backend Development - ЛЭП Management System

## 📋 Содержание

1. [Архитектура и технологии](#архитектура-и-технологии)
2. [Структура проекта](#структура-проекта)
3. [База данных](#база-данных)
4. [API Endpoints](#api-endpoints)
5. [Аутентификация и безопасность](#аутентификация-и-безопасность)
6. [Nginx конфигурация](#nginx-конфигурация)
7. [Docker и развертывание](#docker-и-развертывание)
8. [Примеры проблем и решений](#примеры-проблем-и-решений)

---

## Архитектура и технологии

### Используемый стек:

- **FastAPI** - современный асинхронный веб-фреймворк для создания REST API
- **PostgreSQL 15** - реляционная база данных для хранения данных
- **SQLAlchemy (async)** - асинхронный ORM для работы с БД
- **Alembic** - система миграций базы данных
- **Redis** - кэширование и очереди задач
- **JWT (jose)** - токены для аутентификации
- **Argon2 (passlib)** - хеширование паролей
- **Pydantic** - валидация данных и схемы
- **Nginx** - reverse proxy и SSL терминация
- **Docker & Docker Compose** - контейнеризация

### Архитектурные решения:

1. **Асинхронная архитектура**: Все операции с БД и API используют async/await для лучшей производительности
2. **Dependency Injection**: FastAPI Depends для управления зависимостями
3. **Модульная структура**: Разделение на модули (auth, power_lines, poles, equipment, map, sync)
4. **Схемы валидации**: Pydantic схемы для входных и выходных данных

---

## Структура проекта

```
backend/
├── app/
│   ├── api/
│   │   └── v1/              # API endpoints версии 1
│   │       ├── auth.py      # Аутентификация
│   │       ├── power_lines.py
│   │       ├── poles.py
│   │       ├── equipment.py
│   │       ├── map_tiles.py # GeoJSON endpoints
│   │       ├── sync.py      # Синхронизация данных
│   │       ├── substations.py
│   │       └── excel_import.py
│   ├── core/
│   │   ├── config.py        # Настройки приложения
│   │   └── security.py      # JWT, хеширование паролей
│   ├── models/              # SQLAlchemy модели
│   │   ├── user.py
│   │   ├── power_line.py
│   │   ├── branch.py
│   │   └── substation.py
│   ├── schemas/             # Pydantic схемы
│   │   ├── user.py
│   │   ├── power_line.py
│   │   └── sync.py
│   ├── database.py          # Настройка БД
│   └── main.py             # Точка входа FastAPI
├── alembic/                 # Миграции БД
├── Dockerfile
├── requirements.txt
├── run.py                   # Скрипт запуска
└── BACKEND_DEVELOPMENT.md   # Этот файл
```

---

## База данных

### Модели данных

#### User (Пользователь)
```python
class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, index=True, nullable=False)
    email = Column(String(100), unique=True, index=True, nullable=False)
    full_name = Column(String(100), nullable=False)
    hashed_password = Column(String(255), nullable=False)
    is_active = Column(Boolean, default=True)
    is_superuser = Column(Boolean, default=False)
    role = Column(String(20), default="engineer")
    branch_id = Column(Integer, ForeignKey("branches.id"), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
```

#### PowerLine (ЛЭП)
- Связь с Branch (филиал)
- Связь с User (создатель)
- Связь с Pole (опоры)

#### Pole (Опора)
- Географические координаты (latitude, longitude)
- Связь с PowerLine
- Связь с Equipment

### Настройка подключения

```python
# app/database.py
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession

# Преобразование URL для asyncpg
database_url = settings.DATABASE_URL.replace(
    "postgresql://", 
    "postgresql+asyncpg://"
)

# Отключение SSL для Docker соединения
if "?" not in database_url:
    database_url += "?ssl=disable"

engine = create_async_engine(database_url, echo=True)
```

### Миграции Alembic

```bash
# Создание миграции
alembic revision --autogenerate -m "Описание изменений"

# Применение миграций
alembic upgrade head

# Откат миграции
alembic downgrade -1
```

---

## API Endpoints

### Аутентификация

#### POST `/api/v1/auth/login`
Авторизация пользователя через OAuth2PasswordRequestForm.

**Запрос:**
```
Content-Type: application/x-www-form-urlencoded
username=admin&password=admin_123456
```

**Ответ:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```

#### POST `/api/v1/auth/register`
Регистрация нового пользователя.

**Запрос:**
```json
{
  "username": "newuser",
  "email": "user@example.com",
  "full_name": "Иван Иванов",
  "password": "secure_password",
  "role": "engineer",
  "branch_id": 1
}
```

#### GET `/api/v1/auth/me`
Получение информации о текущем пользователе (требует JWT токен).

**Заголовки:**
```
Authorization: Bearer <token>
```

**Ответ:**
```json
{
  "id": 1,
  "username": "admin",
  "email": "admin@example.com",
  "full_name": "Администратор",
  "role": "admin",
  "is_active": true,
  "is_superuser": true,
  "branch_id": null,
  "created_at": "2025-01-16T16:01:37.645789+00:00",
  "updated_at": null
}
```

### ЛЭП (Power Lines)

- `GET /api/v1/power-lines` - Список всех ЛЭП
- `POST /api/v1/power-lines` - Создание новой ЛЭП
- `GET /api/v1/power-lines/{id}` - Детали ЛЭП
- `POST /api/v1/power-lines/{id}/poles` - Добавление опоры к ЛЭП

### Опоры (Poles)

- `GET /api/v1/poles` - Список всех опор
- `GET /api/v1/poles/{id}` - Детали опоры
- `POST /api/v1/poles/{id}/equipment` - Добавление оборудования

### Карта (Map)

- `GET /api/v1/map/power-lines/geojson` - ЛЭП в формате GeoJSON
- `GET /api/v1/map/poles/geojson` - Опоры в формате GeoJSON
- `GET /api/v1/map/substations/geojson` - Подстанции в формате GeoJSON
- `GET /api/v1/map/bounds` - Границы всех данных

### Синхронизация

- `POST /api/v1/sync/upload` - Загрузка пакета данных
- `GET /api/v1/sync/download` - Скачивание изменений
- `GET /api/v1/sync/schemas` - Получение схем данных

---

## Аутентификация и безопасность

### JWT токены

```python
# app/core/security.py
from jose import jwt
from datetime import datetime, timedelta

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(
            minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES
        )
    
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(
        to_encode, 
        settings.SECRET_KEY, 
        algorithm=settings.ALGORITHM
    )
    return encoded_jwt
```

### Хеширование паролей (Argon2)

```python
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")

def get_password_hash(password: str) -> str:
    """Хеширование пароля"""
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Проверка пароля"""
    return pwd_context.verify(plain_password, hashed_password)
```

### Защита endpoints

```python
from app.core.security import get_current_active_user

@router.get("/protected")
async def protected_endpoint(
    current_user: User = Depends(get_current_active_user)
):
    """Защищенный endpoint - требует авторизации"""
    return {"user": current_user.username}
```

---

## Nginx конфигурация

### Основные функции:

1. **Reverse Proxy** - проксирование запросов к FastAPI
2. **SSL терминация** - обработка HTTPS соединений
3. **Load balancing** (при необходимости)
4. **Security headers** - заголовки безопасности

### Конфигурация HTTP (для разработки)

```nginx
server {
    listen 80;
    server_name _;
    
    # Проксирование API запросов
    location /api/ {
        proxy_pass http://backend:8000/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket поддержка
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

### Конфигурация HTTPS

```nginx
server {
    listen 443 ssl http2;
    server_name localhost;

    # SSL сертификаты
    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    
    # Современные SSL настройки
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
    ssl_prefer_server_ciphers off;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
}
```

---

## Docker и развертывание

### Docker Compose структура

```yaml
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: lepm_db
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: dragon167
    ports:
      - "5433:5432"  # 5433 для избежания конфликта
    volumes:
      - pgdata:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    container_name: lepm_redis

  backend:
    build: ./backend
    depends_on:
      - postgres
      - redis
    environment:
      DATABASE_URL: postgresql://postgres:dragon167@postgres:5432/lepm_db
      REDIS_URL: redis://redis:6379
    expose:
      - "8000"

  nginx:
    image: nginx:alpine
    depends_on:
      - backend
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
```

### Dockerfile

```dockerfile
FROM python:3.9-slim

# Установка системных зависимостей
RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    tzdata

# Установка часового пояса
ENV TZ=Europe/Minsk
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime

WORKDIR /app

# Установка зависимостей
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Копирование кода
COPY . .

# Создание пользователя для безопасности
RUN useradd --create-home --shell /bin/bash app \
    && chown -R app:app /app
USER app

EXPOSE 8000

CMD ["python", "run.py"]
```

---

## Примеры проблем и решений

### Проблема 1: Ошибка парсинга пароля (Argon2)

**Симптомы:**
```
passlib.exc.UnknownHashError: hash could not be identified
```

**Причина:**
Пароль в базе данных был сохранен в неправильном формате или поврежден.

**Решение:**

1. Создали скрипт для обновления пароля:
```python
# backend/update_admin_password.py
import asyncio
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from app.core.security import get_password_hash
from app.models.user import User
from sqlalchemy import select

async def update_password():
    engine = create_async_engine("postgresql+asyncpg://postgres:dragon167@localhost:5433/lepm_db")
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    
    async with async_session() as session:
        result = await session.execute(
            select(User).where(User.username == "admin")
        )
        user = result.scalar_one_or_none()
        
        if user:
            # Генерируем новый хеш
            new_hash = get_password_hash("admin_123456")
            user.hashed_password = new_hash
            await session.commit()
            print(f"Пароль обновлен для пользователя {user.username}")
        else:
            print("Пользователь не найден")

asyncio.run(update_password())
```

2. Выполнили скрипт:
```bash
python backend/update_admin_password.py
```

**Код решения:**
```python
# app/core/security.py
from passlib.context import CryptContext

# Используем Argon2 для хеширования
pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")

def get_password_hash(password: str) -> str:
    """Генерация хеша пароля"""
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Проверка пароля"""
    return pwd_context.verify(plain_password, hashed_password)
```

---

### Проблема 2: Несоответствие формата данных (snake_case vs camelCase)

**Симптомы:**
- Фронтенд не может распарсить ответ от API
- Ошибки `TypeError: null: type 'Null' is not a subtype of type 'String'`

**Причина:**
- Бэкенд (FastAPI/Pydantic) возвращает JSON в формате `snake_case` (Python конвенция)
- Фронтенд (Flutter/Dart) ожидает `camelCase` (Dart конвенция)

**Пример проблемы:**

Бэкенд возвращает:
```json
{
  "access_token": "eyJhbGci...",
  "token_type": "bearer",
  "full_name": "Администратор",
  "is_active": true
}
```

Фронтенд ожидает:
```json
{
  "accessToken": "...",
  "tokenType": "bearer",
  "fullName": "Администратор",
  "isActive": true
}
```

**Решение:**

1. **В Pydantic схемах** (бэкенд) - используем `alias`:
```python
# app/schemas/user.py
from pydantic import BaseModel, Field

class UserResponse(BaseModel):
    id: int
    username: str
    email: str
    full_name: str = Field(alias="fullName")  # Маппинг для фронтенда
    is_active: bool = Field(alias="isActive")
    
    class Config:
        populate_by_name = True  # Разрешаем оба варианта
```

2. **Или оставляем snake_case** и настраиваем маппинг на фронтенде (как мы сделали):
```dart
// frontend/lib/core/models/user.dart
@JsonKey(name: 'full_name')
final String fullName;

@JsonKey(name: 'is_active')
final bool isActive;
```

**Вывод:** Решили оставить `snake_case` на бэкенде (стандарт Python/FastAPI) и настроили маппинг на фронтенде.

---

### Проблема 3: Ошибка подключения к БД в Docker

**Симптомы:**
```
sqlalchemy.exc.OperationalError: (asyncpg.exceptions.InvalidPasswordError)
```

**Причина:**
- Неправильная строка подключения для Docker окружения
- SSL соединение не настроено для внутренней сети Docker

**Решение:**

1. **Настройка DATABASE_URL для Docker:**
```python
# app/core/config.py
class Settings(BaseSettings):
    # Для Docker используем имя сервиса из docker-compose
    DATABASE_URL: str = "postgresql://postgres:dragon167@postgres:5432/lepm_db"
    # Для локального запуска: postgresql://postgres:password@localhost:5432/lepm_db
```

2. **Отключение SSL для внутреннего Docker соединения:**
```python
# app/database.py
database_url = settings.DATABASE_URL.replace(
    "postgresql://", 
    "postgresql+asyncpg://"
)

# Отключаем SSL для Docker внутренней сети
if "?" not in database_url:
    database_url += "?ssl=disable"
elif "ssl=" not in database_url:
    database_url += "&ssl=disable"
```

3. **Docker Compose настройка:**
```yaml
# docker-compose.yml
services:
  backend:
    environment:
      DATABASE_URL: postgresql://postgres:dragon167@postgres:5432/lepm_db
    depends_on:
      postgres:
        condition: service_healthy
```

---

### Проблема 4: Nginx редирект HTTP → HTTPS блокирует разработку

**Симптомы:**
- Все HTTP запросы редиректятся на HTTPS
- Фронтенд не может подключиться к API
- Ошибки CORS или connection refused

**Причина:**
Nginx был настроен на автоматический редирект всех HTTP запросов на HTTPS, что мешало разработке.

**Решение:**

1. **Отключили автоматический редирект для разработки:**
```nginx
# nginx/nginx.conf
server {
    listen 80;
    server_name _;
    
    # Закомментировали редирект для разработки
    # return 301 https://$host$request_uri;
    
    # Оставили проксирование на HTTP
    location /api/ {
        proxy_pass http://backend:8000/api/;
        # ...
    }
}
```

2. **Настроили CORS в FastAPI:**
```python
# app/main.py
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

**Вывод:** Для разработки используем HTTP, для production - HTTPS с редиректом.

---

### Проблема 5: OAuth2PasswordRequestForm требует form-urlencoded

**Симптомы:**
```
422 Unprocessable Entity при попытке логина
```

**Причина:**
FastAPI `OAuth2PasswordRequestForm` ожидает данные в формате `application/x-www-form-urlencoded`, а не JSON.

**Решение:**

1. **На бэкенде** - используем стандартный `OAuth2PasswordRequestForm`:
```python
# app/api/v1/auth.py
from fastapi.security import OAuth2PasswordRequestForm

@router.post("/login", response_model=Token)
async def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db)
):
    user = await authenticate_user(db, form_data.username, form_data.password)
    # ...
```

2. **На фронтенде** - отправляем данные в правильном формате:
```dart
// frontend/lib/core/services/auth_service.dart
final formData = {
  'username': username,
  'password': password,
};

final response = await dio.post(
  '/auth/login',
  data: formData,
  options: Options(
    contentType: 'application/x-www-form-urlencoded',
  ),
);
```

**Вывод:** FastAPI OAuth2 требует специфичный формат данных для совместимости со стандартом OAuth2.

---

## Конфигурация и настройки

### Переменные окружения

Создайте файл `.env` в директории `backend/`:

```env
# База данных
DATABASE_URL=postgresql://postgres:dragon167@localhost:5432/lepm_db

# JWT
SECRET_KEY=your-secret-key-change-in-production
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# Redis
REDIS_URL=redis://localhost:6379

# Настройки файлов
UPLOAD_DIR=uploads
MAX_FILE_SIZE=10485760  # 10MB
```

### Запуск приложения

**Локально:**
```bash
cd backend
python run.py
```

**С Docker:**
```bash
docker compose up -d
```

**Проверка работы:**
```bash
curl http://localhost/api/v1/test
```

---

## Мониторинг и отладка

### Логирование

FastAPI автоматически логирует все запросы при `echo=True` в настройках БД.

### Health Check

```bash
curl http://localhost/health
```

### Документация API

- Swagger UI: `http://localhost/docs`
- ReDoc: `http://localhost/redoc`

---

## Заключение

Бэкенд построен на современном стеке с использованием:
- Асинхронной архитектуры для высокой производительности
- Модульной структуры для масштабируемости
- Безопасной аутентификации через JWT
- Docker для простого развертывания
- Nginx для production-ready конфигурации

Все проблемы, с которыми мы столкнулись, были успешно решены через правильную настройку конфигураций и понимание особенностей используемых технологий.

