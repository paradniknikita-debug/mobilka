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
  final List<Pole>? poles;

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
    this.poles,
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
    List<Pole>? poles,
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
      poles: poles ?? this.poles,
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
class Pole {
  final int id;
  final int powerLineId;
  final String poleNumber;
  final double latitude;
  final double longitude;
  final String poleType;
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

  const Pole({
    required this.id,
    required this.powerLineId,
    required this.poleNumber,
    required this.latitude,
    required this.longitude,
    required this.poleType,
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

  factory Pole.fromJson(Map<String, dynamic> json) => _$PoleFromJson(json);
  Map<String, dynamic> toJson() => _$PoleToJson(this);

  Pole copyWith({
    int? id,
    int? powerLineId,
    String? poleNumber,
    double? latitude,
    double? longitude,
    String? poleType,
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
    return Pole(
      id: id ?? this.id,
      powerLineId: powerLineId ?? this.powerLineId,
      poleNumber: poleNumber ?? this.poleNumber,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      poleType: poleType ?? this.poleType,
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
class PoleCreate {
  final String poleNumber;
  final double latitude;
  final double longitude;
  final String poleType;
  final double? height;
  final String? foundationType;
  final String? material;
  final int? yearInstalled;
  final String condition;
  final String? notes;

  const PoleCreate({
    required this.poleNumber,
    required this.latitude,
    required this.longitude,
    required this.poleType,
    this.height,
    this.foundationType,
    this.material,
    this.yearInstalled,
    this.condition = 'good',
    this.notes,
  });

  factory PoleCreate.fromJson(Map<String, dynamic> json) => _$PoleCreateFromJson(json);
  Map<String, dynamic> toJson() => _$PoleCreateToJson(this);
}

@JsonSerializable()
class Equipment {
  final int id;
  final int poleId;
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
    required this.poleId,
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
    int? poleId,
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
      poleId: poleId ?? this.poleId,
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
