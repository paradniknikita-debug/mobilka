import redis.asyncio as redis
from fastapi import FastAPI, Depends, HTTPException, status, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException
import uvicorn
from contextlib import asynccontextmanager
from pathlib import Path

from app.database import init_db
from app.api.v1 import auth, power_lines, poles, equipment, map_tiles, sync, substations, excel_import, cim_line_structure, pole_sequence, cim_export, patrol_sessions
# Временно закомментировано до применения миграции
# from app.api.v1 import base_voltage, wire_info
from app.core.config import settings
from app.core.redis_client import set_redis_client, get_redis_client

# Импортируем модели, чтобы они зарегистрировались в Base.metadata
# Это необходимо для создания таблиц через Base.metadata.create_all
from app.models import (
    User, PowerLine, Pole, Span, Tap, Equipment,
    Branch, Substation, Connection, GeographicRegion, AClineSegment,
    ConnectivityNode, Terminal, LineSection, PatrolSession
)

# Redis клиент будет инициализирован в lifespan
redis_client = None

# Инициализация токена безопасности
security = HTTPBearer()

@asynccontextmanager # lifespan - управление жизненным циклом приложения
async def lifespan(app: FastAPI):
    # Инициализация базы данных при запуске. Всё что внутри этой функции будет выполнено при запуске приложения.
    global redis_client
    
    # Инициализация Redis (опционально)
    try:
        redis_client = redis.from_url(settings.REDIS_URL, decode_responses=True, socket_connect_timeout=5)
        await redis_client.ping()
        set_redis_client(redis_client)
        print("OK: Redis подключен")
    except Exception as e:
        print(f"WARNING: Redis недоступен: {e}. Продолжаем без Redis.")
        redis_client = None
        set_redis_client(None)
    
    # Инициализация базы данных (обязательно)
    try:
        await init_db()
    except Exception as e:
        print(f"ERROR: Критическая ошибка: не удалось инициализировать базу данных.")
        print(f"Приложение не может быть запущено без подключения к БД.")
        raise
    
    # Создание директории для статических файлов
    Path("static").mkdir(exist_ok=True)
    
    yield
    
    # Закрытие соединений при остановке
    set_redis_client(None)
    if redis_client:
        try:
            await redis_client.close()
        except Exception:
            pass
# Создание FastAPI приложения. Далее можно добавить @app.get, @app.post, @app.put, @app.delete методы.
app = FastAPI(
    title="ЛЭП Management System",
    description="Система управления линиями электропередач",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
    redirect_slashes=False,  # Отключаем автоматический редирект со слэшами
)
# app.mount("/static", StaticFiles(directory="static"), name="static")
# Настройка CORS для Flutter приложения
# Определяем origins из настроек или переменных окружения
cors_origins = settings.ALLOWED_ORIGINS.copy()

# Если задана переменная CORS_ORIGINS, используем её
if settings.CORS_ORIGINS:
    cors_origins = [origin.strip() for origin in settings.CORS_ORIGINS.split(",") if origin.strip()]

# Для разработки добавляем localhost варианты
import os
if os.getenv("ENVIRONMENT", "development") == "development":
    dev_origins = [
        "http://localhost:53380",
        "https://localhost:53380",
        "http://127.0.0.1:53380",
        "https://127.0.0.1:53380",
        "http://localhost:4200",
        "https://localhost:4200",
        "http://127.0.0.1:4200",
        "https://127.0.0.1:4200",
        "http://localhost:8000",
        "https://localhost:8000",
    ]
    cors_origins.extend(dev_origins)
    cors_origins = list(set(cors_origins))  # Убираем дубликаты

# Проверка на пустой список (для продакшена обязательно указать домены)
if not cors_origins and os.getenv("ENVIRONMENT") == "production":
    raise ValueError("CORS_ORIGINS должен быть задан для продакшена! Установите переменную CORS_ORIGINS в .env")

app.add_middleware(
    CORSMiddleware, # Перехватывает все запросы и добавляет заголовки CORS
    allow_origins=cors_origins if cors_origins else ["*"],  # В продакшене НЕ использовать "*"
    allow_credentials=True, # разрешает cookies и jwt токены
    allow_methods=["*"], # Разрешает все методы get, post, put, delete
    allow_headers=["*"], # Разрешает все заголовки
    expose_headers=["*"], # Разрешаем доступ ко всем заголовкам ответа
    max_age=3600,  # Кэширование preflight запросов на 1 час
)


# Тестовый endpoint (определяем ДО роутеров)
@app.get("/api/v1/test", tags=["test"])
async def test_endpoint(message: str = "Hello from backend!"):
    """Тестовый endpoint для проверки взаимодействия фронт-бэк"""
    import datetime
    from zoneinfo import ZoneInfo
    
    # Используем часовой пояс Минска (Europe/Minsk)
    minsk_tz = ZoneInfo("Europe/Minsk")
    now_minsk = datetime.datetime.now(minsk_tz)
    
    return {
        "message": message,
        "timestamp": now_minsk.isoformat(),
        "backend_status": "✅ Backend работает!",
        "request_received": True,
        "data": {
            "api_version": "v1",
            "server_time": now_minsk.strftime("%Y-%m-%d %H:%M:%S"),
            "timezone": "Europe/Minsk"
        }
    }

