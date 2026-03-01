#!/bin/bash

# Скрипт автоматического деплоя приложения ЛЭП Management System
# Использование: ./deploy.sh

set -e  # Остановка при ошибке

echo "🚀 Начало деплоя ЛЭП Management System..."

# Проверка наличия .env файла
if [ ! -f ".env" ]; then
    echo "❌ Ошибка: файл .env не найден!"
    echo "Создайте .env файл на основе .env.production.example"
    exit 1
fi

# Проверка обязательных переменных
source .env
required_vars=("POSTGRES_DB" "POSTGRES_USER" "POSTGRES_PASSWORD" "DATABASE_URL" "SECRET_KEY")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ Ошибка: переменная $var не задана в .env"
        exit 1
    fi
done

# Проверка SECRET_KEY
if [ "$SECRET_KEY" = "CHANGE_ME_SECRET_KEY" ] || [ -z "$SECRET_KEY" ]; then
    echo "❌ Ошибка: SECRET_KEY не задан или имеет дефолтное значение!"
    echo "Сгенерируйте новый ключ: python3 -c \"import secrets; print(secrets.token_urlsafe(32))\""
    exit 1
fi

echo "✅ Проверка конфигурации пройдена"

# Остановка существующих контейнеров
echo "🛑 Остановка существующих контейнеров..."
docker compose -f docker-compose.prod.yml down || true

# Сборка образов
echo "🔨 Сборка Docker образов..."
docker compose -f docker-compose.prod.yml build --no-cache

# Запуск сервисов
echo "🚀 Запуск сервисов..."
docker compose -f docker-compose.prod.yml up -d

# Ожидание готовности БД
echo "⏳ Ожидание готовности базы данных..."
sleep 10

# Применение миграций (если используются) или схема создаётся при старте backend (create_all)
if docker compose -f docker-compose.prod.yml exec -T backend alembic upgrade head 2>/dev/null; then
    echo "📦 Миграции применены."
else
    echo "📦 Миграции не использовались. Схема БД создаётся при старте backend (create_all)."
    echo "   Чтобы пересоздать БД: docker compose -f docker-compose.prod.yml exec backend python recreate_db.py"
fi

# Проверка статуса
echo "📊 Проверка статуса сервисов..."
docker compose -f docker-compose.prod.yml ps

# Проверка health check
echo "❤️  Проверка health check..."
sleep 5
if curl -f http://localhost/health > /dev/null 2>&1; then
    echo "✅ Health check пройден"
else
    echo "⚠️  Health check не пройден, проверьте логи: docker compose -f docker-compose.prod.yml logs"
fi

echo ""
echo "✅ Деплой завершён!"
echo ""
echo "📝 Следующие шаги:"
echo "   1. Проверьте логи: docker compose -f docker-compose.prod.yml logs -f"
echo "   2. Откройте приложение: http://localhost (или https://your-domain.com)"
echo "   3. Создайте первого пользователя через API: POST /api/v1/auth/register"
echo "   4. Настройте SSL сертификаты (если используете домен)"
echo ""
