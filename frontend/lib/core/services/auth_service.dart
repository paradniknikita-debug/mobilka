import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../services/api_service.dart';
import '../services/base_url_manager.dart';
import '../models/user.dart';

// Provider для SharedPreferences (должен быть определен первым)
final prefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('prefsProvider должен быть переопределен в main.dart');
});

// Состояние авторизации
sealed class AuthState {
  const AuthState();
}

class AuthStateInitial extends AuthState {
  const AuthStateInitial();
}

class AuthStateLoading extends AuthState {
  const AuthStateLoading();
}

class AuthStateAuthenticated extends AuthState {
  final User user;
  const AuthStateAuthenticated(this.user);
}

class AuthStateUnauthenticated extends AuthState {
  const AuthStateUnauthenticated();
}

class AuthStateError extends AuthState {
  final String message;
  const AuthStateError(this.message);
}

class AuthService extends StateNotifier<AuthState> {
  final ApiService _apiService;
  final SharedPreferences _prefs;

  AuthService(this._apiService, this._prefs) : super(const AuthStateInitial()) {
    // Проверяем статус авторизации асинхронно (не блокирует старт)
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Не проверяем статус, если уже авторизованы или загружаемся
    if (state is AuthStateAuthenticated || state is AuthStateLoading) {
      if (kDebugMode) {
        print('⏭️ [AuthService] Пропускаем _checkAuthStatus: состояние уже ${state.runtimeType}');
      }
      return;
    }
    
    final token = _prefs.getString(AppConfig.authTokenKey);
    if (token != null) {
      try {
        state = const AuthStateLoading();
        final user = await _apiService.getCurrentUser();
        state = AuthStateAuthenticated(user);
        if (kDebugMode) {
          print('✅ [AuthService] Статус авторизации проверен: ${user.username}');
        }
      } catch (e) {
        // Токен невалидный, очищаем
        if (kDebugMode) {
          print('❌ [AuthService] Токен невалидный: $e');
        }
        await logout();
      }
    } else {
      state = const AuthStateUnauthenticated();
    }
  }

