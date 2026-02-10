import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// Менеджер для управления базовым URL с автоматическим fallback HTTPS -> HTTP
class BaseUrlManager {
  static final BaseUrlManager _instance = BaseUrlManager._internal();
  factory BaseUrlManager() => _instance;
  BaseUrlManager._internal();

  static const _serverUrlKey = 'server_url';

  // Текущий протокол (https или http)
  String _protocol = 'https';
  bool _fallbackOccurred = false;

  SharedPreferences? _prefs;
  String? _customServerUrl;

  /// Инициализация менеджера с SharedPreferences
  Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
    _customServerUrl = prefs.getString(_serverUrlKey);
  }

  /// Получить сохранённый URL сервера (если есть)
  String? getSavedServerUrl() {
    return _customServerUrl ?? _prefs?.getString(_serverUrlKey);
  }

  /// Сохранить URL сервера
  Future<void> setServerUrl(String url) async {
    _customServerUrl = url;
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.setString(_serverUrlKey, url);
    }
  }

  /// Получить базовый URL (с учетом протокола)
  String getBaseUrl() {
    // Если пользователь задал URL сервера в настройках — используем его
    final custom = _customServerUrl ?? _prefs?.getString(_serverUrlKey);
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }

    if (!kIsWeb) {
      // Для мобильных платформ используем HTTP напрямую
      return _getMobileBaseUrl();
    }

    // Для web: используем настройку из AppConfig.useHttps
    _protocol = AppConfig.useHttps ? 'https' : 'http';
    return '$_protocol://localhost';
  }

  /// Выполнить fallback на HTTP
  void fallbackToHttp() {
    if (_protocol == 'https' && !_fallbackOccurred) {
      _protocol = 'http';
      _fallbackOccurred = true;
      if (kDebugMode) {
        print('⚠️ HTTPS недоступен, переключение на HTTP');
      }
    }
  }

  /// Сбросить fallback (для повторной попытки HTTPS)
  void resetFallback() {
    _protocol = 'https';
    _fallbackOccurred = false;
  }

  /// Проверить, используется ли HTTP (после fallback)
  bool get isUsingHttp => _protocol == 'http';

  /// Получить базовый URL для мобильных платформ
  String _getMobileBaseUrl() {
    if (kDebugMode) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://192.168.1.100:8000';
  }
}

