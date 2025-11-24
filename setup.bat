@echo off
chcp 65001 >nul
echo ========================================
echo Настройка проекта ЛЭП Management
echo ========================================
echo.

echo [1/5] Проверка Docker...
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Docker не установлен!
    echo Скачай Docker Desktop: https://www.docker.com/products/docker-desktop
    pause
    exit /b 1
)
echo ✅ Docker установлен
echo.

echo [2/5] Проверка Docker Compose...
docker compose version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Docker Compose не найден!
    pause
    exit /b 1
)
echo ✅ Docker Compose установлен
echo.

echo [3/5] Создание .env файла...
if not exist "backend\.env" (
    if exist "backend\env_example.txt" (
        copy "backend\env_example.txt" "backend\.env" >nul
        echo ✅ Файл backend\.env создан из примера
    ) else (
        echo ⚠️  Файл backend\env_example.txt не найден
    )
) else (
    echo ✅ Файл backend\.env уже существует
)
echo.

echo [4/5] Генерация SSL сертификатов...
if not exist "nginx\ssl\cert.pem" (
    if exist "nginx\generate-ssl.bat" (
        call nginx\generate-ssl.bat
        echo ✅ SSL сертификаты созданы
    ) else (
        echo ⚠️  Скрипт генерации SSL не найден
    )
) else (
    echo ✅ SSL сертификаты уже существуют
)
echo.

echo [5/5] Сборка и запуск контейнеров...
docker compose up -d --build
if %errorlevel% neq 0 (
    echo ❌ Ошибка при запуске контейнеров!
    pause
    exit /b 1
)
echo.

echo ========================================
echo ✅ Настройка завершена!
echo ========================================
echo.
echo Ожидание запуска сервисов (30 секунд)...
timeout /t 30 /nobreak >nul
echo.

echo Применение миграций БД...
docker compose exec -T backend alembic upgrade head
echo.

echo ========================================
echo 🎉 Проект готов к работе!
echo ========================================
echo.
echo Доступные URL:
echo   - Backend API: https://localhost/api/v1/test
echo   - Swagger: https://localhost/docs
echo   - Health: https://localhost/health
echo.
echo ⚠️  Браузер покажет предупреждение о сертификате
echo    Нажми "Advanced" → "Proceed to localhost"
echo.
echo Для остановки: docker compose down
echo.

pause

