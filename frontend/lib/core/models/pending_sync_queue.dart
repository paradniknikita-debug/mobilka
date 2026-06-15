/// Элемент очереди синхронизации.
class PendingSyncQueue {
  const PendingSyncQueue({
    required this.lineGroups,
    required this.patrolSessions,
  });

  final List<PendingLineSyncGroup> lineGroups;
  final List<PendingPatrolSyncItem> patrolSessions;

  int get totalItems =>
      lineGroups.fold(0, (sum, g) => sum + g.itemCount) + patrolSessions.length;

  bool get isEmpty => totalItems == 0;
}

class PendingLineSyncGroup {
  const PendingLineSyncGroup({
    required this.lineId,
    required this.lineName,
    required this.linePending,
    required this.poles,
    required this.equipment,
    required this.deletes,
  });

  final int lineId;
  final String lineName;
  final bool linePending;
  final List<PendingPoleSyncItem> poles;
  final List<PendingEquipmentSyncItem> equipment;
  final List<PendingDeleteSyncItem> deletes;

  int get itemCount =>
      (linePending ? 1 : 0) + poles.length + equipment.length + deletes.length;
}

class PendingPoleSyncItem {
  const PendingPoleSyncItem({
    required this.id,
    required this.poleNumber,
    required this.isNew,
    this.sequenceNumber,
  });

  final int id;
  final String poleNumber;
  final bool isNew;
  final int? sequenceNumber;
}

class PendingEquipmentSyncItem {
  const PendingEquipmentSyncItem({
    required this.id,
    required this.name,
    required this.poleId,
    required this.isNew,
  });

  final int id;
  final String name;
  final int poleId;
  final bool isNew;
}

class PendingDeleteSyncItem {
  const PendingDeleteSyncItem({
    required this.entityType,
    required this.id,
    required this.label,
  });

  final String entityType;
  final int id;
  final String label;
}

class PendingPatrolSyncItem {
  const PendingPatrolSyncItem({
    required this.id,
    required this.lineId,
    required this.lineName,
    required this.statusLabel,
  });

  final int id;
  final int lineId;
  final String lineName;
  final String statusLabel;
}
