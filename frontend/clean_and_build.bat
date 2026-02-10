@echo off
REM Используйте при ошибках: Invalid depfile, Kotlin "different roots", Daemon compilation failed
echo Cleaning Flutter and Gradle caches...
cd /d "%~dp0"
call flutter clean
call flutter pub get
echo.
echo Clean done. Run: flutter run   or   flutter build apk
pause
