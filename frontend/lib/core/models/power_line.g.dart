// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'power_line.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PowerLine _$PowerLineFromJson(Map<String, dynamic> json) => PowerLine(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      code: json['code'] as String,
      voltageLevel: (json['voltageLevel'] as num).toDouble(),
      length: (json['length'] as num?)?.toDouble(),
      branchId: (json['branchId'] as num).toInt(),
      createdBy: (json['createdBy'] as num).toInt(),
      status: json['status'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      towers: (json['towers'] as List<dynamic>?)
          ?.map((e) => Tower.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$PowerLineToJson(PowerLine instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'code': instance.code,
      'voltageLevel': instance.voltageLevel,
      'length': instance.length,
      'branchId': instance.branchId,
      'createdBy': instance.createdBy,
      'status': instance.status,
      'description': instance.description,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'towers': instance.towers,
    };

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

Tower _$TowerFromJson(Map<String, dynamic> json) => Tower(
      id: (json['id'] as num).toInt(),
      powerLineId: (json['powerLineId'] as num).toInt(),
      towerNumber: json['towerNumber'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      towerType: json['towerType'] as String,
      height: (json['height'] as num?)?.toDouble(),
      foundationType: json['foundationType'] as String?,
      material: json['material'] as String?,
      yearInstalled: (json['yearInstalled'] as num?)?.toInt(),
      condition: json['condition'] as String,
      notes: json['notes'] as String?,
      createdBy: (json['createdBy'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      equipment: (json['equipment'] as List<dynamic>?)
          ?.map((e) => Equipment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$TowerToJson(Tower instance) => <String, dynamic>{
      'id': instance.id,
      'powerLineId': instance.powerLineId,
      'towerNumber': instance.towerNumber,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'towerType': instance.towerType,
      'height': instance.height,
      'foundationType': instance.foundationType,
      'material': instance.material,
      'yearInstalled': instance.yearInstalled,
      'condition': instance.condition,
      'notes': instance.notes,
      'createdBy': instance.createdBy,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'equipment': instance.equipment,
    };

TowerCreate _$TowerCreateFromJson(Map<String, dynamic> json) => TowerCreate(
      towerNumber: json['towerNumber'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      towerType: json['towerType'] as String,
      height: (json['height'] as num?)?.toDouble(),
      foundationType: json['foundationType'] as String?,
      material: json['material'] as String?,
      yearInstalled: (json['yearInstalled'] as num?)?.toInt(),
      condition: json['condition'] as String? ?? 'good',
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$TowerCreateToJson(TowerCreate instance) =>
    <String, dynamic>{
      'towerNumber': instance.towerNumber,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'towerType': instance.towerType,
      'height': instance.height,
      'foundationType': instance.foundationType,
      'material': instance.material,
      'yearInstalled': instance.yearInstalled,
      'condition': instance.condition,
      'notes': instance.notes,
    };

Equipment _$EquipmentFromJson(Map<String, dynamic> json) => Equipment(
      id: (json['id'] as num).toInt(),
      towerId: (json['towerId'] as num).toInt(),
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
      'towerId': instance.towerId,
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
