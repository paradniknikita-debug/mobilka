import '../services/base_url_manager.dart';

class AppConfig {
  static const String appName = 'ЛЭП Management';
  static const String appVersion = '1.0.0';
  
  // ============================================
  // НАСТРОЙКА ПРОТОКОЛА ПОДКЛЮЧЕНИЯ
  // ============================================
  // Измените эту переменную для переключения между HTTP и HTTPS
  // true = HTTPS, false = HTTP
  static const bool useHttps = false; // Для разработки — HTTP (localhost:8000), иначе ERR_CERT_AUTHORITY_INVALID
  // ============================================
  
  static final BaseUrlManager _urlManager = BaseUrlManager();
  
  // API Configuration
  static String get baseUrl => _urlManager.getBaseUrl();
  
  static String get apiVersion => 'v1';
  static String get apiBaseUrl => '$baseUrl/api/$apiVersion';
  
  /// Сбросить fallback (для повторной попытки HTTPS)
  static void resetUrlFallback() {
    _urlManager.resetFallback();
  }

  /// Принудительно обновить протокол из конфига (вызвать после изменения useHttps)
  static void updateProtocolFromConfig() {
    _urlManager.updateProtocolFromConfig();
  }

  /// Проверить, используется ли HTTP (после fallback)
  static bool get isUsingHttp => _urlManager.isUsingHttp;
  
  // Map Configuration (minZoom 3 — не отдалять до дублирования континентов)
  /// Центр карты по умолчанию — Минск (не привязываемся к GPS/Москве при старте).
  static const double defaultMapLatitude = 53.9045;
  static const double defaultMapLongitude = 27.5615;
  static const double defaultZoom = 10.0;
  /// Не уходить ниже 4 — на малых z тайлы OSM нестабильны и «рвёт» подложку.
  static const double minZoom = 4.0;
  static const double maxZoom = 19.0;

  /// Как на Angular: линейное оборудование при зуме ≤ этого значения скрыто;
  /// показывать только после достаточного зума (иначе значки «теряются»).
  static const double minZoomToShowEquipment = 14.0;

  /// Офлайн-карта: границы Беларуси (юг, запад, север, восток) для загрузки тайлов
  static const double belarusSouth = 51.26;
  static const double belarusWest = 23.18;
  static const double belarusNorth = 56.17;
  static const double belarusEast = 32.78;
  /// Уровни зума для офлайн-карты (OSM не рекомендует bulk после 13)
  static const int offlineMinZoom = 4;
  /// До 14 — плавный зум по Беларуси без смены стиля подложки в офлайне.
  static const int offlineMaxZoom = 14;
  /// Имя хранилища FMTC (v2 — единый URL с API, не прямой tile.openstreetmap.org).
  static const String mapStoreName = 'lepm_map_tiles_v2';
  
  // Sync Configuration
  static const int syncIntervalMinutes = 5;
  static const int maxRetryAttempts = 3;
  /// Режим синхронизации: 'manual' (по умолчанию) | 'auto_wifi'
  static const String syncModeKey = 'sync_mode';
  static const String syncModeManual = 'manual';
  static const String syncModeAutoWifi = 'auto_wifi';
  
  // Database Configuration
  static const String databaseName = 'lepm_local.db';
  static const int databaseVersion = 12;
  
  // Storage Keys
  static const String authTokenKey = 'auth_token';
  static const String userIdKey = 'user_id';
  static const String lastSyncKey = 'last_sync';
  /// Не выходить из аккаунта: токен не сбрасывается при 401, сессия сохраняется
  static const String stayLoggedInKey = 'stay_logged_in';
  static const String usernameKey = 'username'; // для отображения в оффлайн-режиме
  /// Профиль пользователя после успешного онлайн-входа (JSON) — для офлайн-режима
  static const String cachedUserProfileKey = 'cached_user_profile';
  /// Маркер завершённой первичной подготовки офлайн-данных (по user id)
  static String initialBootstrapDoneKey(int userId) => 'initial_bootstrap_done_$userId';
  /// Карта: тайлы Беларуси загружены в FMTC
  static const String offlineTilesReadyKey = 'offline_tiles_ready';
  /// Счётчик для генерации временных локальных ID (отрицательные)
  static const String lastLocalPoleIdKey = 'last_local_pole_id';
  static const String lastLocalPowerLineIdKey = 'last_local_power_line_id';
  static const String lastLocalEquipmentIdKey = 'last_local_equipment_id';
  /// Шаблон автозаполнения оборудования (Фундамент, Изоляторы, Траверсы) для следующей опоры. JSON.
  static const String autofillEquipmentTemplateKey = 'autofill_equipment_template';
  /// Список id ЛЭП для отложенного удаления на сервере (офлайн-удаление)
  static const String pendingDeletePowerLineIdsKey = 'pending_delete_power_line_ids';
  /// Маппинг локальный id опоры → серверный (JSON, string→int) для pole_server_id в equipment
  static const String syncPoleMappingKey = 'sync_pole_mapping';
  /// Маппинг локальный id ЛЭП → серверный (JSON, string→int) для подстановки line_id в опорах
  static const String syncPowerLineMappingKey = 'sync_power_line_mapping';
  /// Активная сессия обхода: id выбранной линии (line_id)
  static const String activeSessionPowerLineIdKey = 'active_session_power_line_id';
  /// Время начала сессии (ISO8601)
  static const String activeSessionStartTimeKey = 'active_session_start_time';
  /// Примечание сессии
  static const String activeSessionNoteKey = 'active_session_note';
  /// Y позиция точки старта (опционально)
  static const String activeSessionLatKey = 'active_session_lat';
  /// X позиция точки старта (опционально)
  static const String activeSessionLonKey = 'active_session_lon';
  /// Точность последней зафиксированной GPS-точки активной сессии (м)
  static const String activeSessionAccuracyKey = 'active_session_accuracy';
  /// Локальный id сессии обхода в Drift (для обновления при завершении)
  static const String activeSessionLocalIdKey = 'active_session_local_id';
  /// Id сессии обхода на сервере (при восстановлении из API — для завершения на сервере)
  static const String activeSessionServerIdKey = 'active_session_server_id';
  /// Id сессий на сервере: нужно вызвать завершение при синхронизации (офлайн, без строки в Drift)
  static const String pendingEndPatrolServerIdsKey = 'pending_end_patrol_server_ids';
  /// Локальная сессия уже на сервере, но завершение не дошло — досылаем через sync
  static const String patrolSessionSyncStatusPendingEnd = 'pending_end';
  /// Кэш справочника марок оборудования (JSON list) для офлайн-автоподстановки.
  static const String equipmentCatalogCacheKey = 'equipment_catalog_cache';
  /// Время последнего обновления кэша справочника (ISO8601, UTC).
  static const String equipmentCatalogCacheUpdatedAtKey = 'equipment_catalog_cache_updated_at';
  /// Тема приложения: light | dark | system
  static const String themeModeKey = 'theme_mode';

  // Validation (создание/смена пароля; при входе минимальная длина не проверяется)
  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 128;

  /// Сообщение для форм регистрации и смены пароля.
  static String? validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите пароль';
    }
    if (value.length < minPasswordLength) {
      return 'Пароль должен содержать минимум $minPasswordLength символов';
    }
    if (value.length > maxPasswordLength) {
      return 'Пароль не должен быть длиннее $maxPasswordLength символов';
    }
    return null;
  }
  
  // UI Configuration
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 8.0;
}
