// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $PowerLinesTable extends PowerLines
    with TableInfo<$PowerLinesTable, PowerLine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PowerLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
      'code', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _voltageLevelMeta =
      const VerificationMeta('voltageLevel');
  @override
  late final GeneratedColumn<double> voltageLevel = GeneratedColumn<double>(
      'voltage_level', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _lengthMeta = const VerificationMeta('length');
  @override
  late final GeneratedColumn<double> length = GeneratedColumn<double>(
      'length', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _branchIdMeta =
      const VerificationMeta('branchId');
  @override
  late final GeneratedColumn<int> branchId = GeneratedColumn<int>(
      'branch_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _createdByMeta =
      const VerificationMeta('createdBy');
  @override
  late final GeneratedColumn<int> createdBy = GeneratedColumn<int>(
      'created_by', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _isLocalMeta =
      const VerificationMeta('isLocal');
  @override
  late final GeneratedColumn<bool> isLocal = GeneratedColumn<bool>(
      'is_local', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_local" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _needsSyncMeta =
      const VerificationMeta('needsSync');
  @override
  late final GeneratedColumn<bool> needsSync = GeneratedColumn<bool>(
      'needs_sync', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("needs_sync" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        code,
        voltageLevel,
        length,
        branchId,
        createdBy,
        status,
        description,
        createdAt,
        updatedAt,
        isLocal,
        needsSync
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'power_lines';
  @override
  VerificationContext validateIntegrity(Insertable<PowerLine> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
          _codeMeta, code.isAcceptableOrUnknown(data['code']!, _codeMeta));
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('voltage_level')) {
      context.handle(
          _voltageLevelMeta,
          voltageLevel.isAcceptableOrUnknown(
              data['voltage_level']!, _voltageLevelMeta));
    } else if (isInserting) {
      context.missing(_voltageLevelMeta);
    }
    if (data.containsKey('length')) {
      context.handle(_lengthMeta,
          length.isAcceptableOrUnknown(data['length']!, _lengthMeta));
    }
    if (data.containsKey('branch_id')) {
      context.handle(_branchIdMeta,
          branchId.isAcceptableOrUnknown(data['branch_id']!, _branchIdMeta));
    } else if (isInserting) {
      context.missing(_branchIdMeta);
    }
    if (data.containsKey('created_by')) {
      context.handle(_createdByMeta,
          createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta));
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('is_local')) {
      context.handle(_isLocalMeta,
          isLocal.isAcceptableOrUnknown(data['is_local']!, _isLocalMeta));
    }
    if (data.containsKey('needs_sync')) {
      context.handle(_needsSyncMeta,
          needsSync.isAcceptableOrUnknown(data['needs_sync']!, _needsSyncMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PowerLine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PowerLine(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      code: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}code'])!,
      voltageLevel: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}voltage_level'])!,
      length: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}length']),
      branchId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}branch_id'])!,
      createdBy: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_by'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
      isLocal: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_local'])!,
      needsSync: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}needs_sync'])!,
    );
  }

  @override
  $PowerLinesTable createAlias(String alias) {
    return $PowerLinesTable(attachedDatabase, alias);
  }
}

class PowerLine extends DataClass implements Insertable<PowerLine> {
  final int id;
  final String name;
  final String code;
  final double voltageLevel;
  final double? length;
  final int branchId;
  final int createdBy;
  final String status;
  final String? description;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isLocal;
  final bool needsSync;
  const PowerLine(
      {required this.id,
      required this.name,
      required this.code,
      required this.voltageLevel,
      this.length,
      required this.branchId,
      required this.createdBy,
      required this.status,
      this.description,
      required this.createdAt,
      this.updatedAt,
      required this.isLocal,
      required this.needsSync});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['code'] = Variable<String>(code);
    map['voltage_level'] = Variable<double>(voltageLevel);
    if (!nullToAbsent || length != null) {
      map['length'] = Variable<double>(length);
    }
    map['branch_id'] = Variable<int>(branchId);
    map['created_by'] = Variable<int>(createdBy);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['is_local'] = Variable<bool>(isLocal);
    map['needs_sync'] = Variable<bool>(needsSync);
    return map;
  }

  PowerLinesCompanion toCompanion(bool nullToAbsent) {
    return PowerLinesCompanion(
      id: Value(id),
      name: Value(name),
      code: Value(code),
      voltageLevel: Value(voltageLevel),
      length:
          length == null && nullToAbsent ? const Value.absent() : Value(length),
      branchId: Value(branchId),
      createdBy: Value(createdBy),
      status: Value(status),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      isLocal: Value(isLocal),
      needsSync: Value(needsSync),
    );
  }

  factory PowerLine.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PowerLine(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      code: serializer.fromJson<String>(json['code']),
      voltageLevel: serializer.fromJson<double>(json['voltageLevel']),
      length: serializer.fromJson<double?>(json['length']),
      branchId: serializer.fromJson<int>(json['branchId']),
      createdBy: serializer.fromJson<int>(json['createdBy']),
      status: serializer.fromJson<String>(json['status']),
      description: serializer.fromJson<String?>(json['description']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      isLocal: serializer.fromJson<bool>(json['isLocal']),
      needsSync: serializer.fromJson<bool>(json['needsSync']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'code': serializer.toJson<String>(code),
      'voltageLevel': serializer.toJson<double>(voltageLevel),
      'length': serializer.toJson<double?>(length),
      'branchId': serializer.toJson<int>(branchId),
      'createdBy': serializer.toJson<int>(createdBy),
      'status': serializer.toJson<String>(status),
      'description': serializer.toJson<String?>(description),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'isLocal': serializer.toJson<bool>(isLocal),
      'needsSync': serializer.toJson<bool>(needsSync),
    };
  }

  PowerLine copyWith(
          {int? id,
          String? name,
          String? code,
          double? voltageLevel,
          Value<double?> length = const Value.absent(),
          int? branchId,
          int? createdBy,
          String? status,
          Value<String?> description = const Value.absent(),
          DateTime? createdAt,
          Value<DateTime?> updatedAt = const Value.absent(),
          bool? isLocal,
          bool? needsSync}) =>
      PowerLine(
        id: id ?? this.id,
        name: name ?? this.name,
        code: code ?? this.code,
        voltageLevel: voltageLevel ?? this.voltageLevel,
        length: length.present ? length.value : this.length,
        branchId: branchId ?? this.branchId,
        createdBy: createdBy ?? this.createdBy,
        status: status ?? this.status,
        description: description.present ? description.value : this.description,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
        isLocal: isLocal ?? this.isLocal,
        needsSync: needsSync ?? this.needsSync,
      );
  PowerLine copyWithCompanion(PowerLinesCompanion data) {
    return PowerLine(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      code: data.code.present ? data.code.value : this.code,
      voltageLevel: data.voltageLevel.present
          ? data.voltageLevel.value
          : this.voltageLevel,
      length: data.length.present ? data.length.value : this.length,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      status: data.status.present ? data.status.value : this.status,
      description:
          data.description.present ? data.description.value : this.description,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isLocal: data.isLocal.present ? data.isLocal.value : this.isLocal,
      needsSync: data.needsSync.present ? data.needsSync.value : this.needsSync,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PowerLine(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('code: $code, ')
          ..write('voltageLevel: $voltageLevel, ')
          ..write('length: $length, ')
          ..write('branchId: $branchId, ')
          ..write('createdBy: $createdBy, ')
          ..write('status: $status, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isLocal: $isLocal, ')
          ..write('needsSync: $needsSync')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      name,
      code,
      voltageLevel,
      length,
      branchId,
      createdBy,
      status,
      description,
      createdAt,
      updatedAt,
      isLocal,
      needsSync);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PowerLine &&
          other.id == this.id &&
          other.name == this.name &&
          other.code == this.code &&
          other.voltageLevel == this.voltageLevel &&
          other.length == this.length &&
          other.branchId == this.branchId &&
          other.createdBy == this.createdBy &&
          other.status == this.status &&
          other.description == this.description &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isLocal == this.isLocal &&
          other.needsSync == this.needsSync);
}

class PowerLinesCompanion extends UpdateCompanion<PowerLine> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> code;
  final Value<double> voltageLevel;
  final Value<double?> length;
  final Value<int> branchId;
  final Value<int> createdBy;
  final Value<String> status;
  final Value<String?> description;
  final Value<DateTime> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<bool> isLocal;
  final Value<bool> needsSync;
  const PowerLinesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.code = const Value.absent(),
    this.voltageLevel = const Value.absent(),
    this.length = const Value.absent(),
    this.branchId = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.status = const Value.absent(),
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isLocal = const Value.absent(),
    this.needsSync = const Value.absent(),
  });
  PowerLinesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String code,
    required double voltageLevel,
    this.length = const Value.absent(),
    required int branchId,
    required int createdBy,
    required String status,
    this.description = const Value.absent(),
    required DateTime createdAt,
    this.updatedAt = const Value.absent(),
    this.isLocal = const Value.absent(),
    this.needsSync = const Value.absent(),
  })  : name = Value(name),
        code = Value(code),
        voltageLevel = Value(voltageLevel),
        branchId = Value(branchId),
        createdBy = Value(createdBy),
        status = Value(status),
        createdAt = Value(createdAt);
  static Insertable<PowerLine> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? code,
    Expression<double>? voltageLevel,
    Expression<double>? length,
    Expression<int>? branchId,
    Expression<int>? createdBy,
    Expression<String>? status,
    Expression<String>? description,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isLocal,
    Expression<bool>? needsSync,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (code != null) 'code': code,
      if (voltageLevel != null) 'voltage_level': voltageLevel,
      if (length != null) 'length': length,
      if (branchId != null) 'branch_id': branchId,
      if (createdBy != null) 'created_by': createdBy,
      if (status != null) 'status': status,
      if (description != null) 'description': description,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isLocal != null) 'is_local': isLocal,
      if (needsSync != null) 'needs_sync': needsSync,
    });
  }

  PowerLinesCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String>? code,
      Value<double>? voltageLevel,
      Value<double?>? length,
      Value<int>? branchId,
      Value<int>? createdBy,
      Value<String>? status,
      Value<String?>? description,
      Value<DateTime>? createdAt,
      Value<DateTime?>? updatedAt,
      Value<bool>? isLocal,
      Value<bool>? needsSync}) {
    return PowerLinesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      voltageLevel: voltageLevel ?? this.voltageLevel,
      length: length ?? this.length,
      branchId: branchId ?? this.branchId,
      createdBy: createdBy ?? this.createdBy,
      status: status ?? this.status,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isLocal: isLocal ?? this.isLocal,
      needsSync: needsSync ?? this.needsSync,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (voltageLevel.present) {
      map['voltage_level'] = Variable<double>(voltageLevel.value);
    }
    if (length.present) {
      map['length'] = Variable<double>(length.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<int>(branchId.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<int>(createdBy.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isLocal.present) {
      map['is_local'] = Variable<bool>(isLocal.value);
    }
    if (needsSync.present) {
      map['needs_sync'] = Variable<bool>(needsSync.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PowerLinesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('code: $code, ')
          ..write('voltageLevel: $voltageLevel, ')
          ..write('length: $length, ')
          ..write('branchId: $branchId, ')
          ..write('createdBy: $createdBy, ')
          ..write('status: $status, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isLocal: $isLocal, ')
          ..write('needsSync: $needsSync')
          ..write(')'))
        .toString();
  }
}

class $TowersTable extends Towers with TableInfo<$TowersTable, Tower> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TowersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _powerLineIdMeta =
      const VerificationMeta('powerLineId');
  @override
  late final GeneratedColumn<int> powerLineId = GeneratedColumn<int>(
      'power_line_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _towerNumberMeta =
      const VerificationMeta('towerNumber');
  @override
  late final GeneratedColumn<String> towerNumber = GeneratedColumn<String>(
      'tower_number', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _latitudeMeta =
      const VerificationMeta('latitude');
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
      'latitude', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _longitudeMeta =
      const VerificationMeta('longitude');
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
      'longitude', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _towerTypeMeta =
      const VerificationMeta('towerType');
  @override
  late final GeneratedColumn<String> towerType = GeneratedColumn<String>(
      'tower_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<double> height = GeneratedColumn<double>(
      'height', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _foundationTypeMeta =
      const VerificationMeta('foundationType');
  @override
  late final GeneratedColumn<String> foundationType = GeneratedColumn<String>(
      'foundation_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _materialMeta =
      const VerificationMeta('material');
  @override
  late final GeneratedColumn<String> material = GeneratedColumn<String>(
      'material', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _yearInstalledMeta =
      const VerificationMeta('yearInstalled');
  @override
  late final GeneratedColumn<int> yearInstalled = GeneratedColumn<int>(
      'year_installed', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _conditionMeta =
      const VerificationMeta('condition');
  @override
  late final GeneratedColumn<String> condition = GeneratedColumn<String>(
      'condition', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdByMeta =
      const VerificationMeta('createdBy');
  @override
  late final GeneratedColumn<int> createdBy = GeneratedColumn<int>(
      'created_by', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _isLocalMeta =
      const VerificationMeta('isLocal');
  @override
  late final GeneratedColumn<bool> isLocal = GeneratedColumn<bool>(
      'is_local', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_local" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _needsSyncMeta =
      const VerificationMeta('needsSync');
  @override
  late final GeneratedColumn<bool> needsSync = GeneratedColumn<bool>(
      'needs_sync', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("needs_sync" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        powerLineId,
        towerNumber,
        latitude,
        longitude,
        towerType,
        height,
        foundationType,
        material,
        yearInstalled,
        condition,
        notes,
        createdBy,
        createdAt,
        updatedAt,
        isLocal,
        needsSync
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'towers';
  @override
  VerificationContext validateIntegrity(Insertable<Tower> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('power_line_id')) {
      context.handle(
          _powerLineIdMeta,
          powerLineId.isAcceptableOrUnknown(
              data['power_line_id']!, _powerLineIdMeta));
    } else if (isInserting) {
      context.missing(_powerLineIdMeta);
    }
    if (data.containsKey('tower_number')) {
      context.handle(
          _towerNumberMeta,
          towerNumber.isAcceptableOrUnknown(
              data['tower_number']!, _towerNumberMeta));
    } else if (isInserting) {
      context.missing(_towerNumberMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(_latitudeMeta,
          latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta));
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(_longitudeMeta,
          longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta));
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('tower_type')) {
      context.handle(_towerTypeMeta,
          towerType.isAcceptableOrUnknown(data['tower_type']!, _towerTypeMeta));
    } else if (isInserting) {
      context.missing(_towerTypeMeta);
    }
    if (data.containsKey('height')) {
      context.handle(_heightMeta,
          height.isAcceptableOrUnknown(data['height']!, _heightMeta));
    }
    if (data.containsKey('foundation_type')) {
      context.handle(
          _foundationTypeMeta,
          foundationType.isAcceptableOrUnknown(
              data['foundation_type']!, _foundationTypeMeta));
    }
    if (data.containsKey('material')) {
      context.handle(_materialMeta,
          material.isAcceptableOrUnknown(data['material']!, _materialMeta));
    }
    if (data.containsKey('year_installed')) {
      context.handle(
          _yearInstalledMeta,
          yearInstalled.isAcceptableOrUnknown(
              data['year_installed']!, _yearInstalledMeta));
    }
    if (data.containsKey('condition')) {
      context.handle(_conditionMeta,
          condition.isAcceptableOrUnknown(data['condition']!, _conditionMeta));
    } else if (isInserting) {
      context.missing(_conditionMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('created_by')) {
      context.handle(_createdByMeta,
          createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta));
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('is_local')) {
      context.handle(_isLocalMeta,
          isLocal.isAcceptableOrUnknown(data['is_local']!, _isLocalMeta));
    }
    if (data.containsKey('needs_sync')) {
      context.handle(_needsSyncMeta,
          needsSync.isAcceptableOrUnknown(data['needs_sync']!, _needsSyncMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tower map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tower(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      powerLineId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}power_line_id'])!,
      towerNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tower_number'])!,
      latitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}latitude'])!,
      longitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}longitude'])!,
      towerType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tower_type'])!,
      height: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}height']),
      foundationType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}foundation_type']),
      material: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}material']),
      yearInstalled: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}year_installed']),
      condition: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}condition'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      createdBy: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_by'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
      isLocal: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_local'])!,
      needsSync: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}needs_sync'])!,
    );
  }

  @override
  $TowersTable createAlias(String alias) {
    return $TowersTable(attachedDatabase, alias);
  }
}

class Tower extends DataClass implements Insertable<Tower> {
  final int id;
  final int powerLineId;
  final String towerNumber;
  final double latitude;
  final double longitude;
  final String towerType;
  final double? height;
  final String? foundationType;
  final String? material;
  final int? yearInstalled;
  final String condition;
  final String? notes;
  final int createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isLocal;
  final bool needsSync;
  const Tower(
      {required this.id,
      required this.powerLineId,
      required this.towerNumber,
      required this.latitude,
      required this.longitude,
      required this.towerType,
      this.height,
      this.foundationType,
      this.material,
      this.yearInstalled,
      required this.condition,
      this.notes,
      required this.createdBy,
      required this.createdAt,
      this.updatedAt,
      required this.isLocal,
      required this.needsSync});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['power_line_id'] = Variable<int>(powerLineId);
    map['tower_number'] = Variable<String>(towerNumber);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    map['tower_type'] = Variable<String>(towerType);
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<double>(height);
    }
    if (!nullToAbsent || foundationType != null) {
      map['foundation_type'] = Variable<String>(foundationType);
    }
    if (!nullToAbsent || material != null) {
      map['material'] = Variable<String>(material);
    }
    if (!nullToAbsent || yearInstalled != null) {
      map['year_installed'] = Variable<int>(yearInstalled);
    }
    map['condition'] = Variable<String>(condition);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_by'] = Variable<int>(createdBy);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['is_local'] = Variable<bool>(isLocal);
    map['needs_sync'] = Variable<bool>(needsSync);
    return map;
  }

  TowersCompanion toCompanion(bool nullToAbsent) {
    return TowersCompanion(
      id: Value(id),
      powerLineId: Value(powerLineId),
      towerNumber: Value(towerNumber),
      latitude: Value(latitude),
      longitude: Value(longitude),
      towerType: Value(towerType),
      height:
          height == null && nullToAbsent ? const Value.absent() : Value(height),
      foundationType: foundationType == null && nullToAbsent
          ? const Value.absent()
          : Value(foundationType),
      material: material == null && nullToAbsent
          ? const Value.absent()
          : Value(material),
      yearInstalled: yearInstalled == null && nullToAbsent
          ? const Value.absent()
          : Value(yearInstalled),
      condition: Value(condition),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      createdBy: Value(createdBy),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      isLocal: Value(isLocal),
      needsSync: Value(needsSync),
    );
  }

  factory Tower.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tower(
      id: serializer.fromJson<int>(json['id']),
      powerLineId: serializer.fromJson<int>(json['powerLineId']),
      towerNumber: serializer.fromJson<String>(json['towerNumber']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      towerType: serializer.fromJson<String>(json['towerType']),
      height: serializer.fromJson<double?>(json['height']),
      foundationType: serializer.fromJson<String?>(json['foundationType']),
      material: serializer.fromJson<String?>(json['material']),
      yearInstalled: serializer.fromJson<int?>(json['yearInstalled']),
      condition: serializer.fromJson<String>(json['condition']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdBy: serializer.fromJson<int>(json['createdBy']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      isLocal: serializer.fromJson<bool>(json['isLocal']),
      needsSync: serializer.fromJson<bool>(json['needsSync']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'powerLineId': serializer.toJson<int>(powerLineId),
      'towerNumber': serializer.toJson<String>(towerNumber),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'towerType': serializer.toJson<String>(towerType),
      'height': serializer.toJson<double?>(height),
      'foundationType': serializer.toJson<String?>(foundationType),
      'material': serializer.toJson<String?>(material),
      'yearInstalled': serializer.toJson<int?>(yearInstalled),
      'condition': serializer.toJson<String>(condition),
      'notes': serializer.toJson<String?>(notes),
      'createdBy': serializer.toJson<int>(createdBy),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'isLocal': serializer.toJson<bool>(isLocal),
      'needsSync': serializer.toJson<bool>(needsSync),
    };
  }

  Tower copyWith(
          {int? id,
          int? powerLineId,
          String? towerNumber,
          double? latitude,
          double? longitude,
          String? towerType,
          Value<double?> height = const Value.absent(),
          Value<String?> foundationType = const Value.absent(),
          Value<String?> material = const Value.absent(),
          Value<int?> yearInstalled = const Value.absent(),
          String? condition,
          Value<String?> notes = const Value.absent(),
          int? createdBy,
          DateTime? createdAt,
          Value<DateTime?> updatedAt = const Value.absent(),
          bool? isLocal,
          bool? needsSync}) =>
      Tower(
        id: id ?? this.id,
        powerLineId: powerLineId ?? this.powerLineId,
        towerNumber: towerNumber ?? this.towerNumber,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        towerType: towerType ?? this.towerType,
        height: height.present ? height.value : this.height,
        foundationType:
            foundationType.present ? foundationType.value : this.foundationType,
        material: material.present ? material.value : this.material,
        yearInstalled:
            yearInstalled.present ? yearInstalled.value : this.yearInstalled,
        condition: condition ?? this.condition,
        notes: notes.present ? notes.value : this.notes,
        createdBy: createdBy ?? this.createdBy,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
        isLocal: isLocal ?? this.isLocal,
        needsSync: needsSync ?? this.needsSync,
      );
  Tower copyWithCompanion(TowersCompanion data) {
    return Tower(
      id: data.id.present ? data.id.value : this.id,
      powerLineId:
          data.powerLineId.present ? data.powerLineId.value : this.powerLineId,
      towerNumber:
          data.towerNumber.present ? data.towerNumber.value : this.towerNumber,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      towerType: data.towerType.present ? data.towerType.value : this.towerType,
      height: data.height.present ? data.height.value : this.height,
      foundationType: data.foundationType.present
          ? data.foundationType.value
          : this.foundationType,
      material: data.material.present ? data.material.value : this.material,
      yearInstalled: data.yearInstalled.present
          ? data.yearInstalled.value
          : this.yearInstalled,
      condition: data.condition.present ? data.condition.value : this.condition,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isLocal: data.isLocal.present ? data.isLocal.value : this.isLocal,
      needsSync: data.needsSync.present ? data.needsSync.value : this.needsSync,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tower(')
          ..write('id: $id, ')
          ..write('powerLineId: $powerLineId, ')
          ..write('towerNumber: $towerNumber, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('towerType: $towerType, ')
          ..write('height: $height, ')
          ..write('foundationType: $foundationType, ')
          ..write('material: $material, ')
          ..write('yearInstalled: $yearInstalled, ')
          ..write('condition: $condition, ')
          ..write('notes: $notes, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isLocal: $isLocal, ')
          ..write('needsSync: $needsSync')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      powerLineId,
      towerNumber,
      latitude,
      longitude,
      towerType,
      height,
      foundationType,
      material,
      yearInstalled,
      condition,
      notes,
      createdBy,
      createdAt,
      updatedAt,
      isLocal,
      needsSync);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tower &&
          other.id == this.id &&
          other.powerLineId == this.powerLineId &&
          other.towerNumber == this.towerNumber &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.towerType == this.towerType &&
          other.height == this.height &&
          other.foundationType == this.foundationType &&
          other.material == this.material &&
          other.yearInstalled == this.yearInstalled &&
          other.condition == this.condition &&
          other.notes == this.notes &&
          other.createdBy == this.createdBy &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isLocal == this.isLocal &&
          other.needsSync == this.needsSync);
}

class TowersCompanion extends UpdateCompanion<Tower> {
  final Value<int> id;
  final Value<int> powerLineId;
  final Value<String> towerNumber;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<String> towerType;
  final Value<double?> height;
  final Value<String?> foundationType;
  final Value<String?> material;
  final Value<int?> yearInstalled;
  final Value<String> condition;
  final Value<String?> notes;
  final Value<int> createdBy;
  final Value<DateTime> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<bool> isLocal;
  final Value<bool> needsSync;
  const TowersCompanion({
    this.id = const Value.absent(),
    this.powerLineId = const Value.absent(),
    this.towerNumber = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.towerType = const Value.absent(),
    this.height = const Value.absent(),
    this.foundationType = const Value.absent(),
    this.material = const Value.absent(),
    this.yearInstalled = const Value.absent(),
    this.condition = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isLocal = const Value.absent(),
    this.needsSync = const Value.absent(),
  });
  TowersCompanion.insert({
    this.id = const Value.absent(),
    required int powerLineId,
    required String towerNumber,
    required double latitude,
    required double longitude,
    required String towerType,
    this.height = const Value.absent(),
    this.foundationType = const Value.absent(),
    this.material = const Value.absent(),
    this.yearInstalled = const Value.absent(),
    required String condition,
    this.notes = const Value.absent(),
    required int createdBy,
    required DateTime createdAt,
    this.updatedAt = const Value.absent(),
    this.isLocal = const Value.absent(),
    this.needsSync = const Value.absent(),
  })  : powerLineId = Value(powerLineId),
        towerNumber = Value(towerNumber),
        latitude = Value(latitude),
        longitude = Value(longitude),
        towerType = Value(towerType),
        condition = Value(condition),
        createdBy = Value(createdBy),
        createdAt = Value(createdAt);
  static Insertable<Tower> custom({
    Expression<int>? id,
    Expression<int>? powerLineId,
    Expression<String>? towerNumber,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? towerType,
    Expression<double>? height,
    Expression<String>? foundationType,
    Expression<String>? material,
    Expression<int>? yearInstalled,
    Expression<String>? condition,
    Expression<String>? notes,
    Expression<int>? createdBy,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isLocal,
    Expression<bool>? needsSync,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (powerLineId != null) 'power_line_id': powerLineId,
      if (towerNumber != null) 'tower_number': towerNumber,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (towerType != null) 'tower_type': towerType,
      if (height != null) 'height': height,
      if (foundationType != null) 'foundation_type': foundationType,
      if (material != null) 'material': material,
      if (yearInstalled != null) 'year_installed': yearInstalled,
      if (condition != null) 'condition': condition,
      if (notes != null) 'notes': notes,
      if (createdBy != null) 'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isLocal != null) 'is_local': isLocal,
      if (needsSync != null) 'needs_sync': needsSync,
    });
  }

  TowersCompanion copyWith(
      {Value<int>? id,
      Value<int>? powerLineId,
      Value<String>? towerNumber,
      Value<double>? latitude,
      Value<double>? longitude,
      Value<String>? towerType,
      Value<double?>? height,
      Value<String?>? foundationType,
      Value<String?>? material,
      Value<int?>? yearInstalled,
      Value<String>? condition,
      Value<String?>? notes,
      Value<int>? createdBy,
      Value<DateTime>? createdAt,
      Value<DateTime?>? updatedAt,
      Value<bool>? isLocal,
      Value<bool>? needsSync}) {
    return TowersCompanion(
      id: id ?? this.id,
      powerLineId: powerLineId ?? this.powerLineId,
      towerNumber: towerNumber ?? this.towerNumber,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      towerType: towerType ?? this.towerType,
      height: height ?? this.height,
      foundationType: foundationType ?? this.foundationType,
      material: material ?? this.material,
      yearInstalled: yearInstalled ?? this.yearInstalled,
      condition: condition ?? this.condition,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isLocal: isLocal ?? this.isLocal,
      needsSync: needsSync ?? this.needsSync,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (powerLineId.present) {
      map['power_line_id'] = Variable<int>(powerLineId.value);
    }
    if (towerNumber.present) {
      map['tower_number'] = Variable<String>(towerNumber.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (towerType.present) {
      map['tower_type'] = Variable<String>(towerType.value);
    }
    if (height.present) {
      map['height'] = Variable<double>(height.value);
    }
    if (foundationType.present) {
      map['foundation_type'] = Variable<String>(foundationType.value);
    }
    if (material.present) {
      map['material'] = Variable<String>(material.value);
    }
    if (yearInstalled.present) {
      map['year_installed'] = Variable<int>(yearInstalled.value);
    }
    if (condition.present) {
      map['condition'] = Variable<String>(condition.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<int>(createdBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isLocal.present) {
      map['is_local'] = Variable<bool>(isLocal.value);
    }
    if (needsSync.present) {
      map['needs_sync'] = Variable<bool>(needsSync.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TowersCompanion(')
          ..write('id: $id, ')
          ..write('powerLineId: $powerLineId, ')
          ..write('towerNumber: $towerNumber, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('towerType: $towerType, ')
          ..write('height: $height, ')
          ..write('foundationType: $foundationType, ')
          ..write('material: $material, ')
          ..write('yearInstalled: $yearInstalled, ')
          ..write('condition: $condition, ')
          ..write('notes: $notes, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isLocal: $isLocal, ')
          ..write('needsSync: $needsSync')
          ..write(')'))
        .toString();
  }
}

class $EquipmentTable extends Equipment
    with TableInfo<$EquipmentTable, EquipmentData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EquipmentTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _towerIdMeta =
      const VerificationMeta('towerId');
  @override
  late final GeneratedColumn<int> towerId = GeneratedColumn<int>(
      'tower_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _equipmentTypeMeta =
      const VerificationMeta('equipmentType');
  @override
  late final GeneratedColumn<String> equipmentType = GeneratedColumn<String>(
      'equipment_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _manufacturerMeta =
      const VerificationMeta('manufacturer');
  @override
  late final GeneratedColumn<String> manufacturer = GeneratedColumn<String>(
      'manufacturer', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
      'model', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _serialNumberMeta =
      const VerificationMeta('serialNumber');
  @override
  late final GeneratedColumn<String> serialNumber = GeneratedColumn<String>(
      'serial_number', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _yearManufacturedMeta =
      const VerificationMeta('yearManufactured');
  @override
  late final GeneratedColumn<int> yearManufactured = GeneratedColumn<int>(
      'year_manufactured', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _installationDateMeta =
      const VerificationMeta('installationDate');
  @override
  late final GeneratedColumn<DateTime> installationDate =
      GeneratedColumn<DateTime>('installation_date', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _conditionMeta =
      const VerificationMeta('condition');
  @override
  late final GeneratedColumn<String> condition = GeneratedColumn<String>(
      'condition', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdByMeta =
      const VerificationMeta('createdBy');
  @override
  late final GeneratedColumn<int> createdBy = GeneratedColumn<int>(
      'created_by', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _isLocalMeta =
      const VerificationMeta('isLocal');
  @override
  late final GeneratedColumn<bool> isLocal = GeneratedColumn<bool>(
      'is_local', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_local" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _needsSyncMeta =
      const VerificationMeta('needsSync');
  @override
  late final GeneratedColumn<bool> needsSync = GeneratedColumn<bool>(
      'needs_sync', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("needs_sync" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        towerId,
        equipmentType,
        name,
        manufacturer,
        model,
        serialNumber,
        yearManufactured,
        installationDate,
        condition,
        notes,
        createdBy,
        createdAt,
        updatedAt,
        isLocal,
        needsSync
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'equipment';
  @override
  VerificationContext validateIntegrity(Insertable<EquipmentData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('tower_id')) {
      context.handle(_towerIdMeta,
          towerId.isAcceptableOrUnknown(data['tower_id']!, _towerIdMeta));
    } else if (isInserting) {
      context.missing(_towerIdMeta);
    }
    if (data.containsKey('equipment_type')) {
      context.handle(
          _equipmentTypeMeta,
          equipmentType.isAcceptableOrUnknown(
              data['equipment_type']!, _equipmentTypeMeta));
    } else if (isInserting) {
      context.missing(_equipmentTypeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('manufacturer')) {
      context.handle(
          _manufacturerMeta,
          manufacturer.isAcceptableOrUnknown(
              data['manufacturer']!, _manufacturerMeta));
    }
    if (data.containsKey('model')) {
      context.handle(
          _modelMeta, model.isAcceptableOrUnknown(data['model']!, _modelMeta));
    }
    if (data.containsKey('serial_number')) {
      context.handle(
          _serialNumberMeta,
          serialNumber.isAcceptableOrUnknown(
              data['serial_number']!, _serialNumberMeta));
    }
    if (data.containsKey('year_manufactured')) {
      context.handle(
          _yearManufacturedMeta,
          yearManufactured.isAcceptableOrUnknown(
              data['year_manufactured']!, _yearManufacturedMeta));
    }
    if (data.containsKey('installation_date')) {
      context.handle(
          _installationDateMeta,
          installationDate.isAcceptableOrUnknown(
              data['installation_date']!, _installationDateMeta));
    }
    if (data.containsKey('condition')) {
      context.handle(_conditionMeta,
          condition.isAcceptableOrUnknown(data['condition']!, _conditionMeta));
    } else if (isInserting) {
      context.missing(_conditionMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('created_by')) {
      context.handle(_createdByMeta,
          createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta));
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('is_local')) {
      context.handle(_isLocalMeta,
          isLocal.isAcceptableOrUnknown(data['is_local']!, _isLocalMeta));
    }
    if (data.containsKey('needs_sync')) {
      context.handle(_needsSyncMeta,
          needsSync.isAcceptableOrUnknown(data['needs_sync']!, _needsSyncMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EquipmentData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EquipmentData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      towerId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tower_id'])!,
      equipmentType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}equipment_type'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      manufacturer: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}manufacturer']),
      model: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}model']),
      serialNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}serial_number']),
      yearManufactured: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}year_manufactured']),
      installationDate: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}installation_date']),
      condition: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}condition'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      createdBy: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_by'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
      isLocal: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_local'])!,
      needsSync: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}needs_sync'])!,
    );
  }

  @override
  $EquipmentTable createAlias(String alias) {
    return $EquipmentTable(attachedDatabase, alias);
  }
}

class EquipmentData extends DataClass implements Insertable<EquipmentData> {
  final int id;
  final int towerId;
  final String equipmentType;
  final String name;
  final String? manufacturer;
  final String? model;
  final String? serialNumber;
  final int? yearManufactured;
  final DateTime? installationDate;
  final String condition;
  final String? notes;
  final int createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isLocal;
  final bool needsSync;
  const EquipmentData(
      {required this.id,
      required this.towerId,
      required this.equipmentType,
      required this.name,
      this.manufacturer,
      this.model,
      this.serialNumber,
      this.yearManufactured,
      this.installationDate,
      required this.condition,
      this.notes,
      required this.createdBy,
      required this.createdAt,
      this.updatedAt,
      required this.isLocal,
      required this.needsSync});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['tower_id'] = Variable<int>(towerId);
    map['equipment_type'] = Variable<String>(equipmentType);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || manufacturer != null) {
      map['manufacturer'] = Variable<String>(manufacturer);
    }
    if (!nullToAbsent || model != null) {
      map['model'] = Variable<String>(model);
    }
    if (!nullToAbsent || serialNumber != null) {
      map['serial_number'] = Variable<String>(serialNumber);
    }
    if (!nullToAbsent || yearManufactured != null) {
      map['year_manufactured'] = Variable<int>(yearManufactured);
    }
    if (!nullToAbsent || installationDate != null) {
      map['installation_date'] = Variable<DateTime>(installationDate);
    }
    map['condition'] = Variable<String>(condition);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_by'] = Variable<int>(createdBy);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['is_local'] = Variable<bool>(isLocal);
    map['needs_sync'] = Variable<bool>(needsSync);
    return map;
  }

  EquipmentCompanion toCompanion(bool nullToAbsent) {
    return EquipmentCompanion(
      id: Value(id),
      towerId: Value(towerId),
      equipmentType: Value(equipmentType),
      name: Value(name),
      manufacturer: manufacturer == null && nullToAbsent
          ? const Value.absent()
          : Value(manufacturer),
      model:
          model == null && nullToAbsent ? const Value.absent() : Value(model),
      serialNumber: serialNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(serialNumber),
      yearManufactured: yearManufactured == null && nullToAbsent
          ? const Value.absent()
          : Value(yearManufactured),
      installationDate: installationDate == null && nullToAbsent
          ? const Value.absent()
          : Value(installationDate),
      condition: Value(condition),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      createdBy: Value(createdBy),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      isLocal: Value(isLocal),
      needsSync: Value(needsSync),
    );
  }

  factory EquipmentData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EquipmentData(
      id: serializer.fromJson<int>(json['id']),
      towerId: serializer.fromJson<int>(json['towerId']),
      equipmentType: serializer.fromJson<String>(json['equipmentType']),
      name: serializer.fromJson<String>(json['name']),
      manufacturer: serializer.fromJson<String?>(json['manufacturer']),
      model: serializer.fromJson<String?>(json['model']),
      serialNumber: serializer.fromJson<String?>(json['serialNumber']),
      yearManufactured: serializer.fromJson<int?>(json['yearManufactured']),
      installationDate:
          serializer.fromJson<DateTime?>(json['installationDate']),
      condition: serializer.fromJson<String>(json['condition']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdBy: serializer.fromJson<int>(json['createdBy']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      isLocal: serializer.fromJson<bool>(json['isLocal']),
      needsSync: serializer.fromJson<bool>(json['needsSync']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'towerId': serializer.toJson<int>(towerId),
      'equipmentType': serializer.toJson<String>(equipmentType),
      'name': serializer.toJson<String>(name),
      'manufacturer': serializer.toJson<String?>(manufacturer),
      'model': serializer.toJson<String?>(model),
      'serialNumber': serializer.toJson<String?>(serialNumber),
      'yearManufactured': serializer.toJson<int?>(yearManufactured),
      'installationDate': serializer.toJson<DateTime?>(installationDate),
      'condition': serializer.toJson<String>(condition),
      'notes': serializer.toJson<String?>(notes),
      'createdBy': serializer.toJson<int>(createdBy),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'isLocal': serializer.toJson<bool>(isLocal),
      'needsSync': serializer.toJson<bool>(needsSync),
    };
  }

  EquipmentData copyWith(
          {int? id,
          int? towerId,
          String? equipmentType,
          String? name,
          Value<String?> manufacturer = const Value.absent(),
          Value<String?> model = const Value.absent(),
          Value<String?> serialNumber = const Value.absent(),
          Value<int?> yearManufactured = const Value.absent(),
          Value<DateTime?> installationDate = const Value.absent(),
          String? condition,
          Value<String?> notes = const Value.absent(),
          int? createdBy,
          DateTime? createdAt,
          Value<DateTime?> updatedAt = const Value.absent(),
          bool? isLocal,
          bool? needsSync}) =>
      EquipmentData(
        id: id ?? this.id,
        towerId: towerId ?? this.towerId,
        equipmentType: equipmentType ?? this.equipmentType,
        name: name ?? this.name,
        manufacturer:
            manufacturer.present ? manufacturer.value : this.manufacturer,
        model: model.present ? model.value : this.model,
        serialNumber:
            serialNumber.present ? serialNumber.value : this.serialNumber,
        yearManufactured: yearManufactured.present
            ? yearManufactured.value
            : this.yearManufactured,
        installationDate: installationDate.present
            ? installationDate.value
            : this.installationDate,
        condition: condition ?? this.condition,
        notes: notes.present ? notes.value : this.notes,
        createdBy: createdBy ?? this.createdBy,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
        isLocal: isLocal ?? this.isLocal,
        needsSync: needsSync ?? this.needsSync,
      );
  EquipmentData copyWithCompanion(EquipmentCompanion data) {
    return EquipmentData(
      id: data.id.present ? data.id.value : this.id,
      towerId: data.towerId.present ? data.towerId.value : this.towerId,
      equipmentType: data.equipmentType.present
          ? data.equipmentType.value
          : this.equipmentType,
      name: data.name.present ? data.name.value : this.name,
      manufacturer: data.manufacturer.present
          ? data.manufacturer.value
          : this.manufacturer,
      model: data.model.present ? data.model.value : this.model,
      serialNumber: data.serialNumber.present
          ? data.serialNumber.value
          : this.serialNumber,
      yearManufactured: data.yearManufactured.present
          ? data.yearManufactured.value
          : this.yearManufactured,
      installationDate: data.installationDate.present
          ? data.installationDate.value
          : this.installationDate,
      condition: data.condition.present ? data.condition.value : this.condition,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isLocal: data.isLocal.present ? data.isLocal.value : this.isLocal,
      needsSync: data.needsSync.present ? data.needsSync.value : this.needsSync,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EquipmentData(')
          ..write('id: $id, ')
          ..write('towerId: $towerId, ')
          ..write('equipmentType: $equipmentType, ')
          ..write('name: $name, ')
          ..write('manufacturer: $manufacturer, ')
          ..write('model: $model, ')
          ..write('serialNumber: $serialNumber, ')
          ..write('yearManufactured: $yearManufactured, ')
          ..write('installationDate: $installationDate, ')
          ..write('condition: $condition, ')
          ..write('notes: $notes, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isLocal: $isLocal, ')
          ..write('needsSync: $needsSync')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      towerId,
      equipmentType,
      name,
      manufacturer,
      model,
      serialNumber,
      yearManufactured,
      installationDate,
      condition,
      notes,
      createdBy,
      createdAt,
      updatedAt,
      isLocal,
      needsSync);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EquipmentData &&
          other.id == this.id &&
          other.towerId == this.towerId &&
          other.equipmentType == this.equipmentType &&
          other.name == this.name &&
          other.manufacturer == this.manufacturer &&
          other.model == this.model &&
          other.serialNumber == this.serialNumber &&
          other.yearManufactured == this.yearManufactured &&
          other.installationDate == this.installationDate &&
          other.condition == this.condition &&
          other.notes == this.notes &&
          other.createdBy == this.createdBy &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isLocal == this.isLocal &&
          other.needsSync == this.needsSync);
}

class EquipmentCompanion extends UpdateCompanion<EquipmentData> {
  final Value<int> id;
  final Value<int> towerId;
  final Value<String> equipmentType;
  final Value<String> name;
  final Value<String?> manufacturer;
  final Value<String?> model;
  final Value<String?> serialNumber;
  final Value<int?> yearManufactured;
  final Value<DateTime?> installationDate;
  final Value<String> condition;
  final Value<String?> notes;
  final Value<int> createdBy;
  final Value<DateTime> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<bool> isLocal;
  final Value<bool> needsSync;
  const EquipmentCompanion({
    this.id = const Value.absent(),
    this.towerId = const Value.absent(),
    this.equipmentType = const Value.absent(),
    this.name = const Value.absent(),
    this.manufacturer = const Value.absent(),
    this.model = const Value.absent(),
    this.serialNumber = const Value.absent(),
    this.yearManufactured = const Value.absent(),
    this.installationDate = const Value.absent(),
    this.condition = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isLocal = const Value.absent(),
    this.needsSync = const Value.absent(),
  });
  EquipmentCompanion.insert({
    this.id = const Value.absent(),
    required int towerId,
    required String equipmentType,
    required String name,
    this.manufacturer = const Value.absent(),
    this.model = const Value.absent(),
    this.serialNumber = const Value.absent(),
    this.yearManufactured = const Value.absent(),
    this.installationDate = const Value.absent(),
    required String condition,
    this.notes = const Value.absent(),
    required int createdBy,
    required DateTime createdAt,
    this.updatedAt = const Value.absent(),
    this.isLocal = const Value.absent(),
    this.needsSync = const Value.absent(),
  })  : towerId = Value(towerId),
        equipmentType = Value(equipmentType),
        name = Value(name),
        condition = Value(condition),
        createdBy = Value(createdBy),
        createdAt = Value(createdAt);
  static Insertable<EquipmentData> custom({
    Expression<int>? id,
    Expression<int>? towerId,
    Expression<String>? equipmentType,
    Expression<String>? name,
    Expression<String>? manufacturer,
    Expression<String>? model,
    Expression<String>? serialNumber,
    Expression<int>? yearManufactured,
    Expression<DateTime>? installationDate,
    Expression<String>? condition,
    Expression<String>? notes,
    Expression<int>? createdBy,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isLocal,
    Expression<bool>? needsSync,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (towerId != null) 'tower_id': towerId,
      if (equipmentType != null) 'equipment_type': equipmentType,
      if (name != null) 'name': name,
      if (manufacturer != null) 'manufacturer': manufacturer,
      if (model != null) 'model': model,
      if (serialNumber != null) 'serial_number': serialNumber,
      if (yearManufactured != null) 'year_manufactured': yearManufactured,
      if (installationDate != null) 'installation_date': installationDate,
      if (condition != null) 'condition': condition,
      if (notes != null) 'notes': notes,
      if (createdBy != null) 'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isLocal != null) 'is_local': isLocal,
      if (needsSync != null) 'needs_sync': needsSync,
    });
  }

  EquipmentCompanion copyWith(
      {Value<int>? id,
      Value<int>? towerId,
      Value<String>? equipmentType,
      Value<String>? name,
      Value<String?>? manufacturer,
      Value<String?>? model,
      Value<String?>? serialNumber,
      Value<int?>? yearManufactured,
      Value<DateTime?>? installationDate,
      Value<String>? condition,
      Value<String?>? notes,
      Value<int>? createdBy,
      Value<DateTime>? createdAt,
      Value<DateTime?>? updatedAt,
      Value<bool>? isLocal,
      Value<bool>? needsSync}) {
    return EquipmentCompanion(
      id: id ?? this.id,
      towerId: towerId ?? this.towerId,
      equipmentType: equipmentType ?? this.equipmentType,
      name: name ?? this.name,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      yearManufactured: yearManufactured ?? this.yearManufactured,
      installationDate: installationDate ?? this.installationDate,
      condition: condition ?? this.condition,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isLocal: isLocal ?? this.isLocal,
      needsSync: needsSync ?? this.needsSync,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (towerId.present) {
      map['tower_id'] = Variable<int>(towerId.value);
    }
    if (equipmentType.present) {
      map['equipment_type'] = Variable<String>(equipmentType.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (manufacturer.present) {
      map['manufacturer'] = Variable<String>(manufacturer.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (serialNumber.present) {
      map['serial_number'] = Variable<String>(serialNumber.value);
    }
    if (yearManufactured.present) {
      map['year_manufactured'] = Variable<int>(yearManufactured.value);
    }
    if (installationDate.present) {
      map['installation_date'] = Variable<DateTime>(installationDate.value);
    }
    if (condition.present) {
      map['condition'] = Variable<String>(condition.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<int>(createdBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isLocal.present) {
      map['is_local'] = Variable<bool>(isLocal.value);
    }
    if (needsSync.present) {
      map['needs_sync'] = Variable<bool>(needsSync.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EquipmentCompanion(')
          ..write('id: $id, ')
          ..write('towerId: $towerId, ')
          ..write('equipmentType: $equipmentType, ')
          ..write('name: $name, ')
          ..write('manufacturer: $manufacturer, ')
          ..write('model: $model, ')
          ..write('serialNumber: $serialNumber, ')
          ..write('yearManufactured: $yearManufactured, ')
          ..write('installationDate: $installationDate, ')
          ..write('condition: $condition, ')
          ..write('notes: $notes, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isLocal: $isLocal, ')
          ..write('needsSync: $needsSync')
          ..write(')'))
        .toString();
  }
}

class $SyncRecordsTable extends SyncRecords
    with TableInfo<$SyncRecordsTable, SyncRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityTypeMeta =
      const VerificationMeta('entityType');
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
      'entity_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
      'action', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
      'data', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
      'user_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _errorMessageMeta =
      const VerificationMeta('errorMessage');
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
      'error_message', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        entityType,
        action,
        data,
        timestamp,
        userId,
        deviceId,
        status,
        errorMessage
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_records';
  @override
  VerificationContext validateIntegrity(Insertable<SyncRecord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
          _entityTypeMeta,
          entityType.isAcceptableOrUnknown(
              data['entity_type']!, _entityTypeMeta));
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('action')) {
      context.handle(_actionMeta,
          action.isAcceptableOrUnknown(data['action']!, _actionMeta));
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
          _dataMeta, this.data.isAcceptableOrUnknown(data['data']!, _dataMeta));
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    }
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('error_message')) {
      context.handle(
          _errorMessageMeta,
          errorMessage.isAcceptableOrUnknown(
              data['error_message']!, _errorMessageMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncRecord(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      entityType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_type'])!,
      action: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}action'])!,
      data: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}data'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}user_id']),
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      errorMessage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}error_message']),
    );
  }

  @override
  $SyncRecordsTable createAlias(String alias) {
    return $SyncRecordsTable(attachedDatabase, alias);
  }
}

class SyncRecord extends DataClass implements Insertable<SyncRecord> {
  final String id;
  final String entityType;
  final String action;
  final String data;
  final DateTime timestamp;
  final int? userId;
  final String? deviceId;
  final String status;
  final String? errorMessage;
  const SyncRecord(
      {required this.id,
      required this.entityType,
      required this.action,
      required this.data,
      required this.timestamp,
      this.userId,
      this.deviceId,
      required this.status,
      this.errorMessage});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['entity_type'] = Variable<String>(entityType);
    map['action'] = Variable<String>(action);
    map['data'] = Variable<String>(data);
    map['timestamp'] = Variable<DateTime>(timestamp);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<int>(userId);
    }
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<String>(deviceId);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    return map;
  }

  SyncRecordsCompanion toCompanion(bool nullToAbsent) {
    return SyncRecordsCompanion(
      id: Value(id),
      entityType: Value(entityType),
      action: Value(action),
      data: Value(data),
      timestamp: Value(timestamp),
      userId:
          userId == null && nullToAbsent ? const Value.absent() : Value(userId),
      deviceId: deviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceId),
      status: Value(status),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
    );
  }

  factory SyncRecord.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncRecord(
      id: serializer.fromJson<String>(json['id']),
      entityType: serializer.fromJson<String>(json['entityType']),
      action: serializer.fromJson<String>(json['action']),
      data: serializer.fromJson<String>(json['data']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      userId: serializer.fromJson<int?>(json['userId']),
      deviceId: serializer.fromJson<String?>(json['deviceId']),
      status: serializer.fromJson<String>(json['status']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'entityType': serializer.toJson<String>(entityType),
      'action': serializer.toJson<String>(action),
      'data': serializer.toJson<String>(data),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'userId': serializer.toJson<int?>(userId),
      'deviceId': serializer.toJson<String?>(deviceId),
      'status': serializer.toJson<String>(status),
      'errorMessage': serializer.toJson<String?>(errorMessage),
    };
  }

  SyncRecord copyWith(
          {String? id,
          String? entityType,
          String? action,
          String? data,
          DateTime? timestamp,
          Value<int?> userId = const Value.absent(),
          Value<String?> deviceId = const Value.absent(),
          String? status,
          Value<String?> errorMessage = const Value.absent()}) =>
      SyncRecord(
        id: id ?? this.id,
        entityType: entityType ?? this.entityType,
        action: action ?? this.action,
        data: data ?? this.data,
        timestamp: timestamp ?? this.timestamp,
        userId: userId.present ? userId.value : this.userId,
        deviceId: deviceId.present ? deviceId.value : this.deviceId,
        status: status ?? this.status,
        errorMessage:
            errorMessage.present ? errorMessage.value : this.errorMessage,
      );
  SyncRecord copyWithCompanion(SyncRecordsCompanion data) {
    return SyncRecord(
      id: data.id.present ? data.id.value : this.id,
      entityType:
          data.entityType.present ? data.entityType.value : this.entityType,
      action: data.action.present ? data.action.value : this.action,
      data: data.data.present ? data.data.value : this.data,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      status: data.status.present ? data.status.value : this.status,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncRecord(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('action: $action, ')
          ..write('data: $data, ')
          ..write('timestamp: $timestamp, ')
          ..write('userId: $userId, ')
          ..write('deviceId: $deviceId, ')
          ..write('status: $status, ')
          ..write('errorMessage: $errorMessage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, entityType, action, data, timestamp,
      userId, deviceId, status, errorMessage);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncRecord &&
          other.id == this.id &&
          other.entityType == this.entityType &&
          other.action == this.action &&
          other.data == this.data &&
          other.timestamp == this.timestamp &&
          other.userId == this.userId &&
          other.deviceId == this.deviceId &&
          other.status == this.status &&
          other.errorMessage == this.errorMessage);
}

class SyncRecordsCompanion extends UpdateCompanion<SyncRecord> {
  final Value<String> id;
  final Value<String> entityType;
  final Value<String> action;
  final Value<String> data;
  final Value<DateTime> timestamp;
  final Value<int?> userId;
  final Value<String?> deviceId;
  final Value<String> status;
  final Value<String?> errorMessage;
  final Value<int> rowid;
  const SyncRecordsCompanion({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    this.action = const Value.absent(),
    this.data = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.userId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.status = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncRecordsCompanion.insert({
    required String id,
    required String entityType,
    required String action,
    required String data,
    required DateTime timestamp,
    this.userId = const Value.absent(),
    this.deviceId = const Value.absent(),
    required String status,
    this.errorMessage = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        entityType = Value(entityType),
        action = Value(action),
        data = Value(data),
        timestamp = Value(timestamp),
        status = Value(status);
  static Insertable<SyncRecord> custom({
    Expression<String>? id,
    Expression<String>? entityType,
    Expression<String>? action,
    Expression<String>? data,
    Expression<DateTime>? timestamp,
    Expression<int>? userId,
    Expression<String>? deviceId,
    Expression<String>? status,
    Expression<String>? errorMessage,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityType != null) 'entity_type': entityType,
      if (action != null) 'action': action,
      if (data != null) 'data': data,
      if (timestamp != null) 'timestamp': timestamp,
      if (userId != null) 'user_id': userId,
      if (deviceId != null) 'device_id': deviceId,
      if (status != null) 'status': status,
      if (errorMessage != null) 'error_message': errorMessage,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncRecordsCompanion copyWith(
      {Value<String>? id,
      Value<String>? entityType,
      Value<String>? action,
      Value<String>? data,
      Value<DateTime>? timestamp,
      Value<int?>? userId,
      Value<String?>? deviceId,
      Value<String>? status,
      Value<String?>? errorMessage,
      Value<int>? rowid}) {
    return SyncRecordsCompanion(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      action: action ?? this.action,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncRecordsCompanion(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('action: $action, ')
          ..write('data: $data, ')
          ..write('timestamp: $timestamp, ')
          ..write('userId: $userId, ')
          ..write('deviceId: $deviceId, ')
          ..write('status: $status, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PowerLinesTable powerLines = $PowerLinesTable(this);
  late final $TowersTable towers = $TowersTable(this);
  late final $EquipmentTable equipment = $EquipmentTable(this);
  late final $SyncRecordsTable syncRecords = $SyncRecordsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [powerLines, towers, equipment, syncRecords];
}

typedef $$PowerLinesTableCreateCompanionBuilder = PowerLinesCompanion Function({
  Value<int> id,
  required String name,
  required String code,
  required double voltageLevel,
  Value<double?> length,
  required int branchId,
  required int createdBy,
  required String status,
  Value<String?> description,
  required DateTime createdAt,
  Value<DateTime?> updatedAt,
  Value<bool> isLocal,
  Value<bool> needsSync,
});
typedef $$PowerLinesTableUpdateCompanionBuilder = PowerLinesCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> code,
  Value<double> voltageLevel,
  Value<double?> length,
  Value<int> branchId,
  Value<int> createdBy,
  Value<String> status,
  Value<String?> description,
  Value<DateTime> createdAt,
  Value<DateTime?> updatedAt,
  Value<bool> isLocal,
  Value<bool> needsSync,
});

class $$PowerLinesTableFilterComposer
    extends Composer<_$AppDatabase, $PowerLinesTable> {
  $$PowerLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get voltageLevel => $composableBuilder(
      column: $table.voltageLevel, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get length => $composableBuilder(
      column: $table.length, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdBy => $composableBuilder(
      column: $table.createdBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isLocal => $composableBuilder(
      column: $table.isLocal, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get needsSync => $composableBuilder(
      column: $table.needsSync, builder: (column) => ColumnFilters(column));
}

class $$PowerLinesTableOrderingComposer
    extends Composer<_$AppDatabase, $PowerLinesTable> {
  $$PowerLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get voltageLevel => $composableBuilder(
      column: $table.voltageLevel,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get length => $composableBuilder(
      column: $table.length, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdBy => $composableBuilder(
      column: $table.createdBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isLocal => $composableBuilder(
      column: $table.isLocal, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get needsSync => $composableBuilder(
      column: $table.needsSync, builder: (column) => ColumnOrderings(column));
}

class $$PowerLinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PowerLinesTable> {
  $$PowerLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<double> get voltageLevel => $composableBuilder(
      column: $table.voltageLevel, builder: (column) => column);

  GeneratedColumn<double> get length =>
      $composableBuilder(column: $table.length, builder: (column) => column);

  GeneratedColumn<int> get branchId =>
      $composableBuilder(column: $table.branchId, builder: (column) => column);

  GeneratedColumn<int> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isLocal =>
      $composableBuilder(column: $table.isLocal, builder: (column) => column);

  GeneratedColumn<bool> get needsSync =>
      $composableBuilder(column: $table.needsSync, builder: (column) => column);
}

class $$PowerLinesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PowerLinesTable,
    PowerLine,
    $$PowerLinesTableFilterComposer,
    $$PowerLinesTableOrderingComposer,
    $$PowerLinesTableAnnotationComposer,
    $$PowerLinesTableCreateCompanionBuilder,
    $$PowerLinesTableUpdateCompanionBuilder,
    (PowerLine, BaseReferences<_$AppDatabase, $PowerLinesTable, PowerLine>),
    PowerLine,
    PrefetchHooks Function()> {
  $$PowerLinesTableTableManager(_$AppDatabase db, $PowerLinesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PowerLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PowerLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PowerLinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> code = const Value.absent(),
            Value<double> voltageLevel = const Value.absent(),
            Value<double?> length = const Value.absent(),
            Value<int> branchId = const Value.absent(),
            Value<int> createdBy = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<bool> isLocal = const Value.absent(),
            Value<bool> needsSync = const Value.absent(),
          }) =>
              PowerLinesCompanion(
            id: id,
            name: name,
            code: code,
            voltageLevel: voltageLevel,
            length: length,
            branchId: branchId,
            createdBy: createdBy,
            status: status,
            description: description,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isLocal: isLocal,
            needsSync: needsSync,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            required String code,
            required double voltageLevel,
            Value<double?> length = const Value.absent(),
            required int branchId,
            required int createdBy,
            required String status,
            Value<String?> description = const Value.absent(),
            required DateTime createdAt,
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<bool> isLocal = const Value.absent(),
            Value<bool> needsSync = const Value.absent(),
          }) =>
              PowerLinesCompanion.insert(
            id: id,
            name: name,
            code: code,
            voltageLevel: voltageLevel,
            length: length,
            branchId: branchId,
            createdBy: createdBy,
            status: status,
            description: description,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isLocal: isLocal,
            needsSync: needsSync,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PowerLinesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PowerLinesTable,
    PowerLine,
    $$PowerLinesTableFilterComposer,
    $$PowerLinesTableOrderingComposer,
    $$PowerLinesTableAnnotationComposer,
    $$PowerLinesTableCreateCompanionBuilder,
    $$PowerLinesTableUpdateCompanionBuilder,
    (PowerLine, BaseReferences<_$AppDatabase, $PowerLinesTable, PowerLine>),
    PowerLine,
    PrefetchHooks Function()>;
typedef $$TowersTableCreateCompanionBuilder = TowersCompanion Function({
  Value<int> id,
  required int powerLineId,
  required String towerNumber,
  required double latitude,
  required double longitude,
  required String towerType,
  Value<double?> height,
  Value<String?> foundationType,
  Value<String?> material,
  Value<int?> yearInstalled,
  required String condition,
  Value<String?> notes,
  required int createdBy,
  required DateTime createdAt,
  Value<DateTime?> updatedAt,
  Value<bool> isLocal,
  Value<bool> needsSync,
});
typedef $$TowersTableUpdateCompanionBuilder = TowersCompanion Function({
  Value<int> id,
  Value<int> powerLineId,
  Value<String> towerNumber,
  Value<double> latitude,
  Value<double> longitude,
  Value<String> towerType,
  Value<double?> height,
  Value<String?> foundationType,
  Value<String?> material,
  Value<int?> yearInstalled,
  Value<String> condition,
  Value<String?> notes,
  Value<int> createdBy,
  Value<DateTime> createdAt,
  Value<DateTime?> updatedAt,
  Value<bool> isLocal,
  Value<bool> needsSync,
});

class $$TowersTableFilterComposer
    extends Composer<_$AppDatabase, $TowersTable> {
  $$TowersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get powerLineId => $composableBuilder(
      column: $table.powerLineId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get towerNumber => $composableBuilder(
      column: $table.towerNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get towerType => $composableBuilder(
      column: $table.towerType, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get height => $composableBuilder(
      column: $table.height, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get foundationType => $composableBuilder(
      column: $table.foundationType,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get material => $composableBuilder(
      column: $table.material, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get yearInstalled => $composableBuilder(
      column: $table.yearInstalled, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get condition => $composableBuilder(
      column: $table.condition, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdBy => $composableBuilder(
      column: $table.createdBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isLocal => $composableBuilder(
      column: $table.isLocal, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get needsSync => $composableBuilder(
      column: $table.needsSync, builder: (column) => ColumnFilters(column));
}

class $$TowersTableOrderingComposer
    extends Composer<_$AppDatabase, $TowersTable> {
  $$TowersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get powerLineId => $composableBuilder(
      column: $table.powerLineId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get towerNumber => $composableBuilder(
      column: $table.towerNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get towerType => $composableBuilder(
      column: $table.towerType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get height => $composableBuilder(
      column: $table.height, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get foundationType => $composableBuilder(
      column: $table.foundationType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get material => $composableBuilder(
      column: $table.material, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get yearInstalled => $composableBuilder(
      column: $table.yearInstalled,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get condition => $composableBuilder(
      column: $table.condition, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdBy => $composableBuilder(
      column: $table.createdBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isLocal => $composableBuilder(
      column: $table.isLocal, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get needsSync => $composableBuilder(
      column: $table.needsSync, builder: (column) => ColumnOrderings(column));
}

class $$TowersTableAnnotationComposer
    extends Composer<_$AppDatabase, $TowersTable> {
  $$TowersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get powerLineId => $composableBuilder(
      column: $table.powerLineId, builder: (column) => column);

  GeneratedColumn<String> get towerNumber => $composableBuilder(
      column: $table.towerNumber, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get towerType =>
      $composableBuilder(column: $table.towerType, builder: (column) => column);

  GeneratedColumn<double> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<String> get foundationType => $composableBuilder(
      column: $table.foundationType, builder: (column) => column);

  GeneratedColumn<String> get material =>
      $composableBuilder(column: $table.material, builder: (column) => column);

  GeneratedColumn<int> get yearInstalled => $composableBuilder(
      column: $table.yearInstalled, builder: (column) => column);

  GeneratedColumn<String> get condition =>
      $composableBuilder(column: $table.condition, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isLocal =>
      $composableBuilder(column: $table.isLocal, builder: (column) => column);

  GeneratedColumn<bool> get needsSync =>
      $composableBuilder(column: $table.needsSync, builder: (column) => column);
}

class $$TowersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TowersTable,
    Tower,
    $$TowersTableFilterComposer,
    $$TowersTableOrderingComposer,
    $$TowersTableAnnotationComposer,
    $$TowersTableCreateCompanionBuilder,
    $$TowersTableUpdateCompanionBuilder,
    (Tower, BaseReferences<_$AppDatabase, $TowersTable, Tower>),
    Tower,
    PrefetchHooks Function()> {
  $$TowersTableTableManager(_$AppDatabase db, $TowersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TowersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TowersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TowersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> powerLineId = const Value.absent(),
            Value<String> towerNumber = const Value.absent(),
            Value<double> latitude = const Value.absent(),
            Value<double> longitude = const Value.absent(),
            Value<String> towerType = const Value.absent(),
            Value<double?> height = const Value.absent(),
            Value<String?> foundationType = const Value.absent(),
            Value<String?> material = const Value.absent(),
            Value<int?> yearInstalled = const Value.absent(),
            Value<String> condition = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<int> createdBy = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<bool> isLocal = const Value.absent(),
            Value<bool> needsSync = const Value.absent(),
          }) =>
              TowersCompanion(
            id: id,
            powerLineId: powerLineId,
            towerNumber: towerNumber,
            latitude: latitude,
            longitude: longitude,
            towerType: towerType,
            height: height,
            foundationType: foundationType,
            material: material,
            yearInstalled: yearInstalled,
            condition: condition,
            notes: notes,
            createdBy: createdBy,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isLocal: isLocal,
            needsSync: needsSync,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int powerLineId,
            required String towerNumber,
            required double latitude,
            required double longitude,
            required String towerType,
            Value<double?> height = const Value.absent(),
            Value<String?> foundationType = const Value.absent(),
            Value<String?> material = const Value.absent(),
            Value<int?> yearInstalled = const Value.absent(),
            required String condition,
            Value<String?> notes = const Value.absent(),
            required int createdBy,
            required DateTime createdAt,
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<bool> isLocal = const Value.absent(),
            Value<bool> needsSync = const Value.absent(),
          }) =>
              TowersCompanion.insert(
            id: id,
            powerLineId: powerLineId,
            towerNumber: towerNumber,
            latitude: latitude,
            longitude: longitude,
            towerType: towerType,
            height: height,
            foundationType: foundationType,
            material: material,
            yearInstalled: yearInstalled,
            condition: condition,
            notes: notes,
            createdBy: createdBy,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isLocal: isLocal,
            needsSync: needsSync,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TowersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TowersTable,
    Tower,
    $$TowersTableFilterComposer,
    $$TowersTableOrderingComposer,
    $$TowersTableAnnotationComposer,
    $$TowersTableCreateCompanionBuilder,
    $$TowersTableUpdateCompanionBuilder,
    (Tower, BaseReferences<_$AppDatabase, $TowersTable, Tower>),
    Tower,
    PrefetchHooks Function()>;
typedef $$EquipmentTableCreateCompanionBuilder = EquipmentCompanion Function({
  Value<int> id,
  required int towerId,
  required String equipmentType,
  required String name,
  Value<String?> manufacturer,
  Value<String?> model,
  Value<String?> serialNumber,
  Value<int?> yearManufactured,
  Value<DateTime?> installationDate,
  required String condition,
  Value<String?> notes,
  required int createdBy,
  required DateTime createdAt,
  Value<DateTime?> updatedAt,
  Value<bool> isLocal,
  Value<bool> needsSync,
});
typedef $$EquipmentTableUpdateCompanionBuilder = EquipmentCompanion Function({
  Value<int> id,
  Value<int> towerId,
  Value<String> equipmentType,
  Value<String> name,
  Value<String?> manufacturer,
  Value<String?> model,
  Value<String?> serialNumber,
  Value<int?> yearManufactured,
  Value<DateTime?> installationDate,
  Value<String> condition,
  Value<String?> notes,
  Value<int> createdBy,
  Value<DateTime> createdAt,
  Value<DateTime?> updatedAt,
  Value<bool> isLocal,
  Value<bool> needsSync,
});

class $$EquipmentTableFilterComposer
    extends Composer<_$AppDatabase, $EquipmentTable> {
  $$EquipmentTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get towerId => $composableBuilder(
      column: $table.towerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get equipmentType => $composableBuilder(
      column: $table.equipmentType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get manufacturer => $composableBuilder(
      column: $table.manufacturer, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get model => $composableBuilder(
      column: $table.model, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serialNumber => $composableBuilder(
      column: $table.serialNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get yearManufactured => $composableBuilder(
      column: $table.yearManufactured,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get installationDate => $composableBuilder(
      column: $table.installationDate,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get condition => $composableBuilder(
      column: $table.condition, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdBy => $composableBuilder(
      column: $table.createdBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isLocal => $composableBuilder(
      column: $table.isLocal, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get needsSync => $composableBuilder(
      column: $table.needsSync, builder: (column) => ColumnFilters(column));
}

class $$EquipmentTableOrderingComposer
    extends Composer<_$AppDatabase, $EquipmentTable> {
  $$EquipmentTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get towerId => $composableBuilder(
      column: $table.towerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get equipmentType => $composableBuilder(
      column: $table.equipmentType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get manufacturer => $composableBuilder(
      column: $table.manufacturer,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get model => $composableBuilder(
      column: $table.model, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serialNumber => $composableBuilder(
      column: $table.serialNumber,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get yearManufactured => $composableBuilder(
      column: $table.yearManufactured,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get installationDate => $composableBuilder(
      column: $table.installationDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get condition => $composableBuilder(
      column: $table.condition, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdBy => $composableBuilder(
      column: $table.createdBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isLocal => $composableBuilder(
      column: $table.isLocal, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get needsSync => $composableBuilder(
      column: $table.needsSync, builder: (column) => ColumnOrderings(column));
}

class $$EquipmentTableAnnotationComposer
    extends Composer<_$AppDatabase, $EquipmentTable> {
  $$EquipmentTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get towerId =>
      $composableBuilder(column: $table.towerId, builder: (column) => column);

  GeneratedColumn<String> get equipmentType => $composableBuilder(
      column: $table.equipmentType, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get manufacturer => $composableBuilder(
      column: $table.manufacturer, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get serialNumber => $composableBuilder(
      column: $table.serialNumber, builder: (column) => column);

  GeneratedColumn<int> get yearManufactured => $composableBuilder(
      column: $table.yearManufactured, builder: (column) => column);

  GeneratedColumn<DateTime> get installationDate => $composableBuilder(
      column: $table.installationDate, builder: (column) => column);

  GeneratedColumn<String> get condition =>
      $composableBuilder(column: $table.condition, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isLocal =>
      $composableBuilder(column: $table.isLocal, builder: (column) => column);

  GeneratedColumn<bool> get needsSync =>
      $composableBuilder(column: $table.needsSync, builder: (column) => column);
}

class $$EquipmentTableTableManager extends RootTableManager<
    _$AppDatabase,
    $EquipmentTable,
    EquipmentData,
    $$EquipmentTableFilterComposer,
    $$EquipmentTableOrderingComposer,
    $$EquipmentTableAnnotationComposer,
    $$EquipmentTableCreateCompanionBuilder,
    $$EquipmentTableUpdateCompanionBuilder,
    (
      EquipmentData,
      BaseReferences<_$AppDatabase, $EquipmentTable, EquipmentData>
    ),
    EquipmentData,
    PrefetchHooks Function()> {
  $$EquipmentTableTableManager(_$AppDatabase db, $EquipmentTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EquipmentTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EquipmentTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EquipmentTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> towerId = const Value.absent(),
            Value<String> equipmentType = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> manufacturer = const Value.absent(),
            Value<String?> model = const Value.absent(),
            Value<String?> serialNumber = const Value.absent(),
            Value<int?> yearManufactured = const Value.absent(),
            Value<DateTime?> installationDate = const Value.absent(),
            Value<String> condition = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<int> createdBy = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<bool> isLocal = const Value.absent(),
            Value<bool> needsSync = const Value.absent(),
          }) =>
              EquipmentCompanion(
            id: id,
            towerId: towerId,
            equipmentType: equipmentType,
            name: name,
            manufacturer: manufacturer,
            model: model,
            serialNumber: serialNumber,
            yearManufactured: yearManufactured,
            installationDate: installationDate,
            condition: condition,
            notes: notes,
            createdBy: createdBy,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isLocal: isLocal,
            needsSync: needsSync,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int towerId,
            required String equipmentType,
            required String name,
            Value<String?> manufacturer = const Value.absent(),
            Value<String?> model = const Value.absent(),
            Value<String?> serialNumber = const Value.absent(),
            Value<int?> yearManufactured = const Value.absent(),
            Value<DateTime?> installationDate = const Value.absent(),
            required String condition,
            Value<String?> notes = const Value.absent(),
            required int createdBy,
            required DateTime createdAt,
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<bool> isLocal = const Value.absent(),
            Value<bool> needsSync = const Value.absent(),
          }) =>
              EquipmentCompanion.insert(
            id: id,
            towerId: towerId,
            equipmentType: equipmentType,
            name: name,
            manufacturer: manufacturer,
            model: model,
            serialNumber: serialNumber,
            yearManufactured: yearManufactured,
            installationDate: installationDate,
            condition: condition,
            notes: notes,
            createdBy: createdBy,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isLocal: isLocal,
            needsSync: needsSync,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$EquipmentTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $EquipmentTable,
    EquipmentData,
    $$EquipmentTableFilterComposer,
    $$EquipmentTableOrderingComposer,
    $$EquipmentTableAnnotationComposer,
    $$EquipmentTableCreateCompanionBuilder,
    $$EquipmentTableUpdateCompanionBuilder,
    (
      EquipmentData,
      BaseReferences<_$AppDatabase, $EquipmentTable, EquipmentData>
    ),
    EquipmentData,
    PrefetchHooks Function()>;
typedef $$SyncRecordsTableCreateCompanionBuilder = SyncRecordsCompanion
    Function({
  required String id,
  required String entityType,
  required String action,
  required String data,
  required DateTime timestamp,
  Value<int?> userId,
  Value<String?> deviceId,
  required String status,
  Value<String?> errorMessage,
  Value<int> rowid,
});
typedef $$SyncRecordsTableUpdateCompanionBuilder = SyncRecordsCompanion
    Function({
  Value<String> id,
  Value<String> entityType,
  Value<String> action,
  Value<String> data,
  Value<DateTime> timestamp,
  Value<int?> userId,
  Value<String?> deviceId,
  Value<String> status,
  Value<String?> errorMessage,
  Value<int> rowid,
});

class $$SyncRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncRecordsTable> {
  $$SyncRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get action => $composableBuilder(
      column: $table.action, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get data => $composableBuilder(
      column: $table.data, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => ColumnFilters(column));
}

class $$SyncRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncRecordsTable> {
  $$SyncRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get action => $composableBuilder(
      column: $table.action, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get data => $composableBuilder(
      column: $table.data, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage,
      builder: (column) => ColumnOrderings(column));
}

class $$SyncRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncRecordsTable> {
  $$SyncRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => column);
}

class $$SyncRecordsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncRecordsTable,
    SyncRecord,
    $$SyncRecordsTableFilterComposer,
    $$SyncRecordsTableOrderingComposer,
    $$SyncRecordsTableAnnotationComposer,
    $$SyncRecordsTableCreateCompanionBuilder,
    $$SyncRecordsTableUpdateCompanionBuilder,
    (SyncRecord, BaseReferences<_$AppDatabase, $SyncRecordsTable, SyncRecord>),
    SyncRecord,
    PrefetchHooks Function()> {
  $$SyncRecordsTableTableManager(_$AppDatabase db, $SyncRecordsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> entityType = const Value.absent(),
            Value<String> action = const Value.absent(),
            Value<String> data = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<int?> userId = const Value.absent(),
            Value<String?> deviceId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> errorMessage = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncRecordsCompanion(
            id: id,
            entityType: entityType,
            action: action,
            data: data,
            timestamp: timestamp,
            userId: userId,
            deviceId: deviceId,
            status: status,
            errorMessage: errorMessage,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String entityType,
            required String action,
            required String data,
            required DateTime timestamp,
            Value<int?> userId = const Value.absent(),
            Value<String?> deviceId = const Value.absent(),
            required String status,
            Value<String?> errorMessage = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncRecordsCompanion.insert(
            id: id,
            entityType: entityType,
            action: action,
            data: data,
            timestamp: timestamp,
            userId: userId,
            deviceId: deviceId,
            status: status,
            errorMessage: errorMessage,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncRecordsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncRecordsTable,
    SyncRecord,
    $$SyncRecordsTableFilterComposer,
    $$SyncRecordsTableOrderingComposer,
    $$SyncRecordsTableAnnotationComposer,
    $$SyncRecordsTableCreateCompanionBuilder,
    $$SyncRecordsTableUpdateCompanionBuilder,
    (SyncRecord, BaseReferences<_$AppDatabase, $SyncRecordsTable, SyncRecord>),
    SyncRecord,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PowerLinesTableTableManager get powerLines =>
      $$PowerLinesTableTableManager(_db, _db.powerLines);
  $$TowersTableTableManager get towers =>
      $$TowersTableTableManager(_db, _db.towers);
  $$EquipmentTableTableManager get equipment =>
      $$EquipmentTableTableManager(_db, _db.equipment);
  $$SyncRecordsTableTableManager get syncRecords =>
      $$SyncRecordsTableTableManager(_db, _db.syncRecords);
}
