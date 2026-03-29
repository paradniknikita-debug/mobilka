import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'auth_service.dart';

/// Режим синхронизации данных.
enum SyncMode {
  /// Только вручную — по умолчанию.
  manual,
  /// Автоматически при Wi‑Fi.
  autoWifi,
}

extension SyncModeExtension on SyncMode {
  String get value {
    switch (this) {
      case SyncMode.manual:
        return AppConfig.syncModeManual;
      case SyncMode.autoWifi:
        return AppConfig.syncModeAutoWifi;
    }
  }

  String get displayName {
    switch (this) {
      case SyncMode.manual:
        return 'Только вручную';
      case SyncMode.autoWifi:
        return 'Автоматически при Wi‑Fi';
    }
  }

  String get subtitle {
    switch (this) {
      case SyncMode.manual:
        return 'Экономия трафика и контроль над исходящими данными';
      case SyncMode.autoWifi:
        return 'Синхронизация при подключении к Wi‑Fi';
    }
  }
}

SyncMode _syncModeFromString(String? v) {
  switch (v) {
    case AppConfig.syncModeAutoWifi:
      return SyncMode.autoWifi;
    case AppConfig.syncModeManual:
    default:
      return SyncMode.manual;
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
