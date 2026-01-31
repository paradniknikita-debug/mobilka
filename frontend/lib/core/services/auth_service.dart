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
      
      // Добавляем обработчик ошибок для автоматического fallback на HTTP при проблемах с SSL
      dio.interceptors.add(
        InterceptorsWrapper(
          onError: (error, handler) async {
            // Автоматический fallback HTTPS -> HTTP при ошибках SSL
            final isSslError = error.message?.contains('CERT_AUTHORITY_INVALID') == true ||
                              error.message?.contains('ERR_CERT') == true ||
                              error.message?.contains('certificate') == true ||
                              error.type == DioExceptionType.connectionError;
            
            if (kIsWeb && 
                !urlManager.isUsingHttp && 
                isSslError &&
                error.response == null) {
              
              if (kDebugMode) {
                print('⚠️ [AuthService] Проблема с HTTPS, переключение на HTTP');
              }
              
              urlManager.fallbackToHttp();
              final newBaseUrl = '${urlManager.getBaseUrl()}/api/${AppConfig.apiVersion}';
              dio.options.baseUrl = newBaseUrl;
              
              try {
                final newRequestOptions = error.requestOptions.copyWith(
                  baseUrl: newBaseUrl,
                );
                final response = await dio.fetch(newRequestOptions);
                return handler.resolve(response);
              } catch (retryError) {
                if (kDebugMode) {
                  print('❌ [AuthService] Fallback на HTTP не помог');
                }
                urlManager.resetFallback();
              }
            }
            handler.next(error);
          },
        ),
      );
      
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
      
      final authResponse = AuthResponse.fromJson(response.data);
      
      // Сохраняем токен
      await _prefs.setString(AppConfig.authTokenKey, authResponse.accessToken);
      if (kDebugMode) {
        print('✅ Авторизация успешна: токен сохранен');
      }
      
      // Обновляем prefs в ApiServiceProvider для немедленного использования
      ApiServiceProvider.updatePrefs(_prefs);
      
      // Получаем информацию о пользователе
      final userDio = Dio();
      final userUrlManager = BaseUrlManager();
      userDio.options.baseUrl = '${userUrlManager.getBaseUrl()}/api/${AppConfig.apiVersion}';
      userDio.options.headers['Authorization'] = 'Bearer ${authResponse.accessToken}';
      
      final userResponse = await userDio.get('/auth/me');
      
      // Парсим данные пользователя напрямую из ответа
      if (userResponse.data is! Map<String, dynamic>) {
        throw Exception('Неверный формат ответа от сервера: ожидался Map, получен ${userResponse.data.runtimeType}');
      }
      
      final user = User.fromJson(userResponse.data as Map<String, dynamic>);
      
      if (user.id > 0) {
        await _prefs.setInt(AppConfig.userIdKey, user.id);
      }
      
      if (kDebugMode) {
        print('✅ Пользователь авторизован: ${user.username}');
      }
      
      state = AuthStateAuthenticated(user);
      
      // Небольшая задержка для обновления UI
      await Future.delayed(const Duration(milliseconds: 100));
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
          // Проверяем, является ли это ошибкой SSL
          final isSslError = e.message?.contains('CERT_AUTHORITY_INVALID') == true ||
                            e.message?.contains('ERR_CERT') == true ||
                            e.message?.contains('certificate') == true ||
                            e.error?.toString().contains('CERT_AUTHORITY_INVALID') == true ||
                            e.error?.toString().contains('ERR_CERT') == true;
          
          if (isSslError) {
            state = AuthStateError('Ошибка SSL сертификата. Пожалуйста:\n\n'
                '1. Откройте https://localhost в новой вкладке браузера\n'
                '2. Нажмите "Дополнительно" → "Перейти на localhost (небезопасно)"\n'
                '3. Или переключите приложение на HTTP в настройках');
          } else {
            state = AuthStateError('Ошибка соединения с сервером');
          }
        }
      } else {
        // Детальная информация об ошибке парсинга
        if (kDebugMode) {
          print('   ⚠️ Ошибка не связана с DioException: ${e.toString()}');
        }
        
        if (e.toString().contains('null') || e.toString().contains('Null')) {
          state = AuthStateError('Ошибка обработки данных пользователя. Проверьте формат ответа сервера.');
        } else if (e.toString().contains('type') && e.toString().contains('is not a subtype')) {
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
