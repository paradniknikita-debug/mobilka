@echo off
REM Скрипт для добавления тестовых данных через Docker
echo ========================================
echo Добавление тестовых данных
echo ========================================
echo.

echo [1/2] Проверка подключения к БД...
docker compose exec backend python -c "from app.database import AsyncSessionLocal; print('OK')" 2>nul
if %errorlevel% neq 0 (
    echo [ПРЕДУПРЕЖДЕНИЕ] Не удалось проверить подключение, но продолжаем...
)

echo.
echo [2/2] Добавление тестовых данных...
docker compose exec backend python seed_test_data.py
if %errorlevel% neq 0 (
    echo [ОШИБКА] Не удалось добавить тестовые данные
    pause
    exit /b 1
)

echo.
echo ========================================
echo [УСПЕХ] Тестовые данные добавлены!
echo ========================================
echo.
echo Данные для входа:
echo   Username: admin
echo   Password: admin123
echo.
pause

