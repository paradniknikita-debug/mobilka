@echo off
echo Генерация самоподписанного SSL сертификата для Nginx...

if not exist "ssl" mkdir ssl

REM Генерируем приватный ключ
openssl genrsa -out ssl/key.pem 2048

REM Генерируем самоподписанный сертификат (действителен 365 дней)
openssl req -new -x509 -key ssl/key.pem -out ssl/cert.pem -days 365 -subj "/C=RU/ST=State/L=City/O=Organization/CN=localhost"

echo.
echo ✓ SSL сертификаты созданы в папке nginx/ssl/
echo   - ssl/key.pem (приватный ключ)
echo   - ssl/cert.pem (сертификат)
echo.
echo ⚠ ВАЖНО: Это самоподписанный сертификат для разработки!
echo   При первом подключении браузер покажет предупреждение безопасности.
echo   Нужно принять сертификат ("Продолжить на сайт" / "Advanced" -^> "Proceed to localhost").
echo.
