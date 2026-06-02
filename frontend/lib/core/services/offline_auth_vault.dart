import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';
import '../models/user.dart';

/// Учётные данные для офлайн-входа после явного выхода (Secure Storage).
class OfflineAuthVault {
  OfflineAuthVault({
    required this.username,
    required this.password,
    required this.accessToken,
    required this.user,
  });

  final String username;
  final String password;
  final String accessToken;
  final User user;

  Map<String, dynamic> toJson() => {
        'username': username,
        'password': password,
        'access_token': accessToken,
        'user': user.toJson(),
      };

  static OfflineAuthVault? fromJsonString(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final userRaw = map['user'];
      if (userRaw is! Map<String, dynamic>) {
        return null;
      }
      return OfflineAuthVault(
        username: map['username']?.toString() ?? '',
        password: map['password']?.toString() ?? '',
        accessToken: map['access_token']?.toString() ?? '',
        user: User.fromJson(userRaw),
      );
    } catch (_) {
      return null;
    }
  }
}

class OfflineAuthVaultStore {
  OfflineAuthVaultStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  Future<void> save({
    required String username,
    required String password,
    required String accessToken,
    required User user,
  }) async {
    final vault = OfflineAuthVault(
      username: username.trim(),
      password: password,
      accessToken: accessToken,
      user: user,
    );
    await _storage.write(
      key: AppConfig.offlineAuthVaultKey,
      value: jsonEncode(vault.toJson()),
    );
  }

  Future<OfflineAuthVault?> read() async {
    final raw = await _storage.read(key: AppConfig.offlineAuthVaultKey);
    return OfflineAuthVault.fromJsonString(raw);
  }

  Future<void> clear() async {
    await _storage.delete(key: AppConfig.offlineAuthVaultKey);
  }

  Future<bool> tryLogin({
    required String username,
    required String password,
  }) async {
    final vault = await read();
    if (vault == null) {
      return false;
    }
    if (vault.accessToken.isEmpty) {
      return false;
    }
    if (vault.username.trim().toLowerCase() != username.trim().toLowerCase()) {
      return false;
    }
    return vault.password == password;
  }
}
