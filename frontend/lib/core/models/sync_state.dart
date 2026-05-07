import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_state.freezed.dart';

/// Состояние фоновой синхронизации (без импорта Flutter — корректная генерация freezed для web).
@freezed
class SyncState with _$SyncState {
  const factory SyncState.idle() = _Idle;
  const factory SyncState.syncing() = _Syncing;
  const factory SyncState.completed() = _Completed;
  const factory SyncState.error(String message) = _Error;
}
