import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

import '../config/app_config.dart';
import '../database/database.dart';
import '../models/power_line.dart' show PoleCreate;
import 'api_service.dart';
import 'attachment_reader.dart';
import 'auth_service.dart'; // prefsProvider
import '../models/sync_state.dart';

export '../models/sync_state.dart';

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

      // Локальные данные не удаляем: выгруженные сущности остаются в БД вместе с загруженными с сервера.
      if (uploadResult != null) {
        _clearPendingDeletePowerLineIds();
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
        state = const SyncState.completed();
      }
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
  Future<void> _uploadPatrolSessions() async {
    final pending = await _database.getPendingPatrolSessions();
    for (final row in pending) {
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

    // Создание: сначала ЛЭП (бэкенд требует name, voltage_level)
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
    for (final pole in poles) {
      var poleData = _toSnakeCaseMap(pole.toJson());
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
          final list = jsonDecode(attachmentJson) as List<dynamic>;
          final resolved = <Map<String, dynamic>>[];
          List<Map<String, dynamic>>? pendingForNew;
          for (final e in list) {
            if (e is! Map) continue;
            final m = Map<String, dynamic>.from(e as Map);
            if (m['url'] != null) {
              resolved.add(m);
              continue;
            }
            final path = m['p'] as String?;
            if (path == null || path.isEmpty) continue;
            final type = m['t'] as String? ?? 'photo';
            if (pole.id > 0) {
              try {
                final bytes = await readAttachmentBytes(path);
                if (bytes.isEmpty) continue;
                final ext = path.contains('.') ? path.split('.').last : 'jpg';
                final filename = 'upload.$ext';
                final result = await _apiService.uploadPoleAttachment(pole.id, type, bytes, filename);
                final url = result['url'] as String?;
                if (url != null) {
                  final entry = <String, dynamic>{'t': type, 'url': url};
                  if (result['thumbnail_url'] != null) entry['thumbnail_url'] = result['thumbnail_url'];
                  resolved.add(entry);
                }
              } catch (_) {
                // файл удалён или сеть — пропускаем
              }
            } else {
              pendingForNew ??= [];
              pendingForNew.add(m);
            }
          }
          if (pole.id > 0) {
            final enc = resolved.isEmpty ? null : jsonEncode(resolved);
            poleData['card_comment_attachment'] = enc;
            if (enc != null) {
              poleCardAttachmentAfterUpload[pole.id] = enc;
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
      records.add(_createSyncRecord('pole', 'create', poleData, batchId));
    }

    // Оборудование: передаём pole_server_id из сохранённого маппинга, если опора уже синхронизирована ранее.
    // Если для локального pole_id нет ни серверного id, ни самой опоры в текущем пакете —
    // считаем запись устаревшей/дублем и переводим её в состояние «не требует синхронизации», не отправляя на сервер.
    final poleMapping = _getSyncPoleMapping();
    final polesInBatch = poles.map((p) => p.id).toSet();
    final List<EquipmentData> equipmentToSync = [];
    for (final eq in equipment) {
      final poleId = eq.poleId;
      final serverPoleId = poleMapping[poleId];
      final hasPoleInBatch = polesInBatch.contains(poleId);
      final canSync = poleId > 0 || (serverPoleId != null && serverPoleId > 0) || hasPoleInBatch;
      if (!canSync) {
        // Старые локальные записи, для которых невозможно восстановить связь с опорой, помечаем как «синхронизированные» локально.
        await _database.setEquipmentNeedsSync(eq.id, false);
        continue;
      }
      equipmentToSync.add(eq);
      records.add(_createSyncRecord('equipment', 'create', _equipmentToJson(eq, poleMapping), batchId));
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
          if (clientId != null) {
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
        for (final m in item.pending) {
          final path = m['p'] as String?;
          if (path == null || path.isEmpty) continue;
          final type = m['t'] as String? ?? 'photo';
          try {
            final bytes = await readAttachmentBytes(path);
            if (bytes.isEmpty) continue;
            final ext = path.contains('.') ? path.split('.').last : 'jpg';
            final result = await _apiService.uploadPoleAttachment(serverPoleId, type, bytes, 'upload.$ext');
            final url = result['url'] as String?;
            if (url != null) {
              final entry = <String, dynamic>{'t': type, 'url': url};
              if (result['thumbnail_url'] != null) entry['thumbnail_url'] = result['thumbnail_url'];
              resolved.add(entry);
            }
          } catch (e, st) {
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
          cardComment: pole.cardComment,
          cardCommentAttachment: resolved.isEmpty ? null : jsonEncode(resolved),
        );
        try {
          await _apiService.updatePole(serverLineId, serverPoleId, poleCreate);
          final attJson =
              resolved.isEmpty ? null : jsonEncode(resolved);
          await _database.setPoleCardCommentAttachment(item.pole.id, attJson);
        } catch (e, st) {
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
        await _database.setEquipmentNeedsSync(eq.id, false);
      }
      for (final pl in powerLines) {
        if (pl.id >= 0) await _database.setPowerLineNeedsSync(pl.id, false);
      }
      return (powerLines, poles, equipment);
    }
    return null;
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

  Map<String, dynamic> _equipmentToJson(EquipmentData equipment, Map<int, int> poleMapping) {
    final map = <String, dynamic>{
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
        final serverComment = data['card_comment'] as String?;
        final serverAttach = data['card_comment_attachment'] as String?;
        String? mergedComment = serverComment;
        if (mergedComment == null || mergedComment.isEmpty) {
          final ex = existingBeforeMerge?.cardComment;
          if (ex != null && ex.isNotEmpty) mergedComment = ex;
        }
        String? mergedAttach = serverAttach;
        if (mergedAttach == null || mergedAttach.isEmpty) {
          final ex = existingBeforeMerge?.cardCommentAttachment;
          if (ex != null && ex.isNotEmpty) mergedAttach = ex;
        }

        await _database.insertPoleOrReplace(
          PolesCompanion.insert(
            id: drift.Value(id),
            lineId: lineId,
            poleNumber: data['pole_number'] as String? ?? '',
            // Используем координаты с сервера или сохраняем локальные (xFinal/yFinal),
            // оборачивая в Value для Drift.
            xPosition: drift.Value(xFinal),
            yPosition: drift.Value(yFinal),
            poleType: drift.Value(data['pole_type'] as String? ?? 'unknown'),
            height: drift.Value(
                data['height'] != null ? _toDouble(data['height']) : null),
            foundationType: drift.Value(data['foundation_type'] as String?),
            material: drift.Value(data['material'] as String?),
            yearInstalled: drift.Value(
                data['year_installed'] != null ? _toInt(data['year_installed']) : null),
            condition: drift.Value(data['condition'] as String? ?? 'good'),
            notes: drift.Value(data['notes'] as String?),
            cardComment: drift.Value(mergedComment),
            cardCommentAttachment: drift.Value(mergedAttach),
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
