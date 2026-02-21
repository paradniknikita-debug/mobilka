import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../database/database.dart';
import 'api_service.dart';
import 'auth_service.dart'; // prefsProvider

part 'sync_service.freezed.dart';

/// Преобразование ключей camelCase в snake_case для API бэкенда
Map<String, dynamic> _toSnakeCaseMap(Map<String, dynamic> map) {
  final result = <String, dynamic>{};
  for (final e in map.entries) {
    final key = e.key.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (m) => '_${m.group(0)!.toLowerCase()}',
    );
    result[key] = e.value;
  }
  return result;
}

class SyncService extends StateNotifier<SyncState> {
  final AppDatabase _database;
  final ApiService _apiService;
  final SharedPreferences? _prefs;
  final Connectivity _connectivity;
  final Uuid _uuid;

  SyncService(this._database, this._apiService, [this._prefs])
      : _connectivity = Connectivity(),
        _uuid = const Uuid(),
        super(const SyncState.idle());

  /// Порог: если последняя синхронизация старше этого срока — делаем полную загрузку с сервера (чтобы офлайн показывал актуальные данные).
  static const Duration _fullSyncIfOlderThan = Duration(days: 30);

  /// Метка времени «очень давно» для запроса полного набора данных с сервера.
  static const String _fullSyncSince = '2000-01-01T00:00:00Z';

  Future<void> syncData() async {
    state = const SyncState.syncing();

    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        state = const SyncState.error('Нет подключения к интернету');
        return;
      }

      final lastSyncDt = await _getLastSyncDateTime();
      final needFullDownload = lastSyncDt == null ||
          (DateTime.now().toUtc().difference(lastSyncDt) > _fullSyncIfOlderThan);

      // Фиксируем время до выгрузки для инкрементальной загрузки
      final lastSyncBeforeUpload = await _getLastSyncTime();

      await _uploadPatrolSessions();
      final uploadResult = await _uploadLocalChanges();

      if (needFullDownload) {
        await _downloadServerChanges(useLastSync: _fullSyncSince);
      } else {
        await _downloadServerChanges(useLastSync: lastSyncBeforeUpload);
      }

