# Настройка подключения к API

## Переключение между HTTP и HTTPS

Для переключения между HTTP и HTTPS подключением измените переменную в файле `lib/core/config/app_config.dart`:

```dart
// true = HTTPS, false = HTTP
static const bool useHttps = false; // Для разработки используем HTTP
```

### HTTP (для разработки)
```dart
static const bool useHttps = false;
```
- Используется для локальной разработки
- Не требует SSL сертификата
- Подключение через `http://localhost`

### HTTPS (для продакшена)
```dart
static const bool useHttps = true;
```
- Используется для продакшена
- Требует валидный SSL сертификат
- Подключение через `https://localhost`

## Текущая конфигурация

- **Протокол**: HTTP (useHttps = false)
- **Базовый URL**: http://localhost
- **API Endpoint**: http://localhost/api/v1

## Примечания

- После изменения `useHttps` перезапустите приложение
- Убедитесь, что Nginx настроен правильно для выбранного протокола
- Для HTTPS убедитесь, что SSL сертификаты установлены в Nginx

