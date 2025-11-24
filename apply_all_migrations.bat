@echo off
chcp 65001 >nul
echo ========================================
echo Применение всех миграций БД
echo ========================================
echo.

echo [1/3] Проверка статуса контейнеров...
docker compose ps
echo.

echo [2/3] Ожидание запуска backend (10 секунд)...
timeout /t 10 /nobreak >nul
echo.

echo [3/3] Применение миграций...
docker compose exec backend alembic upgrade head
if %errorlevel% neq 0 (
    echo.
    echo ❌ Ошибка при применении миграций!
    echo Попробуй перезапустить контейнеры: docker compose restart backend
    pause
    exit /b 1
)
echo.

echo ========================================
echo ✅ Миграции применены!
echo ========================================
echo.

echo Проверка таблиц в БД...
docker compose exec postgres psql -U postgres -d lepm_db -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('poles', 'towers', 'geographic_regions', 'acline_segments', 'line_segments', 'substations', 'power_lines') ORDER BY table_name;"
echo.

echo Текущая версия миграции:
docker compose exec backend alembic current
echo.

pause

