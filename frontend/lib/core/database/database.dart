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
  IntColumn get powerLineId => integer()();
  TextColumn get poleNumber => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get poleType => text()();
  RealColumn get height => real().nullable()();
  TextColumn get foundationType => text().nullable()();
  TextColumn get material => text().nullable()();
  IntColumn get yearInstalled => integer().nullable()();
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

class Equipment extends Table {
  IntColumn get id => integer()();
  IntColumn get poleId => integer()();
  TextColumn get equipmentType => text()();
  TextColumn get name => text()();
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
  IntColumn get powerLineId => integer()();
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
              'power_line_id INTEGER NOT NULL, '
              'note TEXT, '
              'started_at DATETIME NOT NULL, '
              'ended_at DATETIME, '
              'sync_status TEXT NOT NULL DEFAULT "pending", '
              'user_id INTEGER)',
            );
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

  // Методы для работы с опорами
  Future<List<Pole>> getAllPoles() => select(poles).get();
  
  Future<List<Pole>> getPolesByPowerLine(int powerLineId) => 
      (select(poles)..where((tbl) => tbl.powerLineId.equals(powerLineId))).get();
  
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

  /// Удалить все сессии обхода по данной ЛЭП (при удалении линии).
  Future<int> deletePatrolSessionsByPowerLineId(int powerLineId) =>
      (delete(patrolSessions)..where((tbl) => tbl.powerLineId.equals(powerLineId))).go();
}

LazyDatabase _openConnection() {
  return createDatabaseConnection();
}

// Provider для базы данных
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});