# Подключение роутеров Роутер (APIRouter) — это объект FastAPI,
# в котором сгруппированы связанные эндпоинты. Например, все маршруты
# для аутентификации (/login, /register, /refresh) можно держать в одном auth.router.
app.include_router(auth.router, prefix="/api/v1/auth", tags=["authentication"])
app.include_router(power_lines.router, prefix="/api/v1/power-lines", tags=["power-lines"])
app.include_router(poles.router, prefix="/api/v1/poles", tags=["poles"])
app.include_router(equipment.router, prefix="/api/v1/equipment", tags=["equipment"])
app.include_router(map_tiles.router, prefix="/api/v1/map", tags=["map"])
app.include_router(sync.router, prefix="/api/v1/sync", tags=["sync"])
app.include_router(substations.router, prefix="/api/v1/substations", tags=["substations"])
app.include_router(excel_import.router, tags=["import"])
app.include_router(cim_line_structure.router, prefix="/api/v1/cim", tags=["cim"])
app.include_router(pole_sequence.router, prefix="/api/v1", tags=["pole-sequence"])
app.include_router(cim_export.router, prefix="/api/v1/cim", tags=["cim-export"])
app.include_router(patrol_sessions.router, prefix="/api/v1/patrol-sessions", tags=["patrol-sessions"])
# Временно закомментировано до применения миграции
# app.include_router(base_voltage.router, prefix="/api/v1/base-voltages", tags=["base-voltages"])
# app.include_router(wire_info.router, prefix="/api/v1/wire-infos", tags=["wire-infos"])

# Обработчик исключений для обеспечения CORS заголовков даже при ошибках
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Глобальный обработчик исключений с CORS заголовками"""
    import traceback
    
    # Логируем ошибку
    print(f"ERROR: Необработанное исключение: {exc}")
    print(f"ERROR: Traceback:\n{traceback.format_exc()}")
    
    # Возвращаем ответ с CORS заголовками
    from fastapi.responses import JSONResponse
    return JSONResponse(
        status_code=500,
        content={
            "detail": f"Внутренняя ошибка сервера: {str(exc)}"
        },
        headers={
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "*",
            "Access-Control-Allow-Headers": "*",
            "Access-Control-Allow-Credentials": "true",
        }
    )

@app.get("/",response_class=HTMLResponse)
async def root():
    return """
        <!DOCTYPE html>
        <html>
        <head>
            <title>ЛЭП Management System</title>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                body { font-family: Arial, sans-serif; margin: 40px; }
                .container { max-width: 800px; margin: 0 auto; }
                .header { background: #f5f5f5; padding: 20px; border-radius: 5px; }
                .links { margin-top: 20px; }
                .link { display: block; margin: 10px 0; padding: 10px; background: #007bff; color: white; text-decoration: none; border-radius: 3px; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>ЛЭП Management System API</h1>
                    <p>Версия 1.0.0</p>
                    <p>Система управления линиями электропередач для инженеров и диспетчеров</p>
                </div>
                <div class="links">
                    <a href="/docs" class="link">📚 Документация API (Swagger)</a>
                    <a href="/redoc" class="link">📖 Документация API (ReDoc)</a>
                    <a href="/health" class="link">❤️ Проверка здоровья системы</a>
                    <a href="/status" class="link">📊 Статус системы</a>
                </div>
            </div>
        </body>
        </html>
        """


@app.get("/status", response_class=HTMLResponse)
async def status_page():
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Статус системы - ЛЭП Management</title>
        <meta charset="utf-8">
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            .status-card { padding: 20px; margin: 10px 0; border-radius: 5px; }
            .healthy { background: #d4edda; border: 1px solid #c3e6cb; }
            .warning { background: #fff3cd; border: 1px solid #ffeaa7; }
        </style>
    </head>
    <body>
        <h1>Статус системы ЛЭП Management</h1>

        <div class="status-card healthy">
            <h3>✅ API Сервер</h3>
            <p>Статус: Работает нормально</p>
            <p>Версия: 1.0.0</p>
        </div>

        <div class="status-card healthy">
            <h3>🗄️ База данных</h3>
            <p>Статус: Подключено</p>
            <p>Тип: PostgreSQL</p>
        </div>

        <div class="status-card healthy">
            <h3>🔐 Аутентификация</h3>
            <p>Статус: Активна</p>
            <p>Метод: JWT токены</p>
        </div>

        <div class="status-card warning">
            <h3>📱 Мобильное приложение</h3>
            <p>Статус: В разработке</p>
            <p>Платформа: Flutter</p>
        </div>

        <p><a href="/">← На главную</a></p>
    </body>
    </html>
    """

@app.get("/cache")
async def cache_example():
    """Демо: запись/чтение из Redis (для проверки подключения)."""
    client = get_redis_client()
    if not client:
        return {"error": "Redis недоступен"}
    await client.set("hello", "world")
    value = await client.get("hello")
    return {"cached_value": value}


@app.get("/health")
async def health_check():
    """Базовый health: статус приложения и Redis."""
    redis_ok = False
    if get_redis_client():
        try:
            await get_redis_client().ping()
            redis_ok = True
        except Exception:
            pass
    return {
        "status": "healthy",
        "redis": "connected" if redis_ok else "disconnected",
    }

if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )
