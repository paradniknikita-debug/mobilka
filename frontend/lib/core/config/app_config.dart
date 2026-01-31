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
  static const bool useHttps = true; // Для разработки используем HTTP
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
  
  // Sync Configuration
  static const int syncIntervalMinutes = 5;
  static const int maxRetryAttempts = 3;
  
  // Database Configuration
  static const String databaseName = 'lepm_local.db';
  static const int databaseVersion = 1;
  
  // Storage Keys
  static const String authTokenKey = 'auth_token';
  static const String userIdKey = 'user_id';
  static const String lastSyncKey = 'last_sync';
  
  // Validation
  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 50;
  
  // UI Configuration
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 8.0;
}
