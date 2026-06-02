import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../database/database.dart';
import 'auth_service.dart';
import 'sync_service.dart';

enum InitialBootstrapPhase {
  idle,
  done,
  failed,
  skippedOffline,
}

class InitialBootstrapState {
  const InitialBootstrapState({
    this.phase = InitialBootstrapPhase.idle,
    this.message,
  });

  final InitialBootstrapPhase phase;
  final String? message;
}

class InitialBootstrapNotifier extends StateNotifier<InitialBootstrapState> {
  InitialBootstrapNotifier(this._ref) : super(const InitialBootstrapState());

  final Ref _ref;
  bool _running = false;
  int? _lastUserId;

  Future<bool> _isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Future<bool> _hasLocalMapData(AppDatabase db) async {
    final lines = await db.getAllPowerLines();
    if (lines.isNotEmpty) {
      return true;
    }
    final poles = await db.getAllPoles();
    return poles.isNotEmpty;
  }

  Future<bool> needsBootstrap(int userId) async {
    final prefs = _ref.read(prefsProvider);
    final db = _ref.read(databaseProvider);

    if (prefs.getBool(AppConfig.initialBootstrapDoneKey(userId)) == true) {
      return !await _hasLocalMapData(db);
    }

    final lastSync = prefs.getString(AppConfig.lastSyncKey);
    final hasData = await _hasLocalMapData(db);
    return lastSync == null || !hasData;
  }

  Future<void> runIfNeeded({int? userId}) async {
    final auth = _ref.read(authStateProvider);
    if (auth is! AuthStateAuthenticated) {
      return;
    }
    final uid = userId ?? auth.user.id;
    if (_running && _lastUserId == uid) {
      return;
    }

    // Детальные тайлы z11–14 (~3 ГБ) — только вручную из настроек, не автоматически.
    if (!await _isOnline()) {
      state = const InitialBootstrapState(
        phase: InitialBootstrapPhase.skippedOffline,
        message: 'Нет сети — загрузите данные при подключении к интернету',
      );
      return;
    }

    if (!await needsBootstrap(uid)) {
      state = const InitialBootstrapState(phase: InitialBootstrapPhase.done);
      return;
    }

    _running = true;
    _lastUserId = uid;
    final prefs = _ref.read(prefsProvider);

    try {
      // Синхронизация и догрузка тайлов — без блокирующей плашки на главной.
      await _ref.read(syncStateProvider.notifier).syncData();
      final syncError = _ref.read(syncStateProvider).maybeWhen(
            error: (message) => message,
            orElse: () => null,
          );
      if (syncError != null) {
        throw Exception(syncError);
      }

      final db = _ref.read(databaseProvider);
      final hasData = await _hasLocalMapData(db);
      if (hasData) {
        await prefs.setBool(AppConfig.initialBootstrapDoneKey(uid), true);
        state = const InitialBootstrapState(
          phase: InitialBootstrapPhase.done,
          message: 'Данные готовы для работы без интернета',
        );
      } else {
        state = const InitialBootstrapState(
          phase: InitialBootstrapPhase.failed,
          message: 'На сервере нет данных для загрузки или синхронизация не завершилась',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('InitialBootstrap: $e');
      }
      state = InitialBootstrapState(
        phase: InitialBootstrapPhase.failed,
        message: 'Не удалось подготовить офлайн-данные: $e',
      );
    } finally {
      _running = false;
    }
  }
}

final initialBootstrapProvider =
    StateNotifierProvider<InitialBootstrapNotifier, InitialBootstrapState>((ref) {
  return InitialBootstrapNotifier(ref);
});

/// Запускает первичную загрузку данных после входа (подложка — при старте приложения).
class InitialBootstrapListener extends ConsumerStatefulWidget {
  const InitialBootstrapListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<InitialBootstrapListener> createState() =>
      _InitialBootstrapListenerState();
}

class _InitialBootstrapListenerState extends ConsumerState<InitialBootstrapListener> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _trigger());
  }

  void _trigger() {
    final auth = ref.read(authStateProvider);
    if (auth is AuthStateAuthenticated) {
      ref.read(initialBootstrapProvider.notifier).runIfNeeded(userId: auth.user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authStateProvider, (prev, next) {
      if (next is AuthStateAuthenticated &&
          (prev is! AuthStateAuthenticated || prev.user.id != next.user.id)) {
        ref.read(initialBootstrapProvider.notifier).runIfNeeded(userId: next.user.id);
      }
    });
    return widget.child;
  }
}
