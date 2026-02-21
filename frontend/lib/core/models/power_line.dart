import 'package:json_annotation/json_annotation.dart';

part 'power_line.g.dart';

// Вспомогательные функции для безопасной обработки null значений при JSON десериализации
String _stringFromJson(dynamic value) {
  if (value == null) return '';
  if (value is String) return value;
  return value.toString();
}

double? _doubleFromJsonNullable(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

double _doubleFromJson(dynamic value) {
  if (value == null) return 0.0;  // Возвращаем 0.0 вместо null для обязательных полей
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    return parsed ?? 0.0;
  }
  return 0.0;  // Значение по умолчанию
}

int? _intFromJsonNullable(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

int _intFromJson(dynamic value) {
  if (value == null) return 0;  // Возвращаем 0 вместо null для обязательных полей
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value);
    return parsed ?? 0;  // Возвращаем 0 если парсинг не удался
  }
  return 0;  // Значение по умолчанию
}

DateTime _dateTimeFromJson(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (e) {
      return DateTime.now();
    }
  }
  if (value is DateTime) return value;
  return DateTime.now();
}

DateTime? _dateTimeFromJsonNullable(dynamic value) {
  if (value == null) return null;
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (e) {
      return null;
    }
  }
  if (value is DateTime) return value;
  return null;
}

@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false, // Не включать null значения в JSON
)
class PowerLine {
  final int id;
  @JsonKey(fromJson: _stringFromJson)
  final String name;
  @JsonKey(fromJson: _stringFromJson)
  final String code;
  @JsonKey(name: 'voltage_level', fromJson: _doubleFromJsonNullable)
  final double? voltageLevel; // Может быть null на backend
  @JsonKey(fromJson: _doubleFromJsonNullable)
  final double? length;
  @JsonKey(name: 'branch_id', fromJson: _intFromJsonNullable)
  final int? branchId; // Может быть null на backend
  @JsonKey(name: 'created_by')
  final int createdBy;
  @JsonKey(fromJson: _stringFromJson, defaultValue: 'active')
  final String status;
  final String? description;
  @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson)
  final DateTime createdAt;
  @JsonKey(name: 'updated_at', fromJson: _dateTimeFromJsonNullable)
  final DateTime? updatedAt;
  final List<Pole>? poles;
  @JsonKey(name: 'acline_segments')
  final List<dynamic>? aclineSegments; // AClineSegmentResponse из backend

  const PowerLine({
    required this.id,
    required this.name,
    required this.code,
    this.voltageLevel,
    this.length,
    this.branchId,
    required this.createdBy,
    required this.status,
    this.description,
    required this.createdAt,
    this.updatedAt,
    this.poles,
    this.aclineSegments,
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
    List<dynamic>? aclineSegments,
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
      aclineSegments: aclineSegments ?? this.aclineSegments,
    );
  }
}

@JsonSerializable()
class PowerLineCreate {
  final String name;
  final String code;
  @JsonKey(name: 'voltage_level')
  final double voltageLevel;
  final double? length;
  @JsonKey(name: 'branch_id')
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

@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
)
class Pole {
  final int id;
  @JsonKey(name: 'power_line_id')
  final int powerLineId;
  @JsonKey(name: 'pole_number', fromJson: _stringFromJson)
  final String poleNumber;
  @JsonKey(name: 'x_position', fromJson: _doubleFromJson)
  final double xPosition;  // Долгота (longitude)
  @JsonKey(name: 'y_position', fromJson: _doubleFromJson)
  final double yPosition;  // Широта (latitude)
  @JsonKey(name: 'pole_type', fromJson: _stringFromJson)
  final String poleType;
  @JsonKey(fromJson: _doubleFromJsonNullable)
  final double? height;
  @JsonKey(name: 'foundation_type')
  final String? foundationType;
  final String? material;
  @JsonKey(name: 'year_installed', fromJson: _intFromJsonNullable)
  final int? yearInstalled;
  @JsonKey(name: 'sequence_number', fromJson: _intFromJsonNullable)
  final int? sequenceNumber;
  @JsonKey(name: 'is_tap_pole', defaultValue: false)
  final bool isTapPole;
  @JsonKey(fromJson: _stringFromJson, defaultValue: 'good')
  final String condition;
  final String? notes;
  @JsonKey(name: 'created_by')
  final int createdBy;
  @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson)
  final DateTime createdAt;
  @JsonKey(name: 'updated_at', fromJson: _dateTimeFromJsonNullable)
  final DateTime? updatedAt;
  final List<Equipment>? equipment;

  const Pole({
    required this.id,
    required this.powerLineId,
    required this.poleNumber,
    required this.xPosition,
    required this.yPosition,
    required this.poleType,
    this.height,
    this.foundationType,
    this.material,
    this.yearInstalled,
    this.sequenceNumber,
    this.isTapPole = false,
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
    double? xPosition,
    double? yPosition,
    String? poleType,
    double? height,
    String? foundationType,
    String? material,
    int? yearInstalled,
    int? sequenceNumber,
    bool? isTapPole,
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
      xPosition: xPosition ?? this.xPosition,
      yPosition: yPosition ?? this.yPosition,
      poleType: poleType ?? this.poleType,
      height: height ?? this.height,
      foundationType: foundationType ?? this.foundationType,
      material: material ?? this.material,
      yearInstalled: yearInstalled ?? this.yearInstalled,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      isTapPole: isTapPole ?? this.isTapPole,
      condition: condition ?? this.condition,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      equipment: equipment ?? this.equipment,
    );
  }
}

@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
)
class PoleCreate {
  @JsonKey(name: 'pole_number')
  final String poleNumber;
  @JsonKey(name: 'x_position', fromJson: _doubleFromJson)
  final double xPosition;  // Долгота (longitude)
  @JsonKey(name: 'y_position', fromJson: _doubleFromJson)
  final double yPosition;  // Широта (latitude)
  @JsonKey(name: 'pole_type')
  final String poleType;
  final double? height;
  @JsonKey(name: 'foundation_type')
  final String? foundationType;
  final String? material;
  @JsonKey(name: 'year_installed')
  final int? yearInstalled;
  final String condition;
  final String? notes;
  @JsonKey(name: 'is_tap')
  final bool isTap; // Является ли опора отпаечной (точкой отпайки)
  // Параметры кабеля для автоматического создания пролёта
  @JsonKey(name: 'conductor_type') // Марка провода (AC-70, AC-95 и т.д.)
  final String? conductorType;
  @JsonKey(name: 'conductor_material') // Материал (алюминий, медь)
  final String? conductorMaterial;
  @JsonKey(name: 'conductor_section') // Сечение, мм²
  final String? conductorSection;

  const PoleCreate({
    required this.poleNumber,
    required this.xPosition,
    required this.yPosition,
    required this.poleType,
    this.height,
    this.foundationType,
    this.material,
    this.yearInstalled,
    this.condition = 'good',
    this.notes,
    this.isTap = false,
    this.conductorType,
    this.conductorMaterial,
    this.conductorSection,
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
