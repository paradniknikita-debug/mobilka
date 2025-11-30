# Разработка Backend части системы управления ЛЭП

## Введение

В данной работе рассматривается разработка серверной части системы управления линиями электропередач (ЛЭП). Backend реализован с использованием современных технологий и подходов, обеспечивающих высокую производительность, масштабируемость и безопасность.

---

## 1. Архитектура и выбор технологий

### 1.1 FastAPI - веб-фреймворк для создания API

#### Описание технологии

FastAPI — современный веб-фреймворк для создания REST API на Python, основанный на стандартах OpenAPI и JSON Schema. Фреймворк использует асинхронное программирование и автоматическую генерацию документации.

#### Преимущества FastAPI

1. **Высокая производительность**: Сопоставима с NodeJS и Go благодаря асинхронной архитектуре
2. **Автоматическая документация**: Swagger UI и ReDoc генерируются автоматически
3. **Валидация данных**: Встроенная валидация через Pydantic
4. **Типизация**: Поддержка type hints для лучшей читаемости и отладки
5. **Простота разработки**: Минимальный boilerplate код
6. **Современные стандарты**: Основан на OpenAPI 3.0 и JSON Schema

#### Обоснование выбора

FastAPI выбран для данного проекта по следующим причинам:

- **Асинхронность**: Критически важно для работы с базой данных и множественными запросами одновременно
- **Автоматическая документация**: Упрощает интеграцию с фронтендом и тестирование API
- **Валидация данных**: Защита от некорректных данных на уровне фреймворка
- **Активное сообщество**: Большое количество примеров и решений

#### Пример использования

```python
# app/main.py
from fastapi import FastAPI
from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Управление жизненным циклом приложения"""
    await init_db()  # Инициализация БД при запуске
    yield
    # Очистка ресурсов при остановке

app = FastAPI(
    title="ЛЭП Management API",
    version="1.0.0",
    lifespan=lifespan
)

# Пример endpoint
@app.get("/api/v1/test")
async def test_endpoint(message: str = "Hello from backend!"):
    """Тестовый endpoint для проверки работы API"""
    return {
        "status": "ok",
        "message": message,
        "timestamp": datetime.now().isoformat()
    }
```

**Объяснение кода:**
- `@asynccontextmanager` - управление жизненным циклом приложения
- `async def` - асинхронная функция для неблокирующих операций
- Автоматическая генерация документации по docstring

---

### 1.2 PostgreSQL - реляционная база данных

#### Описание технологии

PostgreSQL — мощная объектно-реляционная система управления базами данных с открытым исходным кодом. Поддерживает ACID транзакции, сложные запросы и расширяемость.

#### Преимущества PostgreSQL

1. **Надежность**: Строгое соблюдение ACID принципов
2. **Расширяемость**: Поддержка пользовательских типов данных и функций
3. **Производительность**: Оптимизированный движок запросов
4. **Географические данные**: Встроенная поддержка PostGIS для геоданных
5. **JSON поддержка**: Нативная работа с JSON/JSONB
6. **Бесплатность**: Открытый исходный код

#### Обоснование выбора

PostgreSQL выбран для проекта по следующим причинам:

- **Географические данные**: Необходимо хранить координаты опор и ЛЭП (поддержка PostGIS)
- **Сложные связи**: Многоуровневая структура данных (ЛЭП → Опоры → Оборудование)
- **Надежность**: Критически важно для промышленной системы
- **Масштабируемость**: Возможность горизонтального масштабирования

#### Пример использования

```python
# app/models/power_line.py
from sqlalchemy import Column, Integer, String, Float, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base

class PowerLine(Base):
    """Модель линии электропередачи"""
    __tablename__ = "power_lines"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(200), nullable=False, index=True)
    code = Column(String(50), unique=True, nullable=False)
    voltage_level = Column(Integer, nullable=False)  # кВ
    length = Column(Float)  # километры
    branch_id = Column(Integer, ForeignKey("branches.id"), nullable=True)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Связи с другими таблицами
    branch = relationship("Branch", back_populates="power_lines")
    creator = relationship("User", back_populates="created_power_lines")
    poles = relationship("Pole", back_populates="power_line", cascade="all, delete-orphan")
```

