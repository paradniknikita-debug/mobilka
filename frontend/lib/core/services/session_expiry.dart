import 'package:flutter/foundation.dart';

typedef SessionExpiredCallback = Future<void> Function();

SessionExpiredCallback? _onSessionExpired;

void registerSessionExpiredHandler(SessionExpiredCallback? callback) {
  _onSessionExpired = callback;
}

/// Сброс сессии в UI при ответе API 401 (истёк/невалидный JWT).
Future<void> notifySessionExpired() async {
  final cb = _onSessionExpired;
  if (cb == null) {
    return;
  }
  try {
    await cb();
  } catch (e, st) {
    if (kDebugMode) {
      print('notifySessionExpired: $e\n$st');
    }
  }
}
