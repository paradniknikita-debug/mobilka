@echo off
echo ========================================
echo Применение исправленной миграции
echo ========================================
echo.

echo [1/3] Проверка текущей миграции...
docker compose exec backend alembic current
echo.
pause

echo [2/3] Откат миграции (если частично применена)...
docker compose exec backend alembic downgrade -1
echo.
pause

echo [3/3] Применение исправленной миграции...
docker compose exec backend alembic upgrade head
echo.

if %errorlevel% equ 0 (
    echo ========================================
    echo Миграция успешно применена!
    echo ========================================
    echo.
    echo Теперь добавь тестовые данные:
    echo   docker compose exec backend python seed_test_data.py
    echo.
) else (
    echo ========================================
    echo ОШИБКА при применении миграции!
    echo ========================================
    echo.
    echo Проверь логи выше для деталей.
    echo.
)

pause