**Объяснение кода:**
- `Base` - базовый класс для всех моделей SQLAlchemy
- `relationship` - определение связей между таблицами
- `cascade="all, delete-orphan"` - автоматическое удаление связанных записей
- `server_default=func.now()` - автоматическая установка времени создания

---

### 1.3 SQLAlchemy (Async) - ORM для работы с БД

#### Описание технологии

SQLAlchemy — мощный инструментарий Python SQL и ORM (Object-Relational Mapping), который предоставляет полный набор паттернов для работы с базами данных. Async версия позволяет выполнять неблокирующие запросы.

#### Преимущества SQLAlchemy Async

1. **Асинхронность**: Неблокирующие операции с БД
2. **Абстракция**: Работа с БД через объекты Python
3. **Миграции**: Интеграция с Alembic
4. **Безопасность**: Защита от SQL-инъекций
5. **Гибкость**: Возможность написания raw SQL при необходимости
6. **Производительность**: Оптимизация запросов через connection pooling

#### Обоснование выбора

SQLAlchemy Async выбран потому что:

- **Совместимость с FastAPI**: Оба используют async/await
- **Безопасность**: ORM защищает от SQL-инъекций
- **Удобство**: Работа с БД через Python объекты
- **Миграции**: Легкое управление схемой БД через Alembic

#### Пример использования

```python
# app/database.py
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from app.core.config import settings

# Создание асинхронного движка БД
database_url = settings.DATABASE_URL.replace(
    "postgresql://", 
    "postgresql+asyncpg://"  # Используем asyncpg драйвер
)

# Отключение SSL для внутренней Docker сети
if "?" not in database_url:
    database_url += "?ssl=disable"

engine = create_async_engine(
    database_url,
    echo=True,  # Логирование SQL запросов
    pool_size=10,  # Размер пула соединений
    max_overflow=20
)

# Создание фабрики сессий
AsyncSessionLocal = sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False
)

# Dependency для получения сессии БД
async def get_db():
    """Получение сессии базы данных"""
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()  # Автоматический commit
        except Exception:
            await session.rollback()  # Откат при ошибке
            raise
        finally:
            await session.close()
```

**Пример использования в endpoint:**

```python
# app/api/v1/power_lines.py
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from fastapi import Depends
from app.database import get_db
from app.models.power_line import PowerLine

@router.get("/", response_model=List[PowerLineResponse])
async def get_power_lines(
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db)
):
    """Получение списка всех ЛЭП"""
    # Асинхронный запрос к БД
    result = await db.execute(
        select(PowerLine)
        .offset(skip)
        .limit(limit)
    )
    power_lines = result.scalars().all()
    return power_lines
```

**Объяснение кода:**
- `Depends(get_db)` - внедрение зависимости сессии БД
- `select()` - построение SQL запроса через ORM
- `await db.execute()` - асинхронное выполнение запроса
- `result.scalars().all()` - получение всех результатов

---

### 1.4 JWT (JSON Web Tokens) - аутентификация

#### Описание технологии

JWT — открытый стандарт (RFC 7519) для безопасной передачи информации между сторонами в виде JSON объекта. Токен состоит из трех частей: заголовок, полезная нагрузка и подпись.

#### Преимущества JWT

1. **Stateless**: Серверу не нужно хранить сессии
2. **Масштабируемость**: Легко масштабировать на несколько серверов
3. **Безопасность**: Подпись гарантирует целостность данных
4. **Мобильность**: Легко использовать в мобильных приложениях
5. **Стандартизация**: Широко поддерживается различными платформами

