# Инструкция по применению изменений в Docker

## Быстрый способ (для разработки)

Если вы внесли изменения в код и хотите применить их в Docker:

### 1. Пересборка образа backend
```bash
cd d:\Diplom\mobilka
docker-compose build backend
```

### 2. Перезапуск контейнера backend
```bash
docker-compose up -d backend
```

### 3. Проверка логов
```bash
docker-compose logs -f backend
```

---

## Полная последовательность действий

### Шаг 1: Остановка контейнеров (опционально)
Если нужно полностью перезапустить все сервисы:
```bash
cd d:\Diplom\mobilka
docker-compose down
```

### Шаг 2: Пересборка образа backend
Пересобирает Docker образ с новым кодом:
```bash
docker-compose build backend
```

**Примечание:** Если вы хотите пересобрать без использования кэша (для полной пересборки):
```bash
docker-compose build --no-cache backend
```

### Шаг 3: Запуск/перезапуск контейнеров
```bash
# Если контейнеры остановлены
docker-compose up -d

# Если контейнеры уже запущены, просто перезапустите backend
docker-compose up -d backend
```

### Шаг 4: Проверка статуса
```bash
docker-compose ps
```

### Шаг 5: Проверка логов
```bash
# Просмотр последних 50 строк логов
docker-compose logs --tail=50 backend

# Просмотр логов в реальном времени
docker-compose logs -f backend
```

---

## Для разных типов изменений

### Изменения в backend коде (Python)
```bash
cd d:\Diplom\mobilka
docker-compose build backend
docker-compose up -d backend
docker-compose logs -f backend
```

### Изменения в frontend коде (Angular)
Frontend обычно запускается отдельно (не в Docker), но если он в Docker:
```bash
cd d:\Diplom\mobilka
docker-compose build frontend  # если есть сервис frontend
docker-compose up -d frontend
```

### Изменения в docker-compose.yml или Dockerfile
```bash
cd d:\Diplom\mobilka
docker-compose down
docker-compose build
docker-compose up -d
```

### Изменения в зависимостях (requirements.txt)
```bash
cd d:\Diplom\mobilka
docker-compose build --no-cache backend
docker-compose up -d backend
```

---

## Полезные команды

### Просмотр всех контейнеров
```bash
docker-compose ps
```

### Остановка всех контейнеров
```bash
docker-compose down
```

### Запуск всех контейнеров
```bash
docker-compose up -d
```

### Перезапуск конкретного сервиса
```bash
docker-compose restart backend
docker-compose restart postgres
docker-compose restart nginx
```

### Просмотр логов конкретного сервиса
```bash
docker-compose logs backend
docker-compose logs postgres
docker-compose logs nginx
```

### Вход в контейнер (для отладки)
```bash
docker-compose exec backend bash
# или
docker exec -it lepm_backend bash
```

### Очистка неиспользуемых образов и контейнеров
```bash
docker system prune -a
```

**Внимание:** Эта команда удалит все неиспользуемые образы, контейнеры и сети!

---

## Автоматическое применение изменений (для разработки)

В `docker-compose.yml` уже настроен volume для монтирования кода:
```yaml
volumes:
  - ./backend/app:/app/app:ro
```

Однако, из-за кэширования Python модулей, изменения могут не применяться сразу. Поэтому рекомендуется пересобирать образ при изменениях в коде.

---

## Решение проблем

### Проблема: Изменения не применяются
**Решение:**
1. Убедитесь, что пересобрали образ: `docker-compose build backend`
2. Перезапустите контейнер: `docker-compose up -d backend`
3. Проверьте логи на ошибки: `docker-compose logs backend`

### Проблема: Контейнер не запускается
**Решение:**
1. Проверьте логи: `docker-compose logs backend`
2. Проверьте статус: `docker-compose ps`
3. Попробуйте пересобрать без кэша: `docker-compose build --no-cache backend`

### Проблема: Порт уже занят
**Решение:**
1. Найдите процесс, использующий порт: `netstat -ano | findstr :8000`
2. Остановите контейнер: `docker-compose down`
3. Запустите заново: `docker-compose up -d`

---

## Рекомендуемый workflow

1. **Внесли изменения в код**
2. **Пересоберите образ:** `docker-compose build backend`
3. **Перезапустите контейнер:** `docker-compose up -d backend`
4. **Проверьте логи:** `docker-compose logs -f backend`
5. **Протестируйте изменения**

---

## Примечания

- Все команды выполняются из корневой директории проекта (`d:\Diplom\mobilka`)
- Убедитесь, что Docker Desktop запущен
- Для продакшена рекомендуется использовать CI/CD для автоматической сборки и деплоя
