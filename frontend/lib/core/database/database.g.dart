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
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mridMeta = const VerificationMeta('mrid');
  @override
  late final GeneratedColumn<String> mrid = GeneratedColumn<String>(
    'mrid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _voltageLevelMeta = const VerificationMeta(
    'voltageLevel',
  );
  @override
  late final GeneratedColumn<double> voltageLevel = GeneratedColumn<double>(
    'voltage_level',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lengthMeta = const VerificationMeta('length');
  @override
  late final GeneratedColumn<double> length = GeneratedColumn<double>(
    'length',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _branchIdMeta = const VerificationMeta(
    'branchId',
  );
  @override
  late final GeneratedColumn<int> branchId = GeneratedColumn<int>(
    'branch_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<int> createdBy = GeneratedColumn<int>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isLocalMeta = const VerificationMeta(
    'isLocal',
  );
  @override
  late final GeneratedColumn<bool> isLocal = GeneratedColumn<bool>(
    'is_local',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_local" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _needsSyncMeta = const VerificationMeta(
    'needsSync',
  );
  @override
  late final GeneratedColumn<bool> needsSync = GeneratedColumn<bool>(
    'needs_sync',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("needs_sync" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    code,
    mrid,
    voltageLevel,
    length,
    branchId,
    createdBy,
    status,
    description,
    createdAt,
    updatedAt,
    isLocal,
    needsSync,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'power_lines';
  @override
  VerificationContext validateIntegrity(
    Insertable<PowerLine> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('mrid')) {
      context.handle(
        _mridMeta,
        mrid.isAcceptableOrUnknown(data['mrid']!, _mridMeta),
      );
    }
    if (data.containsKey('voltage_level')) {
      context.handle(
        _voltageLevelMeta,
        voltageLevel.isAcceptableOrUnknown(
          data['voltage_level']!,
          _voltageLevelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_voltageLevelMeta);
    }
    if (data.containsKey('length')) {
      context.handle(
        _lengthMeta,
        length.isAcceptableOrUnknown(data['length']!, _lengthMeta),
      );
    }
    if (data.containsKey('branch_id')) {
      context.handle(
        _branchIdMeta,
        branchId.isAcceptableOrUnknown(data['branch_id']!, _branchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_branchIdMeta);
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('is_local')) {
      context.handle(
        _isLocalMeta,
        isLocal.isAcceptableOrUnknown(data['is_local']!, _isLocalMeta),
      );
    }
    if (data.containsKey('needs_sync')) {
      context.handle(
        _needsSyncMeta,
        needsSync.isAcceptableOrUnknown(data['needs_sync']!, _needsSyncMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PowerLine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PowerLine(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      mrid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mrid'],
      ),
      voltageLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}voltage_level'],
      )!,
      length: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}length'],
      ),
      branchId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}branch_id'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_by'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      isLocal: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_local'],
      )!,
      needsSync: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}needs_sync'],
      )!,
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
  final String? mrid;
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
  const PowerLine({
    required this.id,
    required this.name,
    required this.code,
    this.mrid,
    required this.voltageLevel,
    this.length,
    required this.branchId,
    required this.createdBy,
    required this.status,
    this.description,
    required this.createdAt,
    this.updatedAt,
    required this.isLocal,
    required this.needsSync,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['code'] = Variable<String>(code);
    if (!nullToAbsent || mrid != null) {
      map['mrid'] = Variable<String>(mrid);
    }
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
      mrid: mrid == null && nullToAbsent ? const Value.absent() : Value(mrid),
      voltageLevel: Value(voltageLevel),
      length: length == null && nullToAbsent
          ? const Value.absent()
          : Value(length),
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

  factory PowerLine.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PowerLine(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      code: serializer.fromJson<String>(json['code']),
      mrid: serializer.fromJson<String?>(json['mrid']),
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
      'mrid': serializer.toJson<String?>(mrid),
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

  PowerLine copyWith({
    int? id,
    String? name,
    String? code,
    Value<String?> mrid = const Value.absent(),
    double? voltageLevel,
    Value<double?> length = const Value.absent(),
    int? branchId,
    int? createdBy,
    String? status,
    Value<String?> description = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> updatedAt = const Value.absent(),
    bool? isLocal,
    bool? needsSync,
  }) => PowerLine(
    id: id ?? this.id,
    name: name ?? this.name,
    code: code ?? this.code,
    mrid: mrid.present ? mrid.value : this.mrid,
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
      mrid: data.mrid.present ? data.mrid.value : this.mrid,
      voltageLevel: data.voltageLevel.present
          ? data.voltageLevel.value
          : this.voltageLevel,
      length: data.length.present ? data.length.value : this.length,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      status: data.status.present ? data.status.value : this.status,
      description: data.description.present
          ? data.description.value
          : this.description,
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
          ..write('mrid: $mrid, ')
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
    mrid,
    voltageLevel,
    length,
    branchId,
    createdBy,
    status,
    description,
    createdAt,
    updatedAt,
    isLocal,
    needsSync,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PowerLine &&
          other.id == this.id &&
          other.name == this.name &&
          other.code == this.code &&
          other.mrid == this.mrid &&
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
  final Value<String?> mrid;
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
    this.mrid = const Value.absent(),
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
    this.mrid = const Value.absent(),
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
  }) : name = Value(name),
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
    Expression<String>? mrid,
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
      if (mrid != null) 'mrid': mrid,
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

  PowerLinesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? code,
    Value<String?>? mrid,
    Value<double>? voltageLevel,
    Value<double?>? length,
    Value<int>? branchId,
    Value<int>? createdBy,
    Value<String>? status,
    Value<String?>? description,
    Value<DateTime>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<bool>? isLocal,
    Value<bool>? needsSync,
  }) {
    return PowerLinesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      mrid: mrid ?? this.mrid,
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
    if (mrid.present) {
      map['mrid'] = Variable<String>(mrid.value);
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
          ..write('mrid: $mrid, ')
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

class $PolesTable extends Poles with TableInfo<$PolesTable, Pole> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PolesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lineIdMeta = const VerificationMeta('lineId');
  @override
  late final GeneratedColumn<int> lineId = GeneratedColumn<int>(
    'line_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _poleNumberMeta = const VerificationMeta(
    'poleNumber',
  );
  @override
  late final GeneratedColumn<String> poleNumber = GeneratedColumn<String>(
    'pole_number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _xPositionMeta = const VerificationMeta(
    'xPosition',
  );
  @override
  late final GeneratedColumn<double> xPosition = GeneratedColumn<double>(
    'x_position',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yPositionMeta = const VerificationMeta(
    'yPosition',
  );
  @override
  late final GeneratedColumn<double> yPosition = GeneratedColumn<double>(
    'y_position',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _poleTypeMeta = const VerificationMeta(
    'poleType',
  );
  @override
  late final GeneratedColumn<String> poleType = GeneratedColumn<String>(
    'pole_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<double> height = GeneratedColumn<double>(
    'height',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _foundationTypeMeta = const VerificationMeta(
    'foundationType',
  );
  @override
  late final GeneratedColumn<String> foundationType = GeneratedColumn<String>(
    'foundation_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _materialMeta = const VerificationMeta(
    'material',
  );
  @override
  late final GeneratedColumn<String> material = GeneratedColumn<String>(
    'material',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearInstalledMeta = const VerificationMeta(
    'yearInstalled',
  );
  @override
  late final GeneratedColumn<int> yearInstalled = GeneratedColumn<int>(
    'year_installed',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _conditionMeta = const VerificationMeta(
    'condition',
  );
  @override
  late final GeneratedColumn<String> condition = GeneratedColumn<String>(
    'condition',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _structuralDefectMeta = const VerificationMeta(
    'structuralDefect',
  );
  @override
  late final GeneratedColumn<String> structuralDefect = GeneratedColumn<String>(
    'structural_defect',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _structuralDefectCriticalityMeta =
      const VerificationMeta('structuralDefectCriticality');
  @override
  late final GeneratedColumn<String> structuralDefectCriticality =
      GeneratedColumn<String>(
        'structural_defect_criticality',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _cardCommentMeta = const VerificationMeta(
    'cardComment',
  );
  @override
  late final GeneratedColumn<String> cardComment = GeneratedColumn<String>(
    'card_comment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cardCommentAttachmentMeta =
      const VerificationMeta('cardCommentAttachment');
  @override
  late final GeneratedColumn<String> cardCommentAttachment =
      GeneratedColumn<String>(
        'card_comment_attachment',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<int> createdBy = GeneratedColumn<int>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isLocalMeta = const VerificationMeta(
    'isLocal',
  );
  @override
  late final GeneratedColumn<bool> isLocal = GeneratedColumn<bool>(
    'is_local',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_local" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _needsSyncMeta = const VerificationMeta(
    'needsSync',
  );
  @override
  late final GeneratedColumn<bool> needsSync = GeneratedColumn<bool>(
    'needs_sync',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("needs_sync" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    lineId,
    poleNumber,
    xPosition,
    yPosition,
    poleType,
    height,
    foundationType,
    material,
    yearInstalled,
    condition,
    notes,
    structuralDefect,
    structuralDefectCriticality,
    cardComment,
    cardCommentAttachment,
    createdBy,
    createdAt,
    updatedAt,
    isLocal,
    needsSync,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'poles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Pole> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('line_id')) {
      context.handle(
        _lineIdMeta,
        lineId.isAcceptableOrUnknown(data['line_id']!, _lineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lineIdMeta);
    }
    if (data.containsKey('pole_number')) {
      context.handle(
        _poleNumberMeta,
        poleNumber.isAcceptableOrUnknown(data['pole_number']!, _poleNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_poleNumberMeta);
    }
    if (data.containsKey('x_position')) {
      context.handle(
        _xPositionMeta,
        xPosition.isAcceptableOrUnknown(data['x_position']!, _xPositionMeta),
      );
    }
    if (data.containsKey('y_position')) {
      context.handle(
        _yPositionMeta,
        yPosition.isAcceptableOrUnknown(data['y_position']!, _yPositionMeta),
      );
    }
    if (data.containsKey('pole_type')) {
      context.handle(
        _poleTypeMeta,
        poleType.isAcceptableOrUnknown(data['pole_type']!, _poleTypeMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('foundation_type')) {
      context.handle(
        _foundationTypeMeta,
        foundationType.isAcceptableOrUnknown(
          data['foundation_type']!,
          _foundationTypeMeta,
        ),
      );
    }
    if (data.containsKey('material')) {
      context.handle(
        _materialMeta,
        material.isAcceptableOrUnknown(data['material']!, _materialMeta),
      );
    }
    if (data.containsKey('year_installed')) {
      context.handle(
        _yearInstalledMeta,
        yearInstalled.isAcceptableOrUnknown(
          data['year_installed']!,
          _yearInstalledMeta,
        ),
      );
    }
    if (data.containsKey('condition')) {
      context.handle(
        _conditionMeta,
        condition.isAcceptableOrUnknown(data['condition']!, _conditionMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('structural_defect')) {
      context.handle(
        _structuralDefectMeta,
        structuralDefect.isAcceptableOrUnknown(
          data['structural_defect']!,
          _structuralDefectMeta,
        ),
      );
    }
    if (data.containsKey('structural_defect_criticality')) {
      context.handle(
        _structuralDefectCriticalityMeta,
        structuralDefectCriticality.isAcceptableOrUnknown(
          data['structural_defect_criticality']!,
          _structuralDefectCriticalityMeta,
        ),
      );
    }
    if (data.containsKey('card_comment')) {
      context.handle(
        _cardCommentMeta,
        cardComment.isAcceptableOrUnknown(
          data['card_comment']!,
          _cardCommentMeta,
        ),
      );
    }
    if (data.containsKey('card_comment_attachment')) {
      context.handle(
        _cardCommentAttachmentMeta,
        cardCommentAttachment.isAcceptableOrUnknown(
          data['card_comment_attachment']!,
          _cardCommentAttachmentMeta,
        ),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('is_local')) {
      context.handle(
        _isLocalMeta,
        isLocal.isAcceptableOrUnknown(data['is_local']!, _isLocalMeta),
      );
    }
    if (data.containsKey('needs_sync')) {
      context.handle(
        _needsSyncMeta,
        needsSync.isAcceptableOrUnknown(data['needs_sync']!, _needsSyncMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Pole map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Pole(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      lineId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line_id'],
      )!,
      poleNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pole_number'],
      )!,
      xPosition: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}x_position'],
      ),
      yPosition: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}y_position'],
      ),
      poleType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pole_type'],
      ),
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}height'],
      ),
      foundationType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}foundation_type'],
      ),
      material: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}material'],
      ),
      yearInstalled: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year_installed'],
      ),
      condition: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}condition'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      structuralDefect: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}structural_defect'],
      ),
      structuralDefectCriticality: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}structural_defect_criticality'],
      ),
      cardComment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_comment'],
      ),
      cardCommentAttachment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_comment_attachment'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_by'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      isLocal: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_local'],
      )!,
      needsSync: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}needs_sync'],
      )!,
    );
  }

  @override
  $PolesTable createAlias(String alias) {
    return $PolesTable(attachedDatabase, alias);
  }
}

class Pole extends DataClass implements Insertable<Pole> {
  final int id;

  /// ID линии (ЛЭП). Единое поле line_id (в БД колонка line_id).
  final int lineId;
  final String poleNumber;

  /// Долгота (longitude), CIM x_position
  final double? xPosition;

  /// Широта (latitude), CIM y_position
  final double? yPosition;
  final String? poleType;
  final double? height;
  final String? foundationType;
  final String? material;
  final int? yearInstalled;
  final String? condition;
  final String? notes;

  /// Дефект конструкции опоры (текст)
  final String? structuralDefect;

  /// Критичность дефекта опоры: low | medium | high
  final String? structuralDefectCriticality;

  /// Комментарий в конце карточки опоры (текст)
  final String? cardComment;

