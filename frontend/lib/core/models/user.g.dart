// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
      id: User._intFromJson(json['id']),
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      role: json['role'] as String? ?? 'engineer',
      isActive: json['is_active'] as bool? ?? true,
      isSuperuser: json['is_superuser'] as bool? ?? false,
      branchId: (json['branch_id'] as num?)?.toInt(),
      createdAt: User._dateTimeFromJson(json['created_at']),
      updatedAt: User._dateTimeFromJsonNullable(json['updated_at']),
    );

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'email': instance.email,
      'full_name': instance.fullName,
      'role': instance.role,
      'is_active': instance.isActive,
      'is_superuser': instance.isSuperuser,
      'branch_id': instance.branchId,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

UserCreate _$UserCreateFromJson(Map<String, dynamic> json) => UserCreate(
      username: json['username'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      password: json['password'] as String,
      role: json['role'] as String? ?? 'engineer',
      branchId: (json['branch_id'] as num?)?.toInt(),
    );

Map<String, dynamic> _$UserCreateToJson(UserCreate instance) =>
    <String, dynamic>{
      'username': instance.username,
      'email': instance.email,
      'full_name': instance.fullName,
      'password': instance.password,
      'role': instance.role,
      'branch_id': instance.branchId,
    };

UserLogin _$UserLoginFromJson(Map<String, dynamic> json) => UserLogin(
      username: json['username'] as String,
      password: json['password'] as String,
    );

Map<String, dynamic> _$UserLoginToJson(UserLogin instance) => <String, dynamic>{
      'username': instance.username,
      'password': instance.password,
    };

AuthResponse _$AuthResponseFromJson(Map<String, dynamic> json) => AuthResponse(
      accessToken: AuthResponse._stringFromJson(json['access_token']),
      tokenType: AuthResponse._stringFromJsonWithDefault(json['token_type']),
    );

Map<String, dynamic> _$AuthResponseToJson(AuthResponse instance) =>
    <String, dynamic>{
      'access_token': instance.accessToken,
      'token_type': instance.tokenType,
    };
