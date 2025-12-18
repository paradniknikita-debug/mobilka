# Промпт для генерации изображения архитектуры системы

## Описание для нейросетей генерации изображений

### Основной промпт (на русском)

```
Создай профессиональную диаграмму архитектуры веб-приложения для управления линиями электропередач.

В центре диаграммы размести прямоугольник с надписью "Nginx Reverse Proxy" (зеленый цвет).

Слева от Nginx размести два блока:
1. Верхний блок: "Web Frontend (Angular)" - синий цвет, содержит иконки браузера и карты
2. Нижний блок: "Mobile Frontend (Flutter)" - фиолетовый цвет, содержит иконку мобильного телефона

Справа от Nginx размести блок "FastAPI Backend" (бирюзовый цвет), который содержит три подблока:
- "Auth Module" (JWT токены)
- "Map Module" (GeoJSON)
- "Sync Module" (синхронизация)

Ниже Backend размести два блока базы данных:
1. "PostgreSQL" (синий цвет) - основная база данных с иконкой базы данных
2. "Redis" (красный цвет) - кэш, меньший размер, опциональный

Соедини все блоки стрелками:
- Web Frontend → Nginx (HTTPS, синяя стрелка)
- Mobile Frontend → Nginx (HTTPS, синяя стрелка)
- Nginx → FastAPI Backend (прокси, зеленая стрелка)
- FastAPI Backend → PostgreSQL (SQL запросы, оранжевая стрелка)
- FastAPI Backend → Redis (кэш, пунктирная красная стрелка)

Добавь подписи к стрелкам: "HTTPS", "Proxy", "SQL", "Cache".

Стиль: современный, минималистичный, профессиональный. Используй градиенты и тени для объемности.
```

### Альтернативный промпт (на английском)

```
Create a professional system architecture diagram for a power line management web application.

Layout:
- Left side: Two client applications (Web Frontend Angular, Mobile Frontend Flutter)
- Center: Nginx reverse proxy server
- Right side: FastAPI backend with modules (Auth, Map, Sync)
- Bottom: Two databases (PostgreSQL main database, Redis cache)

Color scheme:
- Web Frontend: Blue (#42b883)
- Mobile Frontend: Purple (#42b883)
- Nginx: Green (#009639)
- Backend: Teal (#009688)
- PostgreSQL: Dark Blue (#336791)
- Redis: Red (#dc382d)

Connections:
- Clients → Nginx (HTTPS, blue arrows)
- Nginx → Backend (proxy, green arrow)
- Backend → PostgreSQL (SQL, orange arrow)
- Backend → Redis (cache, dashed red arrow)

Style: Modern, clean, professional, with gradients and shadows. Include icons for each component.
```

### Детализированный промпт для сложной диаграммы

```
Создай детальную архитектурную диаграмму системы управления ЛЭП в стиле AWS Architecture Diagram.

Структура:

1. КЛИЕНТСКИЙ СЛОЙ (слева):
   - Web Browser (Chrome/Edge) с Angular приложением
   - Mobile Device (Android/iOS) с Flutter приложением
   - Оба подключены через HTTPS

2. СЛОЙ ПРОКСИ (центр-верх):
   - Nginx сервер с SSL/TLS сертификатом
   - Порт 443 (HTTPS)
   - Порт 80 (HTTP редирект)

3. СЛОЙ ПРИЛОЖЕНИЯ (центр):
   - FastAPI Backend в Docker контейнере
   - Модули: Auth (JWT), Map (GeoJSON), Sync (синхронизация)
   - REST API endpoints

4. СЛОЙ ДАННЫХ (справа):
   - PostgreSQL 15 с PostGIS расширением
   - Redis для кэширования
   - Docker volumes для персистентности

5. ИНФРАСТРУКТУРА (внизу):
   - Docker Compose оркестрация
   - Docker Network (lepm_network)
   - Health checks для всех сервисов

Визуальные элементы:
- Используй прямоугольники с закругленными углами
- Добавь иконки для каждого компонента
- Стрелки разных цветов для разных типов соединений
- Легенда внизу диаграммы
- Подписи портов и протоколов

Цветовая схема:
- Клиенты: светло-синий
- Прокси: зеленый
- Backend: бирюзовый
- Базы данных: темно-синий и красный
- Инфраструктура: серый

Стиль: Профессиональный, как в документации AWS или Microsoft Azure.
```

### Промпт для упрощенной блок-схемы

```
Простая блок-схема архитектуры приложения:

[Web Frontend] → [Nginx] → [FastAPI Backend] → [PostgreSQL]
[Mobile App] ↗              ↓
                            [Redis]

Стиль: Минималистичный, черно-белый, с подписями на русском языке.
Каждый блок - прямоугольник с закругленными углами.
Стрелки показывают направление потока данных.
```

## Рекомендации по использованию промптов

1. **Для простых диаграмм**: Используйте "Основной промпт" или "Упрощенную блок-схему"
2. **Для детальных диаграмм**: Используйте "Детализированный промпт"
3. **Для английских нейросетей**: Используйте "Альтернативный промпт на английском"

## Дополнительные элементы для добавления

Если нейросеть поддерживает, добавьте:
- Иконки компонентов (база данных, сервер, браузер, телефон)
- Легенду с объяснением цветов
- Подписи портов (443, 80, 8000, 5432, 6379)
- Протоколы (HTTPS, HTTP, SQL, Redis Protocol)
- Направление данных (Request/Response)
