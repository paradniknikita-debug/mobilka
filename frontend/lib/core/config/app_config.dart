import 'package:flutter/foundation.dart';
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
  
  // Map Configuration
  static const double defaultZoom = 10.0;
  static const double minZoom = 1.0;
  static const double maxZoom = 18.0;

  /// Офлайн-карта: границы Беларуси (юг, запад, север, восток) для загрузки тайлов
  static const double belarusSouth = 51.26;
  static const double belarusWest = 23.18;
  static const double belarusNorth = 56.17;
  static const double belarusEast = 32.78;
  /// Уровни зума для офлайн-карты (OSM не рекомендует bulk после 13)
  static const int offlineMinZoom = 4;
  static const int offlineMaxZoom = 13;
  /// Имя хранилища тайлов FMTC
  static const String mapStoreName = 'osm_belarus';
  
  // Sync Configuration
  static const int syncIntervalMinutes = 5;
  static const int maxRetryAttempts = 3;
  /// Режим синхронизации: 'manual' | 'auto_wifi' | 'auto_any'
  static const String syncModeKey = 'sync_mode';
  static const String syncModeManual = 'manual';
  static const String syncModeAutoWifi = 'auto_wifi';
  static const String syncModeAutoAny = 'auto_any';
  
  // Database Configuration
  static const String databaseName = 'lepm_local.db';
  static const int databaseVersion = 2;
  
  // Storage Keys
  static const String authTokenKey = 'auth_token';
  static const String userIdKey = 'user_id';
  static const String lastSyncKey = 'last_sync';
  /// Не выходить из аккаунта: токен не сбрасывается при 401, сессия сохраняется
  static const String stayLoggedInKey = 'stay_logged_in';
  static const String usernameKey = 'username'; // для отображения в оффлайн-режиме
  /// Счётчик для генерации временных локальных ID (отрицательные)
  static const String lastLocalPoleIdKey = 'last_local_pole_id';
  static const String lastLocalPowerLineIdKey = 'last_local_power_line_id';
  /// Список id ЛЭП для отложенного удаления на сервере (офлайн-удаление)
  static const String pendingDeletePowerLineIdsKey = 'pending_delete_power_line_ids';
  /// Активная сессия обхода: id выбранной ЛЭП
  static const String activeSessionPowerLineIdKey = 'active_session_power_line_id';
  /// Время начала сессии (ISO8601)
  static const String activeSessionStartTimeKey = 'active_session_start_time';
  /// Примечание сессии
  static const String activeSessionNoteKey = 'active_session_note';
  /// Y позиция точки старта (опционально)
  static const String activeSessionLatKey = 'active_session_lat';
  /// X позиция точки старта (опционально)
  static const String activeSessionLonKey = 'active_session_lon';
  /// Локальный id сессии обхода в Drift (для обновления при завершении)
  static const String activeSessionLocalIdKey = 'active_session_local_id';
  /// Id сессии обхода на сервере (при восстановлении из API — для завершения на сервере)
  static const String activeSessionServerIdKey = 'active_session_server_id';

  // Validation
  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 50;
  
  // UI Configuration
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 8.0;
}
