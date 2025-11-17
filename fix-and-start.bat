@echo off
echo ====================================
echo Исправление проблем и запуск
echo ====================================

REM Проверка SSL сертификатов
if not exist "nginx\ssl\cert.pem" (
    echo [1/3] Генерация SSL сертификатов...
    if not exist "nginx\ssl" mkdir "nginx\ssl"
    call nginx\generate-ssl.bat
    if errorlevel 1 (
        echo ОШИБКА: OpenSSL не найден. Установите OpenSSL для Windows.
        pause
        exit /b 1
    )
) else (
    echo [1/3] SSL сертификаты уже есть
)

REM Проверка backend/.env
if not exist "backend\.env" (
    echo [2/3] Создание backend\.env...
    copy backend\env_example.txt backend\.env >nul
    echo Создан backend\.env (отредактируйте при необходимости)
) else (
    echo [2/3] backend\.env существует
)

echo [3/3] Перезапуск контейнеров...
docker compose down
docker compose up -d --build

echo.
echo ====================================
echo Готово! Проверьте статус:
echo   docker compose ps
echo.
echo Проверьте логи если что-то не работает:
echo   docker compose logs backend
echo   docker compose logs nginx
echo ====================================
pause

