import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'auth_service.dart';
import 'pending_sync_provider.dart';
import 'sync_preferences.dart';
import 'sync_service.dart';
import '../../features/home/presentation/pages/home_page.dart';

/// Виджет, запускающий автосинхронизацию по таймеру и при возврате приложения
/// в зависимости от [syncModeProvider] и типа сети.
class SyncScheduler extends ConsumerStatefulWidget {
  const SyncScheduler({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SyncScheduler> createState() => _SyncSchedulerState();
}

class _SyncSchedulerState extends ConsumerState<SyncScheduler>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleTimer() {
    _timer?.cancel();
    final mode = ref.read(syncModeProvider);
    if (mode == SyncMode.manual) return;

    const interval = Duration(minutes: AppConfig.syncIntervalMinutes);
    _timer = Timer.periodic(interval, (_) => _maybeSync());
    _maybeSync();
  }

  Future<void> _maybeSync() async {
    final authState = ref.read(authStateProvider);
    if (authState is! AuthStateAuthenticated) return;

    final mode = ref.read(syncModeProvider);
    if (mode == SyncMode.manual) return;

    final result = await Connectivity().checkConnectivity();
    if (mode == SyncMode.autoWifi && result != ConnectivityResult.wifi) return;
    if (mode == SyncMode.autoAny && result == ConnectivityResult.none) return;

    ref.read(syncServiceProvider).syncData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _maybeSync();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SyncMode>(syncModeProvider, (_, __) => _scheduleTimer());
    ref.listen<SyncState>(syncStateProvider, (prev, next) {
      next.when(
        idle: () {},
        syncing: () {},
        completed: () {
          ref.invalidate(hasPendingSyncProvider);
          ref.invalidate(pendingPatrolSessionsCountProvider);
          ref.invalidate(recentPatrolsProvider);
        },
        error: (_) {},
      );
    });
    return widget.child;
  }
}
