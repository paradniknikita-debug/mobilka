import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../models/power_line.dart';
import '../config/app_config.dart';
import 'base_url_manager.dart';
import 'auth_service.dart'; // Для доступа к prefsProvider

part 'api_service.g.dart';

@RestApi()
abstract class ApiService {
  factory ApiService(Dio dio, {String baseUrl}) = _ApiService;

  // Authentication
  @POST('/auth/login')
  @FormUrlEncoded()
  Future<AuthResponse> login(
    @Field('username') String username,
    @Field('password') String password,
  );

  @POST('/auth/register')
  Future<User> register(@Body() UserCreate userData);

  @GET('/auth/me')
  Future<User> getCurrentUser();

  // Power Lines
  @GET('/power-lines')
  Future<List<PowerLine>> getPowerLines();

  @POST('/power-lines')
  Future<PowerLine> createPowerLine(@Body() PowerLineCreate powerLineData);

  @GET('/power-lines/{id}')
  Future<PowerLine> getPowerLine(@Path('id') int id);

  @POST('/power-lines/{id}/poles')
  Future<Pole> createPole(@Path('id') int powerLineId, @Body() PoleCreate poleData);

  @GET('/power-lines/{id}/poles')
  Future<List<Pole>> getPoles(@Path('id') int powerLineId);

  // Poles
  @GET('/poles')
  Future<List<Pole>> getAllPoles();

  @GET('/poles/{id}')
  Future<Pole> getPole(@Path('id') int id);

  @POST('/poles/{id}/equipment')
  Future<Equipment> createEquipment(@Path('id') int poleId, @Body() EquipmentCreate equipmentData);

  @GET('/poles/{id}/equipment')
  Future<List<Equipment>> getPoleEquipment(@Path('id') int poleId);

  // Equipment
  @GET('/equipment')
  Future<List<Equipment>> getAllEquipment();

  @GET('/equipment/{id}')
  Future<Equipment> getEquipment(@Path('id') int id);

  // Map
  @GET('/map/power-lines/geojson')
  Future<dynamic> getPowerLinesGeoJSON();

  @GET('/map/poles/geojson')
  Future<dynamic> getTowersGeoJSON();

  @GET('/map/taps/geojson')
  Future<dynamic> getTapsGeoJSON();

  @GET('/map/substations/geojson')
  Future<dynamic> getSubstationsGeoJSON();

  @GET('/map/bounds')
  Future<dynamic> getDataBounds();

  // Sync
  @POST('/sync/upload')
  Future<dynamic> uploadSyncBatch(@Body() Map<String, dynamic> batch);

  @GET('/sync/download')
  Future<dynamic> downloadSyncData(@Query('last_sync') String lastSync);

  @GET('/sync/schemas')
  Future<dynamic> getAllSchemas();

  @GET('/sync/schema/{entity_type}')
  Future<dynamic> getEntitySchema(@Path('entity_type') String entityType);
}

class ApiServiceProvider {
  static SharedPreferences? _prefs;
  
  static ApiService create({SharedPreferences? prefs}) {
    _prefs = prefs; // Сохраняем prefs статически
    final dio = Dio();
    final urlManager = BaseUrlManager();
    dio.options.baseUrl = '${urlManager.getBaseUrl()}/api/${AppConfig.apiVersion}';
    
    // Настройка interceptors
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Обновляем baseUrl перед каждым запросом (на случай fallback)
          dio.options.baseUrl = '${urlManager.getBaseUrl()}/api/${AppConfig.apiVersion}';
          options.baseUrl = dio.options.baseUrl;
          
          // Добавление заголовков авторизации
          final token = await _getStoredToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
            if (kDebugMode) {
              print('🔑 [${options.method} ${options.path}] Добавлен токен авторизации');
            }
          } else {
            if (kDebugMode) {
              print('⚠️ [${options.method} ${options.path}] Токен авторизации отсутствует!');
              print('   Запрос будет выполнен без авторизации (может вернуть 403)');
            }
          }
          
          if (kDebugMode) {
            print('📤 [${options.method}] ${options.baseUrl}${options.path}');
            print('   Headers: ${options.headers.keys.join(", ")}');
          }
          