  /// Вложения к комментарию: голос/фото (JSON: [{"t":"voice"|"photo","p":"path"}])
  final String? cardCommentAttachment;
  final int createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isLocal;
  final bool needsSync;
  const Pole({
    required this.id,
    required this.lineId,
    required this.poleNumber,
    this.xPosition,
    this.yPosition,
    this.poleType,
    this.height,
    this.foundationType,
    this.material,
    this.yearInstalled,
    this.condition,
    this.notes,
    this.structuralDefect,
    this.structuralDefectCriticality,
    this.cardComment,
    this.cardCommentAttachment,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    required this.isLocal,
    required this.needsSync,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['line_id'] = Variable<int>(lineId);
    map['pole_number'] = Variable<String>(poleNumber);
    if (!nullToAbsent || xPosition != null) {
      map['x_position'] = Variable<double>(xPosition);
    }
    if (!nullToAbsent || yPosition != null) {
      map['y_position'] = Variable<double>(yPosition);
    }
    if (!nullToAbsent || poleType != null) {
      map['pole_type'] = Variable<String>(poleType);
    }
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
    if (!nullToAbsent || condition != null) {
      map['condition'] = Variable<String>(condition);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || structuralDefect != null) {
      map['structural_defect'] = Variable<String>(structuralDefect);
    }
    if (!nullToAbsent || structuralDefectCriticality != null) {
      map['structural_defect_criticality'] = Variable<String>(
        structuralDefectCriticality,
      );
    }
    if (!nullToAbsent || cardComment != null) {
      map['card_comment'] = Variable<String>(cardComment);
    }
    if (!nullToAbsent || cardCommentAttachment != null) {
      map['card_comment_attachment'] = Variable<String>(cardCommentAttachment);
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

  PolesCompanion toCompanion(bool nullToAbsent) {
    return PolesCompanion(
      id: Value(id),
      lineId: Value(lineId),
      poleNumber: Value(poleNumber),
      xPosition: xPosition == null && nullToAbsent
          ? const Value.absent()
          : Value(xPosition),
      yPosition: yPosition == null && nullToAbsent
          ? const Value.absent()
          : Value(yPosition),
      poleType: poleType == null && nullToAbsent
          ? const Value.absent()
          : Value(poleType),
      height: height == null && nullToAbsent
          ? const Value.absent()
          : Value(height),
      foundationType: foundationType == null && nullToAbsent
          ? const Value.absent()
          : Value(foundationType),
      material: material == null && nullToAbsent
          ? const Value.absent()
          : Value(material),
      yearInstalled: yearInstalled == null && nullToAbsent
          ? const Value.absent()
          : Value(yearInstalled),
      condition: condition == null && nullToAbsent
          ? const Value.absent()
          : Value(condition),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      structuralDefect: structuralDefect == null && nullToAbsent
          ? const Value.absent()
          : Value(structuralDefect),
      structuralDefectCriticality:
          structuralDefectCriticality == null && nullToAbsent
          ? const Value.absent()
          : Value(structuralDefectCriticality),
      cardComment: cardComment == null && nullToAbsent
          ? const Value.absent()
          : Value(cardComment),
      cardCommentAttachment: cardCommentAttachment == null && nullToAbsent
          ? const Value.absent()
          : Value(cardCommentAttachment),
      createdBy: Value(createdBy),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      isLocal: Value(isLocal),
      needsSync: Value(needsSync),
    );
  }

  factory Pole.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Pole(
      id: serializer.fromJson<int>(json['id']),
      lineId: serializer.fromJson<int>(json['lineId']),
      poleNumber: serializer.fromJson<String>(json['poleNumber']),
      xPosition: serializer.fromJson<double?>(json['xPosition']),
      yPosition: serializer.fromJson<double?>(json['yPosition']),
      poleType: serializer.fromJson<String?>(json['poleType']),
      height: serializer.fromJson<double?>(json['height']),
      foundationType: serializer.fromJson<String?>(json['foundationType']),
      material: serializer.fromJson<String?>(json['material']),
      yearInstalled: serializer.fromJson<int?>(json['yearInstalled']),
      condition: serializer.fromJson<String?>(json['condition']),
      notes: serializer.fromJson<String?>(json['notes']),
      structuralDefect: serializer.fromJson<String?>(json['structuralDefect']),
      structuralDefectCriticality: serializer.fromJson<String?>(
        json['structuralDefectCriticality'],
      ),
      cardComment: serializer.fromJson<String?>(json['cardComment']),
      cardCommentAttachment: serializer.fromJson<String?>(
        json['cardCommentAttachment'],
      ),
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
      'lineId': serializer.toJson<int>(lineId),
      'poleNumber': serializer.toJson<String>(poleNumber),
      'xPosition': serializer.toJson<double?>(xPosition),
      'yPosition': serializer.toJson<double?>(yPosition),
      'poleType': serializer.toJson<String?>(poleType),
      'height': serializer.toJson<double?>(height),
      'foundationType': serializer.toJson<String?>(foundationType),
      'material': serializer.toJson<String?>(material),
      'yearInstalled': serializer.toJson<int?>(yearInstalled),
      'condition': serializer.toJson<String?>(condition),
      'notes': serializer.toJson<String?>(notes),
      'structuralDefect': serializer.toJson<String?>(structuralDefect),
      'structuralDefectCriticality': serializer.toJson<String?>(
        structuralDefectCriticality,
      ),
      'cardComment': serializer.toJson<String?>(cardComment),
      'cardCommentAttachment': serializer.toJson<String?>(
        cardCommentAttachment,
      ),
      'createdBy': serializer.toJson<int>(createdBy),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'isLocal': serializer.toJson<bool>(isLocal),
      'needsSync': serializer.toJson<bool>(needsSync),
    };
  }

  Pole copyWith({
    int? id,
    int? lineId,
    String? poleNumber,
    Value<double?> xPosition = const Value.absent(),
    Value<double?> yPosition = const Value.absent(),
    Value<String?> poleType = const Value.absent(),
    Value<double?> height = const Value.absent(),
    Value<String?> foundationType = const Value.absent(),
    Value<String?> material = const Value.absent(),
    Value<int?> yearInstalled = const Value.absent(),
    Value<String?> condition = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<String?> structuralDefect = const Value.absent(),
    Value<String?> structuralDefectCriticality = const Value.absent(),
    Value<String?> cardComment = const Value.absent(),
    Value<String?> cardCommentAttachment = const Value.absent(),
    int? createdBy,
    DateTime? createdAt,
    Value<DateTime?> updatedAt = const Value.absent(),
    bool? isLocal,
    bool? needsSync,
  }) => Pole(
    id: id ?? this.id,
    lineId: lineId ?? this.lineId,
    poleNumber: poleNumber ?? this.poleNumber,
    xPosition: xPosition.present ? xPosition.value : this.xPosition,
    yPosition: yPosition.present ? yPosition.value : this.yPosition,
    poleType: poleType.present ? poleType.value : this.poleType,
    height: height.present ? height.value : this.height,
    foundationType: foundationType.present
        ? foundationType.value
        : this.foundationType,
    material: material.present ? material.value : this.material,
    yearInstalled: yearInstalled.present
        ? yearInstalled.value
        : this.yearInstalled,
    condition: condition.present ? condition.value : this.condition,
    notes: notes.present ? notes.value : this.notes,
    structuralDefect: structuralDefect.present
        ? structuralDefect.value
        : this.structuralDefect,
    structuralDefectCriticality: structuralDefectCriticality.present
        ? structuralDefectCriticality.value
        : this.structuralDefectCriticality,
    cardComment: cardComment.present ? cardComment.value : this.cardComment,
    cardCommentAttachment: cardCommentAttachment.present
        ? cardCommentAttachment.value
        : this.cardCommentAttachment,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    isLocal: isLocal ?? this.isLocal,
    needsSync: needsSync ?? this.needsSync,
  );
  Pole copyWithCompanion(PolesCompanion data) {
    return Pole(
      id: data.id.present ? data.id.value : this.id,
      lineId: data.lineId.present ? data.lineId.value : this.lineId,
      poleNumber: data.poleNumber.present
          ? data.poleNumber.value
          : this.poleNumber,
      xPosition: data.xPosition.present ? data.xPosition.value : this.xPosition,
      yPosition: data.yPosition.present ? data.yPosition.value : this.yPosition,
      poleType: data.poleType.present ? data.poleType.value : this.poleType,
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
      structuralDefect: data.structuralDefect.present
          ? data.structuralDefect.value
          : this.structuralDefect,
      structuralDefectCriticality: data.structuralDefectCriticality.present
          ? data.structuralDefectCriticality.value
          : this.structuralDefectCriticality,
      cardComment: data.cardComment.present
          ? data.cardComment.value
          : this.cardComment,
      cardCommentAttachment: data.cardCommentAttachment.present
          ? data.cardCommentAttachment.value
          : this.cardCommentAttachment,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isLocal: data.isLocal.present ? data.isLocal.value : this.isLocal,
      needsSync: data.needsSync.present ? data.needsSync.value : this.needsSync,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Pole(')
          ..write('id: $id, ')
          ..write('lineId: $lineId, ')
          ..write('poleNumber: $poleNumber, ')
          ..write('xPosition: $xPosition, ')
          ..write('yPosition: $yPosition, ')
          ..write('poleType: $poleType, ')
          ..write('height: $height, ')
          ..write('foundationType: $foundationType, ')
          ..write('material: $material, ')
          ..write('yearInstalled: $yearInstalled, ')
          ..write('condition: $condition, ')
          ..write('notes: $notes, ')
          ..write('structuralDefect: $structuralDefect, ')
          ..write('structuralDefectCriticality: $structuralDefectCriticality, ')
          ..write('cardComment: $cardComment, ')
          ..write('cardCommentAttachment: $cardCommentAttachment, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isLocal: $isLocal, ')
          ..write('needsSync: $needsSync')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    lineId,
    poleNumber,
    xPosition,
    yPosition,
    poleType,
    height,
    foundationType,
    material,
    yearInstalled,
    condition,
    notes,
    structuralDefect,
    structuralDefectCriticality,
    cardComment,
    cardCommentAttachment,
    createdBy,
    createdAt,
    updatedAt,
    isLocal,
    needsSync,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Pole &&
          other.id == this.id &&
          other.lineId == this.lineId &&
          other.poleNumber == this.poleNumber &&
          other.xPosition == this.xPosition &&
          other.yPosition == this.yPosition &&
          other.poleType == this.poleType &&
          other.height == this.height &&
          other.foundationType == this.foundationType &&
          other.material == this.material &&
          other.yearInstalled == this.yearInstalled &&
          other.condition == this.condition &&
          other.notes == this.notes &&
          other.structuralDefect == this.structuralDefect &&
          other.structuralDefectCriticality ==
              this.structuralDefectCriticality &&
          other.cardComment == this.cardComment &&
          other.cardCommentAttachment == this.cardCommentAttachment &&
          other.createdBy == this.createdBy &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isLocal == this.isLocal &&
          other.needsSync == this.needsSync);
}

class PolesCompanion extends UpdateCompanion<Pole> {
  final Value<int> id;
  final Value<int> lineId;
  final Value<String> poleNumber;
  final Value<double?> xPosition;
  final Value<double?> yPosition;
  final Value<String?> poleType;
  final Value<double?> height;
  final Value<String?> foundationType;
  final Value<String?> material;
  final Value<int?> yearInstalled;
  final Value<String?> condition;
  final Value<String?> notes;
  final Value<String?> structuralDefect;
  final Value<String?> structuralDefectCriticality;
  final Value<String?> cardComment;
  final Value<String?> cardCommentAttachment;
  final Value<int> createdBy;
  final Value<DateTime> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<bool> isLocal;
  final Value<bool> needsSync;
  const PolesCompanion({
    this.id = const Value.absent(),
    this.lineId = const Value.absent(),
    this.poleNumber = const Value.absent(),
    this.xPosition = const Value.absent(),
    this.yPosition = const Value.absent(),
    this.poleType = const Value.absent(),
    this.height = const Value.absent(),
    this.foundationType = const Value.absent(),
    this.material = const Value.absent(),
    this.yearInstalled = const Value.absent(),
    this.condition = const Value.absent(),
    this.notes = const Value.absent(),
    this.structuralDefect = const Value.absent(),
    this.structuralDefectCriticality = const Value.absent(),
    this.cardComment = const Value.absent(),
    this.cardCommentAttachment = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isLocal = const Value.absent(),
    this.needsSync = const Value.absent(),
  });
  PolesCompanion.insert({
    this.id = const Value.absent(),
    required int lineId,
    required String poleNumber,
    this.xPosition = const Value.absent(),
    this.yPosition = const Value.absent(),
    this.poleType = const Value.absent(),
    this.height = const Value.absent(),
    this.foundationType = const Value.absent(),
    this.material = const Value.absent(),
    this.yearInstalled = const Value.absent(),
    this.condition = const Value.absent(),
    this.notes = const Value.absent(),
    this.structuralDefect = const Value.absent(),
    this.structuralDefectCriticality = const Value.absent(),
    this.cardComment = const Value.absent(),
    this.cardCommentAttachment = const Value.absent(),
    required int createdBy,
    required DateTime createdAt,
    this.updatedAt = const Value.absent(),
    this.isLocal = const Value.absent(),
    this.needsSync = const Value.absent(),
  }) : lineId = Value(lineId),
       poleNumber = Value(poleNumber),
       createdBy = Value(createdBy),
       createdAt = Value(createdAt);
  static Insertable<Pole> custom({
    Expression<int>? id,
    Expression<int>? lineId,
    Expression<String>? poleNumber,
    Expression<double>? xPosition,
    Expression<double>? yPosition,
    Expression<String>? poleType,
    Expression<double>? height,
    Expression<String>? foundationType,
    Expression<String>? material,
    Expression<int>? yearInstalled,
    Expression<String>? condition,
    Expression<String>? notes,
    Expression<String>? structuralDefect,
    Expression<String>? structuralDefectCriticality,
    Expression<String>? cardComment,
    Expression<String>? cardCommentAttachment,
    Expression<int>? createdBy,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isLocal,
    Expression<bool>? needsSync,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lineId != null) 'line_id': lineId,
      if (poleNumber != null) 'pole_number': poleNumber,
      if (xPosition != null) 'x_position': xPosition,
      if (yPosition != null) 'y_position': yPosition,
      if (poleType != null) 'pole_type': poleType,
      if (height != null) 'height': height,
      if (foundationType != null) 'foundation_type': foundationType,
      if (material != null) 'material': material,
      if (yearInstalled != null) 'year_installed': yearInstalled,
      if (condition != null) 'condition': condition,
      if (notes != null) 'notes': notes,
      if (structuralDefect != null) 'structural_defect': structuralDefect,
      if (structuralDefectCriticality != null)
        'structural_defect_criticality': structuralDefectCriticality,
      if (cardComment != null) 'card_comment': cardComment,
      if (cardCommentAttachment != null)
        'card_comment_attachment': cardCommentAttachment,
      if (createdBy != null) 'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isLocal != null) 'is_local': isLocal,
      if (needsSync != null) 'needs_sync': needsSync,
    });
  }

  PolesCompanion copyWith({
    Value<int>? id,
    Value<int>? lineId,
    Value<String>? poleNumber,
    Value<double?>? xPosition,
    Value<double?>? yPosition,
    Value<String?>? poleType,
    Value<double?>? height,
    Value<String?>? foundationType,
    Value<String?>? material,
    Value<int?>? yearInstalled,
    Value<String?>? condition,
    Value<String?>? notes,
    Value<String?>? structuralDefect,
    Value<String?>? structuralDefectCriticality,
    Value<String?>? cardComment,
    Value<String?>? cardCommentAttachment,
    Value<int>? createdBy,
    Value<DateTime>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<bool>? isLocal,
    Value<bool>? needsSync,
  }) {
    return PolesCompanion(
      id: id ?? this.id,
      lineId: lineId ?? this.lineId,
      poleNumber: poleNumber ?? this.poleNumber,
      xPosition: xPosition ?? this.xPosition,
      yPosition: yPosition ?? this.yPosition,
      poleType: poleType ?? this.poleType,
      height: height ?? this.height,
      foundationType: foundationType ?? this.foundationType,
      material: material ?? this.material,
      yearInstalled: yearInstalled ?? this.yearInstalled,
      condition: condition ?? this.condition,
      notes: notes ?? this.notes,
      structuralDefect: structuralDefect ?? this.structuralDefect,
      structuralDefectCriticality:
          structuralDefectCriticality ?? this.structuralDefectCriticality,
      cardComment: cardComment ?? this.cardComment,
      cardCommentAttachment:
          cardCommentAttachment ?? this.cardCommentAttachment,
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
    if (lineId.present) {
      map['line_id'] = Variable<int>(lineId.value);
    }
    if (poleNumber.present) {
      map['pole_number'] = Variable<String>(poleNumber.value);
    }
    if (xPosition.present) {
      map['x_position'] = Variable<double>(xPosition.value);
    }
    if (yPosition.present) {
      map['y_position'] = Variable<double>(yPosition.value);
    }
    if (poleType.present) {
      map['pole_type'] = Variable<String>(poleType.value);
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
    if (structuralDefect.present) {
      map['structural_defect'] = Variable<String>(structuralDefect.value);
    }
    if (structuralDefectCriticality.present) {
      map['structural_defect_criticality'] = Variable<String>(
        structuralDefectCriticality.value,
      );
    }
    if (cardComment.present) {
      map['card_comment'] = Variable<String>(cardComment.value);
    }
    if (cardCommentAttachment.present) {
      map['card_comment_attachment'] = Variable<String>(
        cardCommentAttachment.value,
      );
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
    return (StringBuffer('PolesCompanion(')
          ..write('id: $id, ')
          ..write('lineId: $lineId, ')
          ..write('poleNumber: $poleNumber, ')
          ..write('xPosition: $xPosition, ')
          ..write('yPosition: $yPosition, ')
          ..write('poleType: $poleType, ')
          ..write('height: $height, ')
          ..write('foundationType: $foundationType, ')
          ..write('material: $material, ')
          ..write('yearInstalled: $yearInstalled, ')
          ..write('condition: $condition, ')
          ..write('notes: $notes, ')
          ..write('structuralDefect: $structuralDefect, ')
          ..write('structuralDefectCriticality: $structuralDefectCriticality, ')
          ..write('cardComment: $cardComment, ')
          ..write('cardCommentAttachment: $cardCommentAttachment, ')
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
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _poleIdMeta = const VerificationMeta('poleId');
  @override
  late final GeneratedColumn<int> poleId = GeneratedColumn<int>(
    'pole_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _equipmentTypeMeta = const VerificationMeta(
    'equipmentType',
  );
  @override
  late final GeneratedColumn<String> equipmentType = GeneratedColumn<String>(
    'equipment_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _defectMeta = const VerificationMeta('defect');
  @override
  late final GeneratedColumn<String> defect = GeneratedColumn<String>(
    'defect',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _criticalityMeta = const VerificationMeta(
    'criticality',
  );
  @override
  late final GeneratedColumn<String> criticality = GeneratedColumn<String>(
    'criticality',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _defectAttachmentMeta = const VerificationMeta(
    'defectAttachment',
  );
  @override
  late final GeneratedColumn<String> defectAttachment = GeneratedColumn<String>(
    'defect_attachment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cardCommentMeta = const VerificationMeta(
    'cardComment',
  );
  @override
  late final GeneratedColumn<String> cardComment = GeneratedColumn<String>(
    'card_comment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cardCommentAttachmentMeta =
      const VerificationMeta('cardCommentAttachment');
  @override
  late final GeneratedColumn<String> cardCommentAttachment =
      GeneratedColumn<String>(
        'card_comment_attachment',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _manufacturerMeta = const VerificationMeta(
    'manufacturer',
  );
  @override
  late final GeneratedColumn<String> manufacturer = GeneratedColumn<String>(
    'manufacturer',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serialNumberMeta = const VerificationMeta(
    'serialNumber',
  );
  @override
  late final GeneratedColumn<String> serialNumber = GeneratedColumn<String>(
    'serial_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearManufacturedMeta = const VerificationMeta(
    'yearManufactured',
  );
  @override
  late final GeneratedColumn<int> yearManufactured = GeneratedColumn<int>(
    'year_manufactured',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _installationDateMeta = const VerificationMeta(
    'installationDate',
  );
  @override
  late final GeneratedColumn<DateTime> installationDate =
      GeneratedColumn<DateTime>(
        'installation_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _conditionMeta = const VerificationMeta(
    'condition',
  );
  @override
  late final GeneratedColumn<String> condition = GeneratedColumn<String>(
    'condition',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mridMeta = const VerificationMeta('mrid');
  @override
  late final GeneratedColumn<String> mrid = GeneratedColumn<String>(
    'mrid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _catalogItemIdMeta = const VerificationMeta(
    'catalogItemId',
  );
  @override
  late final GeneratedColumn<int> catalogItemId = GeneratedColumn<int>(
    'catalog_item_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratedCurrentMeta = const VerificationMeta(
    'ratedCurrent',
  );
  @override
  late final GeneratedColumn<double> ratedCurrent = GeneratedColumn<double>(
    'rated_current',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iThMeta = const VerificationMeta('iTh');
  @override
  late final GeneratedColumn<double> iTh = GeneratedColumn<double>(
    'i_th',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ipMaxMeta = const VerificationMeta('ipMax');
  @override
  late final GeneratedColumn<double> ipMax = GeneratedColumn<double>(
    'ip_max',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tThMeta = const VerificationMeta('tTh');
  @override
  late final GeneratedColumn<double> tTh = GeneratedColumn<double>(
    't_th',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _normalOpenMeta = const VerificationMeta(
    'normalOpen',
  );
  @override
  late final GeneratedColumn<bool> normalOpen = GeneratedColumn<bool>(
    'normal_open',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("normal_open" IN (0, 1))',
    ),
  );
  static const VerificationMeta _retainedMeta = const VerificationMeta(
    'retained',
  );
  @override
  late final GeneratedColumn<bool> retained = GeneratedColumn<bool>(
    'retained',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("retained" IN (0, 1))',
    ),
  );
  static const VerificationMeta _identifiedObjectDescriptionMeta =
      const VerificationMeta('identifiedObjectDescription');
  @override
  late final GeneratedColumn<String> identifiedObjectDescription =
      GeneratedColumn<String>(
        'identified_object_description',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _nameplateMeta = const VerificationMeta(
    'nameplate',
  );
  @override
  late final GeneratedColumn<String> nameplate = GeneratedColumn<String>(
    'nameplate',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _psrSubtypeMeta = const VerificationMeta(
    'psrSubtype',
  );
  @override
  late final GeneratedColumn<String> psrSubtype = GeneratedColumn<String>(
    'psr_subtype',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _installationDisplayNameMeta =
      const VerificationMeta('installationDisplayName');
  @override
  late final GeneratedColumn<String> installationDisplayName =
      GeneratedColumn<String>(
        'installation_display_name',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _tmCodeMeta = const VerificationMeta('tmCode');
  @override
  late final GeneratedColumn<String> tmCode = GeneratedColumn<String>(
    'tm_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _objectSubtypeMeta = const VerificationMeta(
    'objectSubtype',
  );
  @override
  late final GeneratedColumn<String> objectSubtype = GeneratedColumn<String>(
    'object_subtype',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _poleCountMeta = const VerificationMeta(
    'poleCount',
  );
  @override
  late final GeneratedColumn<int> poleCount = GeneratedColumn<int>(
    'pole_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentObjectRefMeta = const VerificationMeta(
    'parentObjectRef',
  );
  @override
  late final GeneratedColumn<String> parentObjectRef = GeneratedColumn<String>(
    'parent_object_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentMainEquipmentPoleRefMeta =
      const VerificationMeta('parentMainEquipmentPoleRef');
  @override
  late final GeneratedColumn<String> parentMainEquipmentPoleRef =
      GeneratedColumn<String>(
        'parent_main_equipment_pole_ref',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _nominalVoltageKvMeta = const VerificationMeta(
    'nominalVoltageKv',
  );
  @override
  late final GeneratedColumn<double> nominalVoltageKv = GeneratedColumn<double>(
    'nominal_voltage_kv',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nominalBreakingCurrentKaMeta =
      const VerificationMeta('nominalBreakingCurrentKa');
  @override
  late final GeneratedColumn<double> nominalBreakingCurrentKa =
      GeneratedColumn<double>(
        'nominal_breaking_current_ka',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _ownTripTimeSecMeta = const VerificationMeta(
    'ownTripTimeSec',
  );
  @override
  late final GeneratedColumn<double> ownTripTimeSec = GeneratedColumn<double>(
    'own_trip_time_sec',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _emergencyCurrentAMeta = const VerificationMeta(
    'emergencyCurrentA',
  );
  @override
  late final GeneratedColumn<double> emergencyCurrentA =
      GeneratedColumn<double>(
        'emergency_current_a',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _continuousCurrentAMeta =
      const VerificationMeta('continuousCurrentA');
  @override
  late final GeneratedColumn<double> continuousCurrentA =
      GeneratedColumn<double>(
        'continuous_current_a',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _arresterTypeMeta = const VerificationMeta(
    'arresterType',
  );
  @override
  late final GeneratedColumn<String> arresterType = GeneratedColumn<String>(
    'arrester_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _xPositionMeta = const VerificationMeta(
    'xPosition',
  );
  @override
  late final GeneratedColumn<double> xPosition = GeneratedColumn<double>(
    'x_position',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yPositionMeta = const VerificationMeta(
    'yPosition',
  );
  @override
  late final GeneratedColumn<double> yPosition = GeneratedColumn<double>(
    'y_position',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _directionAngleMeta = const VerificationMeta(
    'directionAngle',
  );
  @override
  late final GeneratedColumn<double> directionAngle = GeneratedColumn<double>(
    'direction_angle',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<int> createdBy = GeneratedColumn<int>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isLocalMeta = const VerificationMeta(
    'isLocal',
  );
  @override
  late final GeneratedColumn<bool> isLocal = GeneratedColumn<bool>(
    'is_local',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_local" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _needsSyncMeta = const VerificationMeta(
    'needsSync',
  );
  @override
  late final GeneratedColumn<bool> needsSync = GeneratedColumn<bool>(
    'needs_sync',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("needs_sync" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    poleId,
    equipmentType,
    name,
    quantity,
    defect,
    criticality,
    defectAttachment,
    cardComment,
    cardCommentAttachment,
    manufacturer,
    model,
    serialNumber,
    yearManufactured,
    installationDate,
    condition,
    notes,
    mrid,
    catalogItemId,
    ratedCurrent,
    iTh,
    ipMax,
    tTh,
    normalOpen,
    retained,
    identifiedObjectDescription,
    nameplate,
    psrSubtype,
    installationDisplayName,
    tmCode,
    objectSubtype,
    poleCount,
    parentObjectRef,
    parentMainEquipmentPoleRef,
    nominalVoltageKv,
    nominalBreakingCurrentKa,
    ownTripTimeSec,
    emergencyCurrentA,
    continuousCurrentA,
    arresterType,
    xPosition,
    yPosition,
    directionAngle,
    createdBy,
    createdAt,
    updatedAt,
    isLocal,
    needsSync,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'equipment';
  @override
  VerificationContext validateIntegrity(
    Insertable<EquipmentData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('pole_id')) {
      context.handle(
        _poleIdMeta,
        poleId.isAcceptableOrUnknown(data['pole_id']!, _poleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_poleIdMeta);
    }
    if (data.containsKey('equipment_type')) {
      context.handle(
        _equipmentTypeMeta,
        equipmentType.isAcceptableOrUnknown(
          data['equipment_type']!,
          _equipmentTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_equipmentTypeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('defect')) {
      context.handle(
        _defectMeta,
        defect.isAcceptableOrUnknown(data['defect']!, _defectMeta),
      );
    }
    if (data.containsKey('criticality')) {
      context.handle(
        _criticalityMeta,
        criticality.isAcceptableOrUnknown(
          data['criticality']!,
          _criticalityMeta,
        ),
      );
    }
    if (data.containsKey('defect_attachment')) {
      context.handle(
        _defectAttachmentMeta,
        defectAttachment.isAcceptableOrUnknown(
          data['defect_attachment']!,
          _defectAttachmentMeta,
        ),
      );
    }
    if (data.containsKey('card_comment')) {
      context.handle(
        _cardCommentMeta,
        cardComment.isAcceptableOrUnknown(
          data['card_comment']!,
          _cardCommentMeta,
        ),
      );
    }
    if (data.containsKey('card_comment_attachment')) {
      context.handle(
        _cardCommentAttachmentMeta,
        cardCommentAttachment.isAcceptableOrUnknown(
          data['card_comment_attachment']!,
          _cardCommentAttachmentMeta,
        ),
      );
    }
    if (data.containsKey('manufacturer')) {
      context.handle(
        _manufacturerMeta,
        manufacturer.isAcceptableOrUnknown(
          data['manufacturer']!,
          _manufacturerMeta,
        ),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    }
    if (data.containsKey('serial_number')) {
      context.handle(
        _serialNumberMeta,
        serialNumber.isAcceptableOrUnknown(
          data['serial_number']!,
          _serialNumberMeta,
        ),
      );
    }
    if (data.containsKey('year_manufactured')) {
      context.handle(
        _yearManufacturedMeta,
        yearManufactured.isAcceptableOrUnknown(
          data['year_manufactured']!,
          _yearManufacturedMeta,
        ),
      );
    }
    if (data.containsKey('installation_date')) {
      context.handle(
        _installationDateMeta,
        installationDate.isAcceptableOrUnknown(
          data['installation_date']!,
          _installationDateMeta,
        ),
      );
    }
    if (data.containsKey('condition')) {
      context.handle(
        _conditionMeta,
        condition.isAcceptableOrUnknown(data['condition']!, _conditionMeta),
      );
    } else if (isInserting) {
      context.missing(_conditionMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('mrid')) {
      context.handle(
        _mridMeta,
        mrid.isAcceptableOrUnknown(data['mrid']!, _mridMeta),
      );
    }
    if (data.containsKey('catalog_item_id')) {
      context.handle(
        _catalogItemIdMeta,
        catalogItemId.isAcceptableOrUnknown(
          data['catalog_item_id']!,
          _catalogItemIdMeta,
        ),
      );
    }
    if (data.containsKey('rated_current')) {
      context.handle(
        _ratedCurrentMeta,
        ratedCurrent.isAcceptableOrUnknown(
          data['rated_current']!,
          _ratedCurrentMeta,
        ),
      );
    }
    if (data.containsKey('i_th')) {
      context.handle(
        _iThMeta,
        iTh.isAcceptableOrUnknown(data['i_th']!, _iThMeta),
      );
    }
    if (data.containsKey('ip_max')) {
      context.handle(
        _ipMaxMeta,
        ipMax.isAcceptableOrUnknown(data['ip_max']!, _ipMaxMeta),
      );
    }
    if (data.containsKey('t_th')) {
      context.handle(
        _tThMeta,
        tTh.isAcceptableOrUnknown(data['t_th']!, _tThMeta),
      );
    }
    if (data.containsKey('normal_open')) {
      context.handle(
        _normalOpenMeta,
        normalOpen.isAcceptableOrUnknown(data['normal_open']!, _normalOpenMeta),
      );
    }
    if (data.containsKey('retained')) {
      context.handle(
        _retainedMeta,
        retained.isAcceptableOrUnknown(data['retained']!, _retainedMeta),
      );
    }
    if (data.containsKey('identified_object_description')) {
      context.handle(
        _identifiedObjectDescriptionMeta,
        identifiedObjectDescription.isAcceptableOrUnknown(
          data['identified_object_description']!,
          _identifiedObjectDescriptionMeta,
        ),
      );
    }
    if (data.containsKey('nameplate')) {
      context.handle(
        _nameplateMeta,
        nameplate.isAcceptableOrUnknown(data['nameplate']!, _nameplateMeta),
      );
    }
    if (data.containsKey('psr_subtype')) {
      context.handle(
        _psrSubtypeMeta,
        psrSubtype.isAcceptableOrUnknown(data['psr_subtype']!, _psrSubtypeMeta),
      );
    }
    if (data.containsKey('installation_display_name')) {
      context.handle(
        _installationDisplayNameMeta,
        installationDisplayName.isAcceptableOrUnknown(
          data['installation_display_name']!,
          _installationDisplayNameMeta,
        ),
      );
    }
    if (data.containsKey('tm_code')) {
      context.handle(
        _tmCodeMeta,
        tmCode.isAcceptableOrUnknown(data['tm_code']!, _tmCodeMeta),
      );
    }
    if (data.containsKey('object_subtype')) {
      context.handle(
        _objectSubtypeMeta,
        objectSubtype.isAcceptableOrUnknown(
          data['object_subtype']!,
          _objectSubtypeMeta,
        ),
      );
    }
    if (data.containsKey('pole_count')) {
      context.handle(
        _poleCountMeta,
        poleCount.isAcceptableOrUnknown(data['pole_count']!, _poleCountMeta),
      );
    }
    if (data.containsKey('parent_object_ref')) {
      context.handle(
        _parentObjectRefMeta,
        parentObjectRef.isAcceptableOrUnknown(
          data['parent_object_ref']!,
          _parentObjectRefMeta,
        ),
      );
    }
    if (data.containsKey('parent_main_equipment_pole_ref')) {
      context.handle(
        _parentMainEquipmentPoleRefMeta,
        parentMainEquipmentPoleRef.isAcceptableOrUnknown(
          data['parent_main_equipment_pole_ref']!,
          _parentMainEquipmentPoleRefMeta,
        ),
      );
    }
    if (data.containsKey('nominal_voltage_kv')) {
      context.handle(
        _nominalVoltageKvMeta,
        nominalVoltageKv.isAcceptableOrUnknown(
          data['nominal_voltage_kv']!,
          _nominalVoltageKvMeta,
        ),
      );
    }
    if (data.containsKey('nominal_breaking_current_ka')) {
      context.handle(
        _nominalBreakingCurrentKaMeta,
        nominalBreakingCurrentKa.isAcceptableOrUnknown(
          data['nominal_breaking_current_ka']!,
          _nominalBreakingCurrentKaMeta,
        ),
      );
    }
    if (data.containsKey('own_trip_time_sec')) {
      context.handle(
        _ownTripTimeSecMeta,
        ownTripTimeSec.isAcceptableOrUnknown(
          data['own_trip_time_sec']!,
          _ownTripTimeSecMeta,
        ),
      );
    }
    if (data.containsKey('emergency_current_a')) {
      context.handle(
        _emergencyCurrentAMeta,
        emergencyCurrentA.isAcceptableOrUnknown(
          data['emergency_current_a']!,
          _emergencyCurrentAMeta,
        ),
      );
    }
    if (data.containsKey('continuous_current_a')) {
      context.handle(
        _continuousCurrentAMeta,
        continuousCurrentA.isAcceptableOrUnknown(
          data['continuous_current_a']!,
          _continuousCurrentAMeta,
        ),
      );
    }
    if (data.containsKey('arrester_type')) {
      context.handle(
        _arresterTypeMeta,
        arresterType.isAcceptableOrUnknown(
          data['arrester_type']!,
          _arresterTypeMeta,
        ),
      );
    }
    if (data.containsKey('x_position')) {
      context.handle(
        _xPositionMeta,
        xPosition.isAcceptableOrUnknown(data['x_position']!, _xPositionMeta),
      );
    }
    if (data.containsKey('y_position')) {
      context.handle(
        _yPositionMeta,
        yPosition.isAcceptableOrUnknown(data['y_position']!, _yPositionMeta),
      );
    }
    if (data.containsKey('direction_angle')) {
      context.handle(
        _directionAngleMeta,
        directionAngle.isAcceptableOrUnknown(
          data['direction_angle']!,
          _directionAngleMeta,
        ),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('is_local')) {
      context.handle(
        _isLocalMeta,
        isLocal.isAcceptableOrUnknown(data['is_local']!, _isLocalMeta),
      );
    }
    if (data.containsKey('needs_sync')) {
      context.handle(
        _needsSyncMeta,
        needsSync.isAcceptableOrUnknown(data['needs_sync']!, _needsSyncMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EquipmentData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EquipmentData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      poleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pole_id'],
      )!,
      equipmentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}equipment_type'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
      defect: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}defect'],
      ),
      criticality: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}criticality'],
      ),
      defectAttachment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}defect_attachment'],
      ),
      cardComment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_comment'],
      ),
      cardCommentAttachment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_comment_attachment'],
      ),
      manufacturer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manufacturer'],
      ),
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      ),
      serialNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}serial_number'],
      ),
      yearManufactured: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year_manufactured'],
      ),
      installationDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}installation_date'],
      ),
      condition: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}condition'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      mrid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mrid'],
      ),
      catalogItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}catalog_item_id'],
      ),
      ratedCurrent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rated_current'],
      ),
      iTh: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}i_th'],
      ),
      ipMax: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ip_max'],
      ),
      tTh: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}t_th'],
      ),
      normalOpen: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}normal_open'],
      ),
      retained: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}retained'],
      ),
      identifiedObjectDescription: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}identified_object_description'],
      ),
      nameplate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nameplate'],
      ),
      psrSubtype: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}psr_subtype'],
      ),
      installationDisplayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}installation_display_name'],
      ),
      tmCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tm_code'],
      ),
      objectSubtype: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}object_subtype'],
      ),
      poleCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pole_count'],
      ),
      parentObjectRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_object_ref'],
      ),
      parentMainEquipmentPoleRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_main_equipment_pole_ref'],
      ),
      nominalVoltageKv: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}nominal_voltage_kv'],
      ),
      nominalBreakingCurrentKa: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}nominal_breaking_current_ka'],
      ),
      ownTripTimeSec: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}own_trip_time_sec'],
      ),
      emergencyCurrentA: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}emergency_current_a'],
      ),
      continuousCurrentA: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}continuous_current_a'],
      ),
      arresterType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}arrester_type'],
      ),
      xPosition: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}x_position'],
      ),
      yPosition: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}y_position'],
      ),
      directionAngle: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}direction_angle'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_by'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      isLocal: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_local'],
      )!,
      needsSync: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}needs_sync'],
      )!,
    );
  }

  @override
  $EquipmentTable createAlias(String alias) {
    return $EquipmentTable(attachedDatabase, alias);
  }
}

