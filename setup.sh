#!/bin/bash

echo "========================================"
echo "Настройка проекта ЛЭП Management"
echo "========================================"
echo ""

echo "[1/5] Проверка Docker..."
if ! command -v docker &> /dev/null; then
    echo "❌ Docker не установлен!"
    echo "Установи Docker: https://www.docker.com/products/docker-desktop"
    exit 1
fi
echo "✅ Docker установлен"
echo ""

echo "[2/5] Проверка Docker Compose..."
if ! command -v docker compose &> /dev/null; then
    echo "❌ Docker Compose не найден!"
    exit 1
fi
echo "✅ Docker Compose установлен"
echo ""

echo "[3/5] Создание .env файла..."
if [ ! -f "backend/.env" ]; then
    if [ -f "backend/env_example.txt" ]; then
        cp "backend/env_example.txt" "backend/.env"
        echo "✅ Файл backend/.env создан из примера"
    else
        echo "⚠️  Файл backend/env_example.txt не найден"
    fi
else
    echo "✅ Файл backend/.env уже существует"
fi
echo ""

echo "[4/5] Генерация SSL сертификатов..."
if [ ! -f "nginx/ssl/cert.pem" ]; then
    if [ -f "nginx/generate-ssl.sh" ]; then
        chmod +x nginx/generate-ssl.sh
        ./nginx/generate-ssl.sh
        echo "✅ SSL сертификаты созданы"
    else
        echo "⚠️  Скрипт генерации SSL не найден"
    fi
else
    echo "✅ SSL сертификаты уже существуют"
fi
echo ""

echo "[5/5] Сборка и запуск контейнеров..."
docker compose up -d --build
if [ $? -ne 0 ]; then
    echo "❌ Ошибка при запуске контейнеров!"
    exit 1
fi
echo ""

echo "========================================"
echo "✅ Настройка завершена!"
echo "========================================"
echo ""
echo "Ожидание запуска сервисов (30 секунд)..."
sleep 30
echo ""

echo "Применение миграций БД..."
docker compose exec -T backend alembic upgrade head
echo ""

echo "========================================"
echo "🎉 Проект готов к работе!"
echo "========================================"
echo ""
echo "Доступные URL:"
echo "  - Backend API: https://localhost/api/v1/test"
echo "  - Swagger: https://localhost/docs"
echo "  - Health: https://localhost/health"
echo ""
echo "⚠️  Браузер покажет предупреждение о сертификате"
echo "   Нажми 'Advanced' → 'Proceed to localhost'"
echo ""
echo "Для остановки: docker compose down"
echo ""

