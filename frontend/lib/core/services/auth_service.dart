import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../config/app_config.dart';
import '../services/api_service.dart';
import '../models/user.dart';

part 'auth_service.freezed.dart';

@freezed
class AuthState with _$AuthState {
  const factory AuthState.initial() = _Initial;
  const factory AuthState.loading() = _Loading;
  const factory AuthState.authenticated(User user) = _Authenticated;
  const factory AuthState.unauthenticated() = _Unauthenticated;
  const factory AuthState.error(String message) = _Error;
}

class AuthService extends StateNotifier<AuthState> {
  final ApiService _apiService;
  final SharedPreferences _prefs;

  AuthService(this._apiService, this._prefs) : super(const AuthState.initial()) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final token = _prefs.getString(AppConfig.authTokenKey);
    if (token != null) {
      try {
        state = const AuthState.loading();
        final user = await _apiService.getCurrentUser();
        state = AuthState.authenticated(user);
      } catch (e) {
        // Токен невалидный, очищаем
        await logout();
      }
    } else {
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> login(String username, String password) async {
    try {
      state = const AuthState.loading();
      final response = await _apiService.login(
        UserLogin(username: username, password: password),
      );
      
      // Сохраняем токен
      await _prefs.setString(AppConfig.authTokenKey, response.accessToken);
      
      // Получаем информацию о пользователе
      final user = await _apiService.getCurrentUser();
      if (user.id != null) {
        await _prefs.setInt(AppConfig.userIdKey, user.id!);
      }
      
      state = AuthState.authenticated(user);
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  Future<void> register(UserCreate userData) async {
    try {
      state = const AuthState.loading();
      await _apiService.register(userData);
      
      // После регистрации автоматически логинимся
      final response = await _apiService.login(
        UserLogin(username: userData.username, password: userData.password),
      );
      
      await _prefs.setString(AppConfig.authTokenKey, response.accessToken);
      
      // Получаем информацию о пользователе
      final user = await _apiService.getCurrentUser();
      if (user.id != null) {
        await _prefs.setInt(AppConfig.userIdKey, user.id!);
      }
      
      state = AuthState.authenticated(user);
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  Future<void> logout() async {
    await _prefs.remove(AppConfig.authTokenKey);
    await _prefs.remove(AppConfig.userIdKey);
    state = const AuthState.unauthenticated();
  }

  String? getToken() {
    return _prefs.getString(AppConfig.authTokenKey);
  }
}

// Provider для AuthService
final authServiceProvider = StateNotifierProvider<AuthService, AuthState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final prefs = ref.watch(prefsProvider);
  return AuthService(apiService, prefs);
});

// Provider для состояния авторизации
final authStateProvider = StateNotifierProvider<AuthService, AuthState>((ref) {
  return ref.watch(authServiceProvider);
});

// Provider для SharedPreferences
final prefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('prefsProvider должен быть переопределен в main.dart');
});
