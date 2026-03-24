// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'power_line.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PowerLine _$PowerLineFromJson(Map<String, dynamic> json) => PowerLine(
  id: (json['id'] as num).toInt(),
  name: _stringFromJson(json['name']),
  mrid: json['mrid'] as String?,
  voltageLevel: _doubleFromJsonNullable(json['voltage_level']),
  length: _doubleFromJsonNullable(json['length']),
  branchId: _intFromJsonNullable(json['branch_id']),
  createdBy: (json['created_by'] as num).toInt(),
  status: json['status'] == null ? 'active' : _stringFromJson(json['status']),
  description: json['description'] as String?,
  createdAt: _dateTimeFromJson(json['created_at']),
  updatedAt: _dateTimeFromJsonNullable(json['updated_at']),
  poles: (json['poles'] as List<dynamic>?)
      ?.map((e) => Pole.fromJson(e as Map<String, dynamic>))
      .toList(),
  aclineSegments: json['acline_segments'] as List<dynamic>?,
);

Map<String, dynamic> _$PowerLineToJson(PowerLine instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'mrid': ?instance.mrid,
  'voltage_level': ?instance.voltageLevel,
  'length': ?instance.length,
  'branch_id': ?instance.branchId,
  'created_by': instance.createdBy,
  'status': instance.status,
  'description': ?instance.description,
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': ?instance.updatedAt?.toIso8601String(),
  'poles': ?instance.poles?.map((e) => e.toJson()).toList(),
  'acline_segments': ?instance.aclineSegments,
};

