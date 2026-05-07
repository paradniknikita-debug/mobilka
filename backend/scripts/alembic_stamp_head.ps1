# Принудительно отметить БД Alembic как обновлённую до головной ревизии 20260308_100000.
# Запуск: из каталога backend или из корня проекта (скрипт сам перейдёт в backend).
# Требуется: установленный alembic и настроенный alembic.ini / .env с DATABASE_URL.

$ErrorActionPreference = "Stop"
$backendDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path (Join-Path $backendDir "alembic.ini"))) {
    $backendDir = Join-Path (Split-Path -Parent $backendDir) "backend"
}
Set-Location $backendDir
& alembic stamp 20260308_100000
Write-Host "Alembic отмечен до ревизии 20260308_100000."
