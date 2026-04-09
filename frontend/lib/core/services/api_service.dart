import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:retrofit/retrofit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../models/power_line.dart';
import '../models/substation.dart';
import '../models/patrol_session.dart';
import '../config/app_config.dart';
import 'base_url_manager.dart';
import 'auth_service.dart'; // Для доступа к prefsProvider

part 'api_service.g.dart';

/// MIME для multipart вложений опоры (когда клиент не задаёт Content-Type части).
String _guessMimeForPoleAttachment(String filename) {
  final f = filename.toLowerCase();
  if (f.endsWith('.jpg') || f.endsWith('.jpeg')) return 'image/jpeg';
  if (f.endsWith('.png')) return 'image/png';
  if (f.endsWith('.gif')) return 'image/gif';
  if (f.endsWith('.webp')) return 'image/webp';
  if (f.endsWith('.svg')) return 'image/svg+xml';
  if (f.endsWith('.pdf')) return 'application/pdf';
  if (f.endsWith('.m4a')) return 'audio/mp4';
  if (f.endsWith('.mp3')) return 'audio/mpeg';
  if (f.endsWith('.wav')) return 'audio/wav';
  if (f.endsWith('.webm')) return 'video/webm';
  if (f.endsWith('.mp4')) return 'video/mp4';
  return 'application/octet-stream';
}

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

  @DELETE('/power-lines/{id}')
  Future<void> deletePowerLine(@Path('id') int id);

  @POST('/power-lines/{id}/poles')
  Future<Pole> createPole(
    @Path('id') int powerLineId,
    @Body() PoleCreate poleData, {
    @Query('from_pole_id') int? fromPoleId,
  });

  @PUT('/power-lines/{powerLineId}/poles/{poleId}')
  Future<Pole> updatePole(
    @Path('powerLineId') int powerLineId,
    @Path('poleId') int poleId,
    @Body() PoleCreate poleData,
  );

  @GET('/power-lines/{id}/poles')
  Future<List<Pole>> getPoles(@Path('id') int powerLineId);

  @POST('/power-lines/{id}/link-substation')
  /// dynamic — иначе retrofit_generator генерирует неверный `dynamic.fromJson` для web.
  Future<dynamic> linkLineToSubstation(
    @Path('id') int powerLineId,
    @Body() Map<String, dynamic> body,
  );

  @DELETE('/power-lines/{powerLineId}/spans/{spanId}')
  Future<void> deleteSpan(@Path('powerLineId') int powerLineId, @Path('spanId') int spanId);

  @POST('/power-lines/{id}/spans/auto-create')
  Future<dynamic> autoCreateSpans(@Path('id') int powerLineId);

  // Poles
  @GET('/poles')
  Future<List<Pole>> getAllPoles();

  @GET('/poles/{id}')
  Future<Pole> getPole(@Path('id') int id);

  @DELETE('/poles/{id}')
  Future<void> deletePole(@Path('id') int id);

  @POST('/poles/{id}/equipment')
  Future<Equipment> createEquipment(@Path('id') int poleId, @Body() EquipmentCreate equipmentData);

  @GET('/poles/{id}/equipment')
  Future<List<Equipment>> getPoleEquipment(@Path('id') int poleId);

  @DELETE('/poles/{poleId}/equipment/{equipmentId}')
  Future<void> deletePoleEquipment(
    @Path('poleId') int poleId,
    @Path('equipmentId') int equipmentId,
  );

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

  // Substations
  @POST('/substations')
  Future<Substation> createSubstation(@Body() SubstationCreate substationData);

  @DELETE('/substations/{id}')
  Future<void> deleteSubstation(@Path('id') int id);

  @GET('/map/bounds')
  Future<dynamic> getDataBounds();

  // Сессии обхода (админ видит все, инженер — свои)
  @GET('/patrol-sessions')
  Future<List<PatrolSession>> getPatrolSessions(
    @Query('user_id') int? userId,
    @Query('line_id') int? lineId,
    @Query('limit') int? limit,
    @Query('offset') int? offset,
  );

  @POST('/patrol-sessions')
  Future<dynamic> createPatrolSession(
    @Body() Map<String, dynamic> body,
  );

  @PATCH('/patrol-sessions/{id}')
  Future<dynamic> endPatrolSession(@Path('id') int id);

  @GET('/change-log')
  Future<List<dynamic>> getChangeLog(
    @Query('source') String? source,
    @Query('action') String? action,
    @Query('entity_type') String? entityType,
    @Query('entity_id') int? entityId,
    @Query('limit') int? limit,
    @Query('offset') int? offset,
  );

  // CIM: карточка участка линии (AClineSegment)
  @GET('/cim/acline-segments/{id}')
  Future<dynamic> getAclineSegment(@Path('id') int segmentId);

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

