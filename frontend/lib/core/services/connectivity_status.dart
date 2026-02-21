import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Три состояния подключения для отображения пользователю.
enum ConnectionStatus {
  online,
  offline,
  unstable,
}

/// Провайдер, отслеживающий подключение и определяющий «Нестабильно»
/// при периодических обрывах (в последние 2 минуты были и онлайн, и офлайн).
final connectivityStatusProvider = StateNotifierProvider<ConnectivityStatusNotifier, ConnectionStatus>((ref) {
  final notifier = ConnectivityStatusNotifier();
  ref.onDispose(() => notifier.dispose());
  return notifier;
});

class ConnectivityStatusNotifier extends StateNotifier<ConnectionStatus> {
  ConnectivityStatusNotifier() : super(ConnectionStatus.online) {
    _init();
  }

  static const _unstableWindow = Duration(minutes: 2);
  final List<DateTime> _onlineTimestamps = [];
  final List<DateTime> _offlineTimestamps = [];
  StreamSubscription<ConnectivityResult>? _sub;

  void _init() {
    Connectivity().checkConnectivity().then(_onResult);
    _sub = Connectivity().onConnectivityChanged.listen(_onResult);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onResult(dynamic result) {
    final isOnline = _resultToOnline(result);
    final now = DateTime.now();
    if (isOnline) {
      _onlineTimestamps.add(now);
    } else {
      _offlineTimestamps.add(now);
    }
    _pruneOld(_unstableWindow);
    state = _evaluate();
  }

  /// Принудительная перепроверка подключения (например, при открытии главной или после синхронизации).
  Future<void> refresh() async {
    final result = await Connectivity().checkConnectivity();
    _onResult(result);
  }

  bool _resultToOnline(dynamic result) {
    if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }
    if (result is List<ConnectivityResult>) {
      return result.isNotEmpty &&
          !(result.length == 1 && result.single == ConnectivityResult.none);
    }
    return false;
  }

  void _pruneOld(Duration window) {
    final cutoff = DateTime.now().subtract(window);
    _onlineTimestamps.removeWhere((t) => t.isBefore(cutoff));
    _offlineTimestamps.removeWhere((t) => t.isBefore(cutoff));
  }

  ConnectionStatus _evaluate() {
    final now = DateTime.now();
    final cutoff = now.subtract(_unstableWindow);
    final hadOnline = _onlineTimestamps.any((t) => t.isAfter(cutoff));
    final hadOffline = _offlineTimestamps.any((t) => t.isAfter(cutoff));
    if (hadOnline && hadOffline) {
      return ConnectionStatus.unstable;
    }
    return hadOnline ? ConnectionStatus.online : ConnectionStatus.offline;
  }
}
