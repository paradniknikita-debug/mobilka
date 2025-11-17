# Инструкция по развертыванию

## Локальное развертывание

### Предварительные требования

1. **Python 3.8+**
2. **PostgreSQL 12+**
3. **Redis** (опционально)
4. **Flutter SDK 3.0+**

### Быстрая настройка

1. **Клонирование проекта**
```bash
git clone <repository-url>
cd mobilka
```

2. **Автоматическая настройка (Windows)**
```bash
setup_project.bat
```

3. **Ручная настройка**

#### Backend
```bash
cd backend
pip install -r requirements.txt
```

#### Frontend
```bash
cd frontend
flutter pub get
flutter packages pub run build_runner build
```

### Настройка базы данных

1. **Установка PostgreSQL**
   - Скачайте с официального сайта
   - Установите с настройками по умолчанию

2. **Создание базы данных**
```sql
CREATE DATABASE lepm_db;
CREATE USER lepm_user WITH PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE lepm_db TO lepm_user;
```

3. **Настройка переменных окружения**
```bash
cd backend
cp env_example.txt .env
```

Отредактируйте `.env`:
```env
DATABASE_URL=postgresql://lepm_user:your_password@localhost/lepm_db
SECRET_KEY=your-secret-key-change-in-production
REDIS_URL=redis://localhost:6379
```

4. **Инициализация базы данных**
```bash
cd backend
alembic upgrade head
```

### Запуск приложения

#### Вариант 1: Автоматический запуск
```bash
# Backend
start_backend.bat

# Frontend (в другом терминале)
start_frontend.bat
```

#### Вариант 2: Ручной запуск
```bash
# Backend
cd backend
python run.py

# Frontend
cd frontend
flutter run
```

## Docker развертывание

### Предварительные требования

1. **Docker**
2. **Docker Compose**

### Запуск с Docker

1. **Клонирование проекта**
```bash
git clone <repository-url>
cd mobilka
```

2. **Запуск всех сервисов**
```bash
docker-compose up -d
```

3. **Инициализация базы данных**
```bash
docker-compose exec backend alembic upgrade head
```

4. **Проверка статуса**
```bash
docker-compose ps
```

### Доступ к сервисам

- **Backend API**: http://localhost:8000
- **API Documentation**: http://localhost:8000/docs
- **PostgreSQL**: localhost:5432
- **Redis**: localhost:6379

## Production развертывание

### Рекомендации

1. **Используйте HTTPS**
2. **Настройте обратный прокси (nginx)**
3. **Используйте переменные окружения для секретов**
4. **Настройте мониторинг и логирование**
5. **Регулярно создавайте бэкапы базы данных**

### Nginx конфигурация

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Systemd сервис

```ini
[Unit]
Description=LEPM Backend API
After=network.target

[Service]
Type=simple
User=lepm
WorkingDirectory=/opt/lepm/backend
Environment=PATH=/opt/lepm/backend/venv/bin
ExecStart=/opt/lepm/backend/venv/bin/python run.py
Restart=always

[Install]
WantedBy=multi-user.target
```

## Мониторинг

### Health Check

```bash
curl http://localhost:8000/health
```

### Логи

```bash
# Docker
docker-compose logs -f backend

# Systemd
journalctl -u lepm-backend -f
```

### Метрики

- **API**: http://localhost:8000/metrics (если настроено)
- **База данных**: pg_stat_statements
- **Redis**: INFO command

## Бэкапы

### База данных

```bash
# Создание бэкапа
pg_dump -h localhost -U lepm_user lepm_db > backup_$(date +%Y%m%d_%H%M%S).sql

# Восстановление
psql -h localhost -U lepm_user lepm_db < backup_file.sql
```

### Автоматические бэкапы

```bash
#!/bin/bash
# backup.sh
DATE=$(date +%Y%m%d_%H%M%S)
pg_dump -h localhost -U lepm_user lepm_db | gzip > /backups/lepm_backup_$DATE.sql.gz
find /backups -name "lepm_backup_*.sql.gz" -mtime +7 -delete
```

## Устранение неполадок

### Частые проблемы

1. **Ошибка подключения к базе данных**
   - Проверьте статус PostgreSQL
   - Проверьте настройки в .env
   - Проверьте права пользователя

2. **Ошибки миграций**
   ```bash
   alembic current
   alembic heads
   alembic upgrade head
   ```

3. **Проблемы с Flutter**
   ```bash
   flutter clean
   flutter pub get
   flutter packages pub run build_runner build
   ```

4. **Проблемы с Docker**
   ```bash
   docker-compose down
   docker-compose up -d --build
   ```

### Логи для диагностики

```bash
# Backend логи
tail -f backend/logs/app.log

# PostgreSQL логи
tail -f /var/log/postgresql/postgresql-*.log

# Flutter логи
flutter logs
```

## Обновление

### Обновление кода

1. **Остановка сервисов**
```bash
docker-compose down
```

2. **Обновление кода**
```bash
git pull origin main
```

3. **Обновление зависимостей**
```bash
# Backend
cd backend
pip install -r requirements.txt

# Frontend
cd frontend
flutter pub get
flutter packages pub run build_runner build
```

4. **Миграции базы данных**
```bash
cd backend
alembic upgrade head
```

5. **Запуск сервисов**
```bash
docker-compose up -d
```

## Безопасность

### Рекомендации

1. **Измените пароли по умолчанию**
2. **Используйте сильные SECRET_KEY**
3. **Настройте файрвол**
4. **Регулярно обновляйте зависимости**
5. **Используйте HTTPS в production**

### Проверка безопасности

```bash
# Сканирование зависимостей
pip-audit

# Проверка Flutter зависимостей
flutter pub deps
```

## Поддержка

При возникновении проблем:

1. Проверьте логи
2. Убедитесь в корректности конфигурации
3. Проверьте статус всех сервисов
4. Обратитесь к документации
5. Создайте issue в репозитории
