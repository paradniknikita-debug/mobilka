import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'auth_service.dart';

/// Режим синхронизации данных.
enum SyncMode {
  /// Только вручную — экономия трафика и полный контроль.
  manual,
  /// Автоматически при Wi‑Fi — сбалансированный вариант.
  autoWifi,
  /// Автоматически при любой сети — максимальная оперативность.
  autoAny,
}

extension SyncModeExtension on SyncMode {
  String get value {
    switch (this) {
      case SyncMode.manual:
        return AppConfig.syncModeManual;
      case SyncMode.autoWifi:
        return AppConfig.syncModeAutoWifi;
      case SyncMode.autoAny:
        return AppConfig.syncModeAutoAny;
    }
  }

  String get displayName {
    switch (this) {
      case SyncMode.manual:
        return 'Только вручную';
      case SyncMode.autoWifi:
        return 'Автоматически при Wi‑Fi';
      case SyncMode.autoAny:
        return 'Автоматически при любой сети';
    }
  }

  String get subtitle {
    switch (this) {
      case SyncMode.manual:
        return 'Экономия трафика и контроль над исходящими данными';
      case SyncMode.autoWifi:
        return 'Синхронизация при подключении к Wi‑Fi';
      case SyncMode.autoAny:
        return 'Максимальная оперативность доставки данных';
    }
  }
}

SyncMode _syncModeFromString(String? v) {
  switch (v) {
    case AppConfig.syncModeManual:
      return SyncMode.manual;
    case AppConfig.syncModeAutoAny:
      return SyncMode.autoAny;
    case AppConfig.syncModeAutoWifi:
    default:
      return SyncMode.autoWifi;
  }
}

class SyncModeNotifier extends StateNotifier<SyncMode> {
  SyncModeNotifier(this._prefs) : super(_syncModeFromString(_prefs?.getString(AppConfig.syncModeKey))) {
    _load();
  }

  final SharedPreferences? _prefs;

  void _load() {
    final s = _prefs?.getString(AppConfig.syncModeKey);
    state = _syncModeFromString(s);
  }

  Future<void> setMode(SyncMode mode) async {
    await _prefs?.setString(AppConfig.syncModeKey, mode.value);
    state = mode;
  }
}

final syncModeProvider = StateNotifierProvider<SyncModeNotifier, SyncMode>((ref) {
  final prefs = ref.watch(prefsProvider);
  return SyncModeNotifier(prefs);
});
