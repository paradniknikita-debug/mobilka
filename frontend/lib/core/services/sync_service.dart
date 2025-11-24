import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:drift/drift.dart' as drift;

import '../config/app_config.dart';
import '../database/database.dart';
import 'api_service.dart';

part 'sync_service.freezed.dart';

class SyncService extends StateNotifier<SyncState> {
  final AppDatabase _database;
  final ApiService _apiService;
  final Connectivity _connectivity;
  final Uuid _uuid;

  SyncService(this._database, this._apiService)
      : _connectivity = Connectivity(),
        _uuid = const Uuid(),
        super(const SyncState.idle());

  Future<void> syncData() async {
    state = const SyncState.syncing();

    try {
      // Проверяем подключение к интернету
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        state = const SyncState.error('Нет подключения к интернету');
        return;
      }

      // Синхронизируем данные в обе стороны
      await _uploadLocalChanges();
      await _downloadServerChanges();

      state = const SyncState.completed();
    } catch (e) {
      state = SyncState.error('Ошибка синхронизации: ${e.toString()}');
    }
  }

  Future<void> _uploadLocalChanges() async {
    // Получаем все записи, которые нужно синхронизировать
    final powerLines = await _database.getPowerLinesNeedingSync();
    final poles = await _database.getPolesNeedingSync();
    final equipment = await _database.getEquipmentNeedingSync();

    // Создаем пакет для отправки
    final batchId = _uuid.v4();
    final records = <Map<String, dynamic>>[];

    // Добавляем ЛЭП
    for (final powerLine in powerLines) {
      records.add(_createSyncRecord('power_line', 'create', powerLine.toJson(), batchId));
    }

    // Добавляем опоры
    for (final pole in poles) {
      records.add(_createSyncRecord('pole', 'create', pole.toJson(), batchId));
    }

    // Добавляем оборудование
    for (final equipmentItem in equipment) {
      records.add(_createSyncRecord('equipment', 'create', _equipmentToJson(equipmentItem), batchId));
    }

    if (records.isNotEmpty) {
      final batch = {
        'batch_id': batchId,
        'timestamp': DateTime.now().toIso8601String(),
        'records': records,
      };

      // Отправляем на сервер
      final response = await _apiService.uploadSyncBatch(batch);
      
      if (response['success'] == true) {
        // Помечаем записи как синхронизированные
        await _markAsSynced(powerLines, poles, equipment);
      }
    }
  }

  Future<void> _downloadServerChanges() async {
    // Получаем последнюю дату синхронизации
    final lastSync = await _getLastSyncTime();
    
    // Скачиваем изменения с сервера
    final response = await _apiService.downloadSyncData(lastSync);
    final records = response['records'] as List<dynamic>? ?? [];

    // Обрабатываем каждую запись
    for (final recordData in records) {
      await _processServerRecord(recordData);
    }

    // Обновляем время последней синхронизации
    await _setLastSyncTime(DateTime.now());
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

  Future<void> _processPowerLineRecord(String action, Map<String, dynamic> data) async {
    switch (action) {
      case 'create':
      case 'update':
        await _database.insertPowerLine(
          PowerLinesCompanion.insert(
            id: drift.Value(data['id']),
            name: data['name'],
            code: data['code'],
            voltageLevel: data['voltage_level'],
            length: drift.Value(data['length']),
            branchId: data['branch_id'],
            createdBy: data['created_by'],
            status: data['status'],
            description: drift.Value(data['description']),
            createdAt: DateTime.parse(data['created_at']),
            updatedAt: drift.Value(data['updated_at'] != null ? DateTime.parse(data['updated_at']) : null),
          ),
        );
        break;
      case 'delete':
        await _database.deletePowerLine(data['id']);
        break;
    }
  }

  Future<void> _processPoleRecord(String action, Map<String, dynamic> data) async {
    switch (action) {
      case 'create':
      case 'update':
        await _database.insertPole(
          PolesCompanion.insert(
            id: drift.Value(data['id']),
            powerLineId: data['power_line_id'],
            poleNumber: data['pole_number'],
            latitude: data['latitude'],
            longitude: data['longitude'],
            poleType: data['pole_type'],
            height: drift.Value(data['height']),
            foundationType: drift.Value(data['foundation_type']),
            material: drift.Value(data['material']),
            yearInstalled: drift.Value(data['year_installed']),
            condition: data['condition'],
            notes: drift.Value(data['notes']),
            createdBy: data['created_by'],
            createdAt: DateTime.parse(data['created_at']),
            updatedAt: drift.Value(data['updated_at'] != null ? DateTime.parse(data['updated_at']) : null),
          ),
        );
        break;
      case 'delete':
        await _database.deletePole(data['id']);
        break;
    }
  }

  Future<void> _processEquipmentRecord(String action, Map<String, dynamic> data) async {
    switch (action) {
      case 'create':
      case 'update':
        await _database.insertEquipment(
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

  Future<void> _markAsSynced(
    List<PowerLine> powerLines,
    List<Pole> poles,
    List<EquipmentData> equipment,
  ) async {
    // Помечаем ЛЭП как синхронизированные
    for (final powerLine in powerLines) {
      await _database.updatePowerLine(
        PowerLinesCompanion(
          id: drift.Value(powerLine.id),
          needsSync: drift.Value(false),
        ),
      );
    }

    // Помечаем опоры как синхронизированные
    for (final pole in poles) {
      await _database.updatePole(
        PolesCompanion(
          id: drift.Value(pole.id),
          needsSync: drift.Value(false),
        ),
      );
    }

    // Помечаем оборудование как синхронизированное
    for (final equipmentItem in equipment) {
      await _database.updateEquipment(
        EquipmentCompanion(
          id: drift.Value(equipmentItem.id),
          needsSync: drift.Value(false),
        ),
      );
    }
  }

  Future<String> _getLastSyncTime() async {
    // Здесь должна быть логика получения времени последней синхронизации
    // Пока возвращаем время 24 часа назад
    return DateTime.now().subtract(const Duration(hours: 24)).toIso8601String();
  }

  Future<void> _setLastSyncTime(DateTime time) async {
    // Здесь должна быть логика сохранения времени последней синхронизации
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
  return SyncService(database, apiService);
});

// Provider для состояния синхронизации
final syncStateProvider = StateNotifierProvider<SyncService, SyncState>((ref) {
  return ref.watch(syncServiceProvider);
});