PowerLineCreate _$PowerLineCreateFromJson(Map<String, dynamic> json) =>
    PowerLineCreate(
      name: json['name'] as String,
      voltageLevel: (json['voltage_level'] as num).toDouble(),
      length: (json['length'] as num?)?.toDouble(),
      branchId: (json['branch_id'] as num).toInt(),
      status: json['status'] as String? ?? 'active',
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
  id: (json['id'] as num).toInt(),
  lineId: (json['line_id'] as num).toInt(),
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
  isTapPole: json['is_tap_pole'] as bool? ?? false,
  branchType: json['branch_type'] as String?,
  tapPoleId: (json['tap_pole_id'] as num?)?.toInt(),
  tapBranchIndex: (json['tap_branch_index'] as num?)?.toInt(),
  condition: json['condition'] == null
      ? 'good'
      : _stringFromJson(json['condition']),
  notes: json['notes'] as String?,
  cardComment: json['card_comment'] as String?,
  cardCommentAttachment: json['card_comment_attachment'] as String?,
  createdBy: (json['created_by'] as num).toInt(),
  createdAt: _dateTimeFromJson(json['created_at']),
  updatedAt: _dateTimeFromJsonNullable(json['updated_at']),
  equipment: (json['equipment'] as List<dynamic>?)
      ?.map((e) => Equipment.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$PoleToJson(Pole instance) => <String, dynamic>{
  'id': instance.id,
  'line_id': instance.lineId,
  'pole_number': instance.poleNumber,
  'x_position': instance.xPosition,
  'y_position': instance.yPosition,
  'pole_type': instance.poleType,
  'height': ?instance.height,
  'foundation_type': ?instance.foundationType,
  'material': ?instance.material,
  'year_installed': ?instance.yearInstalled,
  'conductor_type': ?instance.conductorType,
  'conductor_material': ?instance.conductorMaterial,
  'conductor_section': ?instance.conductorSection,
  'sequence_number': ?instance.sequenceNumber,
  'is_tap_pole': instance.isTapPole,
  'branch_type': ?instance.branchType,
  'tap_pole_id': ?instance.tapPoleId,
  'tap_branch_index': ?instance.tapBranchIndex,
  'condition': instance.condition,
  'notes': ?instance.notes,
  'card_comment': ?instance.cardComment,
  'card_comment_attachment': ?instance.cardCommentAttachment,
  'created_by': instance.createdBy,
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': ?instance.updatedAt?.toIso8601String(),
  'equipment': ?instance.equipment?.map((e) => e.toJson()).toList(),
};

PoleCreate _$PoleCreateFromJson(Map<String, dynamic> json) => PoleCreate(
  poleNumber: json['pole_number'] as String,
  xPosition: _doubleFromJson(json['x_position']),
  yPosition: _doubleFromJson(json['y_position']),
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
  cardComment: json['card_comment'] as String?,
  cardCommentAttachment: json['card_comment_attachment'] as String?,
  tapPoleId: (json['tap_pole_id'] as num?)?.toInt(),
  branchType: json['branch_type'] as String?,
  tapBranchIndex: (json['tap_branch_index'] as num?)?.toInt(),
  startNewTap: json['start_new_tap'] as bool? ?? false,
);

Map<String, dynamic> _$PoleCreateToJson(PoleCreate instance) =>
    <String, dynamic>{
      'pole_number': instance.poleNumber,
      'x_position': instance.xPosition,
      'y_position': instance.yPosition,
      'pole_type': instance.poleType,
      'height': ?instance.height,
      'foundation_type': ?instance.foundationType,
      'material': ?instance.material,
      'year_installed': ?instance.yearInstalled,
      'condition': instance.condition,
      'notes': ?instance.notes,
      'is_tap': instance.isTap,
      'conductor_type': ?instance.conductorType,
      'conductor_material': ?instance.conductorMaterial,
      'conductor_section': ?instance.conductorSection,
      'card_comment': ?instance.cardComment,
      'card_comment_attachment': ?instance.cardCommentAttachment,
      'tap_pole_id': ?instance.tapPoleId,
      'branch_type': ?instance.branchType,
      'tap_branch_index': ?instance.tapBranchIndex,
      'start_new_tap': instance.startNewTap,
    };

Equipment _$EquipmentFromJson(Map<String, dynamic> json) => Equipment(
  id: _intFromJson(json['id']),
  poleId: _intFromJson(json['pole_id']),
  equipmentType: _stringFromJson(json['equipment_type']),
  name: _stringFromJson(json['name']),
  manufacturer: json['manufacturer'] as String?,
  model: json['model'] as String?,
  serialNumber: json['serial_number'] as String?,
  yearManufactured: _intFromJsonNullable(json['year_manufactured']),
  installationDate: _dateTimeFromJsonNullable(json['installation_date']),
  condition: json['condition'] == null
      ? 'good'
      : _stringFromJson(json['condition']),
  notes: json['notes'] as String?,
  createdBy: _intFromJson(json['created_by']),
  createdAt: _dateTimeFromJson(json['created_at']),
  updatedAt: _dateTimeFromJsonNullable(json['updated_at']),
);

Map<String, dynamic> _$EquipmentToJson(Equipment instance) => <String, dynamic>{
  'id': instance.id,
  'pole_id': instance.poleId,
  'equipment_type': instance.equipmentType,
  'name': instance.name,
  'manufacturer': instance.manufacturer,
  'model': instance.model,
  'serial_number': instance.serialNumber,
  'year_manufactured': instance.yearManufactured,
  'installation_date': instance.installationDate?.toIso8601String(),
  'condition': instance.condition,
  'notes': instance.notes,
  'created_by': instance.createdBy,
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};

EquipmentCreate _$EquipmentCreateFromJson(Map<String, dynamic> json) =>
    EquipmentCreate(
      equipmentType: json['equipment_type'] as String,
      name: json['name'] as String,
      manufacturer: json['manufacturer'] as String?,
      model: json['model'] as String?,
      serialNumber: json['serial_number'] as String?,
      yearManufactured: (json['year_manufactured'] as num?)?.toInt(),
      installationDate: json['installation_date'] == null
          ? null
          : DateTime.parse(json['installation_date'] as String),
      condition: json['condition'] as String? ?? 'good',
      notes: json['notes'] as String?,
      defect: json['defect'] as String?,
      criticality: json['criticality'] as String?,
    );

Map<String, dynamic> _$EquipmentCreateToJson(EquipmentCreate instance) =>
    <String, dynamic>{
      'equipment_type': instance.equipmentType,
      'name': instance.name,
      'manufacturer': instance.manufacturer,
      'model': instance.model,
      'serial_number': instance.serialNumber,
      'year_manufactured': instance.yearManufactured,
      'installation_date': instance.installationDate?.toIso8601String(),
      'condition': instance.condition,
      'notes': instance.notes,
      'defect': instance.defect,
      'criticality': instance.criticality,
    };