class EquipmentData extends DataClass implements Insertable<EquipmentData> {
  final int id;
  final int poleId;
  final String equipmentType;
  final String name;
  final int quantity;
  final String? defect;
  final String? criticality;

  /// Вложения к описанию иного дефекта: голос/фото (JSON: [{"t":"voice"|"photo","p":"path"}])
  final String? defectAttachment;

  /// Комментарий карточки оборудования (как у опоры)
  final String? cardComment;

  /// Вложения к комментарию карточки (JSON с url или локальным p)
  final String? cardCommentAttachment;
  final String? manufacturer;
  final String? model;
  final String? serialNumber;
  final int? yearManufactured;
  final DateTime? installationDate;
  final String condition;
  final String? notes;

  /// Поля карты / карточки оборудования (как на сервере Equipment), для офлайна и выбора сегмента ЛЭП.
  final String? mrid;
  final int? catalogItemId;
  final double? ratedCurrent;
  final double? iTh;
  final double? ipMax;
  final double? tTh;
  final bool? normalOpen;
  final bool? retained;
  final String? identifiedObjectDescription;
  final String? nameplate;
  final String? psrSubtype;
  final String? installationDisplayName;
  final String? tmCode;
  final String? objectSubtype;
  final int? poleCount;
  final String? parentObjectRef;
  final String? parentMainEquipmentPoleRef;
  final double? nominalVoltageKv;
  final double? nominalBreakingCurrentKa;
  final double? ownTripTimeSec;
  final double? emergencyCurrentA;
  final double? continuousCurrentA;
  final String? arresterType;

