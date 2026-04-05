#!/bin/bash
# Пересоздание БД на сервере: удаление всех таблиц и создание по текущим моделям.
# Запуск на сервере из корня проекта: ./scripts/server_recreate_db.sh
# Требуется: сервисы подняты (docker compose -f docker-compose.prod.yml up -d).

set -e

COMPOSE_FILE="${1:-docker-compose.prod.yml}"

echo "Пересоздание БД (все таблицы будут удалены, данные потеряются)..."
docker compose -f "$COMPOSE_FILE" exec -T backend python recreate_db.py
echo "Готово. Схема БД приведена к текущему состоянию моделей."
echo "Пользователей нет — создайте первого через API: POST /api/v1/auth/register"
