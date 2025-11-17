import 'package:json_annotation/json_annotation.dart';

part 'power_line.g.dart';

@JsonSerializable()
class PowerLine {
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
  final List<Tower>? towers;

  const PowerLine({
    required this.id,
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
    this.towers,
  });

  factory PowerLine.fromJson(Map<String, dynamic> json) => _$PowerLineFromJson(json);
  Map<String, dynamic> toJson() => _$PowerLineToJson(this);

  PowerLine copyWith({
    int? id,
    String? name,
    String? code,
    double? voltageLevel,
    double? length,
    int? branchId,
    int? createdBy,
    String? status,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Tower>? towers,
  }) {
    return PowerLine(
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
      towers: towers ?? this.towers,
    );
  }
}

@JsonSerializable()
class PowerLineCreate {
  final String name;
  final String code;
  final double voltageLevel;
  final double? length;
  final int branchId;
  final String status;
  final String? description;

  const PowerLineCreate({
    required this.name,
    required this.code,
    required this.voltageLevel,
    this.length,
    required this.branchId,
    this.status = 'active',
    this.description,
  });

  factory PowerLineCreate.fromJson(Map<String, dynamic> json) => _$PowerLineCreateFromJson(json);
  Map<String, dynamic> toJson() => _$PowerLineCreateToJson(this);
}

@JsonSerializable()
class Tower {
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
  final List<Equipment>? equipment;

  const Tower({
    required this.id,
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
    this.equipment,
  });

  factory Tower.fromJson(Map<String, dynamic> json) => _$TowerFromJson(json);
  Map<String, dynamic> toJson() => _$TowerToJson(this);

  Tower copyWith({
    int? id,
    int? powerLineId,
    String? towerNumber,
    double? latitude,
    double? longitude,
    String? towerType,
    double? height,
    String? foundationType,
    String? material,
    int? yearInstalled,
    String? condition,
    String? notes,
    int? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Equipment>? equipment,
  }) {
    return Tower(
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
      equipment: equipment ?? this.equipment,
    );
  }
}

@JsonSerializable()
class TowerCreate {
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

  const TowerCreate({
    required this.towerNumber,
    required this.latitude,
    required this.longitude,
    required this.towerType,
    this.height,
    this.foundationType,
    this.material,
    this.yearInstalled,
    this.condition = 'good',
    this.notes,
  });

  factory TowerCreate.fromJson(Map<String, dynamic> json) => _$TowerCreateFromJson(json);
  Map<String, dynamic> toJson() => _$TowerCreateToJson(this);
}

@JsonSerializable()
class Equipment {
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

  const Equipment({
    required this.id,
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
  });

  factory Equipment.fromJson(Map<String, dynamic> json) => _$EquipmentFromJson(json);
  Map<String, dynamic> toJson() => _$EquipmentToJson(this);

  Equipment copyWith({
    int? id,
    int? towerId,
    String? equipmentType,
    String? name,
    String? manufacturer,
    String? model,
    String? serialNumber,
    int? yearManufactured,
    DateTime? installationDate,
    String? condition,
    String? notes,
    int? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Equipment(
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
    );
  }
}

@JsonSerializable()
class EquipmentCreate {
  final String equipmentType;
  final String name;
  final String? manufacturer;
  final String? model;
  final String? serialNumber;
  final int? yearManufactured;
  final DateTime? installationDate;
  final String condition;
  final String? notes;

  const EquipmentCreate({
    required this.equipmentType,
    required this.name,
    this.manufacturer,
    this.model,
    this.serialNumber,
    this.yearManufactured,
    this.installationDate,
    this.condition = 'good',
    this.notes,
  });

  factory EquipmentCreate.fromJson(Map<String, dynamic> json) => _$EquipmentCreateFromJson(json);
  Map<String, dynamic> toJson() => _$EquipmentCreateToJson(this);
}
