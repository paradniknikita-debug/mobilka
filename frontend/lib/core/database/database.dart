import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Условные импорты для разных платформ
import 'database_stub.dart'
    if (dart.library.io) 'database_io.dart'
    if (dart.library.html) 'database_web.dart';

import '../config/app_config.dart';
import '../utils/local_pole_sequence.dart';
import '../utils/mrid.dart';
import '../utils/normalize_pole_number.dart';

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
  /// CIM mRID (UID опоры)
  TextColumn get mrid => text().nullable()();
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
  /// Дефект конструкции опоры (текст)
  TextColumn get structuralDefect => text().nullable()();
  /// Критичность дефекта опоры: low | medium | high
  TextColumn get structuralDefectCriticality => text().nullable()();
  /// Комментарий в конце карточки опоры (текст)
  TextColumn get cardComment => text().nullable()();
  /// Вложения к комментарию: голос/фото (JSON: [{"t":"voice"|"photo","p":"path"}])
  TextColumn get cardCommentAttachment => text().nullable()();
  /// Порядок на линии (как sequence_number на сервере)
  IntColumn get sequenceNumber => integer().nullable().named('sequence_number')();
  /// main | tap
  TextColumn get branchType => text().nullable().named('branch_type')();
  IntColumn get tapPoleId => integer().nullable().named('tap_pole_id')();
  IntColumn get tapBranchIndex => integer().nullable().named('tap_branch_index')();
  BoolColumn get isTapPole => boolean().withDefault(const Constant(false)).named('is_tap_pole')();
  TextColumn get conductorType => text().nullable().named('conductor_type')();
  TextColumn get conductorMaterial => text().nullable().named('conductor_material')();
  TextColumn get conductorSection => text().nullable().named('conductor_section')();
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
  /// Комментарий карточки оборудования (как у опоры)
  TextColumn get cardComment => text().nullable()();
  /// Вложения к комментарию карточки (JSON с url или локальным p)
  TextColumn get cardCommentAttachment => text().nullable()();
  TextColumn get manufacturer => text().nullable()();
  TextColumn get model => text().nullable()();
  TextColumn get serialNumber => text().nullable()();
  IntColumn get yearManufactured => integer().nullable()();
  DateTimeColumn get installationDate => dateTime().nullable()();
  TextColumn get condition => text()();
  TextColumn get notes => text().nullable()();
  /// Поля карты / карточки оборудования (как на сервере Equipment), для офлайна и выбора сегмента ЛЭП.
  TextColumn get mrid => text().nullable()();
  IntColumn get catalogItemId => integer().nullable()();
  RealColumn get ratedCurrent => real().nullable()();
  RealColumn get iTh => real().nullable()();
  RealColumn get ipMax => real().nullable()();
  RealColumn get tTh => real().nullable()();
  BoolColumn get normalOpen => boolean().nullable()();
  BoolColumn get retained => boolean().nullable()();
  TextColumn get identifiedObjectDescription => text().nullable()();
  TextColumn get nameplate => text().nullable()();
  TextColumn get psrSubtype => text().nullable()();
  TextColumn get installationDisplayName => text().nullable()();
  TextColumn get tmCode => text().nullable()();
  TextColumn get objectSubtype => text().nullable()();
  IntColumn get poleCount => integer().nullable()();
  TextColumn get parentObjectRef => text().nullable()();
  TextColumn get parentMainEquipmentPoleRef => text().nullable()();
  RealColumn get nominalVoltageKv => real().nullable()();
  RealColumn get nominalBreakingCurrentKa => real().nullable()();
  RealColumn get ownTripTimeSec => real().nullable()();
  RealColumn get emergencyCurrentA => real().nullable()();
  RealColumn get continuousCurrentA => real().nullable()();
  TextColumn get arresterType => text().nullable()();
  /// Долгота / широта объекта оборудования (CIM x/y), если заданы — помогают привязать к нужному пролёту.
  RealColumn get xPosition => real().nullable()();
  RealColumn get yPosition => real().nullable()();
  RealColumn get directionAngle => real().nullable()();
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
          if (from < 10) {
            await migrator.addColumn(poles, poles.structuralDefect);
            await migrator.addColumn(poles, poles.structuralDefectCriticality);
          }
          if (from < 11) {
            await migrator.addColumn(equipment, equipment.mrid);
            await migrator.addColumn(equipment, equipment.catalogItemId);
            await migrator.addColumn(equipment, equipment.ratedCurrent);
            await migrator.addColumn(equipment, equipment.iTh);
            await migrator.addColumn(equipment, equipment.ipMax);
            await migrator.addColumn(equipment, equipment.tTh);
            await migrator.addColumn(equipment, equipment.normalOpen);
            await migrator.addColumn(equipment, equipment.retained);
            await migrator.addColumn(equipment, equipment.identifiedObjectDescription);
            await migrator.addColumn(equipment, equipment.nameplate);
            await migrator.addColumn(equipment, equipment.psrSubtype);
            await migrator.addColumn(equipment, equipment.installationDisplayName);
            await migrator.addColumn(equipment, equipment.tmCode);
            await migrator.addColumn(equipment, equipment.objectSubtype);
            await migrator.addColumn(equipment, equipment.poleCount);
            await migrator.addColumn(equipment, equipment.parentObjectRef);
            await migrator.addColumn(equipment, equipment.parentMainEquipmentPoleRef);
            await migrator.addColumn(equipment, equipment.nominalVoltageKv);
            await migrator.addColumn(equipment, equipment.nominalBreakingCurrentKa);
            await migrator.addColumn(equipment, equipment.ownTripTimeSec);
            await migrator.addColumn(equipment, equipment.emergencyCurrentA);
            await migrator.addColumn(equipment, equipment.continuousCurrentA);
            await migrator.addColumn(equipment, equipment.arresterType);
            await migrator.addColumn(equipment, equipment.xPosition);
            await migrator.addColumn(equipment, equipment.yPosition);
            await migrator.addColumn(equipment, equipment.directionAngle);
          }
          if (from < 12) {
            await migrator.addColumn(equipment, equipment.cardComment);
            await migrator.addColumn(equipment, equipment.cardCommentAttachment);
          }
          if (from < 13) {
            await migrator.addColumn(poles, poles.mrid);
          }
          if (from < 14) {
            final rowsWithoutMrid = await (select(poles)
                  ..where(
                    (t) => t.mrid.isNull() | t.mrid.equals(''),
                  ))
                .get();
            for (final row in rowsWithoutMrid) {
              await (update(poles)..where((t) => t.id.equals(row.id))).write(
                PolesCompanion(mrid: Value(generateMrid())),
              );
            }
          }
          if (from < 15) {
            await migrator.addColumn(poles, poles.sequenceNumber);
            await migrator.addColumn(poles, poles.branchType);
            await migrator.addColumn(poles, poles.tapPoleId);
            await migrator.addColumn(poles, poles.tapBranchIndex);
            await migrator.addColumn(poles, poles.isTapPole);
            await migrator.addColumn(poles, poles.conductorType);
            await migrator.addColumn(poles, poles.conductorMaterial);
            await migrator.addColumn(poles, poles.conductorSection);
            await backfillMissingPoleSequenceNumbers();
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
  
  /// Проставляет sequence_number опорам без него (правила как на сервере).
  Future<int> backfillMissingPoleSequenceNumbers() async {
    final allLines = await select(powerLines).get();
    var count = 0;
    for (final line in allLines) {
      final linePoles = await getPolesByLine(line.id);
      final patches = computeMissingSequenceNumberPatches(linePoles);
      for (final entry in patches.entries) {
        await (update(poles)..where((t) => t.id.equals(entry.key))).write(
          PolesCompanion(sequenceNumber: Value(entry.value)),
        );
        count++;
      }
    }
    return count;
  }

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

  /// Обновить JSON вложений карточки после загрузки файлов на сервер (до смены id опоры).
  Future<int> setPoleCardCommentAttachment(int poleId, String? json) =>
      (update(poles)..where((tbl) => tbl.id.equals(poleId)))
          .write(PolesCompanion(cardCommentAttachment: Value(json)));

  /// Обновить JSON вложений карточки оборудования после загрузки файлов на сервер.
  Future<int> setEquipmentCardCommentAttachment(int equipmentId, String? json) =>
      (update(equipment)..where((tbl) => tbl.id.equals(equipmentId)))
          .write(EquipmentCompanion(cardCommentAttachment: Value(json)));

  /// После синка: локальная опора (id &lt; 0) → серверный id. Иначе остаются две строки и UI теряет вложения.
  Future<void> reassignPoleLocalToServerId(int localId, int serverId) async {
    if (localId >= 0 || serverId <= 0 || localId == serverId) return;
    final p = await getPole(localId);
    if (p == null) return;

    final existingServer = await getPole(serverId);
    if (existingServer != null) {
      final locA = p.cardCommentAttachment;
      final srvA = existingServer.cardCommentAttachment;
      final locC = p.cardComment;
      final srvC = existingServer.cardComment;
      final patch = PolesCompanion(
        cardComment: (srvC == null || srvC.isEmpty) &&
                locC != null &&
                locC.isNotEmpty
            ? Value(locC)
            : const Value.absent(),
        cardCommentAttachment: (srvA == null || srvA.isEmpty) &&
                locA != null &&
                locA.isNotEmpty
            ? Value(locA)
            : const Value.absent(),
      );
      if (patch.cardComment.present || patch.cardCommentAttachment.present) {
        await (update(poles)..where((tbl) => tbl.id.equals(serverId))).write(
          patch,
        );
      }
      await (update(equipment)..where((tbl) => tbl.poleId.equals(localId)))
          .write(EquipmentCompanion(poleId: Value(serverId)));
      await deletePole(localId);
      return;
    }

    await insertPoleOrReplace(
      PolesCompanion.insert(
        id: Value(serverId),
        lineId: p.lineId,
        poleNumber: p.poleNumber,
        mrid: Value(p.mrid),
        xPosition: Value(p.xPosition),
        yPosition: Value(p.yPosition),
        poleType: Value(p.poleType),
        height: Value(p.height),
        foundationType: Value(p.foundationType),
        material: Value(p.material),
        yearInstalled: Value(p.yearInstalled),
        condition: Value(p.condition),
        notes: Value(p.notes),
        structuralDefect: Value(p.structuralDefect),
        structuralDefectCriticality: Value(p.structuralDefectCriticality),
        cardComment: Value(p.cardComment),
        cardCommentAttachment: Value(p.cardCommentAttachment),
        sequenceNumber: Value(p.sequenceNumber),
        branchType: Value(p.branchType),
        tapPoleId: Value(p.tapPoleId),
        tapBranchIndex: Value(p.tapBranchIndex),
        isTapPole: Value(p.isTapPole),
        conductorType: Value(p.conductorType),
        conductorMaterial: Value(p.conductorMaterial),
        conductorSection: Value(p.conductorSection),
        createdBy: p.createdBy,
        createdAt: p.createdAt,
        updatedAt: Value(p.updatedAt),
        isLocal: const Value(false),
        needsSync: const Value(false),
      ),
    );
    await (update(equipment)..where((tbl) => tbl.poleId.equals(localId)))
        .write(EquipmentCompanion(poleId: Value(serverId)));
    await deletePole(localId);
  }

  /// Локальное оборудование (id &lt; 0) → серверный id после синхронизации.
  Future<void> reassignEquipmentLocalToServerId(
    int localId,
    int serverId, {
    bool keepNeedsSync = false,
  }) async {
    if (localId >= 0 || serverId <= 0 || localId == serverId) return;
    final e = await getEquipment(localId);
    if (e == null) return;

    final existingServer = await getEquipment(serverId);
    if (existingServer != null) {
      final locA = e.cardCommentAttachment;
      final srvA = existingServer.cardCommentAttachment;
      final locC = e.cardComment;
      final srvC = existingServer.cardComment;
      final patch = EquipmentCompanion(
        cardComment: (srvC == null || srvC.isEmpty) && locC != null && locC.isNotEmpty
            ? Value(locC)
            : const Value.absent(),
        cardCommentAttachment: (srvA == null || srvA.isEmpty) && locA != null && locA.isNotEmpty
            ? Value(locA)
            : const Value.absent(),
      );
      if (patch.cardComment.present || patch.cardCommentAttachment.present) {
        await (update(equipment)..where((tbl) => tbl.id.equals(serverId))).write(patch);
      }
      await deleteEquipment(localId);
      return;
    }

    await insertEquipmentOrReplace(
      EquipmentCompanion.insert(
        id: Value(serverId),
        poleId: e.poleId,
        equipmentType: e.equipmentType,
        name: e.name,
        quantity: Value(e.quantity),
        defect: Value(e.defect),
        criticality: Value(e.criticality),
        defectAttachment: Value(e.defectAttachment),
        cardComment: Value(e.cardComment),
        cardCommentAttachment: Value(e.cardCommentAttachment),
        manufacturer: Value(e.manufacturer),
        model: Value(e.model),
        serialNumber: Value(e.serialNumber),
        yearManufactured: Value(e.yearManufactured),
        installationDate: Value(e.installationDate),
        condition: e.condition,
        notes: Value(e.notes),
        mrid: Value(e.mrid),
        catalogItemId: Value(e.catalogItemId),
        ratedCurrent: Value(e.ratedCurrent),
        iTh: Value(e.iTh),
        ipMax: Value(e.ipMax),
        tTh: Value(e.tTh),
        normalOpen: Value(e.normalOpen),
        retained: Value(e.retained),
        identifiedObjectDescription: Value(e.identifiedObjectDescription),
        nameplate: Value(e.nameplate),
        psrSubtype: Value(e.psrSubtype),
        installationDisplayName: Value(e.installationDisplayName),
        tmCode: Value(e.tmCode),
        objectSubtype: Value(e.objectSubtype),
        poleCount: Value(e.poleCount),
        parentObjectRef: Value(e.parentObjectRef),
        parentMainEquipmentPoleRef: Value(e.parentMainEquipmentPoleRef),
        nominalVoltageKv: Value(e.nominalVoltageKv),
        nominalBreakingCurrentKa: Value(e.nominalBreakingCurrentKa),
        ownTripTimeSec: Value(e.ownTripTimeSec),
        emergencyCurrentA: Value(e.emergencyCurrentA),
        continuousCurrentA: Value(e.continuousCurrentA),
        arresterType: Value(e.arresterType),
        xPosition: Value(e.xPosition),
        yPosition: Value(e.yPosition),
        directionAngle: Value(e.directionAngle),
        createdBy: e.createdBy,
        createdAt: e.createdAt,
        updatedAt: Value(e.updatedAt),
        isLocal: const Value(false),
        needsSync: Value(keepNeedsSync),
      ),
    );
    await deleteEquipment(localId);
  }

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
  /// Сессии, которые нужно отправить на сервер: новые (pending) или только завершение (pending_end).
  Future<List<PatrolSession>> getPendingPatrolSessions() => (select(patrolSessions)
        ..where((tbl) => tbl.syncStatus.isIn(['pending', AppConfig.patrolSessionSyncStatusPendingEnd])))
      .get();

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

  /// Завершение на сервере не удалось (офлайн): дослать через [SyncService._uploadPatrolSessions].
  Future<int> markPatrolSessionPendingEndSync(int id) =>
      (update(patrolSessions)..where((tbl) => tbl.id.equals(id))).write(
        PatrolSessionsCompanion(
          syncStatus: Value(AppConfig.patrolSessionSyncStatusPendingEnd),
        ),
      );

  /// Обновить lineId во всех сессиях обхода при маппинге локальной ЛЭП на серверную.
  /// Оставляем старое имя метода для обратной совместимости.
  Future<int> updatePatrolSessionsPowerLineId(int fromPowerLineId, int toPowerLineId) =>
      (update(patrolSessions)..where((tbl) => tbl.lineId.equals(fromPowerLineId)))
          .write(PatrolSessionsCompanion(lineId: Value(toPowerLineId)));

  /// Удалить все сессии обхода по данной ЛЭП (при удалении линии).
  Future<int> deletePatrolSessionsByLineId(int lineId) =>
      (delete(patrolSessions)..where((tbl) => tbl.lineId.equals(lineId))).go();

  /// Удалить все несинхронизированные сессии обхода (pending / pending_end).
  Future<int> deleteAllPendingPatrolSessions() => (delete(patrolSessions)
        ..where((tbl) => tbl.syncStatus.isIn(['pending', AppConfig.patrolSessionSyncStatusPendingEnd])))
      .go();
}

LazyDatabase _openConnection() {
  return createDatabaseConnection();
}

// Provider для базы данных
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});
