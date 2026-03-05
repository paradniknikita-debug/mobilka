import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Условные импорты для разных платформ
import 'database_stub.dart'
    if (dart.library.io) 'database_io.dart'
    if (dart.library.html) 'database_web.dart';

import '../config/app_config.dart';

part 'database.g.dart';

// Таблицы для локальной базы данных

class PowerLines extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get code => text()();
  TextColumn get mrid => text().nullable()();
  RealColumn get voltageLevel => real()();
  RealColumn get length => real().nullable()();
  IntColumn get branchId => integer()();
  IntColumn get createdBy => integer()();
  TextColumn get status => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  BoolColumn get isLocal => boolean().withDefault(const Constant(false))();
  BoolColumn get needsSync => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Poles extends Table {
  IntColumn get id => integer()();
  /// ID линии (ЛЭП). Единое поле line_id (в БД колонка line_id).
  IntColumn get lineId => integer().named('line_id')();
  TextColumn get poleNumber => text()();
  /// Долгота (longitude), CIM x_position
  RealColumn get xPosition => real().nullable()();
  /// Широта (latitude), CIM y_position
  RealColumn get yPosition => real().nullable()();
  TextColumn get poleType => text().nullable()();
  RealColumn get height => real().nullable()();
  TextColumn get foundationType => text().nullable()();
  TextColumn get material => text().nullable()();
  IntColumn get yearInstalled => integer().nullable()();
  TextColumn get condition => text().nullable()();
  TextColumn get notes => text().nullable()();
  /// Комментарий в конце карточки опоры (текст)
  TextColumn get cardComment => text().nullable()();
  /// Вложения к комментарию: голос/фото (JSON: [{"t":"voice"|"photo","p":"path"}])
  TextColumn get cardCommentAttachment => text().nullable()();
  IntColumn get createdBy => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  BoolColumn get isLocal => boolean().withDefault(const Constant(false))();
  BoolColumn get needsSync => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Equipment extends Table {
  IntColumn get id => integer()();
  IntColumn get poleId => integer()();
  TextColumn get equipmentType => text()();
  TextColumn get name => text()();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  TextColumn get defect => text().nullable()();
  TextColumn get criticality => text().nullable()(); // low | medium | high
  /// Вложения к описанию иного дефекта: голос/фото (JSON: [{"t":"voice"|"photo","p":"path"}])
  TextColumn get defectAttachment => text().nullable()();
  TextColumn get manufacturer => text().nullable()();
  TextColumn get model => text().nullable()();
  TextColumn get serialNumber => text().nullable()();
  IntColumn get yearManufactured => integer().nullable()();
  DateTimeColumn get installationDate => dateTime().nullable()();
  TextColumn get condition => text()();
  TextColumn get notes => text().nullable()();
  IntColumn get createdBy => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  BoolColumn get isLocal => boolean().withDefault(const Constant(false))();
  BoolColumn get needsSync => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncRecords extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get action => text()();
  TextColumn get data => text()();
  DateTimeColumn get timestamp => dateTime()();
  IntColumn get userId => integer().nullable()();
  TextColumn get deviceId => text().nullable()();
  TextColumn get status => text()();
  TextColumn get errorMessage => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Локальные сессии обхода ЛЭП. Синхронизация только по кнопке.
class PatrolSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverId => integer().nullable()();
  IntColumn get lineId => integer().named('line_id')();
  TextColumn get note => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  IntColumn get userId => integer().nullable()();
}

@DriftDatabase(tables: [PowerLines, Poles, Equipment, SyncRecords, PatrolSessions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => AppConfig.databaseVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.issueCustomQuery(
              'CREATE TABLE IF NOT EXISTS patrol_sessions ('
              'id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, '
              'server_id INTEGER, '
              'line_id INTEGER NOT NULL, '
              'note TEXT, '
              'started_at DATETIME NOT NULL, '
              'ended_at DATETIME, '
              'sync_status TEXT NOT NULL DEFAULT "pending", '
              'user_id INTEGER)',
            );
          }
          if (from < 3) {
            // CIM: latitude -> y_position, longitude -> x_position (безопасно: если колонки уже переименованы — пропускаем)
            try {
              await migrator.issueCustomQuery(
                'ALTER TABLE poles RENAME COLUMN latitude TO y_position',
              );
            } catch (_) {}
            try {
              await migrator.issueCustomQuery(
                'ALTER TABLE poles RENAME COLUMN longitude TO x_position',
              );
            } catch (_) {}
          }
          if (from < 4) {
            await migrator.addColumn(powerLines, powerLines.mrid);
          }
          if (from < 5) {
            await migrator.addColumn(equipment, equipment.quantity);
            await migrator.addColumn(equipment, equipment.defect);
            await migrator.addColumn(equipment, equipment.criticality);
          }
          if (from < 6) {
            await migrator.addColumn(poles, poles.cardComment);
            await migrator.addColumn(poles, poles.cardCommentAttachment);
            await migrator.addColumn(equipment, equipment.defectAttachment);
          }
          if (from < 7) {
            // Единое именование: power_line_id -> line_id
            try {
              await migrator.issueCustomQuery(
                'ALTER TABLE poles RENAME COLUMN power_line_id TO line_id',
              );
            } catch (_) {}
            try {
              await migrator.issueCustomQuery(
                'ALTER TABLE patrol_sessions RENAME COLUMN power_line_id TO line_id',
              );
            } catch (_) {}
          }
          if (from < 8) {
            // Исправление NULL в is_local/needs_sync (Unexpected null value при map)
            await migrator.issueCustomQuery(
              "UPDATE poles SET is_local = 0 WHERE is_local IS NULL",
            );
            await migrator.issueCustomQuery(
              "UPDATE poles SET needs_sync = 0 WHERE needs_sync IS NULL",
            );
          }
          if (from < 9) {
            // Повторно переименовать longitude/latitude в x_position/y_position для БД, где миграция 3 не сработала
            try {
              await migrator.issueCustomQuery(
                'ALTER TABLE poles RENAME COLUMN longitude TO x_position',
              );
            } catch (_) {}
            try {
              await migrator.issueCustomQuery(
                'ALTER TABLE poles RENAME COLUMN latitude TO y_position',
              );
            } catch (_) {}
          }
        },
      );

  // Методы для работы с ЛЭП
  Future<List<PowerLine>> getAllPowerLines() => select(powerLines).get();
  
  Future<PowerLine?> getPowerLine(int id) => 
      (select(powerLines)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  
  Future<int> insertPowerLine(PowerLinesCompanion powerLine) => 
      into(powerLines).insert(powerLine);
  
  /// Вставка или замена (для синхронизации: запись с сервера по id)
  Future<int> insertPowerLineOrReplace(PowerLinesCompanion powerLine) => 
      into(powerLines).insert(powerLine, mode: InsertMode.insertOrReplace);
  
  Future<bool> updatePowerLine(PowerLinesCompanion powerLine) => 
      update(powerLines).replace(powerLine);
  
  Future<int> deletePowerLine(int id) => 
      (delete(powerLines)..where((tbl) => tbl.id.equals(id))).go();

  /// Удаляет дубликаты ЛЭП: одинаковые по (name, mrid) объединяются в одну запись.
  /// Оставляем запись с приоритетом: серверная (id >= 0) с меньшим id, иначе локальная с меньшим id.
  /// Опоры и сессии обхода с дубликатов перепривязываются к оставляемой линии.
  /// Возвращает количество удалённых дубликатов.
  Future<int> removeDuplicatePowerLines() async {
    final all = await select(powerLines).get();
    final key = (PowerLine pl) => (
      pl.name.trim().toLowerCase(),
      (pl.mrid ?? '').trim().toLowerCase(),
    );
    final groups = <(String, String), List<PowerLine>>{};
    for (final pl in all) {
      final k = key(pl);
      groups.putIfAbsent(k, () => []).add(pl);
    }
    int removed = 0;
    for (final list in groups.values) {
      if (list.length <= 1) continue;
      // Оставляем одну: предпочитаем id >= 0 с меньшим id, иначе с наименьшим id
      list.sort((a, b) {
        final aServer = a.id >= 0;
        final bServer = b.id >= 0;
        if (aServer != bServer) return aServer ? -1 : 1;
        return a.id.compareTo(b.id);
      });
      final keepId = list.first.id;
      for (var i = 1; i < list.length; i++) {
        final dupId = list[i].id;
        await updatePolesLineId(dupId, keepId);
        await (update(patrolSessions)..where((tbl) => tbl.lineId.equals(dupId)))
            .write(PatrolSessionsCompanion(lineId: Value(keepId)));
        await deletePowerLine(dupId);
        removed++;
      }
    }
    return removed;
  }

  /// Обновить line_id у всех опор с fromLineId на toLineId (при слиянии/маппинге ЛЭП).
  Future<int> updatePolesLineId(int fromLineId, int toLineId) =>
      (update(poles)..where((tbl) => tbl.lineId.equals(fromLineId)))
          .write(PolesCompanion(lineId: Value(toLineId)));

  /// Найти локальную ЛЭП (id < 0) по mrid или по имени (для слияния с серверной).
  Future<PowerLine?> getLocalPowerLineByMridOrName(String? mrid, String name) async {
    final nameNorm = name.trim().toLowerCase();
    if (nameNorm.isEmpty) return null;
    final all = await select(powerLines).get();
    for (final pl in all) {
      if (pl.id >= 0) continue;
      if (mrid != null && mrid.trim().isNotEmpty) {
        if (pl.mrid != null && pl.mrid!.trim().toLowerCase() == mrid.trim().toLowerCase()) {
          return pl;
        }
      }
      if (pl.name.trim().toLowerCase() == nameNorm) return pl;
    }
    return null;
  }

  /// Пометить ЛЭП как синхронизированную (после успешного upload).
  Future<int> setPowerLineNeedsSync(int powerLineId, bool needsSync) =>
      (update(powerLines)..where((tbl) => tbl.id.equals(powerLineId)))
          .write(PowerLinesCompanion(needsSync: Value(needsSync)));

  // Методы для работы с опорами
  Future<List<Pole>> getAllPoles() => select(poles).get();
  
  Future<List<Pole>> getPolesByLine(int lineId) =>
      (select(poles)..where((tbl) => tbl.lineId.equals(lineId))).get();
  
  Future<Pole?> getPole(int id) => 
      (select(poles)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  
  Future<int> insertPole(PolesCompanion pole) => 
      into(poles).insert(pole);
  
  Future<int> insertPoleOrReplace(PolesCompanion pole) => 
      into(poles).insert(pole, mode: InsertMode.insertOrReplace);
  
  Future<bool> updatePole(PolesCompanion pole) => 
      update(poles).replace(pole);
  
  Future<int> deletePole(int id) => 
      (delete(poles)..where((tbl) => tbl.id.equals(id))).go();

  /// Пометить опору как синхронизированную (после успешного upload).
  Future<int> setPoleNeedsSync(int poleId, bool needsSync) =>
      (update(poles)..where((tbl) => tbl.id.equals(poleId)))
          .write(PolesCompanion(needsSync: Value(needsSync)));

  // Методы для работы с оборудованием
  Future<List<EquipmentData>> getAllEquipment() => select(equipment).get();
  
  Future<List<EquipmentData>> getEquipmentByPole(int poleId) => 
      (select(equipment)..where((tbl) => tbl.poleId.equals(poleId))).get();
  
  Future<EquipmentData?> getEquipment(int id) => 
      (select(equipment)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  
  Future<int> insertEquipment(EquipmentCompanion equipmentItem) => 
      into(equipment).insert(equipmentItem);
  
  Future<int> insertEquipmentOrReplace(EquipmentCompanion equipmentItem) => 
      into(equipment).insert(equipmentItem, mode: InsertMode.insertOrReplace);
  
  Future<bool> updateEquipment(EquipmentCompanion equipmentItem) => 
      update(equipment).replace(equipmentItem);
  
  Future<int> deleteEquipment(int id) => 
      (delete(equipment)..where((tbl) => tbl.id.equals(id))).go();

  /// Пометить оборудование как синхронизированное (после успешного upload).
  Future<int> setEquipmentNeedsSync(int equipmentId, bool needsSync) =>
      (update(equipment)..where((tbl) => tbl.id.equals(equipmentId)))
          .write(EquipmentCompanion(needsSync: Value(needsSync)));

  // Методы для синхронизации
  Future<List<SyncRecord>> getPendingSyncRecords() => 
      (select(syncRecords)..where((tbl) => tbl.status.equals('pending'))).get();
  
  Future<int> insertSyncRecord(SyncRecordsCompanion record) => 
      into(syncRecords).insert(record);
  
  Future<bool> updateSyncRecord(SyncRecordsCompanion record) => 
      update(syncRecords).replace(record);
  
  Future<int> deleteSyncRecord(String id) => 
      (delete(syncRecords)..where((tbl) => tbl.id.equals(id))).go();

  // Методы для получения данных, требующих синхронизации
  Future<List<PowerLine>> getPowerLinesNeedingSync() => 
      (select(powerLines)..where((tbl) => tbl.needsSync.equals(true))).get();
  
  Future<List<Pole>> getPolesNeedingSync() => 
      (select(poles)..where((tbl) => tbl.needsSync.equals(true))).get();
  
  Future<List<EquipmentData>> getEquipmentNeedingSync() => 
      (select(equipment)..where((tbl) => tbl.needsSync.equals(true))).get();

  // Сессии обхода (офлайн + синхронизация по кнопке)
  Future<List<PatrolSession>> getPendingPatrolSessions() =>
      (select(patrolSessions)..where((tbl) => tbl.syncStatus.equals('pending'))).get();

  /// Недавние сессии обхода из локальной БД (для блока «Последние обходы» при офлайне).
  Future<List<PatrolSession>> getRecentPatrolSessionsFromDb(int limit) =>
      (select(patrolSessions)
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
            ..limit(limit))
          .get();

  Future<PatrolSession?> getPatrolSession(int id) =>
      (select(patrolSessions)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<int> insertPatrolSession(PatrolSessionsCompanion row) =>
      into(patrolSessions).insert(row);

  Future<bool> updatePatrolSession(PatrolSessionsCompanion row) =>
      update(patrolSessions).replace(row);

  /// Проставить время окончания сессии обхода (при завершении обхода).
  Future<int> setPatrolSessionEnded(int id, DateTime endedAt) =>
      (update(patrolSessions)..where((tbl) => tbl.id.equals(id)))
          .write(PatrolSessionsCompanion(endedAt: Value(endedAt)));

  /// После успешной отправки на сервер: проставить serverId и статус synced.
  Future<int> setPatrolSessionSynced(int id, int serverId) =>
      (update(patrolSessions)..where((tbl) => tbl.id.equals(id)))
          .write(PatrolSessionsCompanion(
        serverId: Value(serverId),
        syncStatus: const Value('synced'),
      ));

  /// Обновить lineId во всех сессиях обхода при маппинге локальной ЛЭП на серверную.
  /// Оставляем старое имя метода для обратной совместимости.
  Future<int> updatePatrolSessionsPowerLineId(int fromPowerLineId, int toPowerLineId) =>
      (update(patrolSessions)..where((tbl) => tbl.lineId.equals(fromPowerLineId)))
          .write(PatrolSessionsCompanion(lineId: Value(toPowerLineId)));

  /// Удалить все сессии обхода по данной ЛЭП (при удалении линии).
  Future<int> deletePatrolSessionsByLineId(int lineId) =>
      (delete(patrolSessions)..where((tbl) => tbl.lineId.equals(lineId))).go();

  /// Удалить все несинхронизированные сессии обхода (pending). После этого синхронизация не будет пытаться их отправить.
  Future<int> deleteAllPendingPatrolSessions() =>
      (delete(patrolSessions)..where((tbl) => tbl.syncStatus.equals('pending'))).go();
}

LazyDatabase _openConnection() {
  return createDatabaseConnection();
}

// Provider для базы данных
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});
