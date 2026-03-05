// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'power_line.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PowerLine _$PowerLineFromJson(Map<String, dynamic> json) => PowerLine(
      id: _intFromJson(json['id']),
      name: _stringFromJson(json['name']),
      mrid: json['mrid'] as String?,
      voltageLevel: _doubleFromJsonNullable(json['voltage_level']),
      length: _doubleFromJsonNullable(json['length']),
      branchId: _intFromJsonNullable(json['branch_id']),
      createdBy: _intFromJson(json['created_by']),
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
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('mrid', instance.mrid);
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
      name: _stringFromJson(json['name']),
      voltageLevel: _doubleFromJson(json['voltage_level']),
      length: _doubleFromJsonNullable(json['length']),
      branchId: _intFromJson(json['branch_id']),
      status: _stringFromJson(json['status'] ?? 'active'),
      description: json['description'] as String?,
    );

Map<String, dynamic> _$PowerLineCreateToJson(PowerLineCreate instance) =>
    <String, dynamic>{
      'name': instance.name,
      'voltage_level': instance.voltageLevel,
      'length': instance.length,
      'branch_id': instance.branchId,
      'status': instance.status,
      'description': instance.description,
    };

Pole _$PoleFromJson(Map<String, dynamic> json) => Pole(
      id: _intFromJson(json['id']),
      powerLineId: _intFromJson(json['power_line_id']),
      poleNumber: _stringFromJson(json['pole_number']),
      xPosition: _doubleFromJson(json['x_position']),
      yPosition: _doubleFromJson(json['y_position']),
      poleType: _stringFromJson(json['pole_type']),
      height: _doubleFromJsonNullable(json['height']),
      foundationType: json['foundation_type'] as String?,
      material: json['material'] as String?,
      yearInstalled: _intFromJsonNullable(json['year_installed']),
      conductorType: json['conductor_type'] as String?,
      conductorMaterial: json['conductor_material'] as String?,
      conductorSection: json['conductor_section'] as String?,
      sequenceNumber: _intFromJsonNullable(json['sequence_number']),
      isTapPole: json['is_tap_pole'] == true,
      condition: json['condition'] == null
          ? 'good'
          : _stringFromJson(json['condition']),
      notes: json['notes'] as String?,
      createdBy: _intFromJson(json['created_by']),
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
    'x_position': instance.xPosition,
    'y_position': instance.yPosition,
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
  writeNotNull('conductor_type', instance.conductorType);
  writeNotNull('conductor_material', instance.conductorMaterial);
  writeNotNull('conductor_section', instance.conductorSection);
  writeNotNull('sequence_number', instance.sequenceNumber);
  val['is_tap_pole'] = instance.isTapPole;
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
      poleNumber: _stringFromJson(json['pole_number']),
      xPosition: _doubleFromJson(json['x_position']),
      yPosition: _doubleFromJson(json['y_position']),
      poleType: _stringFromJson(json['pole_type']),
      height: _doubleFromJsonNullable(json['height']),
      foundationType: json['foundation_type'] as String?,
      material: json['material'] as String?,
      yearInstalled: _intFromJsonNullable(json['year_installed']),
      condition: _stringFromJson(json['condition'] ?? 'good'),
      notes: json['notes'] as String?,
      isTap: json['is_tap'] == true,
      conductorType: json['conductor_type'] as String?,
      conductorMaterial: json['conductor_material'] as String?,
      conductorSection: json['conductor_section'] as String?,
    );

Map<String, dynamic> _$PoleCreateToJson(PoleCreate instance) {
  final val = <String, dynamic>{
    'pole_number': instance.poleNumber,
    'x_position': instance.xPosition,
    'y_position': instance.yPosition,
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
      id: _intFromJson(json['id']),
      poleId: _intFromJson(json['pole_id'] ?? json['poleId']),
      equipmentType: _stringFromJson(json['equipment_type'] ?? json['equipmentType']),
      name: _stringFromJson(json['name']),
      manufacturer: json['manufacturer'] as String?,
      model: json['model'] as String?,
      serialNumber: json['serial_number'] as String? ?? json['serialNumber'] as String?,
      yearManufactured: _intFromJsonNullable(json['year_manufactured'] ?? json['yearManufactured']),
      installationDate: json['installation_date'] == null && json['installationDate'] == null
          ? null
          : _dateTimeFromJsonNullable(json['installation_date'] ?? json['installationDate']),
      condition: _stringFromJson(json['condition'] ?? 'good'),
      notes: json['notes'] as String?,
      createdBy: _intFromJson(json['created_by'] ?? json['createdBy']),
      createdAt: _dateTimeFromJson(json['created_at'] ?? json['createdAt']),
      updatedAt: _dateTimeFromJsonNullable(json['updated_at'] ?? json['updatedAt']),
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
      equipmentType: _stringFromJson(json['equipment_type'] ?? json['equipmentType']),
      name: _stringFromJson(json['name']),
      manufacturer: json['manufacturer'] as String?,
      model: json['model'] as String?,
      serialNumber: json['serial_number'] as String? ?? json['serialNumber'] as String?,
      yearManufactured: _intFromJsonNullable(json['year_manufactured'] ?? json['yearManufactured']),
      installationDate: json['installation_date'] == null && json['installationDate'] == null
          ? null
          : _dateTimeFromJsonNullable(json['installation_date'] ?? json['installationDate']),
      condition: _stringFromJson(json['condition'] ?? 'good'),
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