#### Обоснование выбора

JWT выбран для аутентификации потому что:

- **Stateless архитектура**: Упрощает масштабирование
- **Мобильные приложения**: Идеально подходит для Flutter приложения
- **Безопасность**: Токены подписываются и могут содержать срок действия
- **Стандартность**: Легкая интеграция с различными клиентами

#### Пример использования

```python
# app/core/security.py
from jose import jwt
from datetime import datetime, timedelta
from app.core.config import settings

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    """
    Создание JWT токена
    
    Args:
        data: Данные для включения в токен (обычно username)
        expires_delta: Время жизни токена
    
    Returns:
        Закодированный JWT токен
    """
    to_encode = data.copy()
    
    # Установка времени истечения
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(
            minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES
        )
    
    to_encode.update({"exp": expire})
    
    # Кодирование токена с секретным ключом
    encoded_jwt = jwt.encode(
        to_encode, 
        settings.SECRET_KEY, 
        algorithm=settings.ALGORITHM
    )
    return encoded_jwt

# Пример использования в endpoint логина
@router.post("/login", response_model=Token)
async def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db)
):
    """Авторизация пользователя"""
    # Проверка учетных данных
    user = await authenticate_user(db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password"
        )
    
    # Создание токена
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.username},  # subject - обычно username или user_id
        expires_delta=access_token_expires
    )
    
    return {
        "access_token": access_token,
        "token_type": "bearer"
    }
```

**Валидация токена:**

```python
async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db)
) -> User:
    """Получение текущего пользователя из JWT токена"""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials"
    )
    
    try:
        # Декодирование токена
        payload = jwt.decode(
            credentials.credentials, 
            settings.SECRET_KEY, 
            algorithms=[settings.ALGORITHM]
        )
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    
    # Получение пользователя из БД
    user = await get_user_by_username(db, username=username)
    if user is None:
        raise credentials_exception
    return user
```

**Объяснение кода:**
- `jwt.encode()` - создание токена с секретным ключом
- `jwt.decode()` - проверка подписи и декодирование токена
- `exp` - автоматическая проверка срока действия
- `Depends(security)` - извлечение токена из заголовка Authorization

---

### 1.5 Argon2 - хеширование паролей

#### Описание технологии

Argon2 — победитель конкурса Password Hashing Competition (2015). Современный алгоритм хеширования паролей, устойчивый к атакам перебора и перебору на GPU/ASIC.

#### Преимущества Argon2

1. **Безопасность**: Устойчивость к различным типам атак
2. **Гибкость**: Настраиваемые параметры сложности
3. **Стандартность**: Рекомендуется OWASP и многими экспертами
4. **Производительность**: Оптимизирован для современных процессоров
5. **Защита от перебора**: Защита от атак на GPU и ASIC

#### Обоснование выбора

Argon2 выбран для хеширования паролей потому что:

- **Современный стандарт**: Рекомендуется для новых проектов
- **Безопасность**: Максимальная защита от взлома
- **Будущее**: Долгосрочная поддержка и развитие
- **Производительность**: Оптимальный баланс безопасности и скорости

#### Пример использования

```python
# app/core/security.py
from passlib.context import CryptContext

# Настройка контекста хеширования
pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")

def get_password_hash(password: str) -> str:
    """
    Хеширование пароля
    
    Args:
        password: Пароль в открытом виде
    
    Returns:
        Хеш пароля в формате Argon2
    """
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """
    Проверка пароля
    
    Args:
        plain_password: Пароль в открытом виде
        hashed_password: Хеш из базы данных
    
    Returns:
        True если пароль верный, False иначе
    """
    return pwd_context.verify(plain_password, hashed_password)

# Пример использования при регистрации
@router.post("/register", response_model=UserResponse)
async def register(user_data: UserCreate, db: AsyncSession = Depends(get_db)):
    """Регистрация нового пользователя"""
    # Хеширование пароля перед сохранением
    hashed_password = get_password_hash(user_data.password)
    
    db_user = User(
        username=user_data.username,
        email=user_data.email,
        hashed_password=hashed_password,  # Сохраняем только хеш
        # ... другие поля
    )
    
    db.add(db_user)
    await db.commit()
    return db_user

# Пример проверки при логине
async def authenticate_user(
    db: AsyncSession, 
    username: str, 
    password: str
) -> Optional[User]:
    """Аутентификация пользователя"""
    user = await get_user_by_username(db, username)
    if not user:
        return None
    
    # Проверка пароля
    if not verify_password(password, user.hashed_password):
        return None
    
    return user
```

