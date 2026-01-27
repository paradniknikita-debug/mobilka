// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'power_line.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PowerLine _$PowerLineFromJson(Map<String, dynamic> json) => PowerLine(
      id: (json['id'] as num).toInt(),
      name: _stringFromJson(json['name']),
      code: _stringFromJson(json['code']),
      voltageLevel: _doubleFromJsonNullable(json['voltage_level']),
      length: _doubleFromJsonNullable(json['length']),
      branchId: _intFromJsonNullable(json['branch_id']),
      createdBy: (json['created_by'] as num).toInt(),
      status:
          json['status'] == null ? 'active' : _stringFromJson(json['status']),
      description: json['description'] as String?,
      createdAt: _dateTimeFromJson(json['created_at']),
      updatedAt: _dateTimeFromJsonNullable(json['updated_at']),
      poles: (json['poles'] as List<dynamic>?)
          ?.map((e) => Pole.fromJson(e as Map<String, dynamic>))
          .toList(),
      aclineSegments: json['acline_segments'] as List<dynamic>?,
    );

Map<String, dynamic> _$PowerLineToJson(PowerLine instance) {
  final val = <String, dynamic>{
    'id': instance.id,
    'name': instance.name,
    'code': instance.code,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('voltage_level', instance.voltageLevel);
  writeNotNull('length', instance.length);
  writeNotNull('branch_id', instance.branchId);
  val['created_by'] = instance.createdBy;
  val['status'] = instance.status;
  writeNotNull('description', instance.description);
  val['created_at'] = instance.createdAt.toIso8601String();
  writeNotNull('updated_at', instance.updatedAt?.toIso8601String());
  writeNotNull('poles', instance.poles?.map((e) => e.toJson()).toList());
  writeNotNull('acline_segments', instance.aclineSegments);
  return val;
}

PowerLineCreate _$PowerLineCreateFromJson(Map<String, dynamic> json) =>
    PowerLineCreate(
      name: json['name'] as String,
      code: json['code'] as String,
      voltageLevel: (json['voltageLevel'] as num).toDouble(),
      length: (json['length'] as num?)?.toDouble(),
      branchId: (json['branchId'] as num).toInt(),
      status: json['status'] as String? ?? 'active',
      description: json['description'] as String?,
    );

Map<String, dynamic> _$PowerLineCreateToJson(PowerLineCreate instance) =>
    <String, dynamic>{
      'name': instance.name,
      'code': instance.code,
      'voltageLevel': instance.voltageLevel,
      'length': instance.length,
      'branchId': instance.branchId,
      'status': instance.status,
      'description': instance.description,
    };

Pole _$PoleFromJson(Map<String, dynamic> json) => Pole(
      id: (json['id'] as num).toInt(),
      powerLineId: (json['power_line_id'] as num).toInt(),
      poleNumber: _stringFromJson(json['pole_number']),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      poleType: _stringFromJson(json['pole_type']),
      height: _doubleFromJsonNullable(json['height']),
      foundationType: json['foundation_type'] as String?,
      material: json['material'] as String?,
      yearInstalled: _intFromJsonNullable(json['year_installed']),
      condition: json['condition'] == null
          ? 'good'
          : _stringFromJson(json['condition']),
      notes: json['notes'] as String?,
      createdBy: (json['created_by'] as num).toInt(),
      createdAt: _dateTimeFromJson(json['created_at']),
      updatedAt: _dateTimeFromJsonNullable(json['updated_at']),
      equipment: (json['equipment'] as List<dynamic>?)
          ?.map((e) => Equipment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$PoleToJson(Pole instance) {
  final val = <String, dynamic>{
    'id': instance.id,
    'power_line_id': instance.powerLineId,
    'pole_number': instance.poleNumber,
    'latitude': instance.latitude,
    'longitude': instance.longitude,
    'pole_type': instance.poleType,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('height', instance.height);
  writeNotNull('foundation_type', instance.foundationType);
  writeNotNull('material', instance.material);
  writeNotNull('year_installed', instance.yearInstalled);
  val['condition'] = instance.condition;
  writeNotNull('notes', instance.notes);
  val['created_by'] = instance.createdBy;
  val['created_at'] = instance.createdAt.toIso8601String();
  writeNotNull('updated_at', instance.updatedAt?.toIso8601String());
  writeNotNull(
      'equipment', instance.equipment?.map((e) => e.toJson()).toList());
  return val;
}

PoleCreate _$PoleCreateFromJson(Map<String, dynamic> json) => PoleCreate(
      poleNumber: json['pole_number'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      poleType: json['pole_type'] as String,
      height: (json['height'] as num?)?.toDouble(),
      foundationType: json['foundation_type'] as String?,
      material: json['material'] as String?,
      yearInstalled: (json['year_installed'] as num?)?.toInt(),
      condition: json['condition'] as String? ?? 'good',
      notes: json['notes'] as String?,
      isTap: json['is_tap'] as bool? ?? false,
      conductorType: json['conductor_type'] as String?,
      conductorMaterial: json['conductor_material'] as String?,
      conductorSection: json['conductor_section'] as String?,
    );

Map<String, dynamic> _$PoleCreateToJson(PoleCreate instance) {
  final val = <String, dynamic>{
    'pole_number': instance.poleNumber,
    'latitude': instance.latitude,
    'longitude': instance.longitude,
    'pole_type': instance.poleType,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('height', instance.height);
  writeNotNull('foundation_type', instance.foundationType);
  writeNotNull('material', instance.material);
  writeNotNull('year_installed', instance.yearInstalled);
  val['condition'] = instance.condition;
  writeNotNull('notes', instance.notes);
  val['is_tap'] = instance.isTap;
  writeNotNull('conductor_type', instance.conductorType);
  writeNotNull('conductor_material', instance.conductorMaterial);
  writeNotNull('conductor_section', instance.conductorSection);
  return val;
}

Equipment _$EquipmentFromJson(Map<String, dynamic> json) => Equipment(
      id: (json['id'] as num).toInt(),
      poleId: (json['poleId'] as num).toInt(),
      equipmentType: json['equipmentType'] as String,
      name: json['name'] as String,
      manufacturer: json['manufacturer'] as String?,
      model: json['model'] as String?,
      serialNumber: json['serialNumber'] as String?,
      yearManufactured: (json['yearManufactured'] as num?)?.toInt(),
      installationDate: json['installationDate'] == null
          ? null
          : DateTime.parse(json['installationDate'] as String),
      condition: json['condition'] as String,
      notes: json['notes'] as String?,
      createdBy: (json['createdBy'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$EquipmentToJson(Equipment instance) => <String, dynamic>{
      'id': instance.id,
      'poleId': instance.poleId,
      'equipmentType': instance.equipmentType,
      'name': instance.name,
      'manufacturer': instance.manufacturer,
      'model': instance.model,
      'serialNumber': instance.serialNumber,
      'yearManufactured': instance.yearManufactured,
      'installationDate': instance.installationDate?.toIso8601String(),
      'condition': instance.condition,
      'notes': instance.notes,
      'createdBy': instance.createdBy,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

EquipmentCreate _$EquipmentCreateFromJson(Map<String, dynamic> json) =>
    EquipmentCreate(
      equipmentType: json['equipmentType'] as String,
      name: json['name'] as String,
      manufacturer: json['manufacturer'] as String?,
      model: json['model'] as String?,
      serialNumber: json['serialNumber'] as String?,
      yearManufactured: (json['yearManufactured'] as num?)?.toInt(),
      installationDate: json['installationDate'] == null
          ? null
          : DateTime.parse(json['installationDate'] as String),
      condition: json['condition'] as String? ?? 'good',
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$EquipmentCreateToJson(EquipmentCreate instance) =>
    <String, dynamic>{
      'equipmentType': instance.equipmentType,
      'name': instance.name,
      'manufacturer': instance.manufacturer,
      'model': instance.model,
      'serialNumber': instance.serialNumber,
      'yearManufactured': instance.yearManufactured,
      'installationDate': instance.installationDate?.toIso8601String(),
      'condition': instance.condition,
      'notes': instance.notes,
    };