      // Удаляем локальные копии только после успешной выгрузки И загрузки — иначе данные не потеряются при сбое
      if (uploadResult != null) {
        await _removeUploadedLocalEntities(uploadResult.$1, uploadResult.$2, uploadResult.$3);
        _clearPendingDeletePowerLineIds();
      }
      await _setLastSyncTime(DateTime.now());
      state = const SyncState.completed();
    } catch (e) {
      final msg = e.toString();
      final short = msg.contains('DioException') && msg.contains('status code')
          ? _shortSyncError(msg)
          : msg;
      state = SyncState.error('Ошибка синхронизации: $short');
    }
  }

  static String _shortSyncError(String dioMessage) {
    if (dioMessage.contains('400')) return 'Сервер отклонил запрос (400). Проверьте данные или обновите приложение.';
    if (dioMessage.contains('401')) return 'Сессия истекла. Войдите снова.';
    if (dioMessage.contains('404')) return 'Сервер не найден. Проверьте адрес и сеть.';
    if (dioMessage.contains('500')) return 'Ошибка на сервере. Попробуйте позже.';
    return 'Ошибка сети или сервера. Проверьте подключение.';
  }

  /// Выгрузить сессии обхода со статусом pending: POST на сервер, обновить локально serverId и synced.
  /// Сессии с power_line_id < 0 (локальная ЛЭП) пропускаем — линия ещё не на сервере.
  Future<void> _uploadPatrolSessions() async {
    final pending = await _database.getPendingPatrolSessions();
    for (final row in pending) {
      if (row.powerLineId < 0) continue; // ЛЭП создана офлайн — отправим после синхронизации линии
      final body = <String, dynamic>{
        'power_line_id': row.powerLineId,
        if (row.note != null && row.note!.isNotEmpty) 'note': row.note,
      };
      final response = await _apiService.createPatrolSession(body);
      final serverId = (response['id'] as num?)?.toInt();
      if (serverId == null) continue;

      await _database.setPatrolSessionSynced(row.id, serverId);

      if (row.endedAt != null) {
        await _apiService.endPatrolSession(serverId);
      }
    }
  }

  /// Возвращает (powerLines, poles, equipment) для последующего удаления из локальной БД после успешного download, или null.
  Future<(List<PowerLine>, List<Pole>, List<EquipmentData>)?> _uploadLocalChanges() async {
    // Порядок: сначала отложенные удаления ЛЭП, затем создание (ЛЭП → опоры → оборудование).
    final powerLines = await _database.getPowerLinesNeedingSync();
    final poles = await _database.getPolesNeedingSync();
    final equipment = await _database.getEquipmentNeedingSync();
    final pendingDeletePlIds = _getPendingDeletePowerLineIds();

    final batchId = _uuid.v4();
    final records = <Map<String, dynamic>>[];

    // Отложенные удаления ЛЭП (офлайн-удаление)
    for (final id in pendingDeletePlIds) {
      records.add(_createSyncRecord('power_line', 'delete', {'id': id}, batchId));
    }

    // Создание: сначала ЛЭП (бэкенд требует name, code, voltage_level — задаём явно)
    for (final powerLine in powerLines) {
      final data = _toSnakeCaseMap(powerLine.toJson());
      // Всегда задаём обязательные поля, чтобы не терялись при сериализации
      final String name = (powerLine.name.trim().isNotEmpty)
          ? powerLine.name
          : (powerLine.code.trim().isNotEmpty ? powerLine.code : 'ЛЭП');
      final String code = powerLine.code.trim().isNotEmpty
          ? powerLine.code
          : (powerLine.id >= 0 ? 'LEP-${powerLine.id}' : 'LEP-L${-powerLine.id}');
      final num voltageLevel = powerLine.voltageLevel;
      data['name'] = name;
      data['code'] = code;
      data['voltage_level'] = voltageLevel is int ? voltageLevel.toDouble() : (voltageLevel as double? ?? 0.0);
      records.add(_createSyncRecord('power_line', 'create', data, batchId));
    }

    // Затем опоры (power_line_id может быть локальным < 0 — сервер подставит server id)
    for (final pole in poles) {
      records.add(_createSyncRecord('pole', 'create', _toSnakeCaseMap(pole.toJson()), batchId));
    }

    // Оборудование
    for (final equipmentItem in equipment) {
      records.add(_createSyncRecord('equipment', 'create', _equipmentToJson(equipmentItem), batchId));
    }

    if (records.isEmpty) return null;

    final batch = {
      'batch_id': batchId,
      'timestamp': DateTime.now().toIso8601String(),
      'records': records,
    };
    final response = await _apiService.uploadSyncBatch(batch);
    if (response['success'] == true) {
      return (powerLines, poles, equipment);
    }
    return null;
  }

  List<int> _getPendingDeletePowerLineIds() {
    if (_prefs == null) return [];
    final list = _prefs!.getStringList(AppConfig.pendingDeletePowerLineIdsKey) ?? [];
    return list.map((s) => int.tryParse(s)).whereType<int>().toList();
  }

  void _clearPendingDeletePowerLineIds() {
    _prefs?.setStringList(AppConfig.pendingDeletePowerLineIdsKey, []);
  }

  Future<void> _removeUploadedLocalEntities(
    List<PowerLine> powerLines,
    List<Pole> poles,
    List<EquipmentData> equipment,
  ) async {
    for (final pl in powerLines) {
      if (pl.isLocal && pl.id < 0) await _database.deletePowerLine(pl.id);
    }
    for (final p in poles) {
      if (p.isLocal && p.id < 0) await _database.deletePole(p.id);
    }
    for (final eq in equipment) {
      if (eq.isLocal && eq.id < 0) await _database.deleteEquipment(eq.id);
    }
  }

  /// [useLastSync] — если задано, использовать его для запроса (например, время до выгрузки).
  Future<void> _downloadServerChanges({String? useLastSync}) async {
    final lastSync = useLastSync ?? await _getLastSyncTime();
    final response = await _apiService.downloadSyncData(lastSync);
    final records = response['records'] as List<dynamic>? ?? [];

    for (final recordData in records) {
      await _processServerRecord(recordData);
    }
    // Время обновляется в syncData() после успешного завершения
  }

  Map<String, dynamic> _equipmentToJson(EquipmentData equipment) {
    return {
      'id': equipment.id,
      'pole_id': equipment.poleId,
      'equipment_type': equipment.equipmentType,
      'name': equipment.name,
      'manufacturer': equipment.manufacturer,
      'model': equipment.model,
      'serial_number': equipment.serialNumber,
      'year_manufactured': equipment.yearManufactured,
      'installation_date': equipment.installationDate?.toIso8601String(),
      'condition': equipment.condition,
      'notes': equipment.notes,
      'created_by': equipment.createdBy,
      'created_at': equipment.createdAt.toIso8601String(),
      'updated_at': equipment.updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> _createSyncRecord(
    String entityType,
    String action,
    Map<String, dynamic> data,
    String batchId,
  ) {
    return {
      'id': _uuid.v4(),
      'entity_type': entityType,
      'action': action,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'pending',
    };
  }

  Future<void> _processServerRecord(Map<String, dynamic> recordData) async {
    final entityType = recordData['entity_type'] as String;
    final action = recordData['action'] as String;
    final data = recordData['data'] as Map<String, dynamic>;

    switch (entityType) {
      case 'power_line':
        await _processPowerLineRecord(action, data);
        break;
      case 'pole':
        await _processPoleRecord(action, data);
        break;
      case 'equipment':
        await _processEquipmentRecord(action, data);
        break;
    }
  }

  static int _toInt(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0);
  static double _toDouble(dynamic v) => v is double ? v : (v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0);
  static DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString();
    return s.isEmpty ? null : DateTime.tryParse(s);
  }

  Future<void> _processPowerLineRecord(String action, Map<String, dynamic> data) async {
    switch (action) {
      case 'create':
      case 'update':
        final id = _toInt(data['id']);
        final createdAt = _parseDateTime(data['created_at']) ?? DateTime.now();
        final updatedAt = _parseDateTime(data['updated_at']);
        await _database.insertPowerLineOrReplace(
          PowerLinesCompanion.insert(
            id: drift.Value(id),
            name: data['name'] as String? ?? '',
            code: data['code'] as String? ?? '',
            voltageLevel: _toDouble(data['voltage_level']),
            length: drift.Value(data['length'] != null ? _toDouble(data['length']) : null),
            branchId: _toInt(data['branch_id']) != 0 ? _toInt(data['branch_id']) : 1,
            createdBy: _toInt(data['created_by']),
            status: data['status'] as String? ?? 'active',
            description: drift.Value(data['description'] as String?),
            createdAt: createdAt,
            updatedAt: drift.Value(updatedAt),
          ),
        );
        break;
      case 'delete':
        await _database.deletePowerLine(_toInt(data['id']));
        break;
    }
  }

  Future<void> _processPoleRecord(String action, Map<String, dynamic> data) async {
    switch (action) {
      case 'create':
      case 'update':
        final id = _toInt(data['id']);
        final powerLineId = _toInt(data['power_line_id']);
        final createdAt = _parseDateTime(data['created_at']) ?? DateTime.now();
        final updatedAt = _parseDateTime(data['updated_at']);
        await _database.insertPoleOrReplace(
          PolesCompanion.insert(
            id: drift.Value(id),
            powerLineId: powerLineId,
            poleNumber: data['pole_number'] as String? ?? '',
            latitude: _toDouble(data['latitude']),
            longitude: _toDouble(data['longitude']),
            poleType: data['pole_type'] as String? ?? 'unknown',
            height: drift.Value(data['height'] != null ? _toDouble(data['height']) : null),
            foundationType: drift.Value(data['foundation_type'] as String?),
            material: drift.Value(data['material'] as String?),
            yearInstalled: drift.Value(data['year_installed'] != null ? _toInt(data['year_installed']) : null),
            condition: data['condition'] as String? ?? 'good',
            notes: drift.Value(data['notes'] as String?),
            createdBy: _toInt(data['created_by']),
            createdAt: createdAt,
            updatedAt: drift.Value(updatedAt),
          ),
        );
        break;
      case 'delete':
        await _database.deletePole(_toInt(data['id']));
        break;
    }
  }

  Future<void> _processEquipmentRecord(String action, Map<String, dynamic> data) async {
    switch (action) {
      case 'create':
      case 'update':
        await _database.insertEquipmentOrReplace(
          EquipmentCompanion.insert(
            id: drift.Value(data['id']),
            poleId: data['pole_id'] ?? data['tower_id'], // Поддержка старого формата
            equipmentType: data['equipment_type'],
            name: data['name'],
            manufacturer: drift.Value(data['manufacturer']),
            model: drift.Value(data['model']),
            serialNumber: drift.Value(data['serial_number']),
            yearManufactured: drift.Value(data['year_manufactured']),
            installationDate: drift.Value(data['installation_date'] != null ? DateTime.parse(data['installation_date']) : null),
            condition: data['condition'],
            notes: drift.Value(data['notes']),
            createdBy: data['created_by'],
            createdAt: DateTime.parse(data['created_at']),
            updatedAt: drift.Value(data['updated_at'] != null ? DateTime.parse(data['updated_at']) : null),
          ),
        );
        break;
      case 'delete':
        await _database.deleteEquipment(data['id']);
        break;
    }
  }

  Future<String> _getLastSyncTime() async {
    if (_prefs == null) return DateTime.now().subtract(const Duration(hours: 24)).toIso8601String();
    final s = _prefs!.getString(AppConfig.lastSyncKey);
    if (s == null || s.isEmpty) return DateTime.now().subtract(const Duration(hours: 24)).toIso8601String();
    return s;
  }

  /// Возвращает дату последней синхронизации или null, если ещё ни разу не синхронизировались.
  Future<DateTime?> _getLastSyncDateTime() async {
    if (_prefs == null) return null;
    final s = _prefs!.getString(AppConfig.lastSyncKey);
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  Future<void> _setLastSyncTime(DateTime time) async {
    await _prefs?.setString(AppConfig.lastSyncKey, time.toIso8601String());
  }
}

@freezed
class SyncState with _$SyncState {
  const factory SyncState.idle() = _Idle;
  const factory SyncState.syncing() = _Syncing;
  const factory SyncState.completed() = _Completed;
  const factory SyncState.error(String message) = _Error;
}

// Provider для SyncService
final syncServiceProvider = Provider<SyncService>((ref) {
  final database = ref.watch(databaseProvider);
  final apiService = ref.watch(apiServiceProvider);
  final prefs = ref.watch(prefsProvider);
  return SyncService(database, apiService, prefs);
});

// Provider для состояния синхронизации
final syncStateProvider = StateNotifierProvider<SyncService, SyncState>((ref) {
  return ref.watch(syncServiceProvider);
});