**Объяснение кода:**
- `CryptContext` - контекст для управления различными алгоритмами хеширования
- `hash()` - создание хеша с автоматической генерацией соли
- `verify()` - безопасное сравнение пароля с хешем
- Пароль никогда не сохраняется в открытом виде

---

### 1.6 Pydantic - валидация данных

#### Описание технологии

Pydantic — библиотека для валидации данных с использованием аннотаций типов Python. Автоматически генерирует JSON схемы и обеспечивает валидацию на уровне типов.

#### Преимущества Pydantic

1. **Валидация**: Автоматическая проверка типов и значений
2. **Документация**: Автоматическая генерация схем для OpenAPI
3. **Безопасность**: Защита от некорректных данных
4. **Производительность**: Написана на Cython для скорости
5. **Удобство**: Простой и понятный синтаксис

#### Обоснование выбора

Pydantic выбран потому что:

- **Интеграция с FastAPI**: Встроенная поддержка
- **Валидация**: Защита API от некорректных данных
- **Документация**: Автоматическая генерация схем
- **Типизация**: Улучшает читаемость и поддерживаемость кода

#### Пример использования

```python
# app/schemas/user.py
from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from datetime import datetime

class UserBase(BaseModel):
    """Базовая схема пользователя"""
    username: str = Field(..., min_length=3, max_length=50)
    email: EmailStr  # Автоматическая валидация email
    full_name: str = Field(..., min_length=1, max_length=100)
    role: str = Field(default="engineer", pattern="^(engineer|dispatcher|admin)$")

class UserCreate(UserBase):
    """Схема для создания пользователя"""
    password: str = Field(..., min_length=8, max_length=100)
    branch_id: Optional[int] = None

class UserResponse(UserBase):
    """Схема ответа с данными пользователя"""
    id: int
    is_active: bool
    is_superuser: bool
    branch_id: Optional[int]
    created_at: datetime
    updated_at: Optional[datetime]
    
    class Config:
        from_attributes = True  # Позволяет создавать из SQLAlchemy моделей

# Использование в endpoint
@router.post("/register", response_model=UserResponse)
async def register(
    user_data: UserCreate,  # Автоматическая валидация
    db: AsyncSession = Depends(get_db)
):
    """Регистрация нового пользователя"""
    # user_data уже валидирован Pydantic
    # Если данные неверны, FastAPI вернет 422 автоматически
    
    # Проверка на существование пользователя
    existing_user = await db.execute(
        select(User).where(User.username == user_data.username)
    )
    if existing_user.scalar_one_or_none():
        raise HTTPException(
            status_code=400,
            detail="Username already registered"
        )
    
    # Создание пользователя
    hashed_password = get_password_hash(user_data.password)
    db_user = User(
        username=user_data.username,
        email=user_data.email,
        hashed_password=hashed_password,
        # ...
    )
    
    db.add(db_user)
    await db.commit()
    await db.refresh(db_user)
    
    return db_user  # Автоматически преобразуется в UserResponse
```

**Объяснение кода:**
- `Field(...)` - обязательное поле с ограничениями
- `EmailStr` - автоматическая валидация формата email
- `pattern` - валидация через регулярное выражение
- `from_attributes = True` - позволяет создавать из SQLAlchemy моделей
- Автоматическая валидация при получении запроса

