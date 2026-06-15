import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

import 'package:path/path.dart' as p;

import '../config/app_config.dart';
import '../database/database.dart';
import '../models/power_line.dart' show PoleCreate;
import '../models/sync_state.dart';
import 'api_service.dart';
import 'attachment_reader.dart';
import 'auth_service.dart'; // prefsProvider
import '../utils/mrid.dart';
import '../utils/normalize_pole_number.dart';
import '../utils/sync_pole_merge.dart';
import '../utils/pole_card_attachment_codec.dart';

export '../models/sync_state.dart';

/// Результат выгрузки: какие отложенные удаления были отправлены в batch.
class SyncUploadResult {
  const SyncUploadResult({
    this.deletedPowerLineIds = const {},
    this.deletedPoleIds = const {},
    this.deletedEquipmentIds = const {},
  });

  final Set<int> deletedPowerLineIds;
  final Set<int> deletedPoleIds;
  final Set<int> deletedEquipmentIds;

  bool get isEmpty =>
      deletedPowerLineIds.isEmpty &&
      deletedPoleIds.isEmpty &&
      deletedEquipmentIds.isEmpty;
}

/// Извлечь id сессии обхода из JSON ответа POST/PATCH (int / num / string).
int? readPatrolSessionIdFromResponse(Object? raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  final id = m['id'];
  if (id == null) return null;
  if (id is int) return id;
  if (id is num) return id.toInt();
  if (id is String) return int.tryParse(id.trim());
  return null;
}

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

Future<List<int>> _attachmentBytesFromEntry(Map<String, dynamic> m) async {
  final bytesB64 = m['bytes_b64'] as String?;
  if (bytesB64 != null && bytesB64.toString().trim().isNotEmpty) {
    try {
      return base64Decode(bytesB64);
    } catch (_) {}
  }
  final path = m['p'] as String?;
  if (path != null && path.isNotEmpty) {
    return await readAttachmentBytes(path);
  }
  return [];
}

List<Map<String, dynamic>> _mergePoleAttachmentItems(
  String? primaryJson,
  String? secondaryJson,
) {
  final byKey = <String, Map<String, dynamic>>{};
  void addFrom(String? raw) {
    final items = PoleCardAttachmentCodec.parseItemsJson(raw);
    for (final item in items) {
      final url = item['url']?.toString().trim();
      final path = item['p']?.toString().trim();
      final id = item['id']?.toString().trim();
      final key = (url != null && url.isNotEmpty)
          ? 'u:$url'
          : (path != null && path.isNotEmpty)
              ? 'p:$path'
              : (id != null && id.isNotEmpty)
                  ? 'i:$id'
                  : '';
      if (key.isEmpty) continue;
      final prev = byKey[key];
      if (prev == null) {
        byKey[key] = Map<String, dynamic>.from(item);
      } else {
        byKey[key] = {...item, ...prev};
      }
    }
  }

  // Сначала серверные/актуальные, затем локальные pending (чтобы не терять p).
  addFrom(primaryJson);
  addFrom(secondaryJson);
  return byKey.values.toList(growable: false);
}

class SyncService extends StateNotifier<SyncState> {
  final AppDatabase _database;
  final ApiServiceWithExport _apiService;
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

      await _flushPendingServerPatrolEnds();
      // Сначала отправляем локальные сущности (в т.ч. ЛЭП), чтобы сессии обхода
      // с локальным line_id могли уйти в ЭТОМ же запуске синхронизации.
      final uploadResult = await _uploadLocalChanges();
      await _uploadPatrolSessions();

      if (needFullDownload) {
        await _downloadServerChanges(useLastSync: _fullSyncSince);
      } else {
        await _downloadServerChanges(useLastSync: lastSyncBeforeUpload);
      }

      await _database.removeDuplicatePowerLines();
      await _database.backfillMissingPoleSequenceNumbers();

      // Справочник марок — только по явному согласию пользователя (диалог на главной).

      // Локальные данные не удаляем: выгруженные сущности остаются в БД вместе с загруженными с сервера.
      if (uploadResult != null) {
        _applyUploadDeleteCleanup(uploadResult, fullUpload: true);
      }
      await _setLastSyncTime(DateTime.now());

