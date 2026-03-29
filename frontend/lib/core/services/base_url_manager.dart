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
    }

    // Если не было fallback, всегда используем протокол из конфига
    if (!_fallbackOccurred) {
      final configProtocol = AppConfig.useHttps ? 'https' : 'http';
      if (_protocol != configProtocol) {
        _protocol = configProtocol;
      }
    }
    // Если был fallback, используем сохраненный протокол (HTTP)
    
    // Для production web используем относительный путь через nginx (без порта)
    // Исключение: если приложение открыто с нестандартного порта (например 53380 — Flutter web-server),
    // API на другом порту — используем явный адрес бэкенда (localhost:8000)
    if (kReleaseMode) {
      final currentPort = Uri.base.port;
      final isLocalDevServer = (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1') &&
          currentPort != 80 && currentPort != 443 && currentPort != 8000;
      if (isLocalDevServer) {
        final port = _protocol == 'https' ? 443 : 8000;
        return '$_protocol://localhost:$port';
      }
      // Production за nginx: относительный путь
      return '';
    }

    // Development: абсолютный путь с портом
    final port = _protocol == 'https' ? 443 : 8000;
    final hostname = Uri.base.host;
    final baseUrl = (hostname == 'localhost' ||
            hostname == '127.0.0.1' ||
            hostname.isEmpty)
        ? '$_protocol://localhost:$port'
        : '$_protocol://$hostname:$port';

    if (kDebugMode && (_fallbackOccurred)) {
      final flutterProtocol = Uri.base.scheme;
      print(
          '🌐 BaseUrl: $baseUrl (протокол: $_protocol, fallback: $_fallbackOccurred, flutter: $flutterProtocol)');
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
        print(
            '   Для возврата к HTTPS измените useHttps в конфиге и перезапустите приложение');
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
    // Для эмулятора Android используем специальный адрес, для реальных устройств — пример локального сервера
    final defaultUrl = 'http://lepm.local:8000';
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

