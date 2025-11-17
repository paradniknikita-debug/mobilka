@echo off
REM Скрипт для применения миграции через Docker
echo ========================================
echo Применение миграции базы данных
echo ========================================
echo.

REM Проверка существования папки alembic
if not exist "backend\alembic" (
    echo [ОШИБКА] Папка backend\alembic не найдена!
    echo Убедись, что папка существует.
    pause
    exit /b 1
)

echo [1/4] Пересборка Docker образа backend...
docker compose build backend
if %errorlevel% neq 0 (
    echo [ОШИБКА] Не удалось пересобрать образ
    pause
    exit /b 1
)

echo.
echo [2/4] Запуск контейнеров...
docker compose up -d
if %errorlevel% neq 0 (
    echo [ОШИБКА] Не удалось запустить контейнеры
    pause
    exit /b 1
)

echo.
echo [3/4] Ожидание готовности PostgreSQL...
timeout /t 5 /nobreak >nul

echo.
echo [4/4] Применение миграции...
docker compose exec backend alembic upgrade head
if %errorlevel% neq 0 (
    echo [ОШИБКА] Не удалось применить миграцию
    echo.
    echo Проверь:
    echo 1. Что папка backend\alembic существует
    echo 2. Что файл backend\.env исправлен (SECRET_KEY в кавычках)
    echo 3. Что PostgreSQL контейнер запущен: docker compose ps
    pause
    exit /b 1
)

echo.
echo ========================================
echo [УСПЕХ] Миграция применена!
echo ========================================
echo.
echo Следующий шаг: добавь тестовые данные
echo   docker compose exec backend python seed_test_data.py
echo.
pause

