# Script to create virtual environment from scratch
# Run: .\setup_venv.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Creating virtual environment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Remove old virtual environment
Write-Host "1. Removing old virtual environment..." -ForegroundColor Yellow
if (Test-Path .venv) {
    Remove-Item -Recurse -Force .venv
    Write-Host "   Old environment removed" -ForegroundColor Green
} else {
    Write-Host "   Old environment not found" -ForegroundColor Green
}

# 2. Check Python
Write-Host ""
Write-Host "2. Checking Python..." -ForegroundColor Yellow
$pythonCmd = $null
$pythonPaths = @("python", "python3", "py")

foreach ($cmd in $pythonPaths) {
    try {
        $version = & $cmd --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            $pythonCmd = $cmd
            Write-Host "   Python found: $version (using: $cmd)" -ForegroundColor Green
            break
        }
    } catch {
        continue
    }
}

if (-not $pythonCmd) {
    Write-Host "   Python not found! Install Python 3.9+ and add to PATH" -ForegroundColor Red
    Write-Host "   Or use: py -3 -m venv .venv" -ForegroundColor Yellow
    exit 1
}

# 3. Create new virtual environment
Write-Host ""
Write-Host "3. Creating new virtual environment..." -ForegroundColor Yellow
& $pythonCmd -m venv .venv
if ($LASTEXITCODE -eq 0) {
    Write-Host "   Virtual environment created" -ForegroundColor Green
} else {
    Write-Host "   Error creating virtual environment" -ForegroundColor Red
    Write-Host "   Trying alternative method..." -ForegroundColor Yellow
    # Try with py launcher
    py -3 -m venv .venv
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   Virtual environment created with py launcher" -ForegroundColor Green
    } else {
        Write-Host "   Failed to create virtual environment" -ForegroundColor Red
        Write-Host "   Please check Python installation" -ForegroundColor Red
        exit 1
    }
}

# 4. Wait for environment to be created
Write-Host ""
Write-Host "4. Waiting for creation to complete..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

# 5. Check Python from venv
Write-Host ""
Write-Host "5. Checking Python from virtual environment..." -ForegroundColor Yellow
if (Test-Path .\.venv\Scripts\python.exe) {
    $venvPythonVersion = .\.venv\Scripts\python.exe --version 2>&1
    Write-Host "   Python from venv works: $venvPythonVersion" -ForegroundColor Green
} else {
    Write-Host "   Python from venv not found!" -ForegroundColor Red
    exit 1
}

# 6. Upgrade pip
Write-Host ""
Write-Host "6. Upgrading pip..." -ForegroundColor Yellow
.\.venv\Scripts\python.exe -m pip install --upgrade pip --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "   pip upgraded" -ForegroundColor Green
} else {
    Write-Host "   Error upgrading pip" -ForegroundColor Red
    exit 1
}

# 7. Install dependencies
Write-Host ""
Write-Host "7. Installing dependencies from requirements.txt..." -ForegroundColor Yellow
Write-Host "   This may take several minutes..." -ForegroundColor Gray
Write-Host "   Using only pre-built wheels (no compilation)..." -ForegroundColor Gray
.\.venv\Scripts\python.exe -m pip install --only-binary :all: -r requirements.txt
if ($LASTEXITCODE -ne 0) {
    Write-Host "   Retrying without --only-binary flag..." -ForegroundColor Yellow
    .\.venv\Scripts\python.exe -m pip install --upgrade pip setuptools wheel
    .\.venv\Scripts\python.exe -m pip install -r requirements.txt
}
if ($LASTEXITCODE -eq 0) {
    Write-Host "   All dependencies installed" -ForegroundColor Green
} else {
    Write-Host "   Error installing dependencies" -ForegroundColor Red
    exit 1
}

# 8. Check pandas installation
Write-Host ""
Write-Host "8. Checking pandas installation..." -ForegroundColor Yellow
$pandasCheck = .\.venv\Scripts\python.exe -m pip list | Select-String "pandas"
if ($pandasCheck) {
    Write-Host "   pandas installed" -ForegroundColor Green
} else {
    Write-Host "   pandas not found, try installing manually" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Virtual environment ready!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "To activate run:" -ForegroundColor Yellow
Write-Host "  .\.venv\Scripts\Activate.ps1" -ForegroundColor White
Write-Host ""
Write-Host "Or use Python directly:" -ForegroundColor Yellow
Write-Host "  .\.venv\Scripts\python.exe run.py" -ForegroundColor White
Write-Host ""