      final pendingPatrols = await _database.getPendingPatrolSessions();
      final queuedEnds = _prefs?.getStringList(AppConfig.pendingEndPatrolServerIdsKey) ?? [];
      if (pendingPatrols.isNotEmpty || queuedEnds.isNotEmpty) {
        final lines = <String>[];
        for (final r in pendingPatrols.take(4)) {
          if (r.lineId < 0) {
            lines.add(
              '• сессия #${r.id}: ЛЭП только локальная (line_id=${r.lineId}) — сначала синхронизируйте линию на сервер',
            );
          } else if (r.syncStatus == AppConfig.patrolSessionSyncStatusPendingEnd) {
            lines.add(
              '• сессия #${r.id}: завершение не дошло до сервера (server_id=${r.serverId})',
            );
          } else {
            lines.add(
              '• сессия #${r.id}: не создана на сервере (line_id=${r.lineId}) — проверьте, что такая ЛЭП есть на сервере',
            );
          }
        }
        if (pendingPatrols.length > 4) {
          lines.add('• … и ещё ${pendingPatrols.length - 4} сессий');
        }
        if (queuedEnds.isNotEmpty) {
          lines.add('• в очереди завершений (без локальной строки): ${queuedEnds.length}');
        }
        state = SyncState.error(
          'Данные обновлены, но обходы отправлены не полностью:\n${lines.join('\n')}',
        );
      } else {
        state = await _syncCompletedOrPendingError();
      }
    } catch (e) {
      final msg = e.toString();
      final short = msg.contains('DioException') && msg.contains('status code')
          ? _shortSyncError(msg)
          : msg;
      state = SyncState.error('Ошибка синхронизации: $short');
    }
  }

  /// Только выгрузка на сервер (без загрузки с сервера).
  /// После старта обхода онлайн — чтобы отправить сессию, не запуская полный sync и не дублируя загрузку карты.
  Future<void> pushLocalChangesOnly() async {
    state = const SyncState.syncing();
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        state = const SyncState.idle();
        return;
      }

      await _flushPendingServerPatrolEnds();
      final uploadResult = await _uploadLocalChanges();
      await _uploadPatrolSessions();
      if (uploadResult != null) {
        _applyUploadDeleteCleanup(uploadResult, fullUpload: true);
      }

      final pendingPatrols = await _database.getPendingPatrolSessions();
      final queuedEnds = _prefs?.getStringList(AppConfig.pendingEndPatrolServerIdsKey) ?? [];
      if (pendingPatrols.isNotEmpty || queuedEnds.isNotEmpty) {
        final lines = <String>[];
        for (final r in pendingPatrols.take(4)) {
          if (r.lineId < 0) {
            lines.add(
              '• сессия #${r.id}: ЛЭП только локальная (line_id=${r.lineId}) — сначала синхронизируйте линию на сервер',
            );
          } else if (r.syncStatus == AppConfig.patrolSessionSyncStatusPendingEnd) {
            lines.add(
              '• сессия #${r.id}: завершение не дошло до сервера (server_id=${r.serverId})',
            );
          } else {
            lines.add(
              '• сессия #${r.id}: не создана на сервере (line_id=${r.lineId}) — проверьте, что такая ЛЭП есть на сервере',
            );
          }
        }
        if (pendingPatrols.length > 4) {
          lines.add('• … и ещё ${pendingPatrols.length - 4} сессий');
        }
        if (queuedEnds.isNotEmpty) {
          lines.add('• в очереди завершений (без локальной строки): ${queuedEnds.length}');
        }
        state = SyncState.error(
          'Отправка не завершена полностью:\n${lines.join('\n')}',
        );
      } else {
        state = await _syncCompletedOrPendingError();
      }
    } catch (e) {
      final msg = e.toString();
      final short = msg.contains('DioException') && msg.contains('status code')
          ? _shortSyncError(msg)
          : msg;
      state = SyncState.error('Ошибка отправки на сервер: $short');
    }
  }

  /// Выгрузка на сервер только по одной ЛЭП (без download).
  Future<void> pushLocalChangesForLine(int lineId) async {
    state = const SyncState.syncing();
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        state = const SyncState.idle();
        return;
      }

      await _flushPendingServerPatrolEnds();
      final uploadResult = await _uploadLocalChanges(scopeLineId: lineId);
      await _uploadPatrolSessions(scopeLineId: lineId);
      if (uploadResult != null) {
        _applyUploadDeleteCleanup(uploadResult, fullUpload: false);
      }
      state = await _syncCompletedOrPendingError(scopeLineId: lineId);
    } catch (e) {
      final msg = e.toString();
      final short = msg.contains('DioException') && msg.contains('status code')
          ? _shortSyncError(msg)
          : msg;
      state = SyncState.error('Ошибка отправки ЛЭП на сервер: $short');
    }
  }

  Future<SyncState> _syncCompletedOrPendingError({int? scopeLineId}) async {
    final pending = await _pendingSyncSummary(scopeLineId: scopeLineId);
    if (pending != null) {
      return SyncState.error(pending);
    }
    return const SyncState.completed();
  }

  Future<String?> _pendingSyncSummary({int? scopeLineId}) async {
    var pl = await _database.getPowerLinesNeedingSync();
    var po = await _database.getPolesNeedingSync();
    var eq = await _database.getEquipmentNeedingSync();
    if (scopeLineId != null) {
      pl = pl.where((x) => _lineMatchesScope(x.id, scopeLineId)).toList();
      po = po.where((x) => _lineMatchesScope(x.lineId, scopeLineId)).toList();
      final scopedEq = <EquipmentData>[];
      for (final item in eq) {
        final pole = await _database.getPole(item.poleId);
        if (pole != null && _lineMatchesScope(pole.lineId, scopeLineId)) {
          scopedEq.add(item);
        }
      }
      eq = scopedEq;
    }
    if (pl.isEmpty && po.isEmpty && eq.isEmpty) return null;
    final parts = <String>[];
    if (pl.isNotEmpty) parts.add('ЛЭП: ${pl.length}');
    if (po.isNotEmpty) {
      parts.add('опоры: ${po.length} (${po.map((p) => p.poleNumber).join(', ')})');
    }
    if (eq.isNotEmpty) parts.add('оборудование: ${eq.length}');
    return 'Не все локальные изменения отправлены на сервер (${parts.join('; ')}). Повторите синхронизацию.';
  }

  /// Новые офлайн-опоры — через тот же API, что и онлайн (номер, порядок, пролёт).
  Future<void> _uploadNewPolesViaCreateApi(List<Pole> poles, {int? scopeLineId}) async {
    var newPoles = poles.where((p) => p.id < 0).toList();
    if (scopeLineId != null) {
      newPoles = newPoles.where((p) => _lineMatchesScope(p.lineId, scopeLineId)).toList();
    }
    newPoles.sort(_comparePolesForUpload);
    if (newPoles.isEmpty) return;

    var lineMapping = Map<int, int>.from(_getSyncPowerLineMapping());
    var poleMapping = Map<int, int>.from(_getSyncPoleMapping());

    for (final pole in newPoles) {
      var lineId = pole.lineId;
      if (lineId < 0) {
        lineId = lineMapping[lineId] ?? lineId;
      }
      if (lineId < 0) continue;

      int? tapPoleId = pole.tapPoleId;
      if (tapPoleId != null && tapPoleId < 0) {
        tapPoleId = poleMapping[tapPoleId];
      }

      final branchType = pole.branchType ??
          (pole.poleNumber.contains('/') || tapPoleId != null ? 'tap' : 'main');

      final create = PoleCreate(
        poleNumber: normalizePoleNumber(pole.poleNumber),
        xPosition: pole.xPosition ?? 0.0,
        yPosition: pole.yPosition ?? 0.0,
        poleType: pole.poleType ?? 'unknown',
        height: pole.height,
        foundationType: pole.foundationType,
        material: pole.material,
        yearInstalled: pole.yearInstalled,
        condition: pole.condition ?? 'good',
        notes: pole.notes,
        structuralDefect: pole.structuralDefect,
        structuralDefectCriticality: pole.structuralDefectCriticality,
        isTap: pole.isTapPole ?? false,
        conductorType: pole.conductorType,
        conductorMaterial: pole.conductorMaterial,
        conductorSection: pole.conductorSection,
        cardComment: pole.cardComment,
        mrid: pole.mrid,
        sequenceNumber: pole.sequenceNumber,
        tapPoleId: tapPoleId,
        branchType: branchType,
        tapBranchIndex: pole.tapBranchIndex,
      );

      try {
        final created = await _apiService.createPole(
          lineId,
          create,
          fromPoleId: branchType == 'tap' ? tapPoleId : null,
        );
        final localId = pole.id;
        await _database.reassignPoleLocalToServerId(localId, created.id);
        await _database.insertPoleOrReplace(
          PolesCompanion.insert(
            id: drift.Value(created.id),
            lineId: created.lineId,
            poleNumber: created.poleNumber,
            mrid: drift.Value(created.mrid),
            xPosition: drift.Value(created.xPosition),
            yPosition: drift.Value(created.yPosition),
            poleType: drift.Value(created.poleType),
            height: drift.Value(created.height),
            foundationType: drift.Value(created.foundationType),
            material: drift.Value(created.material),
            yearInstalled: drift.Value(created.yearInstalled),
            condition: drift.Value(created.condition),
            notes: drift.Value(created.notes),
            structuralDefect: drift.Value(created.structuralDefect),
            structuralDefectCriticality:
                drift.Value(created.structuralDefectCriticality),
            cardComment: pole.cardComment == null
                ? const drift.Value.absent()
                : drift.Value(pole.cardComment!),
            cardCommentAttachment: pole.cardCommentAttachment == null
                ? const drift.Value.absent()
                : drift.Value(pole.cardCommentAttachment!),
            sequenceNumber: drift.Value(created.sequenceNumber),
            branchType: drift.Value(created.branchType),
            tapPoleId: drift.Value(created.tapPoleId),
            tapBranchIndex: drift.Value(created.tapBranchIndex),
            isTapPole: drift.Value(created.isTapPole),
            conductorType: drift.Value(created.conductorType),
            conductorMaterial: drift.Value(created.conductorMaterial),
            conductorSection: drift.Value(created.conductorSection),
            createdBy: created.createdBy,
            createdAt: created.createdAt,
            updatedAt: drift.Value(created.updatedAt),
            isLocal: const drift.Value(false),
            needsSync: const drift.Value(false),
          ),
        );
        poleMapping[localId] = created.id;
        _saveSyncPoleMapping({localId.toString(): created.id});
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('sync: createPole offline pole ${pole.id} failed: $e\n$st');
        }
      }
    }
  }

  static String _shortSyncError(String dioMessage) {
    if (dioMessage.contains('400')) return 'Сервер отклонил запрос (400). Проверьте данные или обновите приложение.';
    if (dioMessage.contains('401')) return 'Сессия истекла. Войдите снова.';
    if (dioMessage.contains('404')) return 'Сервер не найден. Проверьте адрес и сеть.';
    if (dioMessage.contains('500')) return 'Ошибка на сервере. Попробуйте позже.';
    return 'Ошибка сети или сервера. Проверьте подключение.';
  }

  /// Удаляет из локальной БД ЛЭП, которых уже нет на сервере (например, после пересоздания БД).
  /// Возвращает количество удалённых линий.
  Future<int> removeStalePowerLines() async {
    final serverLines = await _apiService.getPowerLines();
    final serverIds = serverLines.map((l) => l.id).toSet();
    final local = await _database.getAllPowerLines();
    int removed = 0;
    for (final pl in local) {
      if (pl.id < 0) continue;
      if (serverIds.contains(pl.id)) continue;
      final poles = await _database.getPolesByLine(pl.id);
      for (final p in poles) {
        final eqList = await _database.getEquipmentByPole(p.id);
        for (final eq in eqList) {
          await _database.deleteEquipment(eq.id);
        }
        await _database.deletePole(p.id);
      }
      await _database.deletePatrolSessionsByLineId(pl.id);
      await _database.deletePowerLine(pl.id);
      removed++;
    }
    return removed;
  }

  /// Завершения сессий, для которых нет строки в Drift (восстановление только с сервера в prefs).
  Future<void> _flushPendingServerPatrolEnds() async {
    if (_prefs == null) return;
    final key = AppConfig.pendingEndPatrolServerIdsKey;
    final raw = _prefs!.getStringList(key) ?? [];
    if (raw.isEmpty) return;
    final remaining = <String>[];
    for (final s in raw) {
      final id = int.tryParse(s);
      if (id == null || id <= 0) continue;
      try {
        await _apiService.endPatrolSession(id);
      } on DioException catch (e) {
        if (e.response?.statusCode == 400 || e.response?.statusCode == 404) {
          continue;
        }
        remaining.add(s);
      } catch (_) {
        remaining.add(s);
      }
    }
    await _prefs!.setStringList(key, remaining);
  }

  /// Выгрузить сессии обхода: pending (создание) и pending_end (только завершение на сервере).
  /// Сессии с line_id < 0 (локальная ЛЭП) пропускаем — линия ещё не на сервере.
  /// При 400/404 (например, ЛЭП не найдена на сервере) пропускаем сессию и не прерываем синхронизацию.
  Future<void> _uploadPatrolSessions({int? scopeLineId}) async {
    final pending = await _database.getPendingPatrolSessions();
    for (final row in pending) {
      if (scopeLineId != null && !_lineMatchesScope(row.lineId, scopeLineId)) continue;
      if (row.lineId < 0) continue; // ЛЭП создана офлайн — отправим после синхронизации линии

      if (row.syncStatus == AppConfig.patrolSessionSyncStatusPendingEnd) {
        final sid = row.serverId;
        if (sid == null || sid <= 0) continue;
        try {
          await _apiService.endPatrolSession(sid);
          await _database.setPatrolSessionSynced(row.id, sid);
        } on DioException catch (e) {
          if (e.response?.statusCode == 400 || e.response?.statusCode == 404) {
            await _database.setPatrolSessionSynced(row.id, sid);
          } else {
            rethrow;
          }
        }
        continue;
      }

      // Сервер ожидает line_id (int) и опционально note (str)
      final body = <String, dynamic>{
        'line_id': row.lineId,
        if (row.note != null && row.note!.isNotEmpty) 'note': row.note!,
      };
      try {
        final response = await _apiService.createPatrolSession(body);
        final serverId = readPatrolSessionIdFromResponse(response);
        if (serverId == null) {
          if (kDebugMode) {
            debugPrint('sync: createPatrolSession: нет id в ответе: $response');
          }
          continue;
        }

        await _database.setPatrolSessionSynced(row.id, serverId);

        if (row.endedAt != null) {
          await _apiService.endPatrolSession(serverId);
        }
      } on DioException catch (e) {
        // ЛЭП не найдена на сервере или неверные данные — пропускаем эту сессию, не ломаем всю синхронизацию
        if (e.response?.statusCode == 400 || e.response?.statusCode == 404) {
          continue;
        }
        rethrow;
      }
    }
  }

  /// Сначала выгрузить только ЛЭП (чтобы офлайн-опоры могли ссылаться на server line_id).
  Future<void> _uploadPendingPowerLinesOnly({int? scopeLineId}) async {
    var powerLines = await _database.getPowerLinesNeedingSync();
    if (scopeLineId != null) {
      powerLines = powerLines.where((pl) => _lineMatchesScope(pl.id, scopeLineId)).toList();
    }
    if (powerLines.isEmpty) return;

    final batchId = _uuid.v4();
    final records = <Map<String, dynamic>>[];
    for (final powerLine in powerLines) {
      final data = _toSnakeCaseMap(powerLine.toJson());
      final name = powerLine.name.trim().isNotEmpty ? powerLine.name : 'ЛЭП';
      final voltageLevel = powerLine.voltageLevel;
      data['name'] = name;
      data['voltage_level'] =
          voltageLevel is int ? voltageLevel.toDouble() : (voltageLevel as double? ?? 0.0);
      records.add(_createSyncRecord('power_line', 'create', data, batchId));
    }
    if (records.isEmpty) return;

    final response = await _apiService.uploadSyncBatch({
      'batch_id': batchId,
      'timestamp': DateTime.now().toIso8601String(),
      'records': records,
    });
    if (response['success'] != true) return;

    final idMapping = response['id_mapping'];
    final idMappingPowerLine = idMapping is Map && idMapping['power_line'] is Map
        ? Map<String, dynamic>.from(idMapping['power_line'] as Map)
        : <String, dynamic>{};
    if (idMappingPowerLine.isNotEmpty) {
      _saveSyncPowerLineMapping(idMappingPowerLine);
      for (final pl in powerLines) {
        if (pl.id >= 0) continue;
        final serverIdRaw = idMappingPowerLine[pl.id.toString()];
        final serverId = serverIdRaw is int
            ? serverIdRaw
            : (serverIdRaw is num
                ? serverIdRaw.toInt()
                : int.tryParse(serverIdRaw?.toString() ?? ''));
        if (serverId == null || serverId <= 0) continue;
        await _database.updatePolesLineId(pl.id, serverId);
        await _database.updatePatrolSessionsPowerLineId(pl.id, serverId);
        await _database.insertPowerLineOrReplace(
          PowerLinesCompanion.insert(
            id: drift.Value(serverId),
            name: pl.name,
            code: pl.name,
            mrid: pl.mrid != null && pl.mrid!.trim().isNotEmpty
                ? drift.Value(pl.mrid!)
                : const drift.Value.absent(),
            voltageLevel: pl.voltageLevel,
            length: pl.length != null ? drift.Value(pl.length!) : const drift.Value.absent(),
            branchId: pl.branchId,
            createdBy: pl.createdBy,
            status: pl.status,
            description: drift.Value(pl.description),
            createdAt: pl.createdAt,
            updatedAt: drift.Value(pl.updatedAt),
            isLocal: const drift.Value(false),
            needsSync: const drift.Value(false),
          ),
        );
        await _database.deletePowerLine(pl.id);
      }
      for (final pl in powerLines) {
        if (pl.id >= 0) await _database.setPowerLineNeedsSync(pl.id, false);
      }
    }
  }

  /// Возвращает отправленные отложенные удаления или null, если batch не ушёл.
  Future<SyncUploadResult?> _uploadLocalChanges({int? scopeLineId}) async {
    // Порядок: сначала отложенные удаления ЛЭП, затем создание (ЛЭП → опоры → оборудование).
    final pendingDeletePlIds = await _filterPendingDeletePowerLineIds(scopeLineId);
    final pendingDeletePoleIds = await _filterPendingDeletePoleIds(scopeLineId);
    final pendingDeleteEquipmentIds = await _filterPendingDeleteEquipmentIds(scopeLineId);
    await _uploadPendingPowerLinesOnly(scopeLineId: scopeLineId);

    var powerLines = await _database.getPowerLinesNeedingSync();
    var poles = await _database.getPolesNeedingSync();
    var equipment = await _database.getEquipmentNeedingSync();
    if (scopeLineId != null) {
      powerLines = powerLines.where((pl) => _lineMatchesScope(pl.id, scopeLineId)).toList();
      poles = poles.where((p) => _lineMatchesScope(p.lineId, scopeLineId)).toList();
      final scopedEq = <EquipmentData>[];
      for (final eq in equipment) {
        final pole = await _database.getPole(eq.poleId);
        if (pole != null && _lineMatchesScope(pole.lineId, scopeLineId)) {
          scopedEq.add(eq);
        }
      }
      equipment = scopedEq;
    }

    // Новые офлайн-опоры — через POST create_pole (как онлайн), не через sync-batch.
    await _uploadNewPolesViaCreateApi(poles, scopeLineId: scopeLineId);
    poles = await _database.getPolesNeedingSync();
    powerLines = await _database.getPowerLinesNeedingSync();
    equipment = await _database.getEquipmentNeedingSync();
    if (scopeLineId != null) {
      powerLines = powerLines.where((pl) => _lineMatchesScope(pl.id, scopeLineId)).toList();
      poles = poles.where((p) => _lineMatchesScope(p.lineId, scopeLineId)).toList();
      final scopedEq = <EquipmentData>[];
      for (final eq in equipment) {
        final pole = await _database.getPole(eq.poleId);
        if (pole != null && _lineMatchesScope(pole.lineId, scopeLineId)) {
          scopedEq.add(eq);
        }
      }
      equipment = scopedEq;
    }

    final batchId = _uuid.v4();
    final records = <Map<String, dynamic>>[];

    // Отложенные удаления ЛЭП (офлайн-удаление)
    for (final id in pendingDeletePlIds) {
      records.add(_createSyncRecord('power_line', 'delete', {'id': id}, batchId));
    }
    // Отложенные удаления опор
    for (final id in pendingDeletePoleIds) {
      records.add(_createSyncRecord('pole', 'delete', {'id': id}, batchId));
    }
    // Отложенные удаления оборудования
    for (final id in pendingDeleteEquipmentIds) {
      records.add(_createSyncRecord('equipment', 'delete', {'id': id}, batchId));
    }

    // Создание: ЛЭП (если остались после _uploadPendingPowerLinesOnly)
    for (final powerLine in powerLines) {
      final data = _toSnakeCaseMap(powerLine.toJson());
      final String name = powerLine.name.trim().isNotEmpty ? powerLine.name : 'ЛЭП';
      final num voltageLevel = powerLine.voltageLevel;
      data['name'] = name;
      data['voltage_level'] = voltageLevel is int ? voltageLevel.toDouble() : (voltageLevel as double? ?? 0.0);
      records.add(_createSyncRecord('power_line', 'create', data, batchId));
    }

    // Затем опоры (line_id может быть локальным < 0 — подставляем server id из маппинга при наличии).
    // Вложения с локальным путём (p) загружаем на сервер и подставляем url; для новых опор — после создания пакета.
    final powerLineMapping = _getSyncPowerLineMapping();
    final newPolesWithPendingAttachments = <({Pole pole, List<Map<String, dynamic>> pending, List<Map<String, dynamic>> resolved})>[];
    /// После успешного upload обновим локальный Drift, чтобы download не затёр путями/пустотой.
    final Map<int, String?> poleCardAttachmentAfterUpload = {};
    final Set<int> polesWithPendingAttachmentUpload = {};
    for (final pole in poles) {
      if (pole.id < 0) continue;
      var poleData = _toSnakeCaseMap(pole.toJson());
      if (normalizeMridDisplay(poleData['mrid']) == null) {
        poleData['mrid'] = generateMrid();
      }
      final plId = pole.lineId;
      if (plId < 0) {
        final serverPlId = powerLineMapping[plId];
        if (serverPlId != null && serverPlId > 0) {
          poleData = {...poleData, 'line_id': serverPlId};
        }
      }
      // Разрешаем card_comment_attachment: загружаем файлы по "p", подставляем "url"
      final attachmentJson = poleData['card_comment_attachment'];
      if (attachmentJson != null && attachmentJson is String) {
        try {
          final list = PoleCardAttachmentCodec.parseItemsJson(attachmentJson);
          final resolved = <Map<String, dynamic>>[];
          List<Map<String, dynamic>>? pendingForNew;
          final unresolvedForExisting = <Map<String, dynamic>>[];
          for (final e in list) {
            final m = Map<String, dynamic>.from(e);
            if (m['url'] != null) {
              resolved.add(m);
              continue;
            }
            final path = m['p'] as String?;
            final hasB64 = (m['bytes_b64'] as String?)?.trim().isNotEmpty == true;
            if ((path == null || path.isEmpty) && !hasB64) continue;
            final type = m['t'] as String? ?? 'photo';
            if (pole.id > 0) {
              try {
                final bytes = await _attachmentBytesFromEntry(m);
                if (bytes.isEmpty) continue;
                final uploadName = (m['filename'] as String?)?.trim().isNotEmpty == true
                    ? (m['filename'] as String).trim()
                    : (path != null && path.isNotEmpty ? p.basename(path) : 'upload.bin');
                final result = await _apiService.uploadPoleAttachment(pole.id, type, bytes, uploadName);
                final url = result['url'] as String?;
                if (url != null) {
                  final entry = <String, dynamic>{'t': type, 'url': url};
                  if (result['thumbnail_url'] != null) entry['thumbnail_url'] = result['thumbnail_url'];
                  if (result['filename'] != null) entry['filename'] = result['filename'];
                  if (result['original_filename'] != null) {
                    entry['original_filename'] = result['original_filename'];
                  }
                  resolved.add(entry);
                } else {
                  unresolvedForExisting.add(m);
                }
              } catch (_) {
                // Файл пока недоступен/нет сети: сохраняем pending и повторим на следующей синхронизации.
                unresolvedForExisting.add(m);
              }
            } else {
              pendingForNew ??= [];
              pendingForNew.add(m);
            }
          }
          if (pole.id > 0) {
            if (unresolvedForExisting.isNotEmpty) {
              polesWithPendingAttachmentUpload.add(pole.id);
              poleData.remove('card_comment_attachment');
              final localPending = [...resolved, ...unresolvedForExisting];
              poleCardAttachmentAfterUpload[pole.id] =
                  localPending.isEmpty ? null : jsonEncode(localPending);
            } else {
              final enc = resolved.isEmpty ? null : jsonEncode(resolved);
              poleData['card_comment_attachment'] = enc;
              if (enc != null) {
                poleCardAttachmentAfterUpload[pole.id] = enc;
              }
            }
          } else {
            poleData['card_comment_attachment'] = resolved.isEmpty ? null : jsonEncode(resolved);
            if (pendingForNew != null && pendingForNew.isNotEmpty) {
              newPolesWithPendingAttachments.add((
                pole: pole,
                pending: pendingForNew,
                resolved: List.from(resolved),
              ));
            }
          }
        } catch (_) {}
      }
      records.add(
        _createSyncRecord('pole', pole.id < 0 ? 'create' : 'update', poleData, batchId),
      );
    }

    // Оборудование: передаём pole_server_id из сохранённого маппинга, если опора уже синхронизирована ранее.
    // Если для локального pole_id нет ни серверного id, ни самой опоры в текущем пакете —
    // считаем запись устаревшей/дублем и переводим её в состояние «не требует синхронизации», не отправляя на сервер.
    final poleMapping = _getSyncPoleMapping();
    final polesInBatch = poles.map((p) => p.id).toSet();
    final List<EquipmentData> equipmentToSync = [];
    final Map<int, String?> equipmentCardAttachmentAfterUpload = {};
    final Set<int> equipmentWithPendingAttachmentUpload = {};
    for (final eq in equipment) {
      final poleId = eq.poleId;
      final serverPoleId = poleMapping[poleId];
      final hasPoleInBatch = polesInBatch.contains(poleId);
      final canSync = poleId > 0 || (serverPoleId != null && serverPoleId > 0) || hasPoleInBatch;
      if (!canSync) {
        // Не сбрасываем needsSync: запись остается pending до появления маппинга.
        continue;
      }
      equipmentToSync.add(eq);
      var eqData = _equipmentToJson(eq, poleMapping);
      final eqAttachJson = eqData['card_comment_attachment'];
      if (eqAttachJson != null && eqAttachJson is String) {
        try {
          final list = PoleCardAttachmentCodec.parseItemsJson(eqAttachJson);
          final resolved = <Map<String, dynamic>>[];
          List<Map<String, dynamic>>? pendingForNew;
          final unresolvedForExisting = <Map<String, dynamic>>[];
          for (final e in list) {
            final m = Map<String, dynamic>.from(e);
            if (m['url'] != null) {
              resolved.add(m);
              continue;
            }
            final path = m['p'] as String?;
            final hasB64 = (m['bytes_b64'] as String?)?.trim().isNotEmpty == true;
            if ((path == null || path.isEmpty) && !hasB64) continue;
            final type = m['t'] as String? ?? 'photo';
            if (eq.id > 0) {
              try {
                final bytes = await _attachmentBytesFromEntry(m);
                if (bytes.isEmpty) continue;
                final uploadName = (m['filename'] as String?)?.trim().isNotEmpty == true
                    ? (m['filename'] as String).trim()
                    : (path != null && path.isNotEmpty ? p.basename(path) : 'upload.bin');
                final result = await _apiService.uploadEquipmentAttachment(eq.id, type, bytes, uploadName);
                final url = result['url'] as String?;
                if (url != null) {
                  final entry = <String, dynamic>{'t': type, 'url': url};
                  if (result['thumbnail_url'] != null) entry['thumbnail_url'] = result['thumbnail_url'];
                  if (result['filename'] != null) entry['filename'] = result['filename'];
                  if (result['original_filename'] != null) {
                    entry['original_filename'] = result['original_filename'];
                  }
                  resolved.add(entry);
                } else {
                  unresolvedForExisting.add(m);
                }
              } catch (_) {
                unresolvedForExisting.add(m);
              }
            } else {
              pendingForNew ??= [];
              pendingForNew.add(m);
            }
          }
          if (eq.id > 0) {
            if (unresolvedForExisting.isNotEmpty) {
              equipmentWithPendingAttachmentUpload.add(eq.id);
              eqData.remove('card_comment_attachment');
              final localPending = [...resolved, ...unresolvedForExisting];
              equipmentCardAttachmentAfterUpload[eq.id] =
                  localPending.isEmpty ? null : jsonEncode(localPending);
            } else {
              final enc = resolved.isEmpty ? null : jsonEncode(resolved);
              eqData['card_comment_attachment'] = enc;
              if (enc != null) {
                equipmentCardAttachmentAfterUpload[eq.id] = enc;
              }
            }
          } else {
            eqData['card_comment_attachment'] = resolved.isEmpty ? null : jsonEncode(resolved);
            if (pendingForNew != null && pendingForNew.isNotEmpty) {
              eqData.remove('card_comment_attachment');
              final localPending = [...resolved, ...pendingForNew];
              equipmentCardAttachmentAfterUpload[eq.id] =
                  localPending.isEmpty ? null : jsonEncode(localPending);
              equipmentWithPendingAttachmentUpload.add(eq.id);
            }
          }
        } catch (_) {}
      }
      records.add(
        _createSyncRecord('equipment', eq.id < 0 ? 'create' : 'update', eqData, batchId),
      );
    }

    if (records.isEmpty) return null;

    final batch = {
      'batch_id': batchId,
      'timestamp': DateTime.now().toIso8601String(),
      'records': records,
    };
    final response = await _apiService.uploadSyncBatch(batch);
    if (response['success'] == true) {
      for (final e in poleCardAttachmentAfterUpload.entries) {
        await _database.setPoleCardCommentAttachment(e.key, e.value);
      }
      for (final e in equipmentCardAttachmentAfterUpload.entries) {
        await _database.setEquipmentCardCommentAttachment(e.key, e.value);
      }

      final idMapping = response['id_mapping'];
      final idMappingPole = idMapping is Map && idMapping['pole'] is Map
          ? Map<String, dynamic>.from(idMapping['pole'] as Map)
          : <String, dynamic>{};
      final idMappingPowerLine = idMapping is Map && idMapping['power_line'] is Map
          ? Map<String, dynamic>.from(idMapping['power_line'] as Map)
          : <String, dynamic>{};

      // Маппинг ЛЭП из ЭТОГО ответа нужен до загрузки вложений: иначе для офлайн-созданной линии
      // powerLineMapping из prefs пуст и updatePole с вложениями не вызывается.
      final effectivePowerLineMapping = Map<int, int>.from(_getSyncPowerLineMapping());
      for (final e in idMappingPowerLine.entries) {
        final k = int.tryParse(e.key.toString());
        final v = e.value is int
            ? e.value as int
            : (e.value is num
                ? (e.value as num).toInt()
                : int.tryParse(e.value?.toString() ?? ''));
        if (k != null && v != null && v > 0) {
          effectivePowerLineMapping[k] = v;
        }
      }

      if (idMappingPole.isNotEmpty) {
        _saveSyncPoleMapping(idMappingPole);
        for (final entry in idMappingPole.entries) {
          final clientId = int.tryParse(entry.key.toString());
          if (clientId != null && !polesWithPendingAttachmentUpload.contains(clientId)) {
            await _database.setPoleNeedsSync(clientId, false);
          }
        }
      }
      // Новые опоры с локальными вложениями: загружаем файлы и обновляем опору на сервере
      for (final item in newPolesWithPendingAttachments) {
        final serverPoleIdRaw = idMappingPole[item.pole.id.toString()];
        final serverPoleId = serverPoleIdRaw is int
            ? serverPoleIdRaw
            : (serverPoleIdRaw is num ? serverPoleIdRaw.toInt() : int.tryParse(serverPoleIdRaw?.toString() ?? ''));
        final serverLineId = effectivePowerLineMapping[item.pole.lineId];
        if (serverPoleId == null || serverPoleId <= 0 || serverLineId == null || serverLineId <= 0) continue;
        final resolved = List<Map<String, dynamic>>.from(item.resolved);
        final unresolved = <Map<String, dynamic>>[];
        for (final m in item.pending) {
          final path = m['p'] as String?;
          final hasB64 = (m['bytes_b64'] as String?)?.trim().isNotEmpty == true;
          if ((path == null || path.isEmpty) && !hasB64) continue;
          final type = m['t'] as String? ?? 'photo';
          try {
            final bytes = await _attachmentBytesFromEntry(m);
            if (bytes.isEmpty) continue;
            final uploadName = (m['filename'] as String?)?.trim().isNotEmpty == true
                ? (m['filename'] as String).trim()
                : (path != null && path.isNotEmpty && path.contains('.')
                    ? p.basename(path)
                    : 'upload.bin');
            final result = await _apiService.uploadPoleAttachment(serverPoleId, type, bytes, uploadName);
            final url = result['url'] as String?;
            if (url != null) {
              final entry = <String, dynamic>{'t': type, 'url': url};
              if (result['thumbnail_url'] != null) entry['thumbnail_url'] = result['thumbnail_url'];
              if (result['filename'] != null) entry['filename'] = result['filename'];
              if (result['original_filename'] != null) {
                entry['original_filename'] = result['original_filename'];
              }
              resolved.add(entry);
            } else {
              unresolved.add(m);
            }
          } catch (e, st) {
            unresolved.add(m);
            if (kDebugMode) {
              debugPrint('sync: upload attachment for new pole failed: $e\n$st');
            }
          }
        }
        final pole = item.pole;
        final poleCreate = PoleCreate(
          poleNumber: pole.poleNumber,
          xPosition: pole.xPosition ?? 0.0,
          yPosition: pole.yPosition ?? 0.0,
          poleType: pole.poleType ?? 'unknown',
          height: pole.height,
          foundationType: pole.foundationType,
          material: pole.material,
          yearInstalled: pole.yearInstalled,
          condition: pole.condition ?? 'good',
          notes: pole.notes,
          structuralDefect: pole.structuralDefect,
          structuralDefectCriticality: pole.structuralDefectCriticality,
          cardComment: pole.cardComment,
          cardCommentAttachment: resolved.isEmpty ? null : jsonEncode(resolved),
        );
        try {
          await _apiService.updatePole(serverLineId, serverPoleId, poleCreate);
          final localJson = [...resolved, ...unresolved];
          await _database.setPoleCardCommentAttachment(
            item.pole.id,
            localJson.isEmpty ? null : jsonEncode(localJson),
          );
          if (unresolved.isNotEmpty) {
            polesWithPendingAttachmentUpload.add(item.pole.id);
            await _database.setPoleNeedsSync(item.pole.id, true);
            await _database.setPoleNeedsSync(serverPoleId, true);
          } else {
            await _database.setPoleNeedsSync(serverPoleId, false);
          }
        } catch (e, st) {
          polesWithPendingAttachmentUpload.add(item.pole.id);
          await _database.setPoleNeedsSync(item.pole.id, true);
          await _database.setPoleNeedsSync(serverPoleId, true);
          if (kDebugMode) {
            debugPrint(
              'sync: updatePole with attachments line=$serverLineId pole=$serverPoleId: $e\n$st',
            );
          }
        }
      }

      // Одна строка опоры с серверным id: копируем данные с локального отрицательного id.
      for (final e in idMappingPole.entries) {
        final localId = int.tryParse(e.key.toString());
        final srvRaw = e.value;
        final serverPoleId = srvRaw is int
            ? srvRaw
            : (srvRaw is num
                ? srvRaw.toInt()
                : int.tryParse(srvRaw?.toString() ?? ''));
        if (localId != null &&
            localId < 0 &&
            serverPoleId != null &&
            serverPoleId > 0) {
          await _database.reassignPoleLocalToServerId(localId, serverPoleId);
        }
      }

      final idMappingEquipment = idMapping is Map && idMapping['equipment'] is Map
          ? Map<String, dynamic>.from(idMapping['equipment'] as Map)
          : <String, dynamic>{};
      for (final e in idMappingEquipment.entries) {
        final localId = int.tryParse(e.key.toString());
        final srvRaw = e.value;
        final serverEqId = srvRaw is int
            ? srvRaw
            : (srvRaw is num ? srvRaw.toInt() : int.tryParse(srvRaw?.toString() ?? ''));
        if (localId != null && localId < 0 && serverEqId != null && serverEqId > 0) {
          await _database.reassignEquipmentLocalToServerId(
            localId,
            serverEqId,
            keepNeedsSync: equipmentWithPendingAttachmentUpload.contains(localId),
          );
        }
      }

      if (idMappingPowerLine.isNotEmpty) {
        final plMapping = idMappingPowerLine;
          _saveSyncPowerLineMapping(plMapping);
          // Заменить локальные ЛЭП на серверные: перенос опор, сессий обхода, вставка строки с server id, удаление локальной
          for (final pl in powerLines) {
            if (pl.id >= 0) continue;
            final serverIdRaw = plMapping[pl.id.toString()];
            final int? serverId = serverIdRaw is int
                ? serverIdRaw
                : (serverIdRaw is num ? serverIdRaw.toInt() : int.tryParse(serverIdRaw?.toString() ?? ''));
            if (serverId == null || serverId <= 0) continue;
            // Переносим опоры и локальные сессии обхода со старого id ЛЭП на новый серверный id
            await _database.updatePolesLineId(pl.id, serverId);
            await _database.updatePatrolSessionsPowerLineId(pl.id, serverId);
            await _database.insertPowerLineOrReplace(
              PowerLinesCompanion.insert(
                id: drift.Value(serverId),
                name: pl.name,
                code: pl.name,
                mrid: pl.mrid != null && pl.mrid!.trim().isNotEmpty ? drift.Value(pl.mrid!) : const drift.Value.absent(),
                voltageLevel: pl.voltageLevel,
                length: pl.length != null ? drift.Value(pl.length!) : const drift.Value.absent(),
                branchId: pl.branchId,
                createdBy: pl.createdBy,
                status: pl.status,
                description: drift.Value(pl.description),
                createdAt: pl.createdAt,
                updatedAt: drift.Value(pl.updatedAt),
                isLocal: const drift.Value(false),
                needsSync: const drift.Value(false),
              ),
            );
            await _database.deletePowerLine(pl.id);
            if (_prefs != null) {
              final sessionLineId = _prefs!.getInt(AppConfig.activeSessionPowerLineIdKey);
              if (sessionLineId == pl.id) {
                await _prefs!.setInt(AppConfig.activeSessionPowerLineIdKey, serverId);
              }
            }
          }
      }
      for (final eq in equipmentToSync) {
        if (equipmentWithPendingAttachmentUpload.contains(eq.id)) {
          continue;
        }
        if (eq.id > 0) {
          await _database.setEquipmentNeedsSync(eq.id, false);
        }
      }
      for (final pl in powerLines) {
        if (pl.id >= 0) await _database.setPowerLineNeedsSync(pl.id, false);
      }
      return SyncUploadResult(
        deletedPowerLineIds: pendingDeletePlIds.toSet(),
        deletedPoleIds: pendingDeletePoleIds.toSet(),
        deletedEquipmentIds: pendingDeleteEquipmentIds.toSet(),
      );
    }
    return null;
  }

  bool _lineMatchesScope(int entityLineId, int? scopeLineId) {
    if (scopeLineId == null) return true;
    if (entityLineId == scopeLineId) return true;
    final mapping = _getSyncPowerLineMapping();
    if (entityLineId < 0 && mapping[entityLineId] == scopeLineId) return true;
    if (scopeLineId < 0 && mapping[scopeLineId] == entityLineId) return true;
    if (scopeLineId < 0 &&
        entityLineId < 0 &&
        mapping[scopeLineId] != null &&
        mapping[scopeLineId] == mapping[entityLineId]) {
      return true;
    }
    return false;
  }

  Future<List<int>> _filterPendingDeletePowerLineIds(int? scopeLineId) async {
    final ids = _getPendingDeletePowerLineIds();
    if (scopeLineId == null) return ids;
    return ids.where((id) => _lineMatchesScope(id, scopeLineId)).toList();
  }

  Future<List<int>> _filterPendingDeletePoleIds(int? scopeLineId) async {
    final ids = _getPendingDeletePoleIds();
    if (scopeLineId == null) return ids;
    final out = <int>[];
    for (final id in ids) {
      final pole = await _database.getPole(id);
      if (pole != null && _lineMatchesScope(pole.lineId, scopeLineId)) out.add(id);
    }
    return out;
  }

  Future<List<int>> _filterPendingDeleteEquipmentIds(int? scopeLineId) async {
    final ids = _getPendingDeleteEquipmentIds();
    if (scopeLineId == null) return ids;
    final out = <int>[];
    for (final id in ids) {
      final eq = await _database.getEquipment(id);
      if (eq == null) continue;
      final pole = await _database.getPole(eq.poleId);
      if (pole != null && _lineMatchesScope(pole.lineId, scopeLineId)) out.add(id);
    }
    return out;
  }

  void _applyUploadDeleteCleanup(SyncUploadResult result, {required bool fullUpload}) {
    if (fullUpload) {
      _clearPendingDeletePowerLineIds();
      _clearPendingDeletePoleIds();
      _clearPendingDeleteEquipmentIds();
      return;
    }
    _removeFromPendingDeleteList(
      AppConfig.pendingDeletePowerLineIdsKey,
      result.deletedPowerLineIds,
    );
    _removeFromPendingDeleteList(
      AppConfig.pendingDeletePoleIdsKey,
      result.deletedPoleIds,
    );
    _removeFromPendingDeleteList(
      AppConfig.pendingDeleteEquipmentIdsKey,
      result.deletedEquipmentIds,
    );
  }

  void _removeFromPendingDeleteList(String key, Set<int> removeIds) {
    if (_prefs == null || removeIds.isEmpty) return;
    final list = _prefs!.getStringList(key) ?? [];
    final next = list.where((s) {
      final id = int.tryParse(s);
      return id == null || !removeIds.contains(id);
    }).toList();
    _prefs!.setStringList(key, next);
  }

  Map<int, int> _getSyncPoleMapping() {
    if (_prefs == null) return {};
    final json = _prefs!.getString(AppConfig.syncPoleMappingKey);
    if (json == null || json.isEmpty) return {};
    try {
      final map = jsonDecode(json) as Map;
      return map.map((k, v) => MapEntry(
        int.tryParse(k.toString()) ?? 0,
        v is int ? v : (v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0),
      ));
    } catch (_) {
      return {};
    }
  }

  void _saveSyncPoleMapping(Map<String, dynamic> newMapping) {
    if (_prefs == null || newMapping.isEmpty) return;
    final current = _getSyncPoleMapping();
    for (final e in newMapping.entries) {
      final k = int.tryParse(e.key.toString());
      final v = e.value is int ? e.value as int : (e.value is num ? (e.value as num).toInt() : int.tryParse(e.value?.toString() ?? ''));
      if (k != null && v != null) current[k] = v;
    }
    final toSave = current.map((k, v) => MapEntry(k.toString(), v));
    _prefs!.setString(AppConfig.syncPoleMappingKey, jsonEncode(toSave));
  }

  Map<int, int> _getSyncPowerLineMapping() {
    if (_prefs == null) return {};
    final json = _prefs!.getString(AppConfig.syncPowerLineMappingKey);
    if (json == null || json.isEmpty) return {};
    try {
      final map = jsonDecode(json) as Map;
      return map.map((k, v) => MapEntry(
        int.tryParse(k.toString()) ?? 0,
        v is int ? v : (v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0),
      ));
    } catch (_) {
      return {};
    }
  }

  void _saveSyncPowerLineMapping(Map<String, dynamic> newMapping) {
    if (_prefs == null || newMapping.isEmpty) return;
    final current = _getSyncPowerLineMapping();
    for (final e in newMapping.entries) {
      final k = int.tryParse(e.key.toString());
      final v = e.value is int ? e.value as int : (e.value is num ? (e.value as num).toInt() : int.tryParse(e.value?.toString() ?? ''));
      if (k != null && v != null) current[k] = v;
    }
    final toSave = current.map((k, v) => MapEntry(k.toString(), v));
    _prefs!.setString(AppConfig.syncPowerLineMappingKey, jsonEncode(toSave));
  }

  List<int> _getPendingDeletePowerLineIds() {
    if (_prefs == null) return [];
    final list = _prefs!.getStringList(AppConfig.pendingDeletePowerLineIdsKey) ?? [];
    return list.map((s) => int.tryParse(s)).whereType<int>().toList();
  }

  void _clearPendingDeletePowerLineIds() {
    _prefs?.setStringList(AppConfig.pendingDeletePowerLineIdsKey, []);
  }

  List<int> _getPendingDeletePoleIds() {
    if (_prefs == null) return [];
    final list = _prefs!.getStringList(AppConfig.pendingDeletePoleIdsKey) ?? [];
    return list.map((s) => int.tryParse(s)).whereType<int>().toList();
  }

  void _clearPendingDeletePoleIds() {
    _prefs?.setStringList(AppConfig.pendingDeletePoleIdsKey, []);
  }

  List<int> _getPendingDeleteEquipmentIds() {
    if (_prefs == null) return [];
    final list = _prefs!.getStringList(AppConfig.pendingDeleteEquipmentIdsKey) ?? [];
    return list.map((s) => int.tryParse(s)).whereType<int>().toList();
  }

  void _clearPendingDeleteEquipmentIds() {
    _prefs?.setStringList(AppConfig.pendingDeleteEquipmentIdsKey, []);
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

  static bool? _parseBoolNullable(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    final s = v.toString().trim().toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes' || s == 'да') return true;
    if (s == 'false' || s == '0' || s == 'no' || s == 'нет') return false;
    return null;
  }

  Map<String, dynamic> _equipmentToJson(EquipmentData equipment, Map<int, int> poleMapping) {
    final map = <String, dynamic>{
      'id': equipment.id,
      'pole_id': equipment.poleId,
      'equipment_type': equipment.equipmentType,
      'name': equipment.name,
      'quantity': equipment.quantity,
      'condition': equipment.condition,
      'created_by': equipment.createdBy,
      'created_at': equipment.createdAt.toIso8601String(),
      'updated_at': equipment.updatedAt?.toIso8601String(),
    };
    void put(String k, Object? v) {
      if (v != null) map[k] = v;
    }

    put('manufacturer', equipment.manufacturer);
    put('model', equipment.model);
    put('serial_number', equipment.serialNumber);
    put('year_manufactured', equipment.yearManufactured);
    put('installation_date', equipment.installationDate?.toIso8601String());
    put('notes', equipment.notes);
    put('defect', equipment.defect);
    put('criticality', equipment.criticality);
    put('defect_attachment', equipment.defectAttachment);
    put('mrid', equipment.mrid);
    put('catalog_item_id', equipment.catalogItemId);
    put('rated_current', equipment.ratedCurrent);
    put('i_th', equipment.iTh);
    put('ip_max', equipment.ipMax);
    put('t_th', equipment.tTh);
    put('normal_open', equipment.normalOpen);
    put('retained', equipment.retained);
    put('identified_object_description', equipment.identifiedObjectDescription);
    put('nameplate', equipment.nameplate);
    put('psr_subtype', equipment.psrSubtype);
    put('installation_display_name', equipment.installationDisplayName);
    put('tm_code', equipment.tmCode);
    put('object_subtype', equipment.objectSubtype);
    put('pole_count', equipment.poleCount);
    put('parent_object_ref', equipment.parentObjectRef);
    put('parent_main_equipment_pole_ref', equipment.parentMainEquipmentPoleRef);
    put('nominal_voltage_kv', equipment.nominalVoltageKv);
    put('nominal_breaking_current_ka', equipment.nominalBreakingCurrentKa);
    put('own_trip_time_sec', equipment.ownTripTimeSec);
    put('emergency_current_a', equipment.emergencyCurrentA);
    put('continuous_current_a', equipment.continuousCurrentA);
    put('arrester_type', equipment.arresterType);
    put('x_position', equipment.xPosition);
    put('y_position', equipment.yPosition);
    put('direction_angle', equipment.directionAngle);
    put('card_comment', equipment.cardComment);
    put('card_comment_attachment', equipment.cardCommentAttachment);

    final serverPoleId = poleMapping[equipment.poleId];
    if (serverPoleId != null && serverPoleId > 0) {
      map['pole_server_id'] = serverPoleId;
    }
    return map;
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
  static int? _toIntOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
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
        final serverMrid = data['mrid'] as String?;
        final serverName = (data['name'] as String?)?.trim() ?? '';
        final createdAt = _parseDateTime(data['created_at']) ?? DateTime.now();
        final updatedAt = _parseDateTime(data['updated_at']);

        // Дедупликация: если есть локальная ЛЭП с тем же mrid или именем — переносим опоры на серверный id и удаляем дубликат
        final localDup = await _database.getLocalPowerLineByMridOrName(
          serverMrid?.trim().isNotEmpty == true ? serverMrid : null,
          serverName.isEmpty ? 'ЛЭП' : serverName,
        );
        if (localDup != null && localDup.id < 0 && localDup.id != id) {
          await _database.updatePolesLineId(localDup.id, id);
          await _database.deletePowerLine(localDup.id);
        }

        final codeStr = data['code'] as String?;
        final branchIdVal = _toInt(data['branch_id']);
        await _database.insertPowerLineOrReplace(
          PowerLinesCompanion.insert(
            id: drift.Value(id),
            name: serverName.isEmpty ? 'ЛЭП' : serverName,
            code: (codeStr != null && codeStr.trim().isNotEmpty) ? codeStr : (serverName.isEmpty ? 'ЛЭП' : serverName),
            mrid: serverMrid != null && serverMrid.trim().isNotEmpty ? drift.Value(serverMrid) : const drift.Value.absent(),
            voltageLevel: _toDouble(data['voltage_level']),
            length: drift.Value(data['length'] != null ? _toDouble(data['length']) : null),
            branchId: branchIdVal != 0 ? branchIdVal : 1,
            createdBy: _toInt(data['created_by']),
            status: data['status'] as String? ?? 'active',
            description: drift.Value(data['description'] as String?),
            createdAt: createdAt,
            updatedAt: drift.Value(updatedAt),
          ),
        );
        break;
      case 'delete':
        final plId = _toInt(data['id']);
        if (plId != 0) {
          await _deleteLocalPowerLineCascade(plId);
        }
        break;
    }
  }

  /// Локальный каскад при удалении ЛЭП с сервера:
  /// удаляем оборудование и опоры линии, сессии обхода и саму линию.
  Future<void> _deleteLocalPowerLineCascade(int powerLineId) async {
    final poles = await _database.getPolesByLine(powerLineId);
    for (final p in poles) {
      final eqList = await _database.getEquipmentByPole(p.id);
      for (final eq in eqList) {
        await _database.deleteEquipment(eq.id);
      }
      await _database.deletePole(p.id);
    }
    await _database.deletePatrolSessionsByLineId(powerLineId);
    await _database.deletePowerLine(powerLineId);
  }

  Future<void> _processPoleRecord(String action, Map<String, dynamic> data) async {
    switch (action) {
      case 'create':
      case 'update':
        final id = _toInt(data['id']);
        final lineId = _toInt(data['line_id']);
        final createdAt = _parseDateTime(data['created_at']) ?? DateTime.now();
        final updatedAt = _parseDateTime(data['updated_at']);

        final existingBeforeMerge = await _database.getPole(id);

        // Локальные правки, ещё не отправленные — не затираем download с сервера.
        if (existingBeforeMerge?.needsSync == true) {
          return;
        }

        // Координаты, пришедшие с сервера (или из longitude/latitude).
        double? xPos =
            data['x_position'] != null ? _toDouble(data['x_position']) : null;
        if (data['longitude'] != null) {
          xPos = _toDouble(data['longitude']);
        }
        double? yPos =
            data['y_position'] != null ? _toDouble(data['y_position']) : null;
        if (data['latitude'] != null) {
          yPos = _toDouble(data['latitude']);
        }

        final serverSentCoords =
            (xPos != null && yPos != null && (xPos != 0 || yPos != 0));

        // Если сервер не прислал валидные координаты, пробуем сохранить локальные.
        if (!serverSentCoords) {
          if (existingBeforeMerge != null &&
              (existingBeforeMerge.xPosition != 0 ||
                  existingBeforeMerge.yPosition != 0)) {
            xPos = existingBeforeMerge.xPosition;
            yPos = existingBeforeMerge.yPosition;
          }
        }

        final xFinal = xPos ?? 0.0;
        final yFinal = yPos ?? 0.0;

        // Сервер в sync/download может не прислать card_* — insertOrReplace иначе затирает локальные вложения.
        final serverAttach = data['card_comment_attachment'] as String?;
        final mergedAttachItems = _mergePoleAttachmentItems(
          serverAttach,
          existingBeforeMerge?.cardCommentAttachment,
        );
        final mergedAttach =
            mergedAttachItems.isEmpty ? null : jsonEncode(mergedAttachItems);

        final mergedSeq = data['sequence_number'] != null
            ? _toIntOrNull(data['sequence_number'])
            : existingBeforeMerge?.sequenceNumber;
        final mergedBranch = data['branch_type'] as String? ??
            existingBeforeMerge?.branchType;
        final mergedTapId = data['tap_pole_id'] != null
            ? _toIntOrNull(data['tap_pole_id'])
            : existingBeforeMerge?.tapPoleId;
        final mergedTapBi = data['tap_branch_index'] != null
            ? _toIntOrNull(data['tap_branch_index'])
            : existingBeforeMerge?.tapBranchIndex;
        final mergedIsTap = _parseBoolNullable(data['is_tap_pole']) ??
            existingBeforeMerge?.isTapPole ??
            false;

        final merged = mergePoleFromServerDownload(
          local: existingBeforeMerge,
          server: data,
          serverX: xFinal,
          serverY: yFinal,
          serverSentCoords: serverSentCoords,
          mergedSequenceNumber: mergedSeq,
          mergedBranchType: mergedBranch,
          mergedTapPoleId: mergedTapId,
          mergedTapBranchIndex: mergedTapBi,
          mergedIsTapPole: mergedIsTap,
        );

        await _database.insertPoleOrReplace(
          PolesCompanion.insert(
            id: drift.Value(id),
            lineId: lineId,
            poleNumber: merged.poleNumber,
            mrid: drift.Value(data['mrid'] as String?),
            xPosition: drift.Value(merged.xPosition),
            yPosition: drift.Value(merged.yPosition),
            poleType: drift.Value(merged.poleType ?? 'unknown'),
            height: drift.Value(merged.height),
            foundationType: drift.Value(merged.foundationType),
            material: drift.Value(merged.material),
            yearInstalled: drift.Value(merged.yearInstalled),
            condition: drift.Value(merged.condition),
            notes: drift.Value(merged.notes),
            structuralDefect: drift.Value(merged.structuralDefect),
            structuralDefectCriticality:
                drift.Value(merged.structuralDefectCriticality),
            cardComment: drift.Value(merged.cardComment),
            cardCommentAttachment: drift.Value(mergedAttach),
            sequenceNumber: drift.Value(merged.sequenceNumber),
            branchType: drift.Value(merged.branchType),
            tapPoleId: drift.Value(merged.tapPoleId),
            tapBranchIndex: drift.Value(merged.tapBranchIndex),
            isTapPole: drift.Value(merged.isTapPole),
            conductorType: drift.Value(merged.conductorType),
            conductorMaterial: drift.Value(merged.conductorMaterial),
            conductorSection: drift.Value(merged.conductorSection),
            createdBy: _toInt(data['created_by']),
            createdAt: createdAt,
            updatedAt: drift.Value(updatedAt),
            isLocal: const drift.Value(false),
            needsSync: const drift.Value(false),
          ),
        );
        break;
      case 'delete':
        final poleId = _toInt(data['id']);
        if (poleId != 0) {
          final eqList = await _database.getEquipmentByPole(poleId);
          for (final eq in eqList) {
            await _database.deleteEquipment(eq.id);
          }
          await _database.deletePole(poleId);
        }
        break;
    }
  }

  Future<void> _processEquipmentRecord(String action, Map<String, dynamic> data) async {
    switch (action) {
      case 'create':
      case 'update':
        final id = _toInt(data['id']);
        final existing = await _database.getEquipment(id);
        final poleId = _toInt(data['pole_id'] ?? data['tower_id']);
        final serverComment = data['card_comment'] as String?;
        final serverAttach = data['card_comment_attachment'] as String?;
        String? mergedComment = serverComment;
        if (mergedComment == null || mergedComment.isEmpty) {
          final ex = existing?.cardComment;
          if (ex != null && ex.isNotEmpty) mergedComment = ex;
        }
        final mergedAttachItems = _mergePoleAttachmentItems(
          serverAttach,
          existing?.cardCommentAttachment,
        );
        final mergedAttach =
            mergedAttachItems.isEmpty ? null : jsonEncode(mergedAttachItems);
        final keepNeedsSyncLocal = existing?.needsSync ?? false;
        await _database.insertEquipmentOrReplace(
          EquipmentCompanion.insert(
            id: drift.Value(id),
            poleId: poleId,
            equipmentType: data['equipment_type'] as String? ?? '',
            name: data['name'] as String? ?? '',
            quantity: drift.Value(
              data['quantity'] != null ? _toInt(data['quantity']) : (existing?.quantity ?? 1),
            ),
            defect: drift.Value(data['defect'] as String? ?? existing?.defect),
            criticality: drift.Value(data['criticality'] as String? ?? existing?.criticality),
            defectAttachment:
                drift.Value(data['defect_attachment'] as String? ?? existing?.defectAttachment),
            cardComment: drift.Value(mergedComment),
            cardCommentAttachment: drift.Value(mergedAttach),
            manufacturer: drift.Value(data['manufacturer'] as String? ?? existing?.manufacturer),
            model: drift.Value(data['model'] as String? ?? existing?.model),
            serialNumber: drift.Value(data['serial_number'] as String? ?? existing?.serialNumber),
            yearManufactured: drift.Value(
              data['year_manufactured'] != null
                  ? _toInt(data['year_manufactured'])
                  : existing?.yearManufactured,
            ),
            installationDate: drift.Value(
              data['installation_date'] != null
                  ? DateTime.parse(data['installation_date'].toString())
                  : existing?.installationDate,
            ),
            condition: data['condition'] as String? ?? existing?.condition ?? 'good',
            notes: drift.Value(data['notes'] as String? ?? existing?.notes),
            mrid: drift.Value(data['mrid'] as String? ?? existing?.mrid),
            catalogItemId: drift.Value(
              data['catalog_item_id'] != null
                  ? _toInt(data['catalog_item_id'])
                  : existing?.catalogItemId,
            ),
            ratedCurrent: drift.Value(
              data['rated_current'] != null
                  ? _toDouble(data['rated_current'])
                  : existing?.ratedCurrent,
            ),
            iTh: drift.Value(data['i_th'] != null ? _toDouble(data['i_th']) : existing?.iTh),
            ipMax: drift.Value(data['ip_max'] != null ? _toDouble(data['ip_max']) : existing?.ipMax),
            tTh: drift.Value(data['t_th'] != null ? _toDouble(data['t_th']) : existing?.tTh),
            normalOpen:
                drift.Value(_parseBoolNullable(data['normal_open']) ?? existing?.normalOpen),
            retained: drift.Value(_parseBoolNullable(data['retained']) ?? existing?.retained),
            identifiedObjectDescription: drift.Value(
              data['identified_object_description'] as String? ??
                  existing?.identifiedObjectDescription,
            ),
            nameplate: drift.Value(data['nameplate'] as String? ?? existing?.nameplate),
            psrSubtype: drift.Value(data['psr_subtype'] as String? ?? existing?.psrSubtype),
            installationDisplayName: drift.Value(
              data['installation_display_name'] as String? ?? existing?.installationDisplayName,
            ),
            tmCode: drift.Value(data['tm_code'] as String? ?? existing?.tmCode),
            objectSubtype: drift.Value(data['object_subtype'] as String? ?? existing?.objectSubtype),
            poleCount: drift.Value(
              data['pole_count'] != null ? _toInt(data['pole_count']) : existing?.poleCount,
            ),
            parentObjectRef:
                drift.Value(data['parent_object_ref'] as String? ?? existing?.parentObjectRef),
            parentMainEquipmentPoleRef: drift.Value(
              data['parent_main_equipment_pole_ref'] as String? ??
                  existing?.parentMainEquipmentPoleRef,
            ),
            nominalVoltageKv: drift.Value(
              data['nominal_voltage_kv'] != null
                  ? _toDouble(data['nominal_voltage_kv'])
                  : existing?.nominalVoltageKv,
            ),
            nominalBreakingCurrentKa: drift.Value(
              data['nominal_breaking_current_ka'] != null
                  ? _toDouble(data['nominal_breaking_current_ka'])
                  : existing?.nominalBreakingCurrentKa,
            ),
            ownTripTimeSec: drift.Value(
              data['own_trip_time_sec'] != null
                  ? _toDouble(data['own_trip_time_sec'])
                  : existing?.ownTripTimeSec,
            ),
            emergencyCurrentA: drift.Value(
              data['emergency_current_a'] != null
                  ? _toDouble(data['emergency_current_a'])
                  : existing?.emergencyCurrentA,
            ),
            continuousCurrentA: drift.Value(
              data['continuous_current_a'] != null
                  ? _toDouble(data['continuous_current_a'])
                  : existing?.continuousCurrentA,
            ),
            arresterType: drift.Value(data['arrester_type'] as String? ?? existing?.arresterType),
            xPosition: drift.Value(
              data['x_position'] != null ? _toDouble(data['x_position']) : existing?.xPosition,
            ),
            yPosition: drift.Value(
              data['y_position'] != null ? _toDouble(data['y_position']) : existing?.yPosition,
            ),
            directionAngle: drift.Value(
              data['direction_angle'] != null
                  ? _toDouble(data['direction_angle'])
                  : existing?.directionAngle,
            ),
            createdBy: _toInt(data['created_by']),
            createdAt: _parseDateTime(data['created_at']) ?? DateTime.now(),
            updatedAt: drift.Value(_parseDateTime(data['updated_at']) ?? existing?.updatedAt),
            isLocal: drift.Value(existing?.isLocal ?? false),
            needsSync: drift.Value(keepNeedsSyncLocal),
          ),
        );
        break;
      case 'delete':
        await _database.deleteEquipment(_toInt(data['id']));
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

  static int _comparePolesForUpload(Pole a, Pole b) {
    final lc = a.lineId.compareTo(b.lineId);
    if (lc != 0) return lc;
    final ta = a.tapPoleId ?? 0;
    final tb = b.tapPoleId ?? 0;
    if (ta != tb) return ta.compareTo(tb);
    final ba = a.tapBranchIndex ?? 1;
    final bb = b.tapBranchIndex ?? 1;
    if (ba != bb) return ba.compareTo(bb);
    final sa = a.sequenceNumber ?? 0;
    final sb = b.sequenceNumber ?? 0;
    if (sa != sb) return sa.compareTo(sb);
    return a.createdAt.compareTo(b.createdAt);
  }
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