---

### 1.7 Nginx - Reverse Proxy и SSL терминация

#### Описание технологии

Nginx — высокопроизводительный веб-сервер и reverse proxy. Используется для проксирования запросов, SSL терминации, балансировки нагрузки и кэширования.

#### Преимущества Nginx

1. **Производительность**: Обрабатывает тысячи соединений одновременно
2. **Гибкость**: Множество модулей и настроек
3. **SSL**: Встроенная поддержка HTTPS
4. **Кэширование**: Эффективное кэширование статики
5. **Балансировка**: Встроенная поддержка load balancing

#### Обоснование выбора

Nginx выбран потому что:

- **Production-ready**: Стандарт для production окружений
- **SSL терминация**: Упрощает управление сертификатами
- **Производительность**: Разгрузка FastAPI от статики
- **Безопасность**: Security headers и защита от атак

#### Пример конфигурации

```nginx
# nginx/nginx.conf
events {
    worker_connections 1024;
}

http {
    # Проксирование к FastAPI
    upstream backend {
        server backend:8000;
    }

    # HTTP сервер (для разработки)
    server {
        listen 80;
        server_name _;
        
        location /api/ {
            proxy_pass http://backend/api/;
            
            # Передача заголовков
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # WebSocket поддержка
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            
            # Таймауты
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }
    }

    # HTTPS сервер (для production)
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
        add_header X-XSS-Protection "1; mode=block" always;
        
        location /api/ {
            proxy_pass http://backend/api/;
            # ... те же настройки проксирования
        }
    }
}
```

**Объяснение конфигурации:**
- `upstream` - определение группы серверов для балансировки
- `proxy_pass` - проксирование запросов к backend
- `proxy_set_header` - передача информации о клиенте
- `ssl_protocols` - поддержка только безопасных версий TLS
- Security headers - защита от различных атак

---

### 1.8 Docker и Docker Compose - контейнеризация

#### Описание технологии

Docker — платформа для контейнеризации приложений. Docker Compose — инструмент для определения и запуска многоконтейнерных приложений.

#### Преимущества Docker

1. **Изоляция**: Приложения работают в изолированных контейнерах
2. **Портативность**: Одинаковая работа на разных системах
3. **Масштабируемость**: Легкое масштабирование сервисов
4. **Упрощение деплоя**: Один образ для всех окружений
5. **Воспроизводимость**: Гарантированная одинаковость окружения

#### Обоснование выбора

Docker выбран потому что:

- **Упрощение разработки**: Единое окружение для всех разработчиков
- **Деплой**: Простое развертывание на сервере
- **Изоляция**: Каждый сервис в своем контейнере
- **Масштабирование**: Легко добавить новые инстансы

#### Пример конфигурации

```yaml
# docker-compose.yml
version: '3.8'

services:
  # PostgreSQL база данных
  postgres:
    image: postgres:15
    container_name: lepm_postgres
    environment:
      POSTGRES_DB: lepm_db
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: dragon167
    ports:
      - "5433:5432"  # Внешний порт:внутренний порт
    volumes:
      - pgdata:/var/lib/postgresql/data  # Постоянное хранилище
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Backend API
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: lepm_backend
    depends_on:
      postgres:
        condition: service_healthy  # Ждем готовности БД
    environment:
      DATABASE_URL: postgresql://postgres:dragon167@postgres:5432/lepm_db
      # Используем имя сервиса 'postgres' вместо localhost
    expose:
      - "8000"  # Доступен только внутри Docker сети
    volumes:
      - ./backend/app:/app/app:ro  # Монтирование кода для разработки

  # Nginx reverse proxy
  nginx:
    image: nginx:alpine
    container_name: lepm_nginx
    depends_on:
      - backend
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro

volumes:
  pgdata:  # Именованный volume для данных БД

networks:
  default:
    driver: bridge
```

