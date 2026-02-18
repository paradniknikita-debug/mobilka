import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// Менеджер для управления базовым URL с автоматическим fallback HTTPS -> HTTP
class BaseUrlManager {
  static final BaseUrlManager _instance = BaseUrlManager._internal();
  factory BaseUrlManager() => _instance;
  BaseUrlManager._internal();

  // Текущий протокол (https или http)
  String? _protocol; // Инициализируем из конфига при первом вызове
  bool _fallbackOccurred = false;
  SharedPreferences? _prefs;
  static const String _serverUrlKey = 'server_url';
  static const String _fallbackKey = 'url_fallback_occurred';

  /// Инициализировать с SharedPreferences
  Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
    // При инициализации всегда сбрасываем fallback и устанавливаем протокол из конфига
    _fallbackOccurred = false;
    _protocol = AppConfig.useHttps ? 'https' : 'http';
    // Логируем только при первой инициализации
    // if (kDebugMode) {
    //   print('🔄 BaseUrlManager инициализирован с протоколом: $_protocol');
    // }
  }

  /// Получить базовый URL (с учетом протокола)
  String getBaseUrl() {
    if (!kIsWeb) {
      // Для мобильных платформ используем настраиваемый URL
      return _getMobileBaseUrl();
    }

    // Для web: инициализируем протокол из конфига, если еще не установлен
    if (_protocol == null) {
      _protocol = AppConfig.useHttps ? 'https' : 'http';
      _fallbackOccurred = false;
      // Логируем только при необходимости
      // if (kDebugMode) {
      //   print('🔄 Протокол инициализирован из конфига: $_protocol');
      // }
    }
    
    // Если не было fallback, всегда используем протокол из конфига
    if (!_fallbackOccurred) {
      final configProtocol = AppConfig.useHttps ? 'https' : 'http';
      if (_protocol != configProtocol) {
        _protocol = configProtocol;
        // Логируем только при необходимости
        // if (kDebugMode) {
        //   print('🔄 Протокол обновлен из конфига: $_protocol');
        // }
      }
    }
    // Если был fallback, используем сохраненный протокол (HTTP)
    
    // Для production web используем относительный путь через nginx (без порта)
    // Это избегает проблем с Mixed Content и работает с HTTPS
    // Для development можно использовать абсолютный путь
    if (kReleaseMode) {
      // Production: относительный путь
      return '';
    }
    
    // Development: абсолютный путь с портом
    final port = _protocol == 'https' ? 443 : 8000;
    final hostname = Uri.base.host;
    final baseUrl = (hostname == 'localhost' || hostname == '127.0.0.1' || hostname.isEmpty)
        ? '$_protocol://localhost:$port'
        : '$_protocol://$hostname:$port';
    
    // Логируем только при изменении протокола или при инициализации
    if (kDebugMode && (_protocol == null || _fallbackOccurred)) {
      final flutterProtocol = Uri.base.scheme;
      print('🌐 BaseUrl: $baseUrl (протокол: $_protocol, fallback: $_fallbackOccurred)');
    }
    
    return baseUrl;
  }

  /// Выполнить fallback на HTTP
  void fallbackToHttp() {
    if (_protocol == 'https' && !_fallbackOccurred) {
      _protocol = 'http';
      _fallbackOccurred = true;
      if (kDebugMode) {
        print('⚠️ HTTPS недоступен, переключение на HTTP');
        print('   Для возврата к HTTPS измените useHttps в конфиге и перезапустите приложение');
      }
      // Сохраняем флаг fallback в SharedPreferences (если доступен)
      if (_prefs != null) {
        _prefs!.setBool(_fallbackKey, true).catchError((e) {
          if (kDebugMode) {
            print('⚠️ Не удалось сохранить флаг fallback: $e');
          }
        });
      }
    }
  }

  /// Сбросить fallback (для повторной попытки HTTPS)
  void resetFallback() {
    _protocol = AppConfig.useHttps ? 'https' : 'http';
    _fallbackOccurred = false;
    // Удаляем флаг fallback из SharedPreferences
    if (_prefs != null) {
      _prefs!.remove(_fallbackKey).catchError((e) {
        if (kDebugMode) {
          print('⚠️ Не удалось удалить флаг fallback: $e');
        }
      });
    }
    if (kDebugMode) {
      print('🔄 Fallback сброшен, протокол: $_protocol');
    }
  }

  /// Принудительно обновить протокол из конфига (при изменении useHttps)
  void updateProtocolFromConfig() {
    _protocol = AppConfig.useHttps ? 'https' : 'http';
    _fallbackOccurred = false;
    // Удаляем флаг fallback из SharedPreferences
    if (_prefs != null) {
      _prefs!.remove(_fallbackKey).catchError((e) {
        if (kDebugMode) {
          print('⚠️ Не удалось удалить флаг fallback: $e');
        }
      });
    }
    // Логируем только при необходимости
    // if (kDebugMode) {
    //   print('🔄 Протокол обновлен из конфига: $_protocol');
    // }
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
    // Логируем только при первой загрузке
    // if (kDebugMode) {
    //   print('📡 Используется URL по умолчанию: $defaultUrl');
    // }
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

