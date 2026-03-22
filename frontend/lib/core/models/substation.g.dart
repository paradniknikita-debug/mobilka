// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'substation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Substation _$SubstationFromJson(Map<String, dynamic> json) => Substation(
  id: (json['id'] as num).toInt(),
  mrid: json['mrid'] as String,
  name: json['name'] as String,
  dispatcherName: json['dispatcher_name'] as String,
  voltageLevel: (json['voltage_level'] as num).toDouble(),
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  address: json['address'] as String?,
  regionId: (json['region_id'] as num?)?.toInt(),
  branchId: (json['branch_id'] as num?)?.toInt(),
  isActive: json['is_active'] as bool,
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$SubstationToJson(Substation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'mrid': instance.mrid,
      'name': instance.name,
      'dispatcher_name': instance.dispatcherName,
      'voltage_level': instance.voltageLevel,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'address': ?instance.address,
      'region_id': ?instance.regionId,
      'branch_id': ?instance.branchId,
      'is_active': instance.isActive,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': ?instance.updatedAt?.toIso8601String(),
    };

SubstationCreate _$SubstationCreateFromJson(Map<String, dynamic> json) =>
    SubstationCreate(
      name: json['name'] as String,
      dispatcherName: json['dispatcher_name'] as String,
      voltageLevel: (json['voltage_level'] as num).toDouble(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String?,
      branchId: (json['branch_id'] as num?)?.toInt(),
      description: json['description'] as String?,
    );

Map<String, dynamic> _$SubstationCreateToJson(SubstationCreate instance) =>
    <String, dynamic>{
      'name': instance.name,
      'dispatcher_name': instance.dispatcherName,
      'voltage_level': instance.voltageLevel,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'address': ?instance.address,
      'branch_id': ?instance.branchId,
      'description': ?instance.description,
    };
