import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Состояния подключения для отображения пользователю (только онлайн/офлайн).
enum ConnectionStatus {
  online,
  offline,
}

/// Провайдер, отслеживающий текущее состояние подключения.
final connectivityStatusProvider = StateNotifierProvider<ConnectivityStatusNotifier, ConnectionStatus>((ref) {
  final notifier = ConnectivityStatusNotifier();
  ref.onDispose(() => notifier.dispose());
  return notifier;
});

class ConnectivityStatusNotifier extends StateNotifier<ConnectionStatus> {
  ConnectivityStatusNotifier() : super(ConnectionStatus.online) {
    _init();
  }

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
    state = _resultToOnline(result) ? ConnectionStatus.online : ConnectionStatus.offline;
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
}