  Future<void> login(String username, String password) async {
    try {
      state = const AuthStateLoading();
      
      // Используем Dio напрямую для login, так как Retrofit может неправильно обрабатывать FormUrlEncoded
      final dio = Dio();
      final urlManager = BaseUrlManager();
      dio.options.baseUrl = '${urlManager.getBaseUrl()}/api/${AppConfig.apiVersion}';
      
      // Для OAuth2PasswordRequestForm нужен application/x-www-form-urlencoded
      final formData = {
        'username': username,
        'password': password,
      };
      
      final response = await dio.post(
        '/auth/login',
        data: formData,
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
        ),
      );
      
      print('📦 Ответ от /auth/login: ${response.data}');
      print('   Тип данных: ${response.data.runtimeType}');
      if (response.data is Map) {
        final data = response.data as Map;
        print('   Поля в ответе: ${data.keys.toList()}');
        for (var entry in data.entries) {
          print('     ${entry.key}: ${entry.value} (${entry.value.runtimeType})');
        }
      }
      
      final authResponse = AuthResponse.fromJson(response.data);
      
      // Сохраняем токен
      await _prefs.setString(AppConfig.authTokenKey, authResponse.accessToken);
      print('✅ Токен сохранен: ${authResponse.accessToken.substring(0, 20)}...');
      
      // Обновляем prefs в ApiServiceProvider для немедленного использования
      ApiServiceProvider.updatePrefs(_prefs);
      
      // Получаем информацию о пользователе
      print('📞 Запрос информации о пользователе через API...');
      
      // Используем Dio напрямую для получения детальной информации об ответе
      final userDio = Dio();
      final userUrlManager = BaseUrlManager();
      userDio.options.baseUrl = '${userUrlManager.getBaseUrl()}/api/${AppConfig.apiVersion}';
      userDio.options.headers['Authorization'] = 'Bearer ${authResponse.accessToken}';
      
      final userResponse = await userDio.get('/auth/me');
      print('📦 Ответ API /auth/me: ${userResponse.data}');
      print('   Тип данных: ${userResponse.data.runtimeType}');
      
      if (userResponse.data is Map) {
        final userData = userResponse.data as Map<String, dynamic>;
        print('   Поля в ответе: ${userData.keys.toList()}');
        for (var entry in userData.entries) {
          print('     ${entry.key}: ${entry.value} (${entry.value.runtimeType})');
        }
      }
      
      // Парсим данные пользователя напрямую из ответа
      if (userResponse.data is! Map<String, dynamic>) {
        throw Exception('Неверный формат ответа от сервера: ожидался Map, получен ${userResponse.data.runtimeType}');
      }
      
      final user = User.fromJson(userResponse.data as Map<String, dynamic>);
      print('📋 Данные пользователя получены: id=${user.id}, username=${user.username}, email=${user.email}');
      print('   fullName: ${user.fullName}, role: ${user.role}');
      print('   isActive: ${user.isActive}, isSuperuser: ${user.isSuperuser}');
      
      if (user.id > 0) {
        await _prefs.setInt(AppConfig.userIdKey, user.id);
      }
      
      print('✅ Пользователь авторизован: ${user.username}');
      print('🔄 Обновление состояния на AuthStateAuthenticated...');
      state = AuthStateAuthenticated(user);
      print('✅ Состояние авторизации обновлено: AuthStateAuthenticated');
      print('   Текущее состояние: ${state.runtimeType}');
      
      // Небольшая задержка для обновления UI
      await Future.delayed(const Duration(milliseconds: 100));
      print('⏱️ Задержка завершена, состояние должно быть обновлено');
    } catch (e, stackTrace) {
      print('❌ [AuthService] Ошибка при логине: $e');
      print('   Тип ошибки: ${e.runtimeType}');
      print('   Stack trace: $stackTrace');
      
      if (e is DioException) {
        print('   DioException details:');
        print('     Type: ${e.type}');
        print('     Status code: ${e.response?.statusCode}');
        print('     Response data: ${e.response?.data}');
        if (e.response?.data != null) {
          try {
            final errorData = e.response!.data;
            if (errorData is Map) {
              final detail = errorData['detail'];
              state = AuthStateError(detail?.toString() ?? 'Ошибка авторизации');
            } else {
              state = AuthStateError(errorData.toString());
            }
          } catch (_) {
            state = AuthStateError('Ошибка авторизации: ${e.response?.statusCode ?? 'неизвестная ошибка'}');
          }
        } else {
          state = AuthStateError('Ошибка соединения с сервером');
        }
      } else {
        // Детальная информация об ошибке парсинга
        print('   ⚠️ Ошибка не связана с DioException');
        print('   Сообщение: ${e.toString()}');
        
        if (e.toString().contains('null') || e.toString().contains('Null')) {
          print('   ⚠️ Обнаружена ошибка null - возможно проблема с парсингом JSON');
          print('   Попробуйте проверить ответ сервера в Network tab браузера');
          state = AuthStateError('Ошибка обработки данных пользователя. Проверьте формат ответа сервера.');
        } else if (e.toString().contains('type') && e.toString().contains('is not a subtype')) {
          print('   ⚠️ Ошибка приведения типа - возможно несоответствие типов данных');
          print('   Попробуйте проверить ответ сервера в Network tab браузера');
          state = AuthStateError('Ошибка обработки данных пользователя. Проверьте формат ответа сервера.');
        } else {
          state = AuthStateError('Ошибка: ${e.toString()}');
        }
      }
    }
  }

  Future<void> register(UserCreate userData) async {
    try {
      state = const AuthStateLoading();
      await _apiService.register(userData);
      
      // После регистрации автоматически логинимся
      // Используем Dio напрямую для login
      final dio = Dio();
      final urlManager = BaseUrlManager();
      dio.options.baseUrl = '${urlManager.getBaseUrl()}/api/${AppConfig.apiVersion}';
      
      final formData = {
        'username': userData.username,
        'password': userData.password,
      };
      
      final loginResponse = await dio.post(
        '/auth/login',
        data: formData,
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
        ),
      );
      
      final authResponse = AuthResponse.fromJson(loginResponse.data);
      await _prefs.setString(AppConfig.authTokenKey, authResponse.accessToken);
      
      // Получаем информацию о пользователе
      final user = await _apiService.getCurrentUser();
      await _prefs.setInt(AppConfig.userIdKey, user.id);
      
      state = AuthStateAuthenticated(user);
    } catch (e) {
      state = AuthStateError(e.toString());
    }
  }

  Future<void> logout() async {
    await _prefs.remove(AppConfig.authTokenKey);
    await _prefs.remove(AppConfig.userIdKey);
    state = const AuthStateUnauthenticated();
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

// Provider для состояния авторизации (алиас для authServiceProvider)
// Используем тот же провайдер, так как StateNotifierProvider уже возвращает состояние
final authStateProvider = authServiceProvider;
