# Запуск Flutter Web для разработки.
#
# 1) Chrome — лучший hot reload / hot restart (рекомендуется вместо web-server).
#    Таймауты в Cursor часто из-за устройства web-server + прокси WebSocket.
#
# 2) Если нужен именно web-server (доступ с другой машины по сети):
#    .\run_web_dev.ps1 -WebServer

param(
  [switch]$WebServer
)

Set-Location $PSScriptRoot

if ($WebServer) {
  Write-Host "web-server: откройте http://127.0.0.1:4300 — при таймаутах hot reload в IDE используйте Chrome или флаги из .vscode/launch.json" -ForegroundColor Yellow
  flutter run -d web-server `
    --web-hostname 127.0.0.1 `
    --web-port 4300 `
    --no-web-experimental-hot-reload
} else {
  Write-Host "Chrome: hot reload стабильнее, чем у web-server" -ForegroundColor Green
  flutter run -d chrome --web-port 4300
}
