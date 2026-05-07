#!/bin/bash

echo "========================================"
echo "Сборка APK для ЛЭП Management System"
echo "========================================"
echo ""

cd frontend

echo "Проверка Flutter окружения..."
flutter doctor
echo ""

echo "Очистка предыдущих сборок..."
flutter clean
echo ""

echo "Получение зависимостей..."
flutter pub get
echo ""

echo "Генерация кода..."
flutter pub run build_runner build --delete-conflicting-outputs
echo ""

echo "Сборка APK (release)..."
flutter build apk --release
echo ""

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================"
    echo "✓ Сборка успешно завершена!"
    echo "========================================"
    echo ""
    echo "APK файл находится в:"
    echo "  frontend/build/app/outputs/flutter-apk/app-release.apk"
    echo ""
    if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
        echo "Размер файла:"
        ls -lh build/app/outputs/flutter-apk/app-release.apk | awk '{print "  " $5}'
    fi
    echo ""
else
    echo ""
    echo "========================================"
    echo "✗ Ошибка при сборке APK"
    echo "========================================"
    echo ""
fi

cd ..