          handler.next(options);
        },
        onError: (error, handler) async {
          // Автоматический fallback HTTPS -> HTTP при ошибках соединения
          // НО: только если это реальная ошибка соединения, не 404 после редиректа
          if (kIsWeb && 
              !urlManager.isUsingHttp && 
              error.type == DioExceptionType.connectionError &&
              error.response == null) { // Только если нет ответа (браузер блокирует)
            
            if (kDebugMode) {
              print('🔄 Попытка fallback на HTTP из-за ошибки: ${error.type}');
              print('   Примечание: Если Nginx редиректит HTTP→HTTPS, fallback не поможет');
              print('   Решение: Прими SSL сертификат в браузере на https://localhost');
            }
            
            // Выполняем fallback на HTTP
            urlManager.fallbackToHttp();
            
            // Обновляем baseUrl
            final newBaseUrl = '${urlManager.getBaseUrl()}/api/${AppConfig.apiVersion}';
            dio.options.baseUrl = newBaseUrl;
            
            // Повторяем запрос с HTTP
            try {
              final newRequestOptions = error.requestOptions.copyWith(
                baseUrl: newBaseUrl,
              );
              
              final response = await dio.fetch(newRequestOptions);
              
              return handler.resolve(response);
            } catch (retryError) {
              // Если и HTTP не работает (404 после редиректа), это значит:
              // Nginx редиректит HTTP → HTTPS, но HTTPS всё ещё блокируется
              if (kDebugMode) {
                print('❌ Fallback на HTTP не помог');
                print('   Вероятная причина: Nginx редиректит HTTP → HTTPS');
                print('   Решение: Прими SSL сертификат в браузере');
                print('   1. Открой https://localhost в новой вкладке');
                print('   2. Нажми "Дополнительно" → "Перейти на localhost (небезопасно)"');
              }
              
              // Сбрасываем fallback, чтобы вернуться к HTTPS после принятия сертификата
              urlManager.resetFallback();
            }
          }
          
          // Обработка других ошибок
          if (error.response?.statusCode == 401) {
            // Токен истёк, нужно перелогиниться
            await _clearStoredToken();
            if (kDebugMode) {
              print('🔓 Токен истёк, требуется повторная авторизация');
            }
          } else if (error.response?.statusCode == 403) {
            final token = await _getStoredToken();
            if (kDebugMode) {
              print('🚫 Доступ запрещен (403) для ${error.requestOptions.path}');
              print('   Токен: ${token != null ? "есть (${token.substring(0, 10)}...)" : "отсутствует"}');
              print('   Headers запроса: ${error.requestOptions.headers}');
            }
            
            // Если токена нет, очищаем состояние авторизации
            if (token == null || token.isEmpty) {
              if (kDebugMode) {
                print('   ⚠️ Токен отсутствует - требуется авторизация');
              }
            }
          }
          handler.next(error);
        },
      ),
    );

    return ApiService(dio, baseUrl: dio.options.baseUrl);
  }

  static Future<String?> _getStoredToken() async {
    if (_prefs == null) {
      if (kDebugMode) {
        print('⚠️ SharedPreferences не инициализирован');
      }
      return null;
    }
    return _prefs!.getString(AppConfig.authTokenKey);
  }

  static Future<void> _clearStoredToken() async {
    if (_prefs != null) {
      await _prefs!.remove(AppConfig.authTokenKey);
    }
  }
  
  static void updatePrefs(SharedPreferences prefs) {
    _prefs = prefs;
  }
}

final apiServiceProvider = Provider<ApiService>((ref) {
  try {
    final prefs = ref.watch(prefsProvider);
    return ApiServiceProvider.create(prefs: prefs);
  } catch (e) {
    // Если prefsProvider не переопределен, создаем без prefs
    return ApiServiceProvider.create();
  }
});

// Провайдер для прямого доступа к Dio (для тестовых запросов)
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio();
  final urlManager = BaseUrlManager();
  dio.options.baseUrl = '${urlManager.getBaseUrl()}/api/${AppConfig.apiVersion}';
  
  // Логирование запросов для отладки (только в debug режиме)
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: true,
        responseHeader: false,
        error: true,
      ),
    );
  }
  
  // Interceptor для автоматического fallback HTTPS -> HTTP
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        // Обновляем baseUrl перед каждым запросом
        dio.options.baseUrl = '${urlManager.getBaseUrl()}/api/${AppConfig.apiVersion}';
        options.baseUrl = dio.options.baseUrl;
        handler.next(options);
      },
      onError: (error, handler) async {
        // Автоматический fallback HTTPS -> HTTP только при connectionError
        // Не делаем fallback при badCertificate/connectionTimeout - они означают проблемы с SSL
        if (kIsWeb && 
            !urlManager.isUsingHttp && 
            error.type == DioExceptionType.connectionError) {
          
          if (kDebugMode) {
            print('🔄 Попытка fallback на HTTP из-за ошибки: ${error.type}');
          }
          
          urlManager.fallbackToHttp();
          final newBaseUrl = '${urlManager.getBaseUrl()}/api/${AppConfig.apiVersion}';
          dio.options.baseUrl = newBaseUrl;
          
          // Повторяем запрос с HTTP
          try {
            final newRequestOptions = error.requestOptions.copyWith(
              baseUrl: newBaseUrl,
            );
            
            final response = await dio.fetch(newRequestOptions);
            
            return handler.resolve(response);
          } catch (retryError) {
            if (kDebugMode) {
              print('❌ Fallback на HTTP не помог. Проверь настройки Nginx и SSL.');
            }
            // Сбрасываем fallback, чтобы попробовать HTTPS снова
            urlManager.resetFallback();
          }
        }
        
        handler.next(error);
      },
    ),
  );
  
  return dio;
});
