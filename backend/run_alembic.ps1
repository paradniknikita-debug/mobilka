# Запуск Alembic через Python из виртуального окружения
# Использование: .\run_alembic.ps1 upgrade head
# Или: .\run_alembic.ps1 current

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

$py = Join-Path $scriptDir ".venv\Scripts\python.exe"
if (-not (Test-Path $py)) {
    Write-Host "Виртуальное окружение не найдено. Создайте его: .\setup_venv.ps1" -ForegroundColor Red
    exit 1
}

& $py -m alembic @args
exit $LASTEXITCODE