  /// Долгота / широта объекта оборудования (CIM x/y), если заданы — помогают привязать к нужному пролёту.
  final double? xPosition;
  final double? yPosition;
  final double? directionAngle;
  final int createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isLocal;
  final bool needsSync;
  const EquipmentData({
    required this.id,
    required this.poleId,
    required this.equipmentType,
    required this.name,
    required this.quantity,
    this.defect,
    this.criticality,
    this.defectAttachment,
    this.cardComment,
    this.cardCommentAttachment,
    this.manufacturer,
    this.model,
    this.serialNumber,
    this.yearManufactured,
    this.installationDate,
    required this.condition,
    this.notes,
    this.mrid,
    this.catalogItemId,
    this.ratedCurrent,
    this.iTh,
    this.ipMax,
    this.tTh,
    this.normalOpen,
    this.retained,
    this.identifiedObjectDescription,
    this.nameplate,
    this.psrSubtype,
    this.installationDisplayName,
    this.tmCode,
    this.objectSubtype,
    this.poleCount,
    this.parentObjectRef,
    this.parentMainEquipmentPoleRef,
    this.nominalVoltageKv,
    this.nominalBreakingCurrentKa,
    this.ownTripTimeSec,
    this.emergencyCurrentA,
    this.continuousCurrentA,
    this.arresterType,
    this.xPosition,
    this.yPosition,
    this.directionAngle,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    required this.isLocal,
    required this.needsSync,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['pole_id'] = Variable<int>(poleId);
    map['equipment_type'] = Variable<String>(equipmentType);
    map['name'] = Variable<String>(name);
    map['quantity'] = Variable<int>(quantity);
    if (!nullToAbsent || defect != null) {
      map['defect'] = Variable<String>(defect);
    }
    if (!nullToAbsent || criticality != null) {
      map['criticality'] = Variable<String>(criticality);
    }
    if (!nullToAbsent || defectAttachment != null) {
      map['defect_attachment'] = Variable<String>(defectAttachment);
    }
    if (!nullToAbsent || cardComment != null) {
      map['card_comment'] = Variable<String>(cardComment);
    }
    if (!nullToAbsent || cardCommentAttachment != null) {
      map['card_comment_attachment'] = Variable<String>(cardCommentAttachment);
    }
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
    if (!nullToAbsent || mrid != null) {
      map['mrid'] = Variable<String>(mrid);
    }
    if (!nullToAbsent || catalogItemId != null) {
      map['catalog_item_id'] = Variable<int>(catalogItemId);
    }
    if (!nullToAbsent || ratedCurrent != null) {
      map['rated_current'] = Variable<double>(ratedCurrent);
    }
    if (!nullToAbsent || iTh != null) {
      map['i_th'] = Variable<double>(iTh);
    }
    if (!nullToAbsent || ipMax != null) {
      map['ip_max'] = Variable<double>(ipMax);
    }
    if (!nullToAbsent || tTh != null) {
      map['t_th'] = Variable<double>(tTh);
    }
    if (!nullToAbsent || normalOpen != null) {
      map['normal_open'] = Variable<bool>(normalOpen);
    }
    if (!nullToAbsent || retained != null) {
      map['retained'] = Variable<bool>(retained);
    }
    if (!nullToAbsent || identifiedObjectDescription != null) {
      map['identified_object_description'] = Variable<String>(
        identifiedObjectDescription,
      );
    }
    if (!nullToAbsent || nameplate != null) {
      map['nameplate'] = Variable<String>(nameplate);
    }
    if (!nullToAbsent || psrSubtype != null) {
      map['psr_subtype'] = Variable<String>(psrSubtype);
    }
    if (!nullToAbsent || installationDisplayName != null) {
      map['installation_display_name'] = Variable<String>(
        installationDisplayName,
      );
    }
    if (!nullToAbsent || tmCode != null) {
      map['tm_code'] = Variable<String>(tmCode);
    }
    if (!nullToAbsent || objectSubtype != null) {
      map['object_subtype'] = Variable<String>(objectSubtype);
    }
    if (!nullToAbsent || poleCount != null) {
      map['pole_count'] = Variable<int>(poleCount);
    }
    if (!nullToAbsent || parentObjectRef != null) {
      map['parent_object_ref'] = Variable<String>(parentObjectRef);
    }
    if (!nullToAbsent || parentMainEquipmentPoleRef != null) {
      map['parent_main_equipment_pole_ref'] = Variable<String>(
        parentMainEquipmentPoleRef,
      );
    }
    if (!nullToAbsent || nominalVoltageKv != null) {
      map['nominal_voltage_kv'] = Variable<double>(nominalVoltageKv);
    }
    if (!nullToAbsent || nominalBreakingCurrentKa != null) {
      map['nominal_breaking_current_ka'] = Variable<double>(
        nominalBreakingCurrentKa,
      );
    }
    if (!nullToAbsent || ownTripTimeSec != null) {
      map['own_trip_time_sec'] = Variable<double>(ownTripTimeSec);
    }
    if (!nullToAbsent || emergencyCurrentA != null) {
      map['emergency_current_a'] = Variable<double>(emergencyCurrentA);
    }
    if (!nullToAbsent || continuousCurrentA != null) {
      map['continuous_current_a'] = Variable<double>(continuousCurrentA);
    }
    if (!nullToAbsent || arresterType != null) {
      map['arrester_type'] = Variable<String>(arresterType);
    }
    if (!nullToAbsent || xPosition != null) {
      map['x_position'] = Variable<double>(xPosition);
    }
    if (!nullToAbsent || yPosition != null) {
      map['y_position'] = Variable<double>(yPosition);
    }
    if (!nullToAbsent || directionAngle != null) {
      map['direction_angle'] = Variable<double>(directionAngle);
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
      poleId: Value(poleId),
      equipmentType: Value(equipmentType),
      name: Value(name),
      quantity: Value(quantity),
      defect: defect == null && nullToAbsent
          ? const Value.absent()
          : Value(defect),
      criticality: criticality == null && nullToAbsent
          ? const Value.absent()
          : Value(criticality),
      defectAttachment: defectAttachment == null && nullToAbsent
          ? const Value.absent()
          : Value(defectAttachment),
      cardComment: cardComment == null && nullToAbsent
          ? const Value.absent()
          : Value(cardComment),
      cardCommentAttachment: cardCommentAttachment == null && nullToAbsent
          ? const Value.absent()
          : Value(cardCommentAttachment),
      manufacturer: manufacturer == null && nullToAbsent
          ? const Value.absent()
          : Value(manufacturer),
      model: model == null && nullToAbsent
          ? const Value.absent()
          : Value(model),
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
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      mrid: mrid == null && nullToAbsent ? const Value.absent() : Value(mrid),
      catalogItemId: catalogItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(catalogItemId),
      ratedCurrent: ratedCurrent == null && nullToAbsent
          ? const Value.absent()
          : Value(ratedCurrent),
      iTh: iTh == null && nullToAbsent ? const Value.absent() : Value(iTh),
      ipMax: ipMax == null && nullToAbsent
          ? const Value.absent()
          : Value(ipMax),
      tTh: tTh == null && nullToAbsent ? const Value.absent() : Value(tTh),
      normalOpen: normalOpen == null && nullToAbsent
          ? const Value.absent()
          : Value(normalOpen),
      retained: retained == null && nullToAbsent
          ? const Value.absent()
          : Value(retained),
      identifiedObjectDescription:
          identifiedObjectDescription == null && nullToAbsent
          ? const Value.absent()
          : Value(identifiedObjectDescription),
      nameplate: nameplate == null && nullToAbsent
          ? const Value.absent()
          : Value(nameplate),
      psrSubtype: psrSubtype == null && nullToAbsent
          ? const Value.absent()
          : Value(psrSubtype),
      installationDisplayName: installationDisplayName == null && nullToAbsent
          ? const Value.absent()
          : Value(installationDisplayName),
      tmCode: tmCode == null && nullToAbsent
          ? const Value.absent()
          : Value(tmCode),
      objectSubtype: objectSubtype == null && nullToAbsent
          ? const Value.absent()
          : Value(objectSubtype),
      poleCount: poleCount == null && nullToAbsent
          ? const Value.absent()
          : Value(poleCount),
      parentObjectRef: parentObjectRef == null && nullToAbsent
          ? const Value.absent()
          : Value(parentObjectRef),
      parentMainEquipmentPoleRef:
          parentMainEquipmentPoleRef == null && nullToAbsent
          ? const Value.absent()
          : Value(parentMainEquipmentPoleRef),
      nominalVoltageKv: nominalVoltageKv == null && nullToAbsent
          ? const Value.absent()
          : Value(nominalVoltageKv),
      nominalBreakingCurrentKa: nominalBreakingCurrentKa == null && nullToAbsent
          ? const Value.absent()
          : Value(nominalBreakingCurrentKa),
      ownTripTimeSec: ownTripTimeSec == null && nullToAbsent
          ? const Value.absent()
          : Value(ownTripTimeSec),
      emergencyCurrentA: emergencyCurrentA == null && nullToAbsent
          ? const Value.absent()
          : Value(emergencyCurrentA),
      continuousCurrentA: continuousCurrentA == null && nullToAbsent
          ? const Value.absent()
          : Value(continuousCurrentA),
      arresterType: arresterType == null && nullToAbsent
          ? const Value.absent()
          : Value(arresterType),
      xPosition: xPosition == null && nullToAbsent
          ? const Value.absent()
          : Value(xPosition),
      yPosition: yPosition == null && nullToAbsent
          ? const Value.absent()
          : Value(yPosition),
      directionAngle: directionAngle == null && nullToAbsent
          ? const Value.absent()
          : Value(directionAngle),
      createdBy: Value(createdBy),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      isLocal: Value(isLocal),
      needsSync: Value(needsSync),
    );
  }

  factory EquipmentData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EquipmentData(
      id: serializer.fromJson<int>(json['id']),
      poleId: serializer.fromJson<int>(json['poleId']),
      equipmentType: serializer.fromJson<String>(json['equipmentType']),
      name: serializer.fromJson<String>(json['name']),
      quantity: serializer.fromJson<int>(json['quantity']),
      defect: serializer.fromJson<String?>(json['defect']),
      criticality: serializer.fromJson<String?>(json['criticality']),
      defectAttachment: serializer.fromJson<String?>(json['defectAttachment']),
      cardComment: serializer.fromJson<String?>(json['cardComment']),
      cardCommentAttachment: serializer.fromJson<String?>(
        json['cardCommentAttachment'],
      ),
      manufacturer: serializer.fromJson<String?>(json['manufacturer']),
      model: serializer.fromJson<String?>(json['model']),
      serialNumber: serializer.fromJson<String?>(json['serialNumber']),
      yearManufactured: serializer.fromJson<int?>(json['yearManufactured']),
      installationDate: serializer.fromJson<DateTime?>(
        json['installationDate'],
      ),
      condition: serializer.fromJson<String>(json['condition']),
      notes: serializer.fromJson<String?>(json['notes']),
      mrid: serializer.fromJson<String?>(json['mrid']),
      catalogItemId: serializer.fromJson<int?>(json['catalogItemId']),
      ratedCurrent: serializer.fromJson<double?>(json['ratedCurrent']),
      iTh: serializer.fromJson<double?>(json['iTh']),
      ipMax: serializer.fromJson<double?>(json['ipMax']),
      tTh: serializer.fromJson<double?>(json['tTh']),
      normalOpen: serializer.fromJson<bool?>(json['normalOpen']),
      retained: serializer.fromJson<bool?>(json['retained']),
      identifiedObjectDescription: serializer.fromJson<String?>(
        json['identifiedObjectDescription'],
      ),
      nameplate: serializer.fromJson<String?>(json['nameplate']),
      psrSubtype: serializer.fromJson<String?>(json['psrSubtype']),
      installationDisplayName: serializer.fromJson<String?>(
        json['installationDisplayName'],
      ),
      tmCode: serializer.fromJson<String?>(json['tmCode']),
      objectSubtype: serializer.fromJson<String?>(json['objectSubtype']),
      poleCount: serializer.fromJson<int?>(json['poleCount']),
      parentObjectRef: serializer.fromJson<String?>(json['parentObjectRef']),
      parentMainEquipmentPoleRef: serializer.fromJson<String?>(
        json['parentMainEquipmentPoleRef'],
      ),
      nominalVoltageKv: serializer.fromJson<double?>(json['nominalVoltageKv']),
      nominalBreakingCurrentKa: serializer.fromJson<double?>(
        json['nominalBreakingCurrentKa'],
      ),
      ownTripTimeSec: serializer.fromJson<double?>(json['ownTripTimeSec']),
      emergencyCurrentA: serializer.fromJson<double?>(
        json['emergencyCurrentA'],
      ),
      continuousCurrentA: serializer.fromJson<double?>(
        json['continuousCurrentA'],
      ),
      arresterType: serializer.fromJson<String?>(json['arresterType']),
      xPosition: serializer.fromJson<double?>(json['xPosition']),
      yPosition: serializer.fromJson<double?>(json['yPosition']),
      directionAngle: serializer.fromJson<double?>(json['directionAngle']),
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
      'poleId': serializer.toJson<int>(poleId),
      'equipmentType': serializer.toJson<String>(equipmentType),
      'name': serializer.toJson<String>(name),
      'quantity': serializer.toJson<int>(quantity),
      'defect': serializer.toJson<String?>(defect),
      'criticality': serializer.toJson<String?>(criticality),
      'defectAttachment': serializer.toJson<String?>(defectAttachment),
      'cardComment': serializer.toJson<String?>(cardComment),
      'cardCommentAttachment': serializer.toJson<String?>(
        cardCommentAttachment,
      ),
      'manufacturer': serializer.toJson<String?>(manufacturer),
      'model': serializer.toJson<String?>(model),
      'serialNumber': serializer.toJson<String?>(serialNumber),
      'yearManufactured': serializer.toJson<int?>(yearManufactured),
      'installationDate': serializer.toJson<DateTime?>(installationDate),
      'condition': serializer.toJson<String>(condition),
      'notes': serializer.toJson<String?>(notes),
      'mrid': serializer.toJson<String?>(mrid),
      'catalogItemId': serializer.toJson<int?>(catalogItemId),
      'ratedCurrent': serializer.toJson<double?>(ratedCurrent),
      'iTh': serializer.toJson<double?>(iTh),
      'ipMax': serializer.toJson<double?>(ipMax),
      'tTh': serializer.toJson<double?>(tTh),
      'normalOpen': serializer.toJson<bool?>(normalOpen),
      'retained': serializer.toJson<bool?>(retained),
      'identifiedObjectDescription': serializer.toJson<String?>(
        identifiedObjectDescription,
      ),
      'nameplate': serializer.toJson<String?>(nameplate),
      'psrSubtype': serializer.toJson<String?>(psrSubtype),
      'installationDisplayName': serializer.toJson<String?>(
        installationDisplayName,
      ),
      'tmCode': serializer.toJson<String?>(tmCode),
      'objectSubtype': serializer.toJson<String?>(objectSubtype),
      'poleCount': serializer.toJson<int?>(poleCount),
      'parentObjectRef': serializer.toJson<String?>(parentObjectRef),
      'parentMainEquipmentPoleRef': serializer.toJson<String?>(
        parentMainEquipmentPoleRef,
      ),
      'nominalVoltageKv': serializer.toJson<double?>(nominalVoltageKv),
      'nominalBreakingCurrentKa': serializer.toJson<double?>(
        nominalBreakingCurrentKa,
      ),
      'ownTripTimeSec': serializer.toJson<double?>(ownTripTimeSec),
      'emergencyCurrentA': serializer.toJson<double?>(emergencyCurrentA),
      'continuousCurrentA': serializer.toJson<double?>(continuousCurrentA),
      'arresterType': serializer.toJson<String?>(arresterType),
      'xPosition': serializer.toJson<double?>(xPosition),
      'yPosition': serializer.toJson<double?>(yPosition),
      'directionAngle': serializer.toJson<double?>(directionAngle),
      'createdBy': serializer.toJson<int>(createdBy),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'isLocal': serializer.toJson<bool>(isLocal),
      'needsSync': serializer.toJson<bool>(needsSync),
    };
  }

