import 'package:json_annotation/json_annotation.dart';

part 'substation.g.dart';

@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
)
class Substation {
  final int id;
  final String mrid;
  final String name;
  @JsonKey(name: 'dispatcher_name')
  final String dispatcherName;
  @JsonKey(name: 'voltage_level')
  final double voltageLevel;
  final double latitude;
  final double longitude;
  final String? address;
  @JsonKey(name: 'region_id')
  final int? regionId;
  @JsonKey(name: 'branch_id')
  final int? branchId;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  const Substation({
    required this.id,
    required this.mrid,
    required this.name,
    required this.dispatcherName,
    required this.voltageLevel,
    required this.latitude,
    required this.longitude,
    this.address,
    this.regionId,
    this.branchId,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });

  factory Substation.fromJson(Map<String, dynamic> json) => _$SubstationFromJson(json);
  Map<String, dynamic> toJson() => _$SubstationToJson(this);
}

@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
)
class SubstationCreate {
  final String name;
  @JsonKey(name: 'dispatcher_name')
  final String dispatcherName;
  @JsonKey(name: 'voltage_level')
  final double voltageLevel;
  final double latitude;
  final double longitude;
  final String? address;
  @JsonKey(name: 'branch_id')
  final int? branchId;
  final String? description;

  const SubstationCreate({
    required this.name,
    required this.dispatcherName,
    required this.voltageLevel,
    required this.latitude,
    required this.longitude,
    this.address,
    this.branchId,
    this.description,
  });

  factory SubstationCreate.fromJson(Map<String, dynamic> json) => _$SubstationCreateFromJson(json);
  Map<String, dynamic> toJson() => _$SubstationCreateToJson(this);
}

