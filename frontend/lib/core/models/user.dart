import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  @JsonKey(fromJson: _intFromJson)
  final int id;
  @JsonKey(defaultValue: '')
  final String username;
  @JsonKey(defaultValue: '')
  final String email;
  @JsonKey(name: 'full_name', defaultValue: '')
  final String fullName;
  @JsonKey(defaultValue: 'engineer')
  final String role;
  @JsonKey(name: 'is_active', defaultValue: true)
  final bool isActive;
  @JsonKey(name: 'is_superuser', defaultValue: false)
  final bool isSuperuser;
  @JsonKey(name: 'branch_id')
  final int? branchId;
  @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson)
  final DateTime createdAt;
  @JsonKey(name: 'updated_at', fromJson: _dateTimeFromJsonNullable)
  final DateTime? updatedAt;

  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isActive,
    required this.isSuperuser,
    this.branchId,
    required this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
  
  // Вспомогательные функции для парсинга
  static int _intFromJson(dynamic value) {
    if (value == null) {
      return 0;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
  
  static DateTime _dateTimeFromJson(dynamic value) {
    if (value == null) {
      return DateTime.now();
    }
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.now();
  }
  
  static DateTime? _dateTimeFromJsonNullable(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  User copyWith({
    int? id,
    String? username,
    String? email,
    String? fullName,
    String? role,
    bool? isActive,
    bool? isSuperuser,
    int? branchId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      isSuperuser: isSuperuser ?? this.isSuperuser,
      branchId: branchId ?? this.branchId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@JsonSerializable()
class UserCreate {
  final String username;
  final String email;
  @JsonKey(name: 'full_name')
  final String fullName;
  final String password;
  final String role;
  @JsonKey(name: 'branch_id')
  final int? branchId;

  const UserCreate({
    required this.username,
    required this.email,
    required this.fullName,
    required this.password,
    this.role = 'engineer',
    this.branchId,
  });

  factory UserCreate.fromJson(Map<String, dynamic> json) => _$UserCreateFromJson(json);
  Map<String, dynamic> toJson() => _$UserCreateToJson(this);
}

@JsonSerializable()
class UserLogin {
  final String username;
  final String password;

  const UserLogin({
    required this.username,
    required this.password,
  });

  factory UserLogin.fromJson(Map<String, dynamic> json) => _$UserLoginFromJson(json);
  Map<String, dynamic> toJson() => _$UserLoginToJson(this);
}

@JsonSerializable()
class AuthResponse {
  @JsonKey(name: 'access_token', fromJson: _stringFromJson)
  final String accessToken;
  @JsonKey(name: 'token_type', fromJson: _stringFromJsonWithDefault)
  final String tokenType;

  const AuthResponse({
    required this.accessToken,
    required this.tokenType,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => _$AuthResponseFromJson(json);
  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);
  
  // Вспомогательные функции для безопасного парсинга строк
  static String _stringFromJson(dynamic value) {
    if (value == null) {
      return '';
    }
    if (value is String) {
      return value;
    }
    return value.toString();
  }
  
  static String _stringFromJsonWithDefault(dynamic value) {
    if (value == null) {
      return 'bearer';
    }
    if (value is String) {
      return value;
    }
    return value.toString();
  }
}