// Расширенный интерфейс с методом exportCimXml и загрузкой вложений опоры
// (не может быть в Retrofit из-за бинарных ответов и multipart)
abstract class ApiServiceWithExport implements ApiService {
  Future<Response<List<int>>> exportCimXml(
    bool useCimpy,
    bool includeSubstations,
    bool includePowerLines,
    bool includeGps,
    int? lineId,
    bool includeEquipment,
  );

  /// Загружает вложение к карточке опоры (фото, голос, схема, видео).
  /// Возвращает {url, thumbnail_url?, type, filename}.
  Future<Map<String, dynamic>> uploadPoleAttachment(
    int poleId,
    String attachmentType,
    List<int> fileBytes,
    String filename,
  );
}

class ApiServiceProvider {
  static SharedPreferences? _prefs;
  
  static ApiServiceWithExport create({SharedPreferences? prefs}) {
    _prefs = prefs; // Сохраняем prefs статически
    final dio = Dio();
    final urlManager = BaseUrlManager();
    // Обновляем протокол из конфига при создании сервиса
    urlManager.updateProtocolFromConfig();
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
          } else if (kDebugMode && !options.path.contains('/auth/login')) {
            print('⚠️ [${options.method} ${options.path}] Токен отсутствует');
          }

          handler.next(options);
        },
        onError: (error, handler) async {
          // Автоматический fallback HTTPS -> HTTP при ошибках соединения или SSL
          // Проверяем различные типы ошибок, которые могут возникнуть при проблемах с SSL
          final isSslError = error.message?.contains('CERT_AUTHORITY_INVALID') == true ||
                            error.message?.contains('ERR_CERT') == true ||
                            error.message?.contains('certificate') == true ||
                            error.type == DioExceptionType.connectionError;
          
          if (kIsWeb && 
              !urlManager.isUsingHttp && 
              isSslError &&
              error.response == null) { // Только если нет ответа (браузер блокирует)
            
            if (kDebugMode) {
              print('⚠️ Проблема с HTTPS (SSL сертификат): ${error.message}');
              print('   Переключение на HTTP...');
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
              
              if (kDebugMode) {
                print('✅ Запрос успешно выполнен через HTTP после fallback');
              }
              
              return handler.resolve(response);
            } catch (retryError) {
              // Если и HTTP не работает (404 после редиректа), это значит:
              // Nginx редиректит HTTP → HTTPS, но HTTPS всё ещё блокируется
              if (kDebugMode) {
                print('❌ Fallback на HTTP не помог. Проверьте SSL сертификат.');
                print('   Решение: Откройте https://localhost в браузере и примите сертификат');
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
              print('🔓 Токен истёк (401), требуется повторная авторизация');
              print('   Очищен токен из хранилища');
            }
            // Ошибка 401 будет проброшена дальше, чтобы UI мог обработать её
            // (например, перенаправить на страницу логина)
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

    final apiService = ApiService(dio, baseUrl: dio.options.baseUrl);
    return _ApiServiceWrapper(apiService, dio);
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

final apiServiceProvider = Provider<ApiServiceWithExport>((ref) {
  try {
    final prefs = ref.watch(prefsProvider);
    return ApiServiceProvider.create(prefs: prefs);
  } catch (e) {
    return ApiServiceProvider.create();
  }
});

// Провайдер для прямого доступа к Dio (вложения, бинарные ответы и т.д.)
final dioProvider = Provider<Dio>((ref) {
  final prefs = ref.watch(prefsProvider);
  final dio = Dio();
  final urlManager = BaseUrlManager();
  dio.options.baseUrl = '${urlManager.getBaseUrl()}/api/${AppConfig.apiVersion}';
  
  // Логирование запросов для отладки (только в debug режиме)
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: false,
        requestHeader: true,
        responseHeader: false,
        error: true,
      ),
    );
  }
  
  // Interceptor для автоматического fallback HTTPS -> HTTP + Bearer (как у ApiService)
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        // Обновляем baseUrl перед каждым запросом
        dio.options.baseUrl = '${urlManager.getBaseUrl()}/api/${AppConfig.apiVersion}';
        options.baseUrl = dio.options.baseUrl;
        final token = prefs.getString(AppConfig.authTokenKey);
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
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

/// Обёртка для ApiService, добавляющая метод exportCimXml
/// (Retrofit не поддерживает бинарные ответы через аннотации)
class _ApiServiceWrapper implements ApiServiceWithExport {
  final ApiService _delegate;
  final Dio _dio;

  _ApiServiceWrapper(this._delegate, this._dio);

  @override
  Future<Response<List<int>>> exportCimXml(
    bool useCimpy,
    bool includeSubstations,
    bool includePowerLines,
    bool includeGps,
    int? lineId,
    bool includeEquipment,
  ) async {
    final queryParameters = <String, dynamic>{
      'use_cimpy': useCimpy,
      'include_substations': includeSubstations,
      'include_power_lines': includePowerLines,
      'include_equipment': includeEquipment,
      'include_gps': includeGps,
      'line_id': lineId,
    };
    
    final response = await _dio.get<List<int>>(
      '/cim/export/xml',
      queryParameters: queryParameters,
      options: Options(
        responseType: ResponseType.bytes,
      ),
    );
    
    return response;
  }

  @override
  Future<Map<String, dynamic>> uploadPoleAttachment(
    int poleId,
    String attachmentType,
    List<int> fileBytes,
    String filename,
  ) async {
    final formData = FormData.fromMap({
      'attachment_type': attachmentType,
      'file': MultipartFile.fromBytes(
        fileBytes,
        filename: filename,
        contentType: MediaType.parse(_guessMimeForPoleAttachment(filename)),
      ),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/attachments/poles/$poleId/attachments',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );
    final data = response.data;
    if (data == null) throw Exception('Пустой ответ при загрузке вложения');
    return data;
  }

  // Делегируем все остальные методы к базовому сервису
  @override
  Future<AuthResponse> login(String username, String password) => _delegate.login(username, password);

  @override
  Future<User> register(UserCreate userData) => _delegate.register(userData);

  @override
  Future<User> getCurrentUser() => _delegate.getCurrentUser();

  @override
  Future<List<PowerLine>> getPowerLines() => _delegate.getPowerLines();

  @override
  Future<PowerLine> createPowerLine(PowerLineCreate powerLineData) => _delegate.createPowerLine(powerLineData);

  @override
  Future<PowerLine> getPowerLine(int id) => _delegate.getPowerLine(id);

  @override
  Future<void> deletePowerLine(int id) => _delegate.deletePowerLine(id);

  @override
  Future<Pole> createPole(int powerLineId, PoleCreate poleData, {int? fromPoleId}) =>
      _delegate.createPole(powerLineId, poleData, fromPoleId: fromPoleId);

  @override
  Future<Pole> updatePole(int powerLineId, int poleId, PoleCreate poleData) =>
      _delegate.updatePole(powerLineId, poleId, poleData);

  @override
  Future<List<Pole>> getPoles(int powerLineId) => _delegate.getPoles(powerLineId);

  @override
  Future<Map<String, dynamic>> linkLineToSubstation(int powerLineId, Map<String, dynamic> body) async {
    final raw = await _delegate.linkLineToSubstation(powerLineId, body);
    return Map<String, dynamic>.from(raw as Map);
  }

  @override
  Future<void> deleteSpan(int powerLineId, int spanId) => _delegate.deleteSpan(powerLineId, spanId);

  @override
  Future<Map<String, dynamic>> autoCreateSpans(int powerLineId) async {
    final raw = await _delegate.autoCreateSpans(powerLineId);
    return Map<String, dynamic>.from(raw as Map);
  }

  @override
  Future<List<Pole>> getAllPoles() => _delegate.getAllPoles();

  @override
  Future<Pole> getPole(int id) => _delegate.getPole(id);

  @override
  Future<void> deletePole(int id) => _delegate.deletePole(id);

  @override
  Future<Equipment> createEquipment(int poleId, EquipmentCreate equipmentData) => _delegate.createEquipment(poleId, equipmentData);

  @override
  Future<List<Equipment>> getPoleEquipment(int poleId) => _delegate.getPoleEquipment(poleId);

  @override
  Future<void> deletePoleEquipment(int poleId, int equipmentId) =>
      _delegate.deletePoleEquipment(poleId, equipmentId);

  @override
  Future<List<Equipment>> getAllEquipment() => _delegate.getAllEquipment();

  @override
  Future<Equipment> getEquipment(int id) => _delegate.getEquipment(id);

  @override
  Future<dynamic> getPowerLinesGeoJSON() => _delegate.getPowerLinesGeoJSON();

  @override
  Future<dynamic> getTowersGeoJSON() => _delegate.getTowersGeoJSON();

  @override
  Future<dynamic> getTapsGeoJSON() => _delegate.getTapsGeoJSON();

  @override
  Future<dynamic> getSubstationsGeoJSON() => _delegate.getSubstationsGeoJSON();

  @override
  Future<Map<String, dynamic>> getAclineSegment(int segmentId) async {
    final raw = await _delegate.getAclineSegment(segmentId);
    return Map<String, dynamic>.from(raw as Map);
  }

  @override
  Future<Substation> createSubstation(SubstationCreate substationData) => _delegate.createSubstation(substationData);

  @override
  Future<void> deleteSubstation(int id) => _delegate.deleteSubstation(id);

  @override
  Future<dynamic> getDataBounds() => _delegate.getDataBounds();

  @override
  Future<List<PatrolSession>> getPatrolSessions(int? userId, int? lineId, int? limit, int? offset) =>
      _delegate.getPatrolSessions(userId, lineId, limit, offset);

  @override
  Future<Map<String, dynamic>> createPatrolSession(Map<String, dynamic> body) async {
    final raw = await _delegate.createPatrolSession(body);
    return Map<String, dynamic>.from(raw as Map);
  }

  @override
  Future<Map<String, dynamic>> endPatrolSession(int id) async {
    final raw = await _delegate.endPatrolSession(id);
    return Map<String, dynamic>.from(raw as Map);
  }

  @override
  Future<List<dynamic>> getChangeLog(
    String? source,
    String? action,
    String? entityType,
    int? entityId,
    int? limit,
    int? offset,
  ) => _delegate.getChangeLog(source, action, entityType, entityId, limit, offset);

  @override
  Future<dynamic> uploadSyncBatch(Map<String, dynamic> batch) => _delegate.uploadSyncBatch(batch);

  @override
  Future<dynamic> downloadSyncData(String lastSync) => _delegate.downloadSyncData(lastSync);

  @override
  Future<dynamic> getAllSchemas() => _delegate.getAllSchemas();

  @override
  Future<dynamic> getEntitySchema(String entityType) => _delegate.getEntitySchema(entityType);
}
