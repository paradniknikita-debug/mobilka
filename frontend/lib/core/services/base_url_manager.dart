import 'package:flutter/foundation.dart';

/// Менеджер для управления базовым URL с автоматическим fallback HTTPS -> HTTP
class BaseUrlManager {
  static final BaseUrlManager _instance = BaseUrlManager._internal();
  factory BaseUrlManager() => _instance;
  BaseUrlManager._internal();

  // Текущий протокол (https или http)
  String _protocol = 'https';
  bool _fallbackOccurred = false;

  /// Получить базовый URL (с учетом протокола)
  String getBaseUrl() {
    if (!kIsWeb) {
      // Для мобильных платформ используем HTTP напрямую
      return _getMobileBaseUrl();
    }

    // Для web: пытаемся HTTPS, с fallback на HTTP
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