  EquipmentData copyWith({
    int? id,
    int? poleId,
    String? equipmentType,
    String? name,
    int? quantity,
    Value<String?> defect = const Value.absent(),
    Value<String?> criticality = const Value.absent(),
    Value<String?> defectAttachment = const Value.absent(),
    Value<String?> cardComment = const Value.absent(),
    Value<String?> cardCommentAttachment = const Value.absent(),
    Value<String?> manufacturer = const Value.absent(),
    Value<String?> model = const Value.absent(),
    Value<String?> serialNumber = const Value.absent(),
    Value<int?> yearManufactured = const Value.absent(),
    Value<DateTime?> installationDate = const Value.absent(),
    String? condition,
    Value<String?> notes = const Value.absent(),
    Value<String?> mrid = const Value.absent(),
    Value<int?> catalogItemId = const Value.absent(),
    Value<double?> ratedCurrent = const Value.absent(),
    Value<double?> iTh = const Value.absent(),
    Value<double?> ipMax = const Value.absent(),
    Value<double?> tTh = const Value.absent(),
    Value<bool?> normalOpen = const Value.absent(),
    Value<bool?> retained = const Value.absent(),
    Value<String?> identifiedObjectDescription = const Value.absent(),
    Value<String?> nameplate = const Value.absent(),
    Value<String?> psrSubtype = const Value.absent(),
    Value<String?> installationDisplayName = const Value.absent(),
    Value<String?> tmCode = const Value.absent(),
    Value<String?> objectSubtype = const Value.absent(),
    Value<int?> poleCount = const Value.absent(),
    Value<String?> parentObjectRef = const Value.absent(),
    Value<String?> parentMainEquipmentPoleRef = const Value.absent(),
    Value<double?> nominalVoltageKv = const Value.absent(),
    Value<double?> nominalBreakingCurrentKa = const Value.absent(),
    Value<double?> ownTripTimeSec = const Value.absent(),
    Value<double?> emergencyCurrentA = const Value.absent(),
    Value<double?> continuousCurrentA = const Value.absent(),
    Value<String?> arresterType = const Value.absent(),
    Value<double?> xPosition = const Value.absent(),
    Value<double?> yPosition = const Value.absent(),
    Value<double?> directionAngle = const Value.absent(),
    int? createdBy,
    DateTime? createdAt,
    Value<DateTime?> updatedAt = const Value.absent(),
    bool? isLocal,
    bool? needsSync,
  }) => EquipmentData(
    id: id ?? this.id,
    poleId: poleId ?? this.poleId,
    equipmentType: equipmentType ?? this.equipmentType,
    name: name ?? this.name,
    quantity: quantity ?? this.quantity,
    defect: defect.present ? defect.value : this.defect,
    criticality: criticality.present ? criticality.value : this.criticality,
    defectAttachment: defectAttachment.present
        ? defectAttachment.value
        : this.defectAttachment,
    cardComment: cardComment.present ? cardComment.value : this.cardComment,
    cardCommentAttachment: cardCommentAttachment.present
        ? cardCommentAttachment.value
        : this.cardCommentAttachment,
    manufacturer: manufacturer.present ? manufacturer.value : this.manufacturer,
    model: model.present ? model.value : this.model,
    serialNumber: serialNumber.present ? serialNumber.value : this.serialNumber,
    yearManufactured: yearManufactured.present
        ? yearManufactured.value
        : this.yearManufactured,
    installationDate: installationDate.present
        ? installationDate.value
        : this.installationDate,
    condition: condition ?? this.condition,
    notes: notes.present ? notes.value : this.notes,
    mrid: mrid.present ? mrid.value : this.mrid,
    catalogItemId: catalogItemId.present
        ? catalogItemId.value
        : this.catalogItemId,
    ratedCurrent: ratedCurrent.present ? ratedCurrent.value : this.ratedCurrent,
    iTh: iTh.present ? iTh.value : this.iTh,
    ipMax: ipMax.present ? ipMax.value : this.ipMax,
    tTh: tTh.present ? tTh.value : this.tTh,
    normalOpen: normalOpen.present ? normalOpen.value : this.normalOpen,
    retained: retained.present ? retained.value : this.retained,
    identifiedObjectDescription: identifiedObjectDescription.present
        ? identifiedObjectDescription.value
        : this.identifiedObjectDescription,
    nameplate: nameplate.present ? nameplate.value : this.nameplate,
    psrSubtype: psrSubtype.present ? psrSubtype.value : this.psrSubtype,
    installationDisplayName: installationDisplayName.present
        ? installationDisplayName.value
        : this.installationDisplayName,
    tmCode: tmCode.present ? tmCode.value : this.tmCode,
    objectSubtype: objectSubtype.present
        ? objectSubtype.value
        : this.objectSubtype,
    poleCount: poleCount.present ? poleCount.value : this.poleCount,
    parentObjectRef: parentObjectRef.present
        ? parentObjectRef.value
        : this.parentObjectRef,
    parentMainEquipmentPoleRef: parentMainEquipmentPoleRef.present
        ? parentMainEquipmentPoleRef.value
        : this.parentMainEquipmentPoleRef,
    nominalVoltageKv: nominalVoltageKv.present
        ? nominalVoltageKv.value
        : this.nominalVoltageKv,
    nominalBreakingCurrentKa: nominalBreakingCurrentKa.present
        ? nominalBreakingCurrentKa.value
        : this.nominalBreakingCurrentKa,
    ownTripTimeSec: ownTripTimeSec.present
        ? ownTripTimeSec.value
        : this.ownTripTimeSec,
    emergencyCurrentA: emergencyCurrentA.present
        ? emergencyCurrentA.value
        : this.emergencyCurrentA,
    continuousCurrentA: continuousCurrentA.present
        ? continuousCurrentA.value
        : this.continuousCurrentA,
    arresterType: arresterType.present ? arresterType.value : this.arresterType,
    xPosition: xPosition.present ? xPosition.value : this.xPosition,
    yPosition: yPosition.present ? yPosition.value : this.yPosition,
    directionAngle: directionAngle.present
        ? directionAngle.value
        : this.directionAngle,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    isLocal: isLocal ?? this.isLocal,
    needsSync: needsSync ?? this.needsSync,
  );
  EquipmentData copyWithCompanion(EquipmentCompanion data) {
    return EquipmentData(
      id: data.id.present ? data.id.value : this.id,
      poleId: data.poleId.present ? data.poleId.value : this.poleId,
      equipmentType: data.equipmentType.present
          ? data.equipmentType.value
          : this.equipmentType,
      name: data.name.present ? data.name.value : this.name,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      defect: data.defect.present ? data.defect.value : this.defect,
      criticality: data.criticality.present
          ? data.criticality.value
          : this.criticality,
      defectAttachment: data.defectAttachment.present
          ? data.defectAttachment.value
          : this.defectAttachment,
      cardComment: data.cardComment.present
          ? data.cardComment.value
          : this.cardComment,
      cardCommentAttachment: data.cardCommentAttachment.present
          ? data.cardCommentAttachment.value
          : this.cardCommentAttachment,
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
      mrid: data.mrid.present ? data.mrid.value : this.mrid,
      catalogItemId: data.catalogItemId.present
          ? data.catalogItemId.value
          : this.catalogItemId,
      ratedCurrent: data.ratedCurrent.present
          ? data.ratedCurrent.value
          : this.ratedCurrent,
      iTh: data.iTh.present ? data.iTh.value : this.iTh,
      ipMax: data.ipMax.present ? data.ipMax.value : this.ipMax,
      tTh: data.tTh.present ? data.tTh.value : this.tTh,
      normalOpen: data.normalOpen.present
          ? data.normalOpen.value
          : this.normalOpen,
      retained: data.retained.present ? data.retained.value : this.retained,
      identifiedObjectDescription: data.identifiedObjectDescription.present
          ? data.identifiedObjectDescription.value
          : this.identifiedObjectDescription,
      nameplate: data.nameplate.present ? data.nameplate.value : this.nameplate,
      psrSubtype: data.psrSubtype.present
          ? data.psrSubtype.value
          : this.psrSubtype,
      installationDisplayName: data.installationDisplayName.present
          ? data.installationDisplayName.value
          : this.installationDisplayName,
      tmCode: data.tmCode.present ? data.tmCode.value : this.tmCode,
      objectSubtype: data.objectSubtype.present
          ? data.objectSubtype.value
          : this.objectSubtype,
      poleCount: data.poleCount.present ? data.poleCount.value : this.poleCount,
      parentObjectRef: data.parentObjectRef.present
          ? data.parentObjectRef.value
          : this.parentObjectRef,
      parentMainEquipmentPoleRef: data.parentMainEquipmentPoleRef.present
          ? data.parentMainEquipmentPoleRef.value
          : this.parentMainEquipmentPoleRef,
      nominalVoltageKv: data.nominalVoltageKv.present
          ? data.nominalVoltageKv.value
          : this.nominalVoltageKv,
      nominalBreakingCurrentKa: data.nominalBreakingCurrentKa.present
          ? data.nominalBreakingCurrentKa.value
          : this.nominalBreakingCurrentKa,
      ownTripTimeSec: data.ownTripTimeSec.present
          ? data.ownTripTimeSec.value
          : this.ownTripTimeSec,
      emergencyCurrentA: data.emergencyCurrentA.present
          ? data.emergencyCurrentA.value
          : this.emergencyCurrentA,
      continuousCurrentA: data.continuousCurrentA.present
          ? data.continuousCurrentA.value
          : this.continuousCurrentA,
      arresterType: data.arresterType.present
          ? data.arresterType.value
          : this.arresterType,
      xPosition: data.xPosition.present ? data.xPosition.value : this.xPosition,
      yPosition: data.yPosition.present ? data.yPosition.value : this.yPosition,
      directionAngle: data.directionAngle.present
          ? data.directionAngle.value
          : this.directionAngle,
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
          ..write('poleId: $poleId, ')
          ..write('equipmentType: $equipmentType, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('defect: $defect, ')
          ..write('criticality: $criticality, ')
          ..write('defectAttachment: $defectAttachment, ')
          ..write('cardComment: $cardComment, ')
          ..write('cardCommentAttachment: $cardCommentAttachment, ')
          ..write('manufacturer: $manufacturer, ')
          ..write('model: $model, ')
          ..write('serialNumber: $serialNumber, ')
          ..write('yearManufactured: $yearManufactured, ')
          ..write('installationDate: $installationDate, ')
          ..write('condition: $condition, ')
          ..write('notes: $notes, ')
          ..write('mrid: $mrid, ')
          ..write('catalogItemId: $catalogItemId, ')
          ..write('ratedCurrent: $ratedCurrent, ')
          ..write('iTh: $iTh, ')
          ..write('ipMax: $ipMax, ')
          ..write('tTh: $tTh, ')
          ..write('normalOpen: $normalOpen, ')
          ..write('retained: $retained, ')
          ..write('identifiedObjectDescription: $identifiedObjectDescription, ')
          ..write('nameplate: $nameplate, ')
          ..write('psrSubtype: $psrSubtype, ')
          ..write('installationDisplayName: $installationDisplayName, ')
          ..write('tmCode: $tmCode, ')
          ..write('objectSubtype: $objectSubtype, ')
          ..write('poleCount: $poleCount, ')
          ..write('parentObjectRef: $parentObjectRef, ')
          ..write('parentMainEquipmentPoleRef: $parentMainEquipmentPoleRef, ')
          ..write('nominalVoltageKv: $nominalVoltageKv, ')
          ..write('nominalBreakingCurrentKa: $nominalBreakingCurrentKa, ')
          ..write('ownTripTimeSec: $ownTripTimeSec, ')
          ..write('emergencyCurrentA: $emergencyCurrentA, ')
          ..write('continuousCurrentA: $continuousCurrentA, ')
          ..write('arresterType: $arresterType, ')
          ..write('xPosition: $xPosition, ')
          ..write('yPosition: $yPosition, ')
          ..write('directionAngle: $directionAngle, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isLocal: $isLocal, ')
          ..write('needsSync: $needsSync')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    poleId,
    equipmentType,
    name,
    quantity,
    defect,
    criticality,
    defectAttachment,
    cardComment,
    cardCommentAttachment,
    manufacturer,
    model,
    serialNumber,
    yearManufactured,
    installationDate,
    condition,
    notes,
    mrid,
    catalogItemId,
    ratedCurrent,
    iTh,
    ipMax,
    tTh,
    normalOpen,
    retained,
    identifiedObjectDescription,
    nameplate,
    psrSubtype,
    installationDisplayName,
    tmCode,
    objectSubtype,
    poleCount,
    parentObjectRef,
    parentMainEquipmentPoleRef,
    nominalVoltageKv,
    nominalBreakingCurrentKa,
    ownTripTimeSec,
    emergencyCurrentA,
    continuousCurrentA,
    arresterType,
    xPosition,
    yPosition,
    directionAngle,
    createdBy,
    createdAt,
    updatedAt,
    isLocal,
    needsSync,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EquipmentData &&
          other.id == this.id &&
          other.poleId == this.poleId &&
          other.equipmentType == this.equipmentType &&
          other.name == this.name &&
          other.quantity == this.quantity &&
          other.defect == this.defect &&
          other.criticality == this.criticality &&
          other.defectAttachment == this.defectAttachment &&
          other.cardComment == this.cardComment &&
          other.cardCommentAttachment == this.cardCommentAttachment &&
          other.manufacturer == this.manufacturer &&
          other.model == this.model &&
          other.serialNumber == this.serialNumber &&
          other.yearManufactured == this.yearManufactured &&
          other.installationDate == this.installationDate &&
          other.condition == this.condition &&
          other.notes == this.notes &&
          other.mrid == this.mrid &&
          other.catalogItemId == this.catalogItemId &&
          other.ratedCurrent == this.ratedCurrent &&
          other.iTh == this.iTh &&
          other.ipMax == this.ipMax &&
          other.tTh == this.tTh &&
          other.normalOpen == this.normalOpen &&
          other.retained == this.retained &&
          other.identifiedObjectDescription ==
              this.identifiedObjectDescription &&
          other.nameplate == this.nameplate &&
          other.psrSubtype == this.psrSubtype &&
          other.installationDisplayName == this.installationDisplayName &&
          other.tmCode == this.tmCode &&
          other.objectSubtype == this.objectSubtype &&
          other.poleCount == this.poleCount &&
          other.parentObjectRef == this.parentObjectRef &&
          other.parentMainEquipmentPoleRef == this.parentMainEquipmentPoleRef &&
          other.nominalVoltageKv == this.nominalVoltageKv &&
          other.nominalBreakingCurrentKa == this.nominalBreakingCurrentKa &&
          other.ownTripTimeSec == this.ownTripTimeSec &&
          other.emergencyCurrentA == this.emergencyCurrentA &&
          other.continuousCurrentA == this.continuousCurrentA &&
          other.arresterType == this.arresterType &&
          other.xPosition == this.xPosition &&
          other.yPosition == this.yPosition &&
          other.directionAngle == this.directionAngle &&
          other.createdBy == this.createdBy &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isLocal == this.isLocal &&
          other.needsSync == this.needsSync);
}

class EquipmentCompanion extends UpdateCompanion<EquipmentData> {
  final Value<int> id;
  final Value<int> poleId;
  final Value<String> equipmentType;
  final Value<String> name;
  final Value<int> quantity;
  final Value<String?> defect;
  final Value<String?> criticality;
  final Value<String?> defectAttachment;
  final Value<String?> cardComment;
  final Value<String?> cardCommentAttachment;
  final Value<String?> manufacturer;
  final Value<String?> model;
  final Value<String?> serialNumber;
  final Value<int?> yearManufactured;
  final Value<DateTime?> installationDate;
  final Value<String> condition;
  final Value<String?> notes;
  final Value<String?> mrid;
  final Value<int?> catalogItemId;
  final Value<double?> ratedCurrent;
  final Value<double?> iTh;
  final Value<double?> ipMax;
  final Value<double?> tTh;
  final Value<bool?> normalOpen;
  final Value<bool?> retained;
  final Value<String?> identifiedObjectDescription;
  final Value<String?> nameplate;
  final Value<String?> psrSubtype;
  final Value<String?> installationDisplayName;
  final Value<String?> tmCode;
  final Value<String?> objectSubtype;
  final Value<int?> poleCount;
  final Value<String?> parentObjectRef;
  final Value<String?> parentMainEquipmentPoleRef;
  final Value<double?> nominalVoltageKv;
  final Value<double?> nominalBreakingCurrentKa;
  final Value<double?> ownTripTimeSec;
  final Value<double?> emergencyCurrentA;
  final Value<double?> continuousCurrentA;
  final Value<String?> arresterType;
  final Value<double?> xPosition;
  final Value<double?> yPosition;
  final Value<double?> directionAngle;
  final Value<int> createdBy;
  final Value<DateTime> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<bool> isLocal;
  final Value<bool> needsSync;
  const EquipmentCompanion({
    this.id = const Value.absent(),
    this.poleId = const Value.absent(),
    this.equipmentType = const Value.absent(),
    this.name = const Value.absent(),
    this.quantity = const Value.absent(),
    this.defect = const Value.absent(),
    this.criticality = const Value.absent(),
    this.defectAttachment = const Value.absent(),
    this.cardComment = const Value.absent(),
    this.cardCommentAttachment = const Value.absent(),
    this.manufacturer = const Value.absent(),
    this.model = const Value.absent(),
    this.serialNumber = const Value.absent(),
    this.yearManufactured = const Value.absent(),
    this.installationDate = const Value.absent(),
    this.condition = const Value.absent(),
    this.notes = const Value.absent(),
    this.mrid = const Value.absent(),
    this.catalogItemId = const Value.absent(),
    this.ratedCurrent = const Value.absent(),
    this.iTh = const Value.absent(),
    this.ipMax = const Value.absent(),
    this.tTh = const Value.absent(),
    this.normalOpen = const Value.absent(),
    this.retained = const Value.absent(),
    this.identifiedObjectDescription = const Value.absent(),
    this.nameplate = const Value.absent(),
    this.psrSubtype = const Value.absent(),
    this.installationDisplayName = const Value.absent(),
    this.tmCode = const Value.absent(),
    this.objectSubtype = const Value.absent(),
    this.poleCount = const Value.absent(),
    this.parentObjectRef = const Value.absent(),
    this.parentMainEquipmentPoleRef = const Value.absent(),
    this.nominalVoltageKv = const Value.absent(),
    this.nominalBreakingCurrentKa = const Value.absent(),
    this.ownTripTimeSec = const Value.absent(),
    this.emergencyCurrentA = const Value.absent(),
    this.continuousCurrentA = const Value.absent(),
    this.arresterType = const Value.absent(),
    this.xPosition = const Value.absent(),
    this.yPosition = const Value.absent(),
    this.directionAngle = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isLocal = const Value.absent(),
    this.needsSync = const Value.absent(),
  });
  EquipmentCompanion.insert({
    this.id = const Value.absent(),
    required int poleId,
    required String equipmentType,
    required String name,
    this.quantity = const Value.absent(),
    this.defect = const Value.absent(),
    this.criticality = const Value.absent(),
    this.defectAttachment = const Value.absent(),
    this.cardComment = const Value.absent(),
    this.cardCommentAttachment = const Value.absent(),
    this.manufacturer = const Value.absent(),
    this.model = const Value.absent(),
    this.serialNumber = const Value.absent(),
    this.yearManufactured = const Value.absent(),
    this.installationDate = const Value.absent(),
    required String condition,
    this.notes = const Value.absent(),
    this.mrid = const Value.absent(),
    this.catalogItemId = const Value.absent(),
    this.ratedCurrent = const Value.absent(),
    this.iTh = const Value.absent(),
    this.ipMax = const Value.absent(),
    this.tTh = const Value.absent(),
    this.normalOpen = const Value.absent(),
    this.retained = const Value.absent(),
    this.identifiedObjectDescription = const Value.absent(),
    this.nameplate = const Value.absent(),
    this.psrSubtype = const Value.absent(),
    this.installationDisplayName = const Value.absent(),
    this.tmCode = const Value.absent(),
    this.objectSubtype = const Value.absent(),
    this.poleCount = const Value.absent(),
    this.parentObjectRef = const Value.absent(),
    this.parentMainEquipmentPoleRef = const Value.absent(),
    this.nominalVoltageKv = const Value.absent(),
    this.nominalBreakingCurrentKa = const Value.absent(),
    this.ownTripTimeSec = const Value.absent(),
    this.emergencyCurrentA = const Value.absent(),
    this.continuousCurrentA = const Value.absent(),
    this.arresterType = const Value.absent(),
    this.xPosition = const Value.absent(),
    this.yPosition = const Value.absent(),
    this.directionAngle = const Value.absent(),
    required int createdBy,
    required DateTime createdAt,
    this.updatedAt = const Value.absent(),
    this.isLocal = const Value.absent(),
    this.needsSync = const Value.absent(),
  }) : poleId = Value(poleId),
       equipmentType = Value(equipmentType),
       name = Value(name),
       condition = Value(condition),
       createdBy = Value(createdBy),
       createdAt = Value(createdAt);
  static Insertable<EquipmentData> custom({
    Expression<int>? id,
    Expression<int>? poleId,
    Expression<String>? equipmentType,
    Expression<String>? name,
    Expression<int>? quantity,
    Expression<String>? defect,
    Expression<String>? criticality,
    Expression<String>? defectAttachment,
    Expression<String>? cardComment,
    Expression<String>? cardCommentAttachment,
    Expression<String>? manufacturer,
    Expression<String>? model,
    Expression<String>? serialNumber,
    Expression<int>? yearManufactured,
    Expression<DateTime>? installationDate,
    Expression<String>? condition,
    Expression<String>? notes,
    Expression<String>? mrid,
    Expression<int>? catalogItemId,
    Expression<double>? ratedCurrent,
    Expression<double>? iTh,
    Expression<double>? ipMax,
    Expression<double>? tTh,
    Expression<bool>? normalOpen,
    Expression<bool>? retained,
    Expression<String>? identifiedObjectDescription,
    Expression<String>? nameplate,
    Expression<String>? psrSubtype,
    Expression<String>? installationDisplayName,
    Expression<String>? tmCode,
    Expression<String>? objectSubtype,
    Expression<int>? poleCount,
    Expression<String>? parentObjectRef,
    Expression<String>? parentMainEquipmentPoleRef,
    Expression<double>? nominalVoltageKv,
    Expression<double>? nominalBreakingCurrentKa,
    Expression<double>? ownTripTimeSec,
    Expression<double>? emergencyCurrentA,
    Expression<double>? continuousCurrentA,
    Expression<String>? arresterType,
    Expression<double>? xPosition,
    Expression<double>? yPosition,
    Expression<double>? directionAngle,
    Expression<int>? createdBy,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isLocal,
    Expression<bool>? needsSync,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (poleId != null) 'pole_id': poleId,
      if (equipmentType != null) 'equipment_type': equipmentType,
      if (name != null) 'name': name,
      if (quantity != null) 'quantity': quantity,
      if (defect != null) 'defect': defect,
      if (criticality != null) 'criticality': criticality,
      if (defectAttachment != null) 'defect_attachment': defectAttachment,
      if (cardComment != null) 'card_comment': cardComment,
      if (cardCommentAttachment != null)
        'card_comment_attachment': cardCommentAttachment,
      if (manufacturer != null) 'manufacturer': manufacturer,
      if (model != null) 'model': model,
      if (serialNumber != null) 'serial_number': serialNumber,
      if (yearManufactured != null) 'year_manufactured': yearManufactured,
      if (installationDate != null) 'installation_date': installationDate,
      if (condition != null) 'condition': condition,
      if (notes != null) 'notes': notes,
      if (mrid != null) 'mrid': mrid,
      if (catalogItemId != null) 'catalog_item_id': catalogItemId,
      if (ratedCurrent != null) 'rated_current': ratedCurrent,
      if (iTh != null) 'i_th': iTh,
      if (ipMax != null) 'ip_max': ipMax,
      if (tTh != null) 't_th': tTh,
      if (normalOpen != null) 'normal_open': normalOpen,
      if (retained != null) 'retained': retained,
      if (identifiedObjectDescription != null)
        'identified_object_description': identifiedObjectDescription,
      if (nameplate != null) 'nameplate': nameplate,
      if (psrSubtype != null) 'psr_subtype': psrSubtype,
      if (installationDisplayName != null)
        'installation_display_name': installationDisplayName,
      if (tmCode != null) 'tm_code': tmCode,
      if (objectSubtype != null) 'object_subtype': objectSubtype,
      if (poleCount != null) 'pole_count': poleCount,
      if (parentObjectRef != null) 'parent_object_ref': parentObjectRef,
      if (parentMainEquipmentPoleRef != null)
        'parent_main_equipment_pole_ref': parentMainEquipmentPoleRef,
      if (nominalVoltageKv != null) 'nominal_voltage_kv': nominalVoltageKv,
      if (nominalBreakingCurrentKa != null)
        'nominal_breaking_current_ka': nominalBreakingCurrentKa,
      if (ownTripTimeSec != null) 'own_trip_time_sec': ownTripTimeSec,
      if (emergencyCurrentA != null) 'emergency_current_a': emergencyCurrentA,
      if (continuousCurrentA != null)
        'continuous_current_a': continuousCurrentA,
      if (arresterType != null) 'arrester_type': arresterType,
      if (xPosition != null) 'x_position': xPosition,
      if (yPosition != null) 'y_position': yPosition,
      if (directionAngle != null) 'direction_angle': directionAngle,
      if (createdBy != null) 'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isLocal != null) 'is_local': isLocal,
      if (needsSync != null) 'needs_sync': needsSync,
    });
  }

  EquipmentCompanion copyWith({
    Value<int>? id,
    Value<int>? poleId,
    Value<String>? equipmentType,
    Value<String>? name,
    Value<int>? quantity,
    Value<String?>? defect,
    Value<String?>? criticality,
    Value<String?>? defectAttachment,
    Value<String?>? cardComment,
    Value<String?>? cardCommentAttachment,
    Value<String?>? manufacturer,
    Value<String?>? model,
    Value<String?>? serialNumber,
    Value<int?>? yearManufactured,
    Value<DateTime?>? installationDate,
    Value<String>? condition,
    Value<String?>? notes,
    Value<String?>? mrid,
    Value<int?>? catalogItemId,
    Value<double?>? ratedCurrent,
    Value<double?>? iTh,
    Value<double?>? ipMax,
    Value<double?>? tTh,
    Value<bool?>? normalOpen,
    Value<bool?>? retained,
    Value<String?>? identifiedObjectDescription,
    Value<String?>? nameplate,
    Value<String?>? psrSubtype,
    Value<String?>? installationDisplayName,
    Value<String?>? tmCode,
    Value<String?>? objectSubtype,
    Value<int?>? poleCount,
    Value<String?>? parentObjectRef,
    Value<String?>? parentMainEquipmentPoleRef,
    Value<double?>? nominalVoltageKv,
    Value<double?>? nominalBreakingCurrentKa,
    Value<double?>? ownTripTimeSec,
    Value<double?>? emergencyCurrentA,
    Value<double?>? continuousCurrentA,
    Value<String?>? arresterType,
    Value<double?>? xPosition,
    Value<double?>? yPosition,
    Value<double?>? directionAngle,
    Value<int>? createdBy,
    Value<DateTime>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<bool>? isLocal,
    Value<bool>? needsSync,
  }) {
    return EquipmentCompanion(
      id: id ?? this.id,
      poleId: poleId ?? this.poleId,
      equipmentType: equipmentType ?? this.equipmentType,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      defect: defect ?? this.defect,
      criticality: criticality ?? this.criticality,
      defectAttachment: defectAttachment ?? this.defectAttachment,
      cardComment: cardComment ?? this.cardComment,
      cardCommentAttachment:
          cardCommentAttachment ?? this.cardCommentAttachment,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      yearManufactured: yearManufactured ?? this.yearManufactured,
      installationDate: installationDate ?? this.installationDate,
      condition: condition ?? this.condition,
      notes: notes ?? this.notes,
      mrid: mrid ?? this.mrid,
      catalogItemId: catalogItemId ?? this.catalogItemId,
      ratedCurrent: ratedCurrent ?? this.ratedCurrent,
      iTh: iTh ?? this.iTh,
      ipMax: ipMax ?? this.ipMax,
      tTh: tTh ?? this.tTh,
      normalOpen: normalOpen ?? this.normalOpen,
      retained: retained ?? this.retained,
      identifiedObjectDescription:
          identifiedObjectDescription ?? this.identifiedObjectDescription,
      nameplate: nameplate ?? this.nameplate,
      psrSubtype: psrSubtype ?? this.psrSubtype,
      installationDisplayName:
          installationDisplayName ?? this.installationDisplayName,
      tmCode: tmCode ?? this.tmCode,
      objectSubtype: objectSubtype ?? this.objectSubtype,
      poleCount: poleCount ?? this.poleCount,
      parentObjectRef: parentObjectRef ?? this.parentObjectRef,
      parentMainEquipmentPoleRef:
          parentMainEquipmentPoleRef ?? this.parentMainEquipmentPoleRef,
      nominalVoltageKv: nominalVoltageKv ?? this.nominalVoltageKv,
      nominalBreakingCurrentKa:
          nominalBreakingCurrentKa ?? this.nominalBreakingCurrentKa,
      ownTripTimeSec: ownTripTimeSec ?? this.ownTripTimeSec,
      emergencyCurrentA: emergencyCurrentA ?? this.emergencyCurrentA,
      continuousCurrentA: continuousCurrentA ?? this.continuousCurrentA,
      arresterType: arresterType ?? this.arresterType,
      xPosition: xPosition ?? this.xPosition,
      yPosition: yPosition ?? this.yPosition,
      directionAngle: directionAngle ?? this.directionAngle,
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
    if (poleId.present) {
      map['pole_id'] = Variable<int>(poleId.value);
    }
    if (equipmentType.present) {
      map['equipment_type'] = Variable<String>(equipmentType.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (defect.present) {
      map['defect'] = Variable<String>(defect.value);
    }
    if (criticality.present) {
      map['criticality'] = Variable<String>(criticality.value);
    }
    if (defectAttachment.present) {
      map['defect_attachment'] = Variable<String>(defectAttachment.value);
    }
    if (cardComment.present) {
      map['card_comment'] = Variable<String>(cardComment.value);
    }
    if (cardCommentAttachment.present) {
      map['card_comment_attachment'] = Variable<String>(
        cardCommentAttachment.value,
      );
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
    if (mrid.present) {
      map['mrid'] = Variable<String>(mrid.value);
    }
    if (catalogItemId.present) {
      map['catalog_item_id'] = Variable<int>(catalogItemId.value);
    }
    if (ratedCurrent.present) {
      map['rated_current'] = Variable<double>(ratedCurrent.value);
    }
    if (iTh.present) {
      map['i_th'] = Variable<double>(iTh.value);
    }
    if (ipMax.present) {
      map['ip_max'] = Variable<double>(ipMax.value);
    }
    if (tTh.present) {
      map['t_th'] = Variable<double>(tTh.value);
    }
    if (normalOpen.present) {
      map['normal_open'] = Variable<bool>(normalOpen.value);
    }
    if (retained.present) {
      map['retained'] = Variable<bool>(retained.value);
    }
    if (identifiedObjectDescription.present) {
      map['identified_object_description'] = Variable<String>(
        identifiedObjectDescription.value,
      );
    }
    if (nameplate.present) {
      map['nameplate'] = Variable<String>(nameplate.value);
    }
    if (psrSubtype.present) {
      map['psr_subtype'] = Variable<String>(psrSubtype.value);
    }
    if (installationDisplayName.present) {
      map['installation_display_name'] = Variable<String>(
        installationDisplayName.value,
      );
    }
    if (tmCode.present) {
      map['tm_code'] = Variable<String>(tmCode.value);
    }
    if (objectSubtype.present) {
      map['object_subtype'] = Variable<String>(objectSubtype.value);
    }
    if (poleCount.present) {
      map['pole_count'] = Variable<int>(poleCount.value);
    }
    if (parentObjectRef.present) {
      map['parent_object_ref'] = Variable<String>(parentObjectRef.value);
    }
    if (parentMainEquipmentPoleRef.present) {
      map['parent_main_equipment_pole_ref'] = Variable<String>(
        parentMainEquipmentPoleRef.value,
      );
    }
    if (nominalVoltageKv.present) {
      map['nominal_voltage_kv'] = Variable<double>(nominalVoltageKv.value);
    }
    if (nominalBreakingCurrentKa.present) {
      map['nominal_breaking_current_ka'] = Variable<double>(
        nominalBreakingCurrentKa.value,
      );
    }
    if (ownTripTimeSec.present) {
      map['own_trip_time_sec'] = Variable<double>(ownTripTimeSec.value);
    }
    if (emergencyCurrentA.present) {
      map['emergency_current_a'] = Variable<double>(emergencyCurrentA.value);
    }
    if (continuousCurrentA.present) {
      map['continuous_current_a'] = Variable<double>(continuousCurrentA.value);
    }
    if (arresterType.present) {
      map['arrester_type'] = Variable<String>(arresterType.value);
    }
    if (xPosition.present) {
      map['x_position'] = Variable<double>(xPosition.value);
    }
    if (yPosition.present) {
      map['y_position'] = Variable<double>(yPosition.value);
    }
    if (directionAngle.present) {
      map['direction_angle'] = Variable<double>(directionAngle.value);
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
          ..write('poleId: $poleId, ')
          ..write('equipmentType: $equipmentType, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('defect: $defect, ')
          ..write('criticality: $criticality, ')
          ..write('defectAttachment: $defectAttachment, ')
          ..write('cardComment: $cardComment, ')
          ..write('cardCommentAttachment: $cardCommentAttachment, ')
          ..write('manufacturer: $manufacturer, ')
          ..write('model: $model, ')
          ..write('serialNumber: $serialNumber, ')
          ..write('yearManufactured: $yearManufactured, ')
          ..write('installationDate: $installationDate, ')
          ..write('condition: $condition, ')
          ..write('notes: $notes, ')
          ..write('mrid: $mrid, ')
          ..write('catalogItemId: $catalogItemId, ')
          ..write('ratedCurrent: $ratedCurrent, ')
          ..write('iTh: $iTh, ')
          ..write('ipMax: $ipMax, ')
          ..write('tTh: $tTh, ')
          ..write('normalOpen: $normalOpen, ')
          ..write('retained: $retained, ')
          ..write('identifiedObjectDescription: $identifiedObjectDescription, ')
          ..write('nameplate: $nameplate, ')
          ..write('psrSubtype: $psrSubtype, ')
          ..write('installationDisplayName: $installationDisplayName, ')
          ..write('tmCode: $tmCode, ')
          ..write('objectSubtype: $objectSubtype, ')
          ..write('poleCount: $poleCount, ')
          ..write('parentObjectRef: $parentObjectRef, ')
          ..write('parentMainEquipmentPoleRef: $parentMainEquipmentPoleRef, ')
          ..write('nominalVoltageKv: $nominalVoltageKv, ')
          ..write('nominalBreakingCurrentKa: $nominalBreakingCurrentKa, ')
          ..write('ownTripTimeSec: $ownTripTimeSec, ')
          ..write('emergencyCurrentA: $emergencyCurrentA, ')
          ..write('continuousCurrentA: $continuousCurrentA, ')
          ..write('arresterType: $arresterType, ')
          ..write('xPosition: $xPosition, ')
          ..write('yPosition: $yPosition, ')
          ..write('directionAngle: $directionAngle, ')
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
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
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
    errorMessage,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncRecord> instance, {
    bool isInserting = false,
  }) {
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
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_id'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
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
  const SyncRecord({
    required this.id,
    required this.entityType,
    required this.action,
    required this.data,
    required this.timestamp,
    this.userId,
    this.deviceId,
    required this.status,
    this.errorMessage,
  });
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
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      deviceId: deviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceId),
      status: Value(status),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
    );
  }

  factory SyncRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
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

  SyncRecord copyWith({
    String? id,
    String? entityType,
    String? action,
    String? data,
    DateTime? timestamp,
    Value<int?> userId = const Value.absent(),
    Value<String?> deviceId = const Value.absent(),
    String? status,
    Value<String?> errorMessage = const Value.absent(),
  }) => SyncRecord(
    id: id ?? this.id,
    entityType: entityType ?? this.entityType,
    action: action ?? this.action,
    data: data ?? this.data,
    timestamp: timestamp ?? this.timestamp,
    userId: userId.present ? userId.value : this.userId,
    deviceId: deviceId.present ? deviceId.value : this.deviceId,
    status: status ?? this.status,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
  );
  SyncRecord copyWithCompanion(SyncRecordsCompanion data) {
    return SyncRecord(
      id: data.id.present ? data.id.value : this.id,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
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
  int get hashCode => Object.hash(
    id,
    entityType,
    action,
    data,
    timestamp,
    userId,
    deviceId,
    status,
    errorMessage,
  );
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
  }) : id = Value(id),
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

  SyncRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? entityType,
    Value<String>? action,
    Value<String>? data,
    Value<DateTime>? timestamp,
    Value<int?>? userId,
    Value<String?>? deviceId,
    Value<String>? status,
    Value<String?>? errorMessage,
    Value<int>? rowid,
  }) {
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

class $PatrolSessionsTable extends PatrolSessions
    with TableInfo<$PatrolSessionsTable, PatrolSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PatrolSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lineIdMeta = const VerificationMeta('lineId');
  @override
  late final GeneratedColumn<int> lineId = GeneratedColumn<int>(
    'line_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    lineId,
    note,
    startedAt,
    endedAt,
    syncStatus,
    userId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'patrol_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PatrolSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('line_id')) {
      context.handle(
        _lineIdMeta,
        lineId.isAcceptableOrUnknown(data['line_id']!, _lineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lineIdMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PatrolSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PatrolSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      lineId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line_id'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_id'],
      ),
    );
  }

  @override
  $PatrolSessionsTable createAlias(String alias) {
    return $PatrolSessionsTable(attachedDatabase, alias);
  }
}

class PatrolSession extends DataClass implements Insertable<PatrolSession> {
  final int id;
  final int? serverId;
  final int lineId;
  final String? note;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String syncStatus;
  final int? userId;
  const PatrolSession({
    required this.id,
    this.serverId,
    required this.lineId,
    this.note,
    required this.startedAt,
    this.endedAt,
    required this.syncStatus,
    this.userId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['line_id'] = Variable<int>(lineId);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<int>(userId);
    }
    return map;
  }

  PatrolSessionsCompanion toCompanion(bool nullToAbsent) {
    return PatrolSessionsCompanion(
      id: Value(id),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      lineId: Value(lineId),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      syncStatus: Value(syncStatus),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
    );
  }

  factory PatrolSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PatrolSession(
      id: serializer.fromJson<int>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      lineId: serializer.fromJson<int>(json['lineId']),
      note: serializer.fromJson<String?>(json['note']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      userId: serializer.fromJson<int?>(json['userId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'lineId': serializer.toJson<int>(lineId),
      'note': serializer.toJson<String?>(note),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'userId': serializer.toJson<int?>(userId),
    };
  }

  PatrolSession copyWith({
    int? id,
    Value<int?> serverId = const Value.absent(),
    int? lineId,
    Value<String?> note = const Value.absent(),
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    String? syncStatus,
    Value<int?> userId = const Value.absent(),
  }) => PatrolSession(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    lineId: lineId ?? this.lineId,
    note: note.present ? note.value : this.note,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    syncStatus: syncStatus ?? this.syncStatus,
    userId: userId.present ? userId.value : this.userId,
  );
  PatrolSession copyWithCompanion(PatrolSessionsCompanion data) {
    return PatrolSession(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      lineId: data.lineId.present ? data.lineId.value : this.lineId,
      note: data.note.present ? data.note.value : this.note,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      userId: data.userId.present ? data.userId.value : this.userId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PatrolSession(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('lineId: $lineId, ')
          ..write('note: $note, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('userId: $userId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    lineId,
    note,
    startedAt,
    endedAt,
    syncStatus,
    userId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PatrolSession &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.lineId == this.lineId &&
          other.note == this.note &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.syncStatus == this.syncStatus &&
          other.userId == this.userId);
}

class PatrolSessionsCompanion extends UpdateCompanion<PatrolSession> {
  final Value<int> id;
  final Value<int?> serverId;
  final Value<int> lineId;
  final Value<String?> note;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<String> syncStatus;
  final Value<int?> userId;
  const PatrolSessionsCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.lineId = const Value.absent(),
    this.note = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.userId = const Value.absent(),
  });
  PatrolSessionsCompanion.insert({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    required int lineId,
    this.note = const Value.absent(),
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.userId = const Value.absent(),
  }) : lineId = Value(lineId),
       startedAt = Value(startedAt);
  static Insertable<PatrolSession> custom({
    Expression<int>? id,
    Expression<int>? serverId,
    Expression<int>? lineId,
    Expression<String>? note,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<String>? syncStatus,
    Expression<int>? userId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (lineId != null) 'line_id': lineId,
      if (note != null) 'note': note,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (userId != null) 'user_id': userId,
    });
  }

  PatrolSessionsCompanion copyWith({
    Value<int>? id,
    Value<int?>? serverId,
    Value<int>? lineId,
    Value<String?>? note,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<String>? syncStatus,
    Value<int?>? userId,
  }) {
    return PatrolSessionsCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      lineId: lineId ?? this.lineId,
      note: note ?? this.note,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      userId: userId ?? this.userId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (lineId.present) {
      map['line_id'] = Variable<int>(lineId.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PatrolSessionsCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('lineId: $lineId, ')
          ..write('note: $note, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('userId: $userId')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PowerLinesTable powerLines = $PowerLinesTable(this);
  late final $PolesTable poles = $PolesTable(this);
  late final $EquipmentTable equipment = $EquipmentTable(this);
  late final $SyncRecordsTable syncRecords = $SyncRecordsTable(this);
  late final $PatrolSessionsTable patrolSessions = $PatrolSessionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    powerLines,
    poles,
    equipment,
    syncRecords,
    patrolSessions,
  ];
}

typedef $$PowerLinesTableCreateCompanionBuilder =
    PowerLinesCompanion Function({
      Value<int> id,
      required String name,
      required String code,
      Value<String?> mrid,
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
typedef $$PowerLinesTableUpdateCompanionBuilder =
    PowerLinesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> code,
      Value<String?> mrid,
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
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mrid => $composableBuilder(
    column: $table.mrid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get voltageLevel => $composableBuilder(
    column: $table.voltageLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get length => $composableBuilder(
    column: $table.length,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get branchId => $composableBuilder(
    column: $table.branchId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isLocal => $composableBuilder(
    column: $table.isLocal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get needsSync => $composableBuilder(
    column: $table.needsSync,
    builder: (column) => ColumnFilters(column),
  );
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
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mrid => $composableBuilder(
    column: $table.mrid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get voltageLevel => $composableBuilder(
    column: $table.voltageLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get length => $composableBuilder(
    column: $table.length,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get branchId => $composableBuilder(
    column: $table.branchId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isLocal => $composableBuilder(
    column: $table.isLocal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get needsSync => $composableBuilder(
    column: $table.needsSync,
    builder: (column) => ColumnOrderings(column),
  );
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

  GeneratedColumn<String> get mrid =>
      $composableBuilder(column: $table.mrid, builder: (column) => column);

  GeneratedColumn<double> get voltageLevel => $composableBuilder(
    column: $table.voltageLevel,
    builder: (column) => column,
  );

  GeneratedColumn<double> get length =>
      $composableBuilder(column: $table.length, builder: (column) => column);

  GeneratedColumn<int> get branchId =>
      $composableBuilder(column: $table.branchId, builder: (column) => column);

  GeneratedColumn<int> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isLocal =>
      $composableBuilder(column: $table.isLocal, builder: (column) => column);

  GeneratedColumn<bool> get needsSync =>
      $composableBuilder(column: $table.needsSync, builder: (column) => column);
}

class $$PowerLinesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PowerLinesTable,
          PowerLine,
          $$PowerLinesTableFilterComposer,
          $$PowerLinesTableOrderingComposer,
          $$PowerLinesTableAnnotationComposer,
          $$PowerLinesTableCreateCompanionBuilder,
          $$PowerLinesTableUpdateCompanionBuilder,
          (
            PowerLine,
            BaseReferences<_$AppDatabase, $PowerLinesTable, PowerLine>,
          ),
          PowerLine,
          PrefetchHooks Function()
        > {
  $$PowerLinesTableTableManager(_$AppDatabase db, $PowerLinesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PowerLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PowerLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PowerLinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String?> mrid = const Value.absent(),
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
              }) => PowerLinesCompanion(
                id: id,
                name: name,
                code: code,
                mrid: mrid,
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
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String code,
                Value<String?> mrid = const Value.absent(),
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
              }) => PowerLinesCompanion.insert(
                id: id,
                name: name,
                code: code,
                mrid: mrid,
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
        ),
      );
}

typedef $$PowerLinesTableProcessedTableManager =
    ProcessedTableManager<
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
      PrefetchHooks Function()
    >;
typedef $$PolesTableCreateCompanionBuilder =
    PolesCompanion Function({
      Value<int> id,
      required int lineId,
      required String poleNumber,
      Value<double?> xPosition,
      Value<double?> yPosition,
      Value<String?> poleType,
      Value<double?> height,
      Value<String?> foundationType,
      Value<String?> material,
      Value<int?> yearInstalled,
      Value<String?> condition,
      Value<String?> notes,
      Value<String?> structuralDefect,
      Value<String?> structuralDefectCriticality,
      Value<String?> cardComment,
      Value<String?> cardCommentAttachment,
      required int createdBy,
      required DateTime createdAt,
      Value<DateTime?> updatedAt,
      Value<bool> isLocal,
      Value<bool> needsSync,
    });
typedef $$PolesTableUpdateCompanionBuilder =
    PolesCompanion Function({
      Value<int> id,
      Value<int> lineId,
      Value<String> poleNumber,
      Value<double?> xPosition,
      Value<double?> yPosition,
      Value<String?> poleType,
      Value<double?> height,
      Value<String?> foundationType,
      Value<String?> material,
      Value<int?> yearInstalled,
      Value<String?> condition,
      Value<String?> notes,
      Value<String?> structuralDefect,
      Value<String?> structuralDefectCriticality,
      Value<String?> cardComment,
      Value<String?> cardCommentAttachment,
      Value<int> createdBy,
      Value<DateTime> createdAt,
      Value<DateTime?> updatedAt,
      Value<bool> isLocal,
      Value<bool> needsSync,
    });

class $$PolesTableFilterComposer extends Composer<_$AppDatabase, $PolesTable> {
  $$PolesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lineId => $composableBuilder(
    column: $table.lineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get poleNumber => $composableBuilder(
    column: $table.poleNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get xPosition => $composableBuilder(
    column: $table.xPosition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get yPosition => $composableBuilder(
    column: $table.yPosition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get poleType => $composableBuilder(
    column: $table.poleType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get foundationType => $composableBuilder(
    column: $table.foundationType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get material => $composableBuilder(
    column: $table.material,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get yearInstalled => $composableBuilder(
    column: $table.yearInstalled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get condition => $composableBuilder(
    column: $table.condition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get structuralDefect => $composableBuilder(
    column: $table.structuralDefect,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get structuralDefectCriticality => $composableBuilder(
    column: $table.structuralDefectCriticality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cardComment => $composableBuilder(
    column: $table.cardComment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cardCommentAttachment => $composableBuilder(
    column: $table.cardCommentAttachment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isLocal => $composableBuilder(
    column: $table.isLocal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get needsSync => $composableBuilder(
    column: $table.needsSync,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PolesTableOrderingComposer
    extends Composer<_$AppDatabase, $PolesTable> {
  $$PolesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lineId => $composableBuilder(
    column: $table.lineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get poleNumber => $composableBuilder(
    column: $table.poleNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get xPosition => $composableBuilder(
    column: $table.xPosition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get yPosition => $composableBuilder(
    column: $table.yPosition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get poleType => $composableBuilder(
    column: $table.poleType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get foundationType => $composableBuilder(
    column: $table.foundationType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get material => $composableBuilder(
    column: $table.material,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get yearInstalled => $composableBuilder(
    column: $table.yearInstalled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get condition => $composableBuilder(
    column: $table.condition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get structuralDefect => $composableBuilder(
    column: $table.structuralDefect,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get structuralDefectCriticality => $composableBuilder(
    column: $table.structuralDefectCriticality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cardComment => $composableBuilder(
    column: $table.cardComment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cardCommentAttachment => $composableBuilder(
    column: $table.cardCommentAttachment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isLocal => $composableBuilder(
    column: $table.isLocal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get needsSync => $composableBuilder(
    column: $table.needsSync,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PolesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PolesTable> {
  $$PolesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get lineId =>
      $composableBuilder(column: $table.lineId, builder: (column) => column);

  GeneratedColumn<String> get poleNumber => $composableBuilder(
    column: $table.poleNumber,
    builder: (column) => column,
  );

  GeneratedColumn<double> get xPosition =>
      $composableBuilder(column: $table.xPosition, builder: (column) => column);

  GeneratedColumn<double> get yPosition =>
      $composableBuilder(column: $table.yPosition, builder: (column) => column);

  GeneratedColumn<String> get poleType =>
      $composableBuilder(column: $table.poleType, builder: (column) => column);

  GeneratedColumn<double> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<String> get foundationType => $composableBuilder(
    column: $table.foundationType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get material =>
      $composableBuilder(column: $table.material, builder: (column) => column);

  GeneratedColumn<int> get yearInstalled => $composableBuilder(
    column: $table.yearInstalled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get condition =>
      $composableBuilder(column: $table.condition, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get structuralDefect => $composableBuilder(
    column: $table.structuralDefect,
    builder: (column) => column,
  );

  GeneratedColumn<String> get structuralDefectCriticality => $composableBuilder(
    column: $table.structuralDefectCriticality,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cardComment => $composableBuilder(
    column: $table.cardComment,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cardCommentAttachment => $composableBuilder(
    column: $table.cardCommentAttachment,
    builder: (column) => column,
  );

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

class $$PolesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PolesTable,
          Pole,
          $$PolesTableFilterComposer,
          $$PolesTableOrderingComposer,
          $$PolesTableAnnotationComposer,
          $$PolesTableCreateCompanionBuilder,
          $$PolesTableUpdateCompanionBuilder,
          (Pole, BaseReferences<_$AppDatabase, $PolesTable, Pole>),
          Pole,
          PrefetchHooks Function()
        > {
  $$PolesTableTableManager(_$AppDatabase db, $PolesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PolesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PolesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PolesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> lineId = const Value.absent(),
                Value<String> poleNumber = const Value.absent(),
                Value<double?> xPosition = const Value.absent(),
                Value<double?> yPosition = const Value.absent(),
                Value<String?> poleType = const Value.absent(),
                Value<double?> height = const Value.absent(),
                Value<String?> foundationType = const Value.absent(),
                Value<String?> material = const Value.absent(),
                Value<int?> yearInstalled = const Value.absent(),
                Value<String?> condition = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> structuralDefect = const Value.absent(),
                Value<String?> structuralDefectCriticality =
                    const Value.absent(),
                Value<String?> cardComment = const Value.absent(),
                Value<String?> cardCommentAttachment = const Value.absent(),
                Value<int> createdBy = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<bool> isLocal = const Value.absent(),
                Value<bool> needsSync = const Value.absent(),
              }) => PolesCompanion(
                id: id,
                lineId: lineId,
                poleNumber: poleNumber,
                xPosition: xPosition,
                yPosition: yPosition,
                poleType: poleType,
                height: height,
                foundationType: foundationType,
                material: material,
                yearInstalled: yearInstalled,
                condition: condition,
                notes: notes,
                structuralDefect: structuralDefect,
                structuralDefectCriticality: structuralDefectCriticality,
                cardComment: cardComment,
                cardCommentAttachment: cardCommentAttachment,
                createdBy: createdBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isLocal: isLocal,
                needsSync: needsSync,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int lineId,
                required String poleNumber,
                Value<double?> xPosition = const Value.absent(),
                Value<double?> yPosition = const Value.absent(),
                Value<String?> poleType = const Value.absent(),
                Value<double?> height = const Value.absent(),
                Value<String?> foundationType = const Value.absent(),
                Value<String?> material = const Value.absent(),
                Value<int?> yearInstalled = const Value.absent(),
                Value<String?> condition = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> structuralDefect = const Value.absent(),
                Value<String?> structuralDefectCriticality =
                    const Value.absent(),
                Value<String?> cardComment = const Value.absent(),
                Value<String?> cardCommentAttachment = const Value.absent(),
                required int createdBy,
                required DateTime createdAt,
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<bool> isLocal = const Value.absent(),
                Value<bool> needsSync = const Value.absent(),
              }) => PolesCompanion.insert(
                id: id,
                lineId: lineId,
                poleNumber: poleNumber,
                xPosition: xPosition,
                yPosition: yPosition,
                poleType: poleType,
                height: height,
                foundationType: foundationType,
                material: material,
                yearInstalled: yearInstalled,
                condition: condition,
                notes: notes,
                structuralDefect: structuralDefect,
                structuralDefectCriticality: structuralDefectCriticality,
                cardComment: cardComment,
                cardCommentAttachment: cardCommentAttachment,
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
        ),
      );
}

typedef $$PolesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PolesTable,
      Pole,
      $$PolesTableFilterComposer,
      $$PolesTableOrderingComposer,
      $$PolesTableAnnotationComposer,
      $$PolesTableCreateCompanionBuilder,
      $$PolesTableUpdateCompanionBuilder,
      (Pole, BaseReferences<_$AppDatabase, $PolesTable, Pole>),
      Pole,
      PrefetchHooks Function()
    >;
typedef $$EquipmentTableCreateCompanionBuilder =
    EquipmentCompanion Function({
      Value<int> id,
      required int poleId,
      required String equipmentType,
      required String name,
      Value<int> quantity,
      Value<String?> defect,
      Value<String?> criticality,
      Value<String?> defectAttachment,
      Value<String?> cardComment,
      Value<String?> cardCommentAttachment,
      Value<String?> manufacturer,
      Value<String?> model,
      Value<String?> serialNumber,
      Value<int?> yearManufactured,
      Value<DateTime?> installationDate,
      required String condition,
      Value<String?> notes,
      Value<String?> mrid,
      Value<int?> catalogItemId,
      Value<double?> ratedCurrent,
      Value<double?> iTh,
      Value<double?> ipMax,
      Value<double?> tTh,
      Value<bool?> normalOpen,
      Value<bool?> retained,
      Value<String?> identifiedObjectDescription,
      Value<String?> nameplate,
      Value<String?> psrSubtype,
      Value<String?> installationDisplayName,
      Value<String?> tmCode,
      Value<String?> objectSubtype,
      Value<int?> poleCount,
      Value<String?> parentObjectRef,
      Value<String?> parentMainEquipmentPoleRef,
      Value<double?> nominalVoltageKv,
      Value<double?> nominalBreakingCurrentKa,
      Value<double?> ownTripTimeSec,
      Value<double?> emergencyCurrentA,
      Value<double?> continuousCurrentA,
      Value<String?> arresterType,
      Value<double?> xPosition,
      Value<double?> yPosition,
      Value<double?> directionAngle,
      required int createdBy,
      required DateTime createdAt,
      Value<DateTime?> updatedAt,
      Value<bool> isLocal,
      Value<bool> needsSync,
    });
typedef $$EquipmentTableUpdateCompanionBuilder =
    EquipmentCompanion Function({
      Value<int> id,
      Value<int> poleId,
      Value<String> equipmentType,
      Value<String> name,
      Value<int> quantity,
      Value<String?> defect,
      Value<String?> criticality,
      Value<String?> defectAttachment,
      Value<String?> cardComment,
      Value<String?> cardCommentAttachment,
      Value<String?> manufacturer,
      Value<String?> model,
      Value<String?> serialNumber,
      Value<int?> yearManufactured,
      Value<DateTime?> installationDate,
      Value<String> condition,
      Value<String?> notes,
      Value<String?> mrid,
      Value<int?> catalogItemId,
      Value<double?> ratedCurrent,
      Value<double?> iTh,
      Value<double?> ipMax,
      Value<double?> tTh,
      Value<bool?> normalOpen,
      Value<bool?> retained,
      Value<String?> identifiedObjectDescription,
      Value<String?> nameplate,
      Value<String?> psrSubtype,
      Value<String?> installationDisplayName,
      Value<String?> tmCode,
      Value<String?> objectSubtype,
      Value<int?> poleCount,
      Value<String?> parentObjectRef,
      Value<String?> parentMainEquipmentPoleRef,
      Value<double?> nominalVoltageKv,
      Value<double?> nominalBreakingCurrentKa,
      Value<double?> ownTripTimeSec,
      Value<double?> emergencyCurrentA,
      Value<double?> continuousCurrentA,
      Value<String?> arresterType,
      Value<double?> xPosition,
      Value<double?> yPosition,
      Value<double?> directionAngle,
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
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get poleId => $composableBuilder(
    column: $table.poleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get equipmentType => $composableBuilder(
    column: $table.equipmentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defect => $composableBuilder(
    column: $table.defect,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get criticality => $composableBuilder(
    column: $table.criticality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defectAttachment => $composableBuilder(
    column: $table.defectAttachment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cardComment => $composableBuilder(
    column: $table.cardComment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cardCommentAttachment => $composableBuilder(
    column: $table.cardCommentAttachment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manufacturer => $composableBuilder(
    column: $table.manufacturer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serialNumber => $composableBuilder(
    column: $table.serialNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get yearManufactured => $composableBuilder(
    column: $table.yearManufactured,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get installationDate => $composableBuilder(
    column: $table.installationDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get condition => $composableBuilder(
    column: $table.condition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mrid => $composableBuilder(
    column: $table.mrid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get catalogItemId => $composableBuilder(
    column: $table.catalogItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ratedCurrent => $composableBuilder(
    column: $table.ratedCurrent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get iTh => $composableBuilder(
    column: $table.iTh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ipMax => $composableBuilder(
    column: $table.ipMax,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get tTh => $composableBuilder(
    column: $table.tTh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get normalOpen => $composableBuilder(
    column: $table.normalOpen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get retained => $composableBuilder(
    column: $table.retained,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get identifiedObjectDescription => $composableBuilder(
    column: $table.identifiedObjectDescription,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameplate => $composableBuilder(
    column: $table.nameplate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get psrSubtype => $composableBuilder(
    column: $table.psrSubtype,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get installationDisplayName => $composableBuilder(
    column: $table.installationDisplayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tmCode => $composableBuilder(
    column: $table.tmCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get objectSubtype => $composableBuilder(
    column: $table.objectSubtype,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get poleCount => $composableBuilder(
    column: $table.poleCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentObjectRef => $composableBuilder(
    column: $table.parentObjectRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentMainEquipmentPoleRef => $composableBuilder(
    column: $table.parentMainEquipmentPoleRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get nominalVoltageKv => $composableBuilder(
    column: $table.nominalVoltageKv,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get nominalBreakingCurrentKa => $composableBuilder(
    column: $table.nominalBreakingCurrentKa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ownTripTimeSec => $composableBuilder(
    column: $table.ownTripTimeSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get emergencyCurrentA => $composableBuilder(
    column: $table.emergencyCurrentA,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get continuousCurrentA => $composableBuilder(
    column: $table.continuousCurrentA,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get arresterType => $composableBuilder(
    column: $table.arresterType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get xPosition => $composableBuilder(
    column: $table.xPosition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get yPosition => $composableBuilder(
    column: $table.yPosition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get directionAngle => $composableBuilder(
    column: $table.directionAngle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isLocal => $composableBuilder(
    column: $table.isLocal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get needsSync => $composableBuilder(
    column: $table.needsSync,
    builder: (column) => ColumnFilters(column),
  );
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
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get poleId => $composableBuilder(
    column: $table.poleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get equipmentType => $composableBuilder(
    column: $table.equipmentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defect => $composableBuilder(
    column: $table.defect,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get criticality => $composableBuilder(
    column: $table.criticality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defectAttachment => $composableBuilder(
    column: $table.defectAttachment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cardComment => $composableBuilder(
    column: $table.cardComment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cardCommentAttachment => $composableBuilder(
    column: $table.cardCommentAttachment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manufacturer => $composableBuilder(
    column: $table.manufacturer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serialNumber => $composableBuilder(
    column: $table.serialNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get yearManufactured => $composableBuilder(
    column: $table.yearManufactured,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get installationDate => $composableBuilder(
    column: $table.installationDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get condition => $composableBuilder(
    column: $table.condition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mrid => $composableBuilder(
    column: $table.mrid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get catalogItemId => $composableBuilder(
    column: $table.catalogItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ratedCurrent => $composableBuilder(
    column: $table.ratedCurrent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get iTh => $composableBuilder(
    column: $table.iTh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ipMax => $composableBuilder(
    column: $table.ipMax,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get tTh => $composableBuilder(
    column: $table.tTh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get normalOpen => $composableBuilder(
    column: $table.normalOpen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get retained => $composableBuilder(
    column: $table.retained,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get identifiedObjectDescription => $composableBuilder(
    column: $table.identifiedObjectDescription,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameplate => $composableBuilder(
    column: $table.nameplate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get psrSubtype => $composableBuilder(
    column: $table.psrSubtype,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get installationDisplayName => $composableBuilder(
    column: $table.installationDisplayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tmCode => $composableBuilder(
    column: $table.tmCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get objectSubtype => $composableBuilder(
    column: $table.objectSubtype,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get poleCount => $composableBuilder(
    column: $table.poleCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentObjectRef => $composableBuilder(
    column: $table.parentObjectRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentMainEquipmentPoleRef => $composableBuilder(
    column: $table.parentMainEquipmentPoleRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get nominalVoltageKv => $composableBuilder(
    column: $table.nominalVoltageKv,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get nominalBreakingCurrentKa => $composableBuilder(
    column: $table.nominalBreakingCurrentKa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ownTripTimeSec => $composableBuilder(
    column: $table.ownTripTimeSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get emergencyCurrentA => $composableBuilder(
    column: $table.emergencyCurrentA,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get continuousCurrentA => $composableBuilder(
    column: $table.continuousCurrentA,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get arresterType => $composableBuilder(
    column: $table.arresterType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get xPosition => $composableBuilder(
    column: $table.xPosition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get yPosition => $composableBuilder(
    column: $table.yPosition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get directionAngle => $composableBuilder(
    column: $table.directionAngle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isLocal => $composableBuilder(
    column: $table.isLocal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get needsSync => $composableBuilder(
    column: $table.needsSync,
    builder: (column) => ColumnOrderings(column),
  );
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

  GeneratedColumn<int> get poleId =>
      $composableBuilder(column: $table.poleId, builder: (column) => column);

  GeneratedColumn<String> get equipmentType => $composableBuilder(
    column: $table.equipmentType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get defect =>
      $composableBuilder(column: $table.defect, builder: (column) => column);

  GeneratedColumn<String> get criticality => $composableBuilder(
    column: $table.criticality,
    builder: (column) => column,
  );

  GeneratedColumn<String> get defectAttachment => $composableBuilder(
    column: $table.defectAttachment,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cardComment => $composableBuilder(
    column: $table.cardComment,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cardCommentAttachment => $composableBuilder(
    column: $table.cardCommentAttachment,
    builder: (column) => column,
  );

  GeneratedColumn<String> get manufacturer => $composableBuilder(
    column: $table.manufacturer,
    builder: (column) => column,
  );

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get serialNumber => $composableBuilder(
    column: $table.serialNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get yearManufactured => $composableBuilder(
    column: $table.yearManufactured,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get installationDate => $composableBuilder(
    column: $table.installationDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get condition =>
      $composableBuilder(column: $table.condition, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get mrid =>
      $composableBuilder(column: $table.mrid, builder: (column) => column);

  GeneratedColumn<int> get catalogItemId => $composableBuilder(
    column: $table.catalogItemId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get ratedCurrent => $composableBuilder(
    column: $table.ratedCurrent,
    builder: (column) => column,
  );

  GeneratedColumn<double> get iTh =>
      $composableBuilder(column: $table.iTh, builder: (column) => column);

  GeneratedColumn<double> get ipMax =>
      $composableBuilder(column: $table.ipMax, builder: (column) => column);

  GeneratedColumn<double> get tTh =>
      $composableBuilder(column: $table.tTh, builder: (column) => column);

  GeneratedColumn<bool> get normalOpen => $composableBuilder(
    column: $table.normalOpen,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get retained =>
      $composableBuilder(column: $table.retained, builder: (column) => column);

  GeneratedColumn<String> get identifiedObjectDescription => $composableBuilder(
    column: $table.identifiedObjectDescription,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nameplate =>
      $composableBuilder(column: $table.nameplate, builder: (column) => column);

  GeneratedColumn<String> get psrSubtype => $composableBuilder(
    column: $table.psrSubtype,
    builder: (column) => column,
  );

  GeneratedColumn<String> get installationDisplayName => $composableBuilder(
    column: $table.installationDisplayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tmCode =>
      $composableBuilder(column: $table.tmCode, builder: (column) => column);

  GeneratedColumn<String> get objectSubtype => $composableBuilder(
    column: $table.objectSubtype,
    builder: (column) => column,
  );

  GeneratedColumn<int> get poleCount =>
      $composableBuilder(column: $table.poleCount, builder: (column) => column);

  GeneratedColumn<String> get parentObjectRef => $composableBuilder(
    column: $table.parentObjectRef,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentMainEquipmentPoleRef => $composableBuilder(
    column: $table.parentMainEquipmentPoleRef,
    builder: (column) => column,
  );

  GeneratedColumn<double> get nominalVoltageKv => $composableBuilder(
    column: $table.nominalVoltageKv,
    builder: (column) => column,
  );

  GeneratedColumn<double> get nominalBreakingCurrentKa => $composableBuilder(
    column: $table.nominalBreakingCurrentKa,
    builder: (column) => column,
  );

  GeneratedColumn<double> get ownTripTimeSec => $composableBuilder(
    column: $table.ownTripTimeSec,
    builder: (column) => column,
  );

  GeneratedColumn<double> get emergencyCurrentA => $composableBuilder(
    column: $table.emergencyCurrentA,
    builder: (column) => column,
  );

  GeneratedColumn<double> get continuousCurrentA => $composableBuilder(
    column: $table.continuousCurrentA,
    builder: (column) => column,
  );

  GeneratedColumn<String> get arresterType => $composableBuilder(
    column: $table.arresterType,
    builder: (column) => column,
  );

  GeneratedColumn<double> get xPosition =>
      $composableBuilder(column: $table.xPosition, builder: (column) => column);

  GeneratedColumn<double> get yPosition =>
      $composableBuilder(column: $table.yPosition, builder: (column) => column);

  GeneratedColumn<double> get directionAngle => $composableBuilder(
    column: $table.directionAngle,
    builder: (column) => column,
  );

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

class $$EquipmentTableTableManager
    extends
        RootTableManager<
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
            BaseReferences<_$AppDatabase, $EquipmentTable, EquipmentData>,
          ),
          EquipmentData,
          PrefetchHooks Function()
        > {
  $$EquipmentTableTableManager(_$AppDatabase db, $EquipmentTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EquipmentTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EquipmentTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EquipmentTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> poleId = const Value.absent(),
                Value<String> equipmentType = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<String?> defect = const Value.absent(),
                Value<String?> criticality = const Value.absent(),
                Value<String?> defectAttachment = const Value.absent(),
                Value<String?> cardComment = const Value.absent(),
                Value<String?> cardCommentAttachment = const Value.absent(),
                Value<String?> manufacturer = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<String?> serialNumber = const Value.absent(),
                Value<int?> yearManufactured = const Value.absent(),
                Value<DateTime?> installationDate = const Value.absent(),
                Value<String> condition = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> mrid = const Value.absent(),
                Value<int?> catalogItemId = const Value.absent(),
                Value<double?> ratedCurrent = const Value.absent(),
                Value<double?> iTh = const Value.absent(),
                Value<double?> ipMax = const Value.absent(),
                Value<double?> tTh = const Value.absent(),
                Value<bool?> normalOpen = const Value.absent(),
                Value<bool?> retained = const Value.absent(),
                Value<String?> identifiedObjectDescription =
                    const Value.absent(),
                Value<String?> nameplate = const Value.absent(),
                Value<String?> psrSubtype = const Value.absent(),
                Value<String?> installationDisplayName = const Value.absent(),
                Value<String?> tmCode = const Value.absent(),
                Value<String?> objectSubtype = const Value.absent(),
                Value<int?> poleCount = const Value.absent(),
                Value<String?> parentObjectRef = const Value.absent(),
                Value<String?> parentMainEquipmentPoleRef =
                    const Value.absent(),
                Value<double?> nominalVoltageKv = const Value.absent(),
                Value<double?> nominalBreakingCurrentKa = const Value.absent(),
                Value<double?> ownTripTimeSec = const Value.absent(),
                Value<double?> emergencyCurrentA = const Value.absent(),
                Value<double?> continuousCurrentA = const Value.absent(),
                Value<String?> arresterType = const Value.absent(),
                Value<double?> xPosition = const Value.absent(),
                Value<double?> yPosition = const Value.absent(),
                Value<double?> directionAngle = const Value.absent(),
                Value<int> createdBy = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<bool> isLocal = const Value.absent(),
                Value<bool> needsSync = const Value.absent(),
              }) => EquipmentCompanion(
                id: id,
                poleId: poleId,
                equipmentType: equipmentType,
                name: name,
                quantity: quantity,
                defect: defect,
                criticality: criticality,
                defectAttachment: defectAttachment,
                cardComment: cardComment,
                cardCommentAttachment: cardCommentAttachment,
                manufacturer: manufacturer,
                model: model,
                serialNumber: serialNumber,
                yearManufactured: yearManufactured,
                installationDate: installationDate,
                condition: condition,
                notes: notes,
                mrid: mrid,
                catalogItemId: catalogItemId,
                ratedCurrent: ratedCurrent,
                iTh: iTh,
                ipMax: ipMax,
                tTh: tTh,
                normalOpen: normalOpen,
                retained: retained,
                identifiedObjectDescription: identifiedObjectDescription,
                nameplate: nameplate,
                psrSubtype: psrSubtype,
                installationDisplayName: installationDisplayName,
                tmCode: tmCode,
                objectSubtype: objectSubtype,
                poleCount: poleCount,
                parentObjectRef: parentObjectRef,
                parentMainEquipmentPoleRef: parentMainEquipmentPoleRef,
                nominalVoltageKv: nominalVoltageKv,
                nominalBreakingCurrentKa: nominalBreakingCurrentKa,
                ownTripTimeSec: ownTripTimeSec,
                emergencyCurrentA: emergencyCurrentA,
                continuousCurrentA: continuousCurrentA,
                arresterType: arresterType,
                xPosition: xPosition,
                yPosition: yPosition,
                directionAngle: directionAngle,
                createdBy: createdBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isLocal: isLocal,
                needsSync: needsSync,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int poleId,
                required String equipmentType,
                required String name,
                Value<int> quantity = const Value.absent(),
                Value<String?> defect = const Value.absent(),
                Value<String?> criticality = const Value.absent(),
                Value<String?> defectAttachment = const Value.absent(),
                Value<String?> cardComment = const Value.absent(),
                Value<String?> cardCommentAttachment = const Value.absent(),
                Value<String?> manufacturer = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<String?> serialNumber = const Value.absent(),
                Value<int?> yearManufactured = const Value.absent(),
                Value<DateTime?> installationDate = const Value.absent(),
                required String condition,
                Value<String?> notes = const Value.absent(),
                Value<String?> mrid = const Value.absent(),
                Value<int?> catalogItemId = const Value.absent(),
                Value<double?> ratedCurrent = const Value.absent(),
                Value<double?> iTh = const Value.absent(),
                Value<double?> ipMax = const Value.absent(),
                Value<double?> tTh = const Value.absent(),
                Value<bool?> normalOpen = const Value.absent(),
                Value<bool?> retained = const Value.absent(),
                Value<String?> identifiedObjectDescription =
                    const Value.absent(),
                Value<String?> nameplate = const Value.absent(),
                Value<String?> psrSubtype = const Value.absent(),
                Value<String?> installationDisplayName = const Value.absent(),
                Value<String?> tmCode = const Value.absent(),
                Value<String?> objectSubtype = const Value.absent(),
                Value<int?> poleCount = const Value.absent(),
                Value<String?> parentObjectRef = const Value.absent(),
                Value<String?> parentMainEquipmentPoleRef =
                    const Value.absent(),
                Value<double?> nominalVoltageKv = const Value.absent(),
                Value<double?> nominalBreakingCurrentKa = const Value.absent(),
                Value<double?> ownTripTimeSec = const Value.absent(),
                Value<double?> emergencyCurrentA = const Value.absent(),
                Value<double?> continuousCurrentA = const Value.absent(),
                Value<String?> arresterType = const Value.absent(),
                Value<double?> xPosition = const Value.absent(),
                Value<double?> yPosition = const Value.absent(),
                Value<double?> directionAngle = const Value.absent(),
                required int createdBy,
                required DateTime createdAt,
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<bool> isLocal = const Value.absent(),
                Value<bool> needsSync = const Value.absent(),
              }) => EquipmentCompanion.insert(
                id: id,
                poleId: poleId,
                equipmentType: equipmentType,
                name: name,
                quantity: quantity,
                defect: defect,
                criticality: criticality,
                defectAttachment: defectAttachment,
                cardComment: cardComment,
                cardCommentAttachment: cardCommentAttachment,
                manufacturer: manufacturer,
                model: model,
                serialNumber: serialNumber,
                yearManufactured: yearManufactured,
                installationDate: installationDate,
                condition: condition,
                notes: notes,
                mrid: mrid,
                catalogItemId: catalogItemId,
                ratedCurrent: ratedCurrent,
                iTh: iTh,
                ipMax: ipMax,
                tTh: tTh,
                normalOpen: normalOpen,
                retained: retained,
                identifiedObjectDescription: identifiedObjectDescription,
                nameplate: nameplate,
                psrSubtype: psrSubtype,
                installationDisplayName: installationDisplayName,
                tmCode: tmCode,
                objectSubtype: objectSubtype,
                poleCount: poleCount,
                parentObjectRef: parentObjectRef,
                parentMainEquipmentPoleRef: parentMainEquipmentPoleRef,
                nominalVoltageKv: nominalVoltageKv,
                nominalBreakingCurrentKa: nominalBreakingCurrentKa,
                ownTripTimeSec: ownTripTimeSec,
                emergencyCurrentA: emergencyCurrentA,
                continuousCurrentA: continuousCurrentA,
                arresterType: arresterType,
                xPosition: xPosition,
                yPosition: yPosition,
                directionAngle: directionAngle,
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
        ),
      );
}

typedef $$EquipmentTableProcessedTableManager =
    ProcessedTableManager<
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
        BaseReferences<_$AppDatabase, $EquipmentTable, EquipmentData>,
      ),
      EquipmentData,
      PrefetchHooks Function()
    >;
typedef $$SyncRecordsTableCreateCompanionBuilder =
    SyncRecordsCompanion Function({
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
typedef $$SyncRecordsTableUpdateCompanionBuilder =
    SyncRecordsCompanion Function({
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
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );
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
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );
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
    column: $table.entityType,
    builder: (column) => column,
  );

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
    column: $table.errorMessage,
    builder: (column) => column,
  );
}

class $$SyncRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncRecordsTable,
          SyncRecord,
          $$SyncRecordsTableFilterComposer,
          $$SyncRecordsTableOrderingComposer,
          $$SyncRecordsTableAnnotationComposer,
          $$SyncRecordsTableCreateCompanionBuilder,
          $$SyncRecordsTableUpdateCompanionBuilder,
          (
            SyncRecord,
            BaseReferences<_$AppDatabase, $SyncRecordsTable, SyncRecord>,
          ),
          SyncRecord,
          PrefetchHooks Function()
        > {
  $$SyncRecordsTableTableManager(_$AppDatabase db, $SyncRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
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
              }) => SyncRecordsCompanion(
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
          createCompanionCallback:
              ({
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
              }) => SyncRecordsCompanion.insert(
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
        ),
      );
}

typedef $$SyncRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncRecordsTable,
      SyncRecord,
      $$SyncRecordsTableFilterComposer,
      $$SyncRecordsTableOrderingComposer,
      $$SyncRecordsTableAnnotationComposer,
      $$SyncRecordsTableCreateCompanionBuilder,
      $$SyncRecordsTableUpdateCompanionBuilder,
      (
        SyncRecord,
        BaseReferences<_$AppDatabase, $SyncRecordsTable, SyncRecord>,
      ),
      SyncRecord,
      PrefetchHooks Function()
    >;
typedef $$PatrolSessionsTableCreateCompanionBuilder =
    PatrolSessionsCompanion Function({
      Value<int> id,
      Value<int?> serverId,
      required int lineId,
      Value<String?> note,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      Value<String> syncStatus,
      Value<int?> userId,
    });
typedef $$PatrolSessionsTableUpdateCompanionBuilder =
    PatrolSessionsCompanion Function({
      Value<int> id,
      Value<int?> serverId,
      Value<int> lineId,
      Value<String?> note,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<String> syncStatus,
      Value<int?> userId,
    });

class $$PatrolSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $PatrolSessionsTable> {
  $$PatrolSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lineId => $composableBuilder(
    column: $table.lineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PatrolSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PatrolSessionsTable> {
  $$PatrolSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lineId => $composableBuilder(
    column: $table.lineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PatrolSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PatrolSessionsTable> {
  $$PatrolSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<int> get lineId =>
      $composableBuilder(column: $table.lineId, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);
}

class $$PatrolSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PatrolSessionsTable,
          PatrolSession,
          $$PatrolSessionsTableFilterComposer,
          $$PatrolSessionsTableOrderingComposer,
          $$PatrolSessionsTableAnnotationComposer,
          $$PatrolSessionsTableCreateCompanionBuilder,
          $$PatrolSessionsTableUpdateCompanionBuilder,
          (
            PatrolSession,
            BaseReferences<_$AppDatabase, $PatrolSessionsTable, PatrolSession>,
          ),
          PatrolSession,
          PrefetchHooks Function()
        > {
  $$PatrolSessionsTableTableManager(
    _$AppDatabase db,
    $PatrolSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PatrolSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PatrolSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PatrolSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<int> lineId = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int?> userId = const Value.absent(),
              }) => PatrolSessionsCompanion(
                id: id,
                serverId: serverId,
                lineId: lineId,
                note: note,
                startedAt: startedAt,
                endedAt: endedAt,
                syncStatus: syncStatus,
                userId: userId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                required int lineId,
                Value<String?> note = const Value.absent(),
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int?> userId = const Value.absent(),
              }) => PatrolSessionsCompanion.insert(
                id: id,
                serverId: serverId,
                lineId: lineId,
                note: note,
                startedAt: startedAt,
                endedAt: endedAt,
                syncStatus: syncStatus,
                userId: userId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PatrolSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PatrolSessionsTable,
      PatrolSession,
      $$PatrolSessionsTableFilterComposer,
      $$PatrolSessionsTableOrderingComposer,
      $$PatrolSessionsTableAnnotationComposer,
      $$PatrolSessionsTableCreateCompanionBuilder,
      $$PatrolSessionsTableUpdateCompanionBuilder,
      (
        PatrolSession,
        BaseReferences<_$AppDatabase, $PatrolSessionsTable, PatrolSession>,
      ),
      PatrolSession,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PowerLinesTableTableManager get powerLines =>
      $$PowerLinesTableTableManager(_db, _db.powerLines);
  $$PolesTableTableManager get poles =>
      $$PolesTableTableManager(_db, _db.poles);
  $$EquipmentTableTableManager get equipment =>
      $$EquipmentTableTableManager(_db, _db.equipment);
  $$SyncRecordsTableTableManager get syncRecords =>
      $$SyncRecordsTableTableManager(_db, _db.syncRecords);
  $$PatrolSessionsTableTableManager get patrolSessions =>
      $$PatrolSessionsTableTableManager(_db, _db.patrolSessions);
}
