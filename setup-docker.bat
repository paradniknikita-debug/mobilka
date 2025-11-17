@echo off
REM Автоматическая настройка для запуска через Docker

echo ====================================
echo Настройка проекта для Docker
echo ====================================

REM Создание .env файла если его нет
if not exist "backend\.env" (
    echo Создание backend\.env из примера...
    copy backend\env_example.txt backend\.env
    echo.
    echo ВАЖНО: Отредактируйте backend\.env и задайте:
    echo   DATABASE_URL=postgresql://postgres:postgres@postgres:5432/lepm_db
    echo   REDIS_URL=redis://redis:6379
    echo   SECRET_KEY=ваш-секретный-ключ
    echo.
) else (
    echo backend\.env уже существует
)

REM Генерация SSL сертификатов если их нет
if not exist "nginx\ssl\cert.pem" (
    echo Генерация SSL сертификатов...
    call nginx\generate-ssl.bat
) else (
    echo SSL сертификаты уже существуют
)

echo.
echo ====================================
echo Готово! Теперь запустите:
echo   docker compose up -d --build
echo ====================================
pause


