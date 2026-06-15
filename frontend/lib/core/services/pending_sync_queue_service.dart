import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../database/database.dart';
import '../models/pending_sync_queue.dart';
import 'auth_service.dart';

/// Собирает детальную очередь несинхронизированных данных.
class PendingSyncQueueService {
  PendingSyncQueueService(this._db, this._prefs);

  final AppDatabase _db;
  final SharedPreferences? _prefs;

  Future<PendingSyncQueue> load() async {
    final lineNameCache = <int, String>{};
    Future<String> lineName(int lineId) async {
      if (lineNameCache.containsKey(lineId)) return lineNameCache[lineId]!;
      final pl = await _db.getPowerLine(lineId);
      final name = pl?.name.trim();
      final label = (name != null && name.isNotEmpty) ? name : 'ЛЭП #$lineId';
      lineNameCache[lineId] = label;
      return label;
    }

    final groups = <int, _MutableLineGroup>{};

    Future<_MutableLineGroup> groupFor(int lineId) async {
      final existing = groups[lineId];
      if (existing != null) return existing;
      final g = _MutableLineGroup(lineId: lineId, lineName: await lineName(lineId));
      groups[lineId] = g;
      return g;
    }

    for (final pl in await _db.getPowerLinesNeedingSync()) {
      final g = await groupFor(pl.id);
      g.linePending = true;
      g.lineName = pl.name.trim().isNotEmpty ? pl.name : g.lineName;
    }

    for (final pole in await _db.getPolesNeedingSync()) {
      final g = await groupFor(pole.lineId);
      g.poles.add(
        PendingPoleSyncItem(
          id: pole.id,
          poleNumber: pole.poleNumber,
          isNew: pole.id < 0,
          sequenceNumber: pole.sequenceNumber,
        ),
      );
    }

    for (final eq in await _db.getEquipmentNeedingSync()) {
      final pole = await _db.getPole(eq.poleId);
      if (pole == null) continue;
      final g = await groupFor(pole.lineId);
      g.equipment.add(
        PendingEquipmentSyncItem(
          id: eq.id,
          name: eq.name,
          poleId: eq.poleId,
          isNew: eq.id < 0,
        ),
      );
    }

    final plDeletes = _prefs?.getStringList(AppConfig.pendingDeletePowerLineIdsKey) ?? [];
    for (final s in plDeletes) {
      final id = int.tryParse(s);
      if (id == null) continue;
      final g = await groupFor(id);
      g.deletes.add(
        PendingDeleteSyncItem(
          entityType: 'power_line',
          id: id,
          label: 'Удаление ЛЭП #$id',
        ),
      );
    }

    final poleDeletes = _prefs?.getStringList(AppConfig.pendingDeletePoleIdsKey) ?? [];
    for (final s in poleDeletes) {
      final id = int.tryParse(s);
      if (id == null) continue;
      final pole = await _db.getPole(id);
      if (pole == null) continue;
      final g = await groupFor(pole.lineId);
      g.deletes.add(
        PendingDeleteSyncItem(
          entityType: 'pole',
          id: id,
          label: 'Удаление опоры ${pole.poleNumber}',
        ),
      );
    }

    final eqDeletes =
        _prefs?.getStringList(AppConfig.pendingDeleteEquipmentIdsKey) ?? [];
    for (final s in eqDeletes) {
      final id = int.tryParse(s);
      if (id == null) continue;
      final eq = await _db.getEquipment(id);
      if (eq == null) continue;
      final pole = await _db.getPole(eq.poleId);
      if (pole == null) continue;
      final g = await groupFor(pole.lineId);
      g.deletes.add(
        PendingDeleteSyncItem(
          entityType: 'equipment',
          id: id,
          label: 'Удаление оборудования ${eq.name}',
        ),
      );
    }

    final patrolItems = <PendingPatrolSyncItem>[];
    for (final row in await _db.getPendingPatrolSessions()) {
      patrolItems.add(
        PendingPatrolSyncItem(
          id: row.id,
          lineId: row.lineId,
          lineName: await lineName(row.lineId),
          statusLabel: row.syncStatus == AppConfig.patrolSessionSyncStatusPendingEnd
              ? 'Завершение обхода'
              : 'Новый обход',
        ),
      );
    }

    final queuedEnds =
        _prefs?.getStringList(AppConfig.pendingEndPatrolServerIdsKey) ?? [];
    for (final _ in queuedEnds) {
      patrolItems.add(
        const PendingPatrolSyncItem(
          id: -1,
          lineId: 0,
          lineName: 'Сервер',
          statusLabel: 'Завершение обхода (очередь)',
        ),
      );
    }

    final sortedGroups = groups.values.toList()
      ..sort((a, b) => a.lineName.compareTo(b.lineName));

    return PendingSyncQueue(
      lineGroups: sortedGroups.map((g) => g.toImmutable()).toList(),
      patrolSessions: patrolItems,
    );
  }
}

class _MutableLineGroup {
  _MutableLineGroup({required this.lineId, required this.lineName});

  final int lineId;
  String lineName;
  bool linePending = false;
  final List<PendingPoleSyncItem> poles = [];
  final List<PendingEquipmentSyncItem> equipment = [];
  final List<PendingDeleteSyncItem> deletes = [];

  PendingLineSyncGroup toImmutable() => PendingLineSyncGroup(
        lineId: lineId,
        lineName: lineName,
        linePending: linePending,
        poles: List.unmodifiable(poles),
        equipment: List.unmodifiable(equipment),
        deletes: List.unmodifiable(deletes),
      );
}

final pendingSyncQueueProvider = FutureProvider<PendingSyncQueue>((ref) async {
  final db = ref.watch(databaseProvider);
  final prefs = ref.watch(prefsProvider);
  return PendingSyncQueueService(db, prefs).load();
});
