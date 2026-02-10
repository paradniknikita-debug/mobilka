# Руководство разработчика: ЛЭП Management System

## Оглавление
1. [Архитектура проекта](#архитектура-проекта)
2. [Структура файлов и назначение](#структура-файлов-и-назначение)
3. [Поток данных в системе](#поток-данных-в-системе)
4. [Инструменты и технологии](#инструменты-и-технологии)
5. [Работа с базой данных](#работа-с-базой-данных)
6. [Внесение изменений](#внесение-изменений)
7. [Анализ и решение проблем](#анализ-и-решение-проблем)
8. [Логирование](#логирование)
9. [Фундаментальные концепции](#фундаментальные-концепции)

---

## Архитектура проекта

### Общая схема

```
┌─────────────────┐
│   Web Browser   │  (Angular Frontend)
│  Port 4200/443  │
└────────┬────────┘
         │ HTTPS/HTTP
         ▼
┌─────────────────┐
│     Nginx       │  (Reverse Proxy)
│  Port 80/443    │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌─────────┐ ┌──────────┐
│ Backend │ │ Frontend │
│ FastAPI │ │  Flutter │
│ :8000   │ │   Web    │
└────┬────┘ └──────────┘
     │
     ├──► PostgreSQL (Port 5433)
     └──► Redis (Port 6379)
```

### Трехслойная архитектура

**1. Presentation Layer (Слой представления)**
- `web-frontend/` - Angular приложение
- `frontend/` - Flutter мобильное приложение
- Отвечает за UI/UX, валидацию форм, отображение данных

**2. Application Layer (Слой приложения)**
- `backend/app/api/v1/` - REST API endpoints
- `backend/app/core/` - Бизнес-логика, безопасность
- Обрабатывает запросы, валидирует данные, вызывает сервисы

**3. Data Layer (Слой данных)**
- `backend/app/models/` - SQLAlchemy модели (ORM)
- PostgreSQL - реляционная БД
- Redis - кэш и сессии

---

## Структура файлов и назначение

### Корневая директория

```
mobilka/
├── docker-compose.yml      # Оркестрация всех сервисов
├── .gitignore              # Игнорируемые файлы Git
├── setup.bat / setup.sh    # Автоматическая настройка
├── start.bat / start.sh    # Быстрый запуск
└── README.md               # Общая документация
```

**docker-compose.yml** - главный файл конфигурации Docker
- Определяет 4 сервиса: postgres, redis, backend, nginx
- Настраивает сети, volumes, порты
- Устанавливает зависимости между сервисами

### Backend (`backend/`)

```
backend/
├── app/                    # Основной код приложения
│   ├── main.py            # Точка входа FastAPI
│   ├── database.py        # Подключение к БД
│   ├── api/v1/            # REST API endpoints
│   │   ├── auth.py        # Аутентификация
│   │   ├── power_lines.py # Управление ЛЭП
│   │   ├── poles.py       # Управление опорами
│   │   └── ...
│   ├── models/            # SQLAlchemy модели (ORM)
│   │   ├── base.py        # Базовый класс моделей
│   │   ├── power_line.py  # Модель ЛЭП
│   │   └── ...
│   ├── schemas/           # Pydantic схемы (валидация)
│   │   ├── power_line.py  # Схемы для ЛЭП
│   │   └── ...
│   └── core/              # Ядро приложения
│       ├── config.py      # Настройки из .env
│       └── security.py    # JWT, хеширование паролей
├── alembic/               # Миграции БД
│   ├── env.py            # Конфигурация Alembic
│   └── versions/         # Файлы миграций
├── requirements.txt       # Python зависимости
├── Dockerfile            # Образ для Docker
└── run.py                # Скрипт запуска
```

#### Ключевые файлы backend

**`app/main.py`** - точка входа FastAPI
```python
# Создает FastAPI приложение
app = FastAPI(lifespan=lifespan)

# lifespan - функция жизненного цикла
# Выполняется при старте: подключение к БД, Redis
# Выполняется при остановке: закрытие соединений

# Подключает роутеры (API endpoints)
app.include_router(power_lines.router, prefix="/api/v1/power-lines")
```

**`app/database.py`** - подключение к PostgreSQL
- Создает async engine SQLAlchemy
- Настраивает пул соединений
- Предоставляет `get_db()` для dependency injection

**`app/models/`** - SQLAlchemy ORM модели
- Каждый файл = одна сущность (PowerLine, Pole, Span)
- Наследуются от `Base` (declarative_base)
- Определяют структуру таблиц БД

**`app/schemas/`** - Pydantic схемы
- Валидация входных данных (Create схемы)
- Сериализация выходных данных (Response схемы)
- Автоматическая валидация типов

**`app/api/v1/`** - REST API endpoints
- Каждый файл = группа связанных endpoints
- Использует dependency injection для БД и пользователя
- Возвращает Pydantic схемы

### Frontend Angular (`web-frontend/`)

```
web-frontend/
├── src/app/
│   ├── app.module.ts          # Главный модуль Angular
│   ├── app-routing.module.ts  # Маршрутизация
│   ├── core/                  # Ядро (сервисы, модели)
│   │   ├── services/          # HTTP клиенты, бизнес-логика
│   │   │   ├── api.service.ts # HTTP запросы к backend
│   │   │   ├── auth.service.ts # Аутентификация
│   │   │   └── map.service.ts  # Работа с картой
│   │   ├── models/            # TypeScript интерфейсы
│   │   ├── guards/            # Route guards (защита маршрутов)
│   │   └── interceptors/      # HTTP interceptors
│   ├── features/              # Функциональные модули
│   │   ├── map/               # Карта и управление объектами
│   │   ├── auth/              # Авторизация
│   │   └── ...
│   └── layout/                # Компоненты макета
│       ├── main-layout/       # Главный layout
│       └── sidebar/           # Боковая панель
├── angular.json               # Конфигурация Angular CLI
├── package.json              # npm зависимости
└── tsconfig.json             # TypeScript конфигурация
```

#### Ключевые файлы frontend

**`app.module.ts`** - главный модуль
- Объявляет все компоненты (declarations)
- Импортирует модули (Material, Forms, Router)
- Настраивает провайдеры (interceptors, guards)

**`core/services/api.service.ts`** - HTTP клиент
- Инкапсулирует все запросы к backend
- Использует RxJS Observables
- Обрабатывает ошибки

**`core/interceptors/auth.interceptor.ts`** - добавляет JWT токен
```typescript
// Автоматически добавляет Authorization header
req = req.clone({
  setHeaders: { Authorization: `Bearer ${token}` }
});
```

**`core/guards/auth.guard.ts`** - защита маршрутов
- Проверяет наличие токена
- Редиректит на /login если нет токена

### Nginx (`nginx/`)

```
nginx/
├── nginx.conf        # Главная конфигурация
└── ssl/              # SSL сертификаты
    ├── key.pem
    └── crt.pem
```

**nginx.conf** - reverse proxy конфигурация
- Проксирует `/api/*` → backend:8000
- Отдает статику Angular из `/app/angular-web`
- Отдает статику Flutter из `/app/flutter-web`
- Настраивает HTTPS, CORS, сжатие

---

## Поток данных в системе

### 1. Создание пролёта (пример полного цикла)

```
Пользователь → Angular Component → API Service → HTTP Request
                                                      ↓
                                            Nginx (reverse proxy)
                                                      ↓
                                            FastAPI Backend
                                                      ↓
                                            Dependency Injection
                                                      ↓
                                            API Endpoint Handler
                                                      ↓
                                            Pydantic Schema Validation
                                                      ↓
                                            SQLAlchemy ORM
                                                      ↓
                                            PostgreSQL Database
                                                      ↓
                                            Response (JSON)
                                                      ↓
                                            Angular Component
                                                      ↓
                                            UI Update
```

### Детальный разбор

**Шаг 1: Пользователь заполняет форму**
```typescript
// create-span-dialog.component.ts
onSubmit() {
  const formData = this.spanForm.value;
  // formData = { from_pole_id: 1, to_pole_id: 2, length: 100, ... }
}
```

**Шаг 2: Отправка HTTP запроса**
```typescript
// api.service.ts
createSpan(powerLineId: number, span: any): Observable<Span> {
  return this.http.post<Span>(
    `${this.apiUrl}/power-lines/${powerLineId}/spans`, 
    span
  );
}
```

**Шаг 3: Interceptor добавляет токен**
```typescript
// auth.interceptor.ts
const token = this.authService.getToken();
req = req.clone({
  setHeaders: { Authorization: `Bearer ${token}` }
});
```

**Шаг 4: Nginx проксирует запрос**
```nginx
# nginx.conf
location /api/ {
    proxy_pass http://backend:8000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```

**Шаг 5: FastAPI получает запрос**
```python
# main.py
app.include_router(power_lines.router, prefix="/api/v1/power-lines")
```

**Шаг 6: Dependency Injection**
```python
# power_lines.py
@router.post("/{power_line_id}/spans")
async def create_span(
    power_line_id: int,
    span_data: SpanCreate,  # Pydantic автоматически валидирует
    current_user: User = Depends(get_current_active_user),  # DI
    db: AsyncSession = Depends(get_db)  # DI
):
```

**Шаг 7: Валидация Pydantic**
```python
# schemas/power_line.py
class SpanCreate(SpanBase):
    from_pole_id: int  # Автоматическая валидация типа
    to_pole_id: int
    length: float
    # Если данные невалидны - автоматически 422 ошибка
```

**Шаг 8: Работа с БД через ORM**
```python
# power_lines.py
span = Span(**span_data.dict())
db.add(span)
await db.commit()
await db.refresh(span)
```

**Шаг 9: SQLAlchemy генерирует SQL**
```sql
-- SQLAlchemy автоматически генерирует:
INSERT INTO spans (from_pole_id, to_pole_id, length, ...)
VALUES (1, 2, 100.0, ...);
```

**Шаг 10: Ответ возвращается**
```python
return span  # FastAPI автоматически сериализует в JSON
```

**Шаг 11: Angular получает ответ**
```typescript
// create-span-dialog.component.ts
this.apiService.createSpan(powerLineId, formData).subscribe({
  next: (span) => {
    // span - объект типа Span
    this.dialogRef.close(span);
  }
});
```

---

## Инструменты и технологии

### NPM (Node Package Manager)

**Что это:** Менеджер пакетов для JavaScript/TypeScript

**Где используется:**
- `web-frontend/package.json` - зависимости Angular
- `web-frontend/node_modules/` - установленные пакеты

**Основные команды:**
```bash
npm install          # Установить зависимости из package.json
npm install <pkg>    # Установить пакет
npm run build        # Собрать проект (вызывает ng build)
npm run start        # Запустить dev server
npm audit            # Проверить уязвимости
```

**package.json** - манифест проекта
```json
{
  "dependencies": {
    "@angular/core": "^17.0.0"  // ^ означает совместимые версии
  },
  "scripts": {
    "build": "ng build"  // npm run build → ng build
  }
}
```

**package-lock.json** - фиксирует точные версии
- Автоматически генерируется
- Гарантирует одинаковые версии у всех разработчиков

### Nginx

**Что это:** Веб-сервер и reverse proxy

**Зачем нужен:**
1. **Reverse Proxy** - проксирует запросы к backend
2. **SSL Termination** - обрабатывает HTTPS
3. **Статические файлы** - отдает Angular/Flutter сборки
4. **Load Balancing** - распределение нагрузки (если несколько backend)
5. **CORS** - настройка заголовков CORS

**Конфигурация (`nginx/nginx.conf`):**
```nginx
# Проксирование API запросов
location /api/ {
    proxy_pass http://backend:8000;  # Имя сервиса из docker-compose
    proxy_set_header Host $host;
}

# Статические файлы Angular
location / {
    root /app/angular-web;
    try_files $uri $uri/ /index.html;
}
```

**Как работает:**
1. Клиент → `https://localhost/api/v1/power-lines`
2. Nginx получает запрос на порту 443
3. Проверяет SSL сертификат
4. Проксирует на `http://backend:8000/api/v1/power-lines`
5. Backend обрабатывает и возвращает ответ
6. Nginx возвращает ответ клиенту

### Redis

**Что это:** In-memory хранилище ключ-значение

**Зачем нужен:**
1. **Кэширование** - быстрый доступ к часто используемым данным
2. **Сессии** - хранение сессий пользователей
3. **Очереди** - для фоновых задач (Celery)

**В нашем проекте:**
```python
# backend/app/main.py
redis_client = redis.from_url(settings.REDIS_URL)

# Использование (пример):
await redis_client.set("user:123", json.dumps(user_data), ex=3600)
user_data = await redis_client.get("user:123")
```

**Docker конфигурация:**
```yaml
# docker-compose.yml
redis:
  image: redis:7-alpine
  ports:
    - "6379:6379"
```

**Подключение:**
```python
# backend/app/core/config.py
REDIS_URL: str = "redis://localhost:6379"
# В Docker: redis://redis:6379
```

### JWT (JSON Web Token)

**Что это:** Стандарт для безопасной передачи информации

**Структура токена:**
```
header.payload.signature

header = {"alg": "HS256", "typ": "JWT"}
payload = {"user_id": 1, "exp": 1234567890}
signature = HMACSHA256(base64(header) + "." + base64(payload), secret)
```

**Как работает в проекте:**

**1. Логин (`backend/app/api/v1/auth.py`):**
```python
@router.post("/login")
async def login(credentials: LoginRequest):
    user = await authenticate_user(credentials.username, credentials.password)
    access_token = create_access_token(data={"sub": user.username})
    return {"access_token": access_token, "token_type": "bearer"}
```

**2. Создание токена (`backend/app/core/security.py`):**
```python
def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=30))
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt
```

**3. Проверка токена:**
```python
async def get_current_active_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db)
):
    payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    username = payload.get("sub")
    user = await get_user_by_username(db, username)
    return user
```

**4. Использование в endpoints:**
```python
@router.get("/power-lines")
async def get_power_lines(
    current_user: User = Depends(get_current_active_user)  # Автоматическая проверка
):
    # current_user уже проверен и загружен
    return await db.execute(select(PowerLine))
```

**5. Frontend отправка токена:**
```typescript
// auth.interceptor.ts
const token = this.authService.getToken();
req = req.clone({
  setHeaders: { Authorization: `Bearer ${token}` }
});
```

### PostgreSQL

**Что это:** Реляционная база данных

**Структура:**
- **Таблицы** - хранят данные (power_lines, poles, spans)
- **Связи** - Foreign Keys между таблицами
- **Индексы** - ускоряют поиск
- **Транзакции** - гарантируют целостность данных

**Подключение:**
```python
# backend/app/database.py
DATABASE_URL = "postgresql://user:password@host:port/database"
engine = create_async_engine(DATABASE_URL)
```

**SQLAlchemy ORM:**
```python
# Модель (app/models/power_line.py)
class PowerLine(Base):
    __tablename__ = "power_lines"
    id = Column(Integer, primary_key=True)
    name = Column(String(100), nullable=False)

# Использование
power_line = PowerLine(name="ЛЭП-1")
db.add(power_line)
await db.commit()
```

**Миграции (Alembic):**
- Версионирование схемы БД
- Автоматическое создание SQL из изменений моделей
- Откат изменений

---

## Работа с базой данных

### SQLAlchemy ORM (Object-Relational Mapping)

**Концепция:** Отображение Python классов на таблицы БД

**Пример:**
```python
# Модель (app/models/power_line.py)
class PowerLine(Base):
    __tablename__ = "power_lines"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    voltage_level = Column(Float, nullable=True)
    
    # Связь один-ко-многим
    poles = relationship("Pole", back_populates="power_line")

# Использование
power_line = PowerLine(name="ЛЭП-1", voltage_level=110.0)
db.add(power_line)
await db.commit()
```

**Типы операций:**

**1. CREATE (Создание):**
```python
new_pole = Pole(
    pole_number="ОП-1",
    latitude=53.9,
    longitude=27.5,
    power_line_id=1
)
db.add(new_pole)
await db.commit()
```

**2. READ (Чтение):**
```python
# Получить все
result = await db.execute(select(Pole))
poles = result.scalars().all()

# Получить один
pole = await db.get(Pole, pole_id)

# С условием
result = await db.execute(
    select(Pole).where(Pole.power_line_id == power_line_id)
)
```

**3. UPDATE (Обновление):**
```python
pole = await db.get(Pole, pole_id)
pole.pole_number = "ОП-2"
await db.commit()
```

**4. DELETE (Удаление):**
```python
from sqlalchemy import delete
stmt = delete(Pole).where(Pole.id == pole_id)
await db.execute(stmt)
await db.commit()
```

**Eager Loading (Жадная загрузка):**
```python
# Проблема: N+1 запросов
for pole in poles:
    print(pole.power_line.name)  # Каждый раз запрос к БД

# Решение: selectinload
result = await db.execute(
    select(Pole).options(selectinload(Pole.power_line))
)
poles = result.scalars().all()
# Теперь power_line уже загружен
```

### Миграции (Alembic)

**Что это:** Версионирование схемы БД

**Создание миграции:**
```bash
cd backend
alembic revision --autogenerate -m "add_new_column"
```

**Структура миграции:**
```python
# alembic/versions/20241216_000000_add_column.py
def upgrade():
    op.add_column('power_lines', 
        sa.Column('new_field', sa.String(50), nullable=True)
    )

def downgrade():
    op.drop_column('power_lines', 'new_field')
```

**Применение миграций:**
```bash
# Применить все миграции
alembic upgrade head

# Откатить последнюю
alembic downgrade -1

# Применить конкретную
alembic upgrade <revision>
```

**Важно:**
- Всегда проверяйте сгенерированный SQL перед применением
- Тестируйте downgrade
- Не редактируйте примененные миграции

### Pydantic схемы

**Что это:** Валидация и сериализация данных

**Схемы для API:**
```python
# schemas/power_line.py

# Входные данные (валидация)
class PowerLineCreate(BaseModel):
    name: str  # Обязательное поле
    voltage_level: Optional[float] = None  # Опциональное

# Выходные данные (сериализация)
class PowerLineResponse(BaseModel):
    id: int
    name: str
    created_at: datetime
    
    class Config:
        from_attributes = True  # Автоматическая конвертация из SQLAlchemy
```

**Использование:**
```python
@router.post("/power-lines", response_model=PowerLineResponse)
async def create_power_line(
    power_line_data: PowerLineCreate  # Автоматическая валидация
):
    # Если данные невалидны - автоматически 422 ошибка
    # power_line_data уже проверен и типизирован
    db_power_line = PowerLine(**power_line_data.dict())
    db.add(db_power_line)
    await db.commit()
    return db_power_line  # Автоматически сериализуется в JSON
```

---

## Внесение изменений

### 1. Добавление нового поля в модель

**Шаг 1: Изменить модель**
```python
# app/models/power_line.py
class PowerLine(Base):
    # ... существующие поля
    new_field = Column(String(50), nullable=True)  # Добавить новое поле
```

**Шаг 2: Создать миграцию**
```bash
cd backend
alembic revision --autogenerate -m "add_new_field_to_power_line"
```

**Шаг 3: Проверить миграцию**
```python
# alembic/versions/XXXXX_add_new_field.py
def upgrade():
    op.add_column('power_lines', 
        sa.Column('new_field', sa.String(50), nullable=True)
    )
```

**Шаг 4: Применить миграцию**
```bash
# Локально
alembic upgrade head

# В Docker
docker compose exec backend alembic upgrade head
```

**Шаг 5: Обновить схемы**
```python
# app/schemas/power_line.py
class PowerLineCreate(BaseModel):
    # ... существующие поля
    new_field: Optional[str] = None  # Добавить в схему

class PowerLineResponse(BaseModel):
    # ... существующие поля
    new_field: Optional[str] = None
```

**Шаг 6: Обновить API endpoint (если нужно)**
```python
# app/api/v1/power_lines.py
@router.post("/power-lines")
async def create_power_line(
    power_line_data: PowerLineCreate  # Автоматически включает new_field
):
    # Логика остается той же
```

**Шаг 7: Обновить frontend (если нужно)**
```typescript
// core/models/power-line.model.ts
export interface PowerLine {
  // ... существующие поля
  new_field?: string;  // Добавить в интерфейс
}
```

### 2. Добавление нового API endpoint

**Шаг 1: Создать endpoint**
```python
# app/api/v1/power_lines.py
@router.get("/{power_line_id}/statistics")
async def get_power_line_statistics(
    power_line_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    # Логика получения статистики
    return {"total_poles": 10, "total_spans": 9}
```

**Шаг 2: Добавить метод в API service**
```typescript
// web-frontend/src/app/core/services/api.service.ts
getPowerLineStatistics(powerLineId: number): Observable<any> {
  return this.http.get(`${this.apiUrl}/power-lines/${powerLineId}/statistics`);
}
```

**Шаг 3: Использовать в компоненте**
```typescript
// some.component.ts
this.apiService.getPowerLineStatistics(powerLineId).subscribe({
  next: (stats) => {
    console.log(stats);
  }
});
```

### 3. Изменение конфигурации

**Backend конфигурация:**
```python
# app/core/config.py
class Settings(BaseSettings):
    NEW_SETTING: str = "default_value"
    
    class Config:
        env_file = ".env"  # Читает из .env файла
```

**Создать/обновить .env:**
```bash
# backend/.env
NEW_SETTING=actual_value
```

**Nginx конфигурация:**
```nginx
# nginx/nginx.conf
# Изменить настройки
# Перезапустить: docker compose restart nginx
```

**Angular конфигурация:**
```json
// angular.json
{
  "budgets": [
    {
      "type": "initial",
      "maximumWarning": "2mb"  // Изменить бюджет
    }
  ]
}
```

### 4. Обновление зависимостей

**Python (Backend):**
```bash
# Изменить версию в requirements.txt
fastapi>=0.109.0  # Изменить на новую версию

# Установить
pip install -r requirements.txt --upgrade

# В Docker
docker compose exec backend pip install -r requirements.txt --upgrade
```

**NPM (Frontend):**
```bash
cd web-frontend

# Обновить версию в package.json
"@angular/core": "^17.0.0"  # Изменить версию

# Установить
npm install

# Обновить все до последних совместимых
npm update
```

---

## Анализ и решение проблем

### 1. Проблемы с подключением к БД

**Симптомы:**
- `Connection refused`
- `Timeout`
- `MissingGreenlet` ошибки

**Диагностика:**
```bash
# Проверить, запущен ли PostgreSQL
docker compose ps postgres

# Проверить логи
docker compose logs postgres

# Проверить подключение
docker compose exec backend python -c "
from app.database import engine
import asyncio
async def test():
    async with engine.begin() as conn:
        result = await conn.execute(text('SELECT 1'))
        print('OK')
asyncio.run(test())
"
```

**Решение:**
1. Проверить `DATABASE_URL` в `.env` или `config.py`
2. Убедиться, что PostgreSQL запущен
3. Проверить порт (5433 для Docker, 5432 для локального)
4. Проверить credentials (username, password)

### 2. MissingGreenlet ошибки

**Причина:** Доступ к lazy-loaded отношениям вне async контекста

**Пример ошибки:**
```python
# ❌ Неправильно
poles = await db.execute(select(Pole))
for pole in poles:
    print(pole.power_line.name)  # MissingGreenlet!

# ✅ Правильно
result = await db.execute(
    select(Pole).options(selectinload(Pole.power_line))
)
poles = result.scalars().all()
for pole in poles:
    print(pole.power_line.name)  # OK
```

**Решение:** Всегда использовать `selectinload` для связанных объектов

### 3. Ошибки компиляции TypeScript

**Симптомы:**
- `Property 'X' does not exist on type 'Y'`
- `Cannot find module`

**Диагностика:**
```bash
cd web-frontend

# Очистить кэш
rm -rf .angular node_modules/.cache

# Переустановить зависимости
rm -rf node_modules
npm install

# Пересобрать
npm run build
```

**Решение:**
1. Проверить импорты (правильные ли пути)
2. Обновить интерфейсы в `core/models/`
3. Перезапустить TypeScript Language Server в IDE
4. Проверить `tsconfig.json` настройки

### 4. CORS ошибки

**Симптомы:**
- `Access-Control-Allow-Origin` ошибки в браузере

**Решение:**
```python
# backend/app/main.py
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Для разработки
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

**Или в nginx:**
```nginx
add_header Access-Control-Allow-Origin *;
add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
```

### 5. Проблемы с миграциями

**Симптомы:**
- `Target database is not up to date`
- Конфликты миграций

**Решение:**
```bash
# Проверить текущую версию
alembic current

# Проверить историю
alembic history

# Применить все
alembic upgrade head

# Если нужно откатить
alembic downgrade -1
```

**Если миграция сломана:**
```sql
-- Вручную в БД
UPDATE alembic_version SET version_num = 'previous_revision';
```

### 6. Проблемы с Docker

**Симптомы:**
- Контейнеры не запускаются
- Порты заняты
- Volume ошибки

**Диагностика:**
```bash
# Проверить статус
docker compose ps

# Логи всех сервисов
docker compose logs

# Логи конкретного сервиса
docker compose logs backend

# Проверить порты
netstat -an | findstr :8000  # Windows
lsof -i :8000  # Linux/Mac
```

**Решение:**
```bash
# Пересобрать контейнеры
docker compose down
docker compose build --no-cache
docker compose up -d

# Очистить volumes (ОСТОРОЖНО: удалит данные)
docker compose down -v
```

---

## Логирование

### Backend логирование

**Настройка:**
```python
# app/main.py
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)
```

**Использование:**
```python
# app/api/v1/power_lines.py
import logging

logger = logging.getLogger(__name__)

@router.post("/power-lines")
async def create_power_line(...):
    logger.info(f"Creating power line: {power_line_data.name}")
    try:
        # Логика
        logger.info(f"Power line created with ID: {db_power_line.id}")
    except Exception as e:
        logger.error(f"Error creating power line: {e}", exc_info=True)
        raise
```

**Уровни логирования:**
- `DEBUG` - детальная информация для отладки
- `INFO` - общая информация о работе
- `WARNING` - предупреждения (не критично)
- `ERROR` - ошибки (требуют внимания)
- `CRITICAL` - критические ошибки

**Просмотр логов:**
```bash
# Docker
docker compose logs -f backend

# Локально
# Логи выводятся в консоль при запуске uvicorn
```

### Frontend логирование

**Console логи:**
```typescript
// В компонентах/сервисах
console.log('Info message');
console.warn('Warning message');
console.error('Error message', error);
```

**Структурированное логирование:**
```typescript
// core/services/api.service.ts
private logError(operation: string, error: any) {
  console.error(`[API] ${operation} failed:`, {
    message: error.message,
    status: error.status,
    url: error.url
  });
}
```

### Nginx логи

**Access log:**
```nginx
# nginx.conf
access_log /var/log/nginx/access.log main;
```

**Просмотр:**
```bash
docker compose exec nginx tail -f /var/log/nginx/access.log
```

**Формат:**
```
172.19.0.1 - - [04/Jan/2026:15:30:00 +0000] "GET /api/v1/power-lines HTTP/1.1" 200 1234
```

---

## Фундаментальные концепции

### ООП (Объектно-ориентированное программирование)

**Классы и объекты:**
```python
# Класс - шаблон
class PowerLine:
    def __init__(self, name: str):
        self.name = name  # Атрибут объекта
    
    def get_info(self) -> str:  # Метод
        return f"Power line: {self.name}"

# Объект - экземпляр класса
power_line = PowerLine("ЛЭП-1")
print(power_line.get_info())
```

**Наследование:**
```python
# Базовый класс
class Base:
    def common_method(self):
        return "common"

# Наследование
class PowerLine(Base):
    def specific_method(self):
        return "specific"
```

**Инкапсуляция:**
```python
class PowerLine:
    def __init__(self):
        self._internal = "private"  # Защищенный
        self.__very_private = "secret"  # Приватный
    
    def get_internal(self):  # Публичный метод
        return self._internal
```

### Dependency Injection (DI)

**Концепция:** Внедрение зависимостей вместо их создания внутри

**Без DI (плохо):**
```python
def create_power_line():
    db = create_db_connection()  # Создание внутри функции
    # Проблема: сложно тестировать, менять реализацию
```

**С DI (хорошо):**
```python
# FastAPI автоматически внедряет зависимости
@router.post("/power-lines")
async def create_power_line(
    db: AsyncSession = Depends(get_db)  # DI
):
    # db уже создан и передан
```

**Преимущества:**
- Легко тестировать (можно подменить mock)
- Гибкость (легко менять реализацию)
- Разделение ответственности

### Async/Await

**Концепция:** Асинхронное программирование

**Синхронный код (блокирующий):**
```python
def get_power_lines():
    result = db.execute(query)  # Блокирует выполнение
    return result
```

**Асинхронный код (неблокирующий):**
```python
async def get_power_lines():
    result = await db.execute(query)  # Не блокирует
    return result
```

**Зачем:**
- Обработка множества запросов одновременно
- Не блокирует выполнение других операций
- Эффективное использование ресурсов

### REST API

**Принципы:**
- **Stateless** - каждый запрос независим
- **Resource-based** - URL = ресурс
- **HTTP методы** - GET (читать), POST (создать), PUT (обновить), DELETE (удалить)

**Примеры:**
```
GET    /api/v1/power-lines        # Список всех ЛЭП
GET    /api/v1/power-lines/1      # Конкретная ЛЭП
POST   /api/v1/power-lines        # Создать ЛЭП
PUT    /api/v1/power-lines/1      # Обновить ЛЭП
DELETE /api/v1/power-lines/1      # Удалить ЛЭП
```

### TypeScript типы

**Интерфейсы:**
```typescript
// Определение структуры
interface PowerLine {
  id: number;
  name: string;
  voltage_level?: number;  // Опциональное поле
}

// Использование
const line: PowerLine = {
  id: 1,
  name: "ЛЭП-1"
};
```

**Типы:**
```typescript
type Status = "active" | "inactive" | "maintenance";

interface PowerLine {
  status: Status;  // Только эти значения
}
```

**Generic типы:**
```typescript
interface ApiResponse<T> {
  data: T;
  status: number;
}

const response: ApiResponse<PowerLine> = {
  data: { id: 1, name: "ЛЭП-1" },
  status: 200
};
```

### RxJS Observables

**Концепция:** Реактивное программирование

**Observable:**
```typescript
// Создание потока данных
this.apiService.getPowerLines().subscribe({
  next: (lines) => {
    console.log(lines);  // Выполнится когда данные придут
  },
  error: (error) => {
    console.error(error);
  },
  complete: () => {
    console.log("Done");
  }
});
```

**Операторы:**
```typescript
import { map, filter, catchError } from 'rxjs/operators';

this.apiService.getPowerLines().pipe(
  map(lines => lines.filter(l => l.status === "active")),
  catchError(error => {
    console.error(error);
    return of([]);  // Возвращаем пустой массив при ошибке
  })
).subscribe(lines => {
  console.log(lines);
});
```

---

## Практические примеры

### Пример 1: Добавление нового поля "description" в PowerLine

**1. Модель:**
```python
# app/models/power_line.py
class PowerLine(Base):
    # ... существующие поля
    description = Column(Text, nullable=True)  # Добавить
```

**2. Миграция:**
```bash
alembic revision --autogenerate -m "add_description_to_power_line"
```

**3. Схема:**
```python
# app/schemas/power_line.py
class PowerLineCreate(BaseModel):
    # ... существующие поля
    description: Optional[str] = None

class PowerLineResponse(BaseModel):
    # ... существующие поля
    description: Optional[str] = None
```

**4. Frontend модель:**
```typescript
// core/models/power-line.model.ts
export interface PowerLine {
  // ... существующие поля
  description?: string;
}
```

**5. Применить миграцию:**
```bash
docker compose exec backend alembic upgrade head
```

### Пример 2: Создание нового endpoint для статистики

**1. Backend endpoint:**
```python
# app/api/v1/power_lines.py
@router.get("/{power_line_id}/statistics")
async def get_statistics(
    power_line_id: int,
    db: AsyncSession = Depends(get_db)
):
    # Подсчет опор
    poles_count = await db.scalar(
        select(func.count(Pole.id))
        .where(Pole.power_line_id == power_line_id)
    )
    
    # Подсчет пролётов
    spans_count = await db.scalar(
        select(func.count(Span.id))
        .where(Span.power_line_id == power_line_id)
    )
    
    return {
        "power_line_id": power_line_id,
        "poles_count": poles_count,
        "spans_count": spans_count
    }
```

**2. API Service:**
```typescript
// core/services/api.service.ts
getPowerLineStatistics(powerLineId: number): Observable<any> {
  return this.http.get(
    `${this.apiUrl}/power-lines/${powerLineId}/statistics`
  );
}
```

**3. Использование:**
```typescript
// some.component.ts
this.apiService.getPowerLineStatistics(powerLineId).subscribe({
  next: (stats) => {
    console.log(`Опор: ${stats.poles_count}, Пролётов: ${stats.spans_count}`);
  }
});
```

---

## Чеклист для разработчика

### Перед началом работы:
- [ ] Клонировать репозиторий
- [ ] Установить зависимости (npm install, pip install)
- [ ] Настроить .env файлы
- [ ] Запустить Docker контейнеры
- [ ] Применить миграции БД

### При внесении изменений:
- [ ] Изменить модель (если нужно)
- [ ] Создать миграцию
- [ ] Обновить схемы Pydantic
- [ ] Обновить TypeScript интерфейсы
- [ ] Обновить API endpoints
- [ ] Обновить frontend компоненты
- [ ] Протестировать изменения

### Перед коммитом:
- [ ] Проверить что код компилируется
- [ ] Запустить тесты (если есть)
- [ ] Проверить логи на ошибки
- [ ] Обновить документацию (если нужно)

---

## Полезные команды

### Docker
```bash
# Запуск
docker compose up -d

# Остановка
docker compose down

# Логи
docker compose logs -f backend

# Перезапуск
docker compose restart backend

# Войти в контейнер
docker compose exec backend bash
```

### Backend
```bash
# Миграции
alembic revision --autogenerate -m "message"
alembic upgrade head
alembic downgrade -1

# Запуск
uvicorn app.main:app --reload

# Тесты
pytest
```

### Frontend
```bash
# Установка
npm install

# Запуск dev server
npm start

# Сборка
npm run build

# Проверка типов
npx tsc --noEmit
```

---

## Заключение

Этот документ покрывает основные аспекты разработки в проекте. При возникновении вопросов:

1. Проверьте логи (`docker compose logs`)
2. Изучите код аналогичных функций
3. Проверьте документацию используемых библиотек
4. Используйте отладку (debugger, console.log)

Помните: код должен быть понятным, поддерживаемым и хорошо документированным.

