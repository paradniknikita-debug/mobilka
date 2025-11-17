@echo off
echo Настройка проекта ЛЭП Management System...

echo.
echo 1. Установка зависимостей backend...
cd backend
pip install -r requirements.txt
cd ..

echo.
echo 2. Установка зависимостей frontend...
cd frontend
flutter pub get
cd ..

echo.
echo 3. Генерация кода для Flutter...
cd frontend
flutter packages pub run build_runner build
cd ..

echo.
echo Настройка завершена!
echo.
echo Для запуска:
echo - Backend: start_backend.bat
echo - Frontend: start_frontend.bat
echo.
pause
