import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// Менеджер для управления базовым URL с автоматическим fallback HTTPS -> HTTP
class BaseUrlManager {
  static final BaseUrlManager _instance = BaseUrlManager._internal();
  factory BaseUrlManager() => _instance;
  BaseUrlManager._internal();

  // Текущий протокол (https или http)
  String _protocol = 'https';
  bool _fallbackOccurred = false;
  SharedPreferences? _prefs;
  static const String _serverUrlKey = 'server_url';

  /// Инициализировать с SharedPreferences
  Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
  }

  /// Получить базовый URL (с учетом протокола)
  String getBaseUrl() {
    if (!kIsWeb) {
      // Для мобильных платформ используем настраиваемый URL
      return _getMobileBaseUrl();
    }

    // Для web: определяем хост динамически
    _protocol = AppConfig.useHttps ? 'https' : 'http';
    
    // Используем тот же хост, что и у веб-приложения, но порт 8000 для бэкенда
    // Если запущено на localhost, используем localhost
    // Если доступно с других устройств, используем IP адрес
    final hostname = Uri.base.host;
    if (hostname == 'localhost' || hostname == '127.0.0.1' || hostname.isEmpty) {
      return '$_protocol://localhost:8000';
    } else {
      return '$_protocol://$hostname:8000';
    }
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
    // Пытаемся получить сохраненный URL из SharedPreferences
    if (_prefs != null) {
      final savedUrl = _prefs!.getString(_serverUrlKey);
      if (savedUrl != null && savedUrl.isNotEmpty) {
        if (kDebugMode) {
          print('📡 Используется сохраненный URL сервера: $savedUrl');
        }
        return savedUrl;
      }
    }
    
    // Если нет сохраненного URL, используем доменное имя по умолчанию
    // Доменное имя работает независимо от изменения IP адреса
    // Для эмулятора Android используем специальный адрес
    final defaultUrl = 'http://lepm.local:8000';
    if (kDebugMode) {
      print('📡 Используется URL по умолчанию: $defaultUrl');
      print('   Для эмулятора Android используйте: http://10.0.2.2:8000');
      print('   Для изменения URL используйте настройки приложения');
      print('   Настройки доступны в профиле → Настройки');
    }
    return defaultUrl;
  }

  /// Установить URL сервера
  Future<void> setServerUrl(String url) async {
    if (_prefs != null) {
      await _prefs!.setString(_serverUrlKey, url);
      if (kDebugMode) {
        print('💾 URL сервера сохранен: $url');
      }
    } else {
      if (kDebugMode) {
        print('⚠️ SharedPreferences не инициализирован, URL не сохранен');
      }
    }
  }

  /// Получить сохраненный URL сервера
  String? getSavedServerUrl() {
    if (_prefs != null) {
      return _prefs!.getString(_serverUrlKey);
    }
    return null;
  }
}

