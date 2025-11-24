@echo off
chcp 65001 >nul
echo ========================================
echo Проверка подключения к Docker PostgreSQL
echo ========================================
echo.

echo [1/5] Проверка статуса контейнера PostgreSQL...
docker compose ps postgres
echo.

echo [2/5] Проверка доступности порта 5433...
netstat -an | findstr :5433
if %errorlevel% neq 0 (
    echo [ОШИБКА] Порт 5433 не слушается! Проверь docker-compose.yml
    pause
    exit /b 1
)
echo [OK] Порт 5433 доступен
echo.

echo [3/5] Проверка подключения к базе данных...
docker compose exec postgres psql -U postgres -d lepm_db -c "SELECT current_database(), current_user;"
echo.

echo [4/5] Список таблиц в Docker базе:
docker compose exec postgres psql -U postgres -d lepm_db -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name;"
echo.

echo [5/5] Проверка данных:
docker compose exec postgres psql -U postgres -d lepm_db -c "SELECT COUNT(*) as poles_count FROM poles; SELECT COUNT(*) as substations_count FROM substations; SELECT COUNT(*) as geographic_regions_count FROM geographic_regions;"
echo.

echo ========================================
echo Настройки для DBeaver:
echo ========================================
echo Host: localhost
echo Port: 5433
echo Database: lepm_db
echo Username: postgres
echo Password: dragon167
echo ========================================
echo.
echo ВАЖНО: Убедись, что в DBeaver используется порт 5433, а НЕ 5432!
echo Если у тебя есть старое подключение на порту 5432 - удали его и создай новое.
echo.
echo Подробная инструкция: backend\FIX_DBEAVER_INVALIDATED.md
echo.

pause
