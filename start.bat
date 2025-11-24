@echo off
chcp 65001 >nul
echo ========================================
echo Запуск проекта ЛЭП Management
echo ========================================
echo.

echo Проверка статуса контейнеров...
docker compose ps
echo.

echo Запуск всех сервисов...
docker compose up -d
if %errorlevel% neq 0 (
    echo ❌ Ошибка при запуске!
    echo Попробуй: docker compose up -d --build
    pause
    exit /b 1
)
echo.

echo ✅ Сервисы запущены!
echo.
echo Доступные URL:
echo   - Backend API: https://localhost/api/v1/test
echo   - Swagger: https://localhost/docs
echo.
echo Для просмотра логов: docker compose logs -f
echo Для остановки: docker compose down
echo.

pause

