import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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

class Towers extends Table {
  IntColumn get id => integer()();
  IntColumn get powerLineId => integer()();
  TextColumn get towerNumber => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get towerType => text()();
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
  IntColumn get towerId => integer()();
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

@DriftDatabase(tables: [PowerLines, Towers, Equipment, SyncRecords])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => AppConfig.databaseVersion;

  // Методы для работы с ЛЭП
  Future<List<PowerLine>> getAllPowerLines() => select(powerLines).get();
  
  Future<PowerLine?> getPowerLine(int id) => 
      (select(powerLines)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  
  Future<int> insertPowerLine(PowerLinesCompanion powerLine) => 
      into(powerLines).insert(powerLine);
  
  Future<bool> updatePowerLine(PowerLinesCompanion powerLine) => 
      update(powerLines).replace(powerLine);
  
  Future<int> deletePowerLine(int id) => 
      (delete(powerLines)..where((tbl) => tbl.id.equals(id))).go();

  // Методы для работы с опорами
  Future<List<Tower>> getAllTowers() => select(towers).get();
  
  Future<List<Tower>> getTowersByPowerLine(int powerLineId) => 
      (select(towers)..where((tbl) => tbl.powerLineId.equals(powerLineId))).get();
  
  Future<Tower?> getTower(int id) => 
      (select(towers)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  
  Future<int> insertTower(TowersCompanion tower) => 
      into(towers).insert(tower);
  
  Future<bool> updateTower(TowersCompanion tower) => 
      update(towers).replace(tower);
  
  Future<int> deleteTower(int id) => 
      (delete(towers)..where((tbl) => tbl.id.equals(id))).go();

  // Методы для работы с оборудованием
  Future<List<Equipment>> getAllEquipment() => select(equipment).get();
  
  Future<List<Equipment>> getEquipmentByTower(int towerId) => 
      (select(equipment)..where((tbl) => tbl.towerId.equals(towerId))).get();
  
  Future<Equipment?> getEquipment(int id) => 
      (select(equipment)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  
  Future<int> insertEquipment(EquipmentCompanion equipmentItem) => 
      into(equipment).insert(equipmentItem);
  
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
  
  Future<List<Tower>> getTowersNeedingSync() => 
      (select(towers)..where((tbl) => tbl.needsSync.equals(true))).get();
  
  Future<List<Equipment>> getEquipmentNeedingSync() => 
      (select(equipment)..where((tbl) => tbl.needsSync.equals(true))).get();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, AppConfig.databaseName));
    return NativeDatabase.createInBackground(file);
  });
}

// Provider для базы данных
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});