**Dockerfile для backend:**

```dockerfile
# backend/Dockerfile
FROM python:3.9-slim

# Установка системных зависимостей
RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Установка часового пояса
ENV TZ=Europe/Minsk
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime

WORKDIR /app

# Установка зависимостей Python
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Копирование кода приложения
COPY . .

# Создание непривилегированного пользователя
RUN useradd --create-home --shell /bin/bash app \
    && chown -R app:app /app
USER app

EXPOSE 8000

CMD ["python", "run.py"]
```

**Объяснение:**
- `depends_on` - порядок запуска сервисов
- `healthcheck` - проверка готовности сервиса
- `volumes` - постоянное хранилище данных
- `expose` - порты доступные внутри сети
- `ports` - проброс портов наружу

---

## 2. Реализация основных компонентов

### 2.1 Система аутентификации

#### Архитектура

Система аутентификации построена на JWT токенах и включает:
- Регистрацию пользователей
- Авторизацию через OAuth2
- Защиту endpoints через dependency injection

#### Пример полного цикла аутентификации

```python
# 1. Регистрация пользователя
@router.post("/register", response_model=UserResponse)
async def register(user_data: UserCreate, db: AsyncSession = Depends(get_db)):
    # Валидация данных через Pydantic
    # Проверка уникальности username и email
    # Хеширование пароля через Argon2
    # Сохранение в БД
    # Возврат данных пользователя

# 2. Авторизация
@router.post("/login", response_model=Token)
async def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db)
):
    # Проверка учетных данных
    # Создание JWT токена
    # Возврат токена клиенту

# 3. Защита endpoint
@router.get("/me", response_model=UserResponse)
async def read_users_me(
    current_user: User = Depends(get_current_active_user)
):
    # Автоматическая проверка токена
    # Извлечение пользователя из БД
    # Возврат данных пользователя
```

---

### 2.2 Работа с геоданными

#### GeoJSON endpoints

Для отображения данных на карте используются GeoJSON форматы:

```python
# app/api/v1/map_tiles.py
@router.get("/poles/geojson")
async def get_poles_geojson(
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Получение всех опор в формате GeoJSON"""
    result = await db.execute(select(Pole))
    poles = result.scalars().all()
    
    features = []
    for pole in poles:
        features.append({
            "type": "Feature",
            "geometry": {
                "type": "Point",
                "coordinates": [pole.longitude, pole.latitude]
            },
            "properties": {
                "id": pole.id,
                "tower_number": pole.tower_number,
                "power_line_id": pole.power_line_id
            }
        })
    
    return {
        "type": "FeatureCollection",
        "features": features
    }
```

---

## 3. Решение проблем в процессе разработки

### Проблема: Несоответствие формата данных между бэкендом и фронтендом

**Описание проблемы:**
Бэкенд возвращал данные в формате `snake_case` (Python конвенция), а фронтенд ожидал `camelCase` (Dart конвенция).

**Решение:**
Использование Pydantic `alias` или настройка маппинга на фронтенде. В нашем случае оставили `snake_case` на бэкенде и настроили маппинг на фронтенде через `@JsonKey`.

**Код решения:**
```python
# Бэкенд остается с snake_case
class UserResponse(BaseModel):
    full_name: str
    is_active: bool
    # ...
```

---

## Заключение

В данной работе была реализована серверная часть системы управления ЛЭП с использованием современных технологий:

- **FastAPI** для создания высокопроизводительного API
- **PostgreSQL** для надежного хранения данных
- **SQLAlchemy Async** для эффективной работы с БД
- **JWT** для безопасной аутентификации
- **Argon2** для защиты паролей
- **Nginx** для production-ready развертывания
- **Docker** для контейнеризации и упрощения деплоя

Все компоненты интегрированы и работают совместно, обеспечивая высокую производительность, безопасность и масштабируемость системы.

