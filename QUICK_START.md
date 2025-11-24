# 🚀 Быстрый старт

## Требования

- **Docker Desktop** (Windows/Mac) или **Docker + Docker Compose** (Linux)
- **Git**
- **Flutter SDK** (только для запуска frontend)

## ⚡ За 3 шага

### 1. Клонируй репозиторий
```bash
git clone https://github.com/paradniknikita-debug/mobilka.git
cd mobilka
```

### 2. Запусти автоматическую настройку

**Windows:**
```bash
setup.bat
```

**Mac/Linux:**
```bash
chmod +x setup.sh
./setup.sh
```

Этот скрипт:
- ✅ Проверит наличие Docker
- ✅ Создаст `.env` файл из примера
- ✅ Сгенерирует SSL сертификаты
- ✅ Запустит все сервисы через Docker

### 3. Запусти проект

**Windows:**
```bash
start.bat
```

**Mac/Linux:**
```bash
./start.sh
```

Или вручную:
```bash
docker compose up -d --build
```

## ✅ Проверка работы

После запуска проверь:

1. **Backend API**: https://localhost/api/v1/test
   - ⚠️ Браузер покажет предупреждение о self-signed сертификате — это нормально
   - Нажми "Advanced" → "Proceed to localhost"

2. **Swagger документация**: https://localhost/docs

3. **Frontend** (опционально):
   ```bash
   cd frontend
   flutter pub get
   flutter run -d chrome
   ```

## 📋 Что дальше?

- **Применить миграции БД**: `apply_migration_docker.bat` (Windows) или `docker compose exec backend alembic upgrade head`
- **Добавить тестовые данные**: `seed_data_docker.bat` (Windows) или `docker compose exec backend python seed_test_data.py`
- **Подключиться к БД**: См. `backend/DBEAVER_CONNECTION.md`

## 🛠️ Остановка

```bash
docker compose down
```

## ❓ Проблемы?

Смотри [README.md](README.md) для подробных инструкций и решения проблем.

