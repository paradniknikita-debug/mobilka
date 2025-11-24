import redis.asyncio as redis
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.security import HTTPBearer
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, JSONResponse
import uvicorn
from contextlib import asynccontextmanager
import os
from pathlib import Path

from app.database import init_db
from app.api.v1 import auth, power_lines, poles, equipment, map_tiles, sync, substations, excel_import
from app.core.config import settings

redis_client = redis.from_url("redis://localhost:6379", decode_responses=True)

# Инициализация токена безопасности
security = HTTPBearer()

@asynccontextmanager # lifespan - управление жизненным циклом приложения
async def lifespan(app: FastAPI):
    # Инициализация базы данных при запуске. Всё что внутри этой функции будет выполнено при запуске приложения.
    await init_db()
    Path("static").mkdir(exist_ok=True)
    yield
# Создание FastAPI приложения. Далее можно добавить @app.get, @app.post, @app.put, @app.delete методы.
app = FastAPI(
    title="ЛЭП Management System",
    description="Система управления линиями электропередач",
    version="1.0.0",
    lifespan=lifespan,
)
# app.mount("/static", StaticFiles(directory="static"), name="static")
# Настройка CORS для Flutter приложения
app.add_middleware(
    CORSMiddleware, # Перехватывает все запросы и добавляет заголовки CORS
    allow_origins=["*"],  # В продакшене указать конкретные домены
    allow_credentials=True, # разрешает cookies и jwt токены
    allow_methods=["*"], # Разрешает все методы get, post, put, delete
    allow_headers=["*"], # Разрешает все заголовки
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
                    <a href="/api/docs" class="link">📚 Документация API (Swagger)</a>
                    <a href="/api/redoc" class="link">📖 Документация API (ReDoc)</a>
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
    await redis_client.set("hello", "world")
    value = await redis_client.get("hello")
    return {"cached_value": value}

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )
