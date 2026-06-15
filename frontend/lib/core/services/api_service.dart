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
import '../models/power_line_edit_hint.dart';
import '../config/app_config.dart';
import 'base_url_manager.dart';
import 'dio_config.dart';
import 'auth_service.dart'; // Для доступа к prefsProvider
import 'session_expiry.dart';

part 'api_service.g.dart';

/// Обёртка для JSON-object ответов: `retrofit_generator` некорректно парсит `Map<String,dynamic>`
/// как return type (`dynamic.fromJson` / `.map(...)` по значениям).
class JsonDict {
  JsonDict(this.data);
  final Map<String, dynamic> data;

  factory JsonDict.fromJson(Map<String, dynamic> json) =>
      JsonDict(Map<String, dynamic>.from(json));
}

/// MIME для multipart вложений опоры (когда клиент не задаёт Content-Type части).
String _guessMimeForPoleAttachment(String filename) {
  final f = filename.toLowerCase();
  if (f.endsWith('.jpg') || f.endsWith('.jpeg')) return 'image/jpeg';
  if (f.endsWith('.png')) return 'image/png';
  if (f.endsWith('.gif')) return 'image/gif';
  if (f.endsWith('.webp')) return 'image/webp';
  if (f.endsWith('.bmp')) return 'image/bmp';
  if (f.endsWith('.svg')) return 'image/svg+xml';
  if (f.endsWith('.pdf')) return 'application/pdf';
  if (f.endsWith('.m4a')) return 'audio/mp4';
  if (f.endsWith('.mp3')) return 'audio/mpeg';
  if (f.endsWith('.wav')) return 'audio/wav';
  if (f.endsWith('.ogg')) return 'audio/ogg';
  if (f.endsWith('.webm')) return 'video/webm';
  if (f.endsWith('.mp4')) return 'video/mp4';
  if (f.endsWith('.mov')) return 'video/quicktime';
  return 'application/octet-stream';
}

@RestApi()
abstract class LepmRetrofit {
  factory LepmRetrofit(Dio dio, {String baseUrl}) = _LepmRetrofit;

  // Authentication
  @POST('/auth/login')
  @FormUrlEncoded()
  Future<AuthResponse> login(
    @Field('username') String username,
    @Field('password') String password,
  );

  @GET('/auth/me')
  Future<User> getCurrentUser();

  // Power Lines
  @GET('/power-lines')
  Future<List<PowerLine>> getPowerLines();

  @POST('/power-lines')
  Future<PowerLine> createPowerLine(@Body() PowerLineCreate powerLineData);

  @GET('/power-lines/{id}')
  Future<PowerLine> getPowerLine(@Path('id') int id);

  @GET('/power-lines/{id}/edit-hint')
  Future<JsonDict> getPowerLineEditHintRaw(@Path('id') int id);

  @PUT('/power-lines/{id}')
  Future<PowerLine> updatePowerLine(
    @Path('id') int id,
    @Body() Map<String, dynamic> body,
  );

  @DELETE('/power-lines/{id}')
  Future<void> deletePowerLine(@Path('id') int id);

  @POST('/power-lines/{id}/poles')
  Future<Pole> createPole(
    @Path('id') int powerLineId,
    @Body() PoleCreate poleData,
    @Query('from_pole_id') int? fromPoleId,
  );

  @PUT('/power-lines/{powerLineId}/poles/{poleId}')
  Future<Pole> updatePole(
    @Path('powerLineId') int powerLineId,
    @Path('poleId') int poleId,
    @Body() PoleCreate poleData,
  );

  @GET('/power-lines/{id}/poles')
  Future<List<Pole>> getPoles(@Path('id') int powerLineId);

  @POST('/power-lines/{id}/link-substation')
  Future<JsonDict> linkLineToSubstation(
    @Path('id') int powerLineId,
    @Body() Map<String, dynamic> body,
  );

  @DELETE('/power-lines/{powerLineId}/spans/{spanId}')
  Future<void> deleteSpan(@Path('powerLineId') int powerLineId, @Path('spanId') int spanId);

  @POST('/power-lines/{id}/spans/auto-create')
  Future<JsonDict> autoCreateSpans(@Path('id') int powerLineId);

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

  @PUT('/equipment/{id}')
  Future<Equipment> updateEquipment(
    @Path('id') int id,
    @Body() EquipmentCreate equipmentData,
  );

  // Map
  @GET('/map/power-lines/geojson')
  Future<JsonDict> getPowerLinesGeoJSON();

  @GET('/map/poles/geojson')
  Future<JsonDict> getTowersGeoJSON();

  @GET('/map/taps/geojson')
  Future<JsonDict> getTapsGeoJSON();

  @GET('/map/substations/geojson')
  Future<JsonDict> getSubstationsGeoJSON();

  @GET('/map/spans/geojson')
  Future<JsonDict> getSpansGeoJSON();

  @GET('/map/equipment/geojson')
  Future<JsonDict> getEquipmentGeoJSON();

  @GET('/map/find-uid')
  Future<JsonDict> findMapUid(@Query('q') String q);

  @GET('/map/overlay-routes/geojson')
  Future<JsonDict> getOverlayRoutesGeoJSON();

  // Substations
  @POST('/substations')
  Future<Substation> createSubstation(@Body() SubstationCreate substationData);

  @DELETE('/substations/{id}')
  Future<void> deleteSubstation(@Path('id') int id);

  @GET('/map/bounds')
  Future<JsonDict> getDataBounds();

  // Сессии обхода (админ видит все, инженер — свои)
  @GET('/patrol-sessions')
  Future<List<PatrolSession>> getPatrolSessions(
    @Query('user_id') int? userId,
    @Query('line_id') int? lineId,
    @Query('limit') int? limit,
    @Query('offset') int? offset,
  );

  @POST('/patrol-sessions')
  Future<JsonDict> createPatrolSession(
    @Body() Map<String, dynamic> body,
  );

  @PATCH('/patrol-sessions/{id}')
  Future<JsonDict> endPatrolSession(@Path('id') int id);

  @GET('/change-log')
  Future<List<JsonDict>> getChangeLog(
    @Query('source') String? source,
    @Query('action') String? action,
    @Query('entity_type') String? entityType,
    @Query('entity_id') int? entityId,
    @Query('limit') int? limit,
    @Query('offset') int? offset,
  );

  // CIM: карточка участка линии (AClineSegment)
  @GET('/cim/acline-segments/{id}')
  Future<JsonDict> getAclineSegment(@Path('id') int segmentId);

  // Sync
  @POST('/sync/upload')
  Future<JsonDict> uploadSyncBatch(@Body() Map<String, dynamic> batch);

  @GET('/sync/download')
  Future<JsonDict> downloadSyncData(@Query('last_sync') String lastSync);

  @GET('/sync/schemas')
  Future<JsonDict> getAllSchemas();

  @GET('/sync/schema/{entity_type}')
  Future<JsonDict> getEntitySchema(@Path('entity_type') String entityType);

  // Equipment catalog
  @GET('/equipment-catalog')
  Future<List<JsonDict>> getEquipmentCatalogRaw(
    @Query('type_code') String? typeCode,
    @Query('q') String? query,
    @Query('is_active') bool? isActive,
    @Query('skip') int? skip,
    @Query('limit') int? limit,
  );

  @POST('/equipment-catalog')
  Future<JsonDict> createEquipmentCatalogItemRaw(@Body() Map<String, dynamic> payload);

  @POST('/equipment-catalog/seed-defaults')
  Future<JsonDict> seedEquipmentCatalogDefaultsRaw();

}

/// Публичный HTTP-контракт приложения (Map / модели без `JsonDict` в типах для вызывающего кода).
abstract class ApiServiceWithExport {
  Future<AuthResponse> login(String username, String password);
  Future<User> getCurrentUser();

  Future<List<PowerLine>> getPowerLines();
  Future<PowerLine> createPowerLine(PowerLineCreate powerLineData);
  Future<PowerLine> getPowerLine(int id);
  Future<PowerLineEditHint> getPowerLineEditHint(int id);
  Future<PowerLine> updatePowerLine(int id, Map<String, dynamic> body);
  Future<void> deletePowerLine(int id);

  Future<Pole> createPole(int powerLineId, PoleCreate poleData, {int? fromPoleId});
  Future<Pole> updatePole(int powerLineId, int poleId, PoleCreate poleData);
  Future<List<Pole>> getPoles(int powerLineId);
  Future<Map<String, dynamic>> linkLineToSubstation(int powerLineId, Map<String, dynamic> body);
  Future<void> deleteSpan(int powerLineId, int spanId);
  Future<Map<String, dynamic>> autoCreateSpans(int powerLineId);

  Future<List<Pole>> getAllPoles();
  Future<Pole> getPole(int id);
  Future<void> deletePole(int id);

  Future<Equipment> createEquipment(int poleId, EquipmentCreate equipmentData);
  Future<List<Equipment>> getPoleEquipment(int poleId);
  Future<void> deletePoleEquipment(int poleId, int equipmentId);

  Future<List<Equipment>> getAllEquipment();
  Future<Equipment> getEquipment(int id);
  Future<Equipment> updateEquipment(
    int id,
    EquipmentCreate equipmentData, {
    int? poleId,
  });

  Future<Map<String, dynamic>> getPowerLinesGeoJSON();
  Future<Map<String, dynamic>> getTowersGeoJSON();
  Future<Map<String, dynamic>> getTapsGeoJSON();
  Future<Map<String, dynamic>> getSubstationsGeoJSON();
  Future<Map<String, dynamic>> getSpansGeoJSON();
  Future<Map<String, dynamic>> getEquipmentGeoJSON();

  /// Поиск на карте по mRID/UID (журнал, CIM). null — не найдено.
  Future<Map<String, dynamic>?> findMapUid(String q);

  Future<Substation> createSubstation(SubstationCreate substationData);
  Future<void> deleteSubstation(int id);

  Future<Map<String, dynamic>> getDataBounds();

  Future<List<PatrolSession>> getPatrolSessions(
    int? userId,
    int? lineId,
    int? limit,
    int? offset,
  );
  Future<Map<String, dynamic>> createPatrolSession(Map<String, dynamic> body);
  Future<Map<String, dynamic>> endPatrolSession(int id);
  Future<List<Map<String, dynamic>>> getChangeLog(
    String? source,
    String? action,
    String? entityType,
    int? entityId,
    int? limit,
    int? offset,
  );

  Future<Map<String, dynamic>> getAclineSegment(int segmentId);

  Future<Map<String, dynamic>> uploadSyncBatch(Map<String, dynamic> batch);
  Future<Map<String, dynamic>> downloadSyncData(String lastSync);
  Future<Map<String, dynamic>> getAllSchemas();
  Future<Map<String, dynamic>> getEntitySchema(String entityType);

  Future<List<Map<String, dynamic>>> getEquipmentCatalogRaw(
    String? typeCode,
    String? query,
    bool? isActive,
    int? skip,
    int? limit,
  );
  Future<Map<String, dynamic>> createEquipmentCatalogItemRaw(Map<String, dynamic> payload);

  Future<Map<String, dynamic>> seedEquipmentCatalogDefaultsRaw();

  Future<List<Map<String, dynamic>>> getLineConductorCatalogRaw(
    String? query,
    double? voltageKv,
    bool? isActive,
    int? skip,
    int? limit,
  );

  /// Бинарные ответы и multipart (не через Retrofit).
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

  /// Вложение карточки оборудования (те же типы, что у опоры).
  Future<Map<String, dynamic>> uploadEquipmentAttachment(
    int equipmentId,
    String attachmentType,
    List<int> fileBytes,
    String filename,
  );

  Future<List<EquipmentCatalogItem>> getEquipmentCatalog({
    String? typeCode,
    String? query,
    bool? isActive,
    int? skip,
    int? limit,
  });

  Future<Map<String, dynamic>> createEquipmentCatalogItem(Map<String, dynamic> payload);

  Future<Map<String, dynamic>> importEquipmentCatalog(
    List<int> fileBytes,
    String filename, {
    String mode = 'upsert',
  });

  Future<Map<String, dynamic>> importEquipmentCatalogRaw(
    MultipartFile file, {
    String mode = 'upsert',
  });

  Future<Map<String, dynamic>> seedEquipmentCatalogDefaults();
}

class ApiServiceProvider {
  static SharedPreferences? _prefs;

  static bool _isAuthCredentialPath(String path) {
    final p = path.toLowerCase();
    return p.contains('/auth/login');
  }

  /// 401 с защищённых эндпоинтов: очистить токен и вернуть пользователя на экран входа.
  static Future<void> handleUnauthorized(DioException error) async {
    if (error.response?.statusCode != 401) {
      return;
    }
    if (_isAuthCredentialPath(error.requestOptions.path)) {
      return;
    }
    // «Оставаться в системе»: не сбрасываем сессию — работаем офлайн, sync при появлении сети.
    if (_prefs != null && (_prefs!.getBool(AppConfig.stayLoggedInKey) ?? true)) {
      if (kDebugMode) {
        print('⚠️ [ApiService] 401 при stayLoggedIn — сессия сохранена для офлайн-режима');
      }
      return;
    }
    await _clearStoredToken();
    await notifySessionExpired();
  }
  
  static ApiServiceWithExport create({SharedPreferences? prefs}) {
    _prefs = prefs; // Сохраняем prefs статически
    final dio = Dio();
    configureDioSslTrust(dio);
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
            await handleUnauthorized(error);
            if (kDebugMode && !_isAuthCredentialPath(error.requestOptions.path)) {
              print('🔓 Токен истёк (401), сессия сброшена, переход на экран входа');
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

    final rest = LepmRetrofit(dio, baseUrl: dio.options.baseUrl);
    return _ApiServiceWrapper(rest, dio);
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
  configureDioSslTrust(dio);
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
  
  // Interceptor для автоматического fallback HTTPS -> HTTP + Bearer (как у ApiServiceProvider.create)
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

        if (error.response?.statusCode == 401) {
          await ApiServiceProvider.handleUnauthorized(error);
        }
        
        handler.next(error);
      },
    ),
  );
  
  return dio;
});

/// Обёртка над [LepmRetrofit]: Map-ответы, бинарный CIM-export, multipart.
class _ApiServiceWrapper implements ApiServiceWithExport {
  final LepmRetrofit _rest;
  final Dio _dio;

  _ApiServiceWrapper(this._rest, this._dio);

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
    };
    if (lineId != null) {
      queryParameters['line_id'] = lineId;
    }

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

  @override
  Future<Map<String, dynamic>> uploadEquipmentAttachment(
    int equipmentId,
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
      '/attachments/equipment/$equipmentId/attachments',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );
    final data = response.data;
    if (data == null) throw Exception('Пустой ответ при загрузке вложения оборудования');
    return data;
  }

  // Делегируем все остальные методы к базовому сервису
  @override
  Future<AuthResponse> login(String username, String password) => _rest.login(username, password);

  @override
  Future<User> getCurrentUser() => _rest.getCurrentUser();

  @override
  Future<List<PowerLine>> getPowerLines() => _rest.getPowerLines();

  @override
  Future<PowerLine> createPowerLine(PowerLineCreate powerLineData) => _rest.createPowerLine(powerLineData);

  @override
  Future<PowerLine> getPowerLine(int id) => _rest.getPowerLine(id);

  @override
  Future<PowerLineEditHint> getPowerLineEditHint(int id) async {
    final raw = await _rest.getPowerLineEditHintRaw(id);
    return PowerLineEditHint.fromJson(raw.data);
  }

  @override
  Future<PowerLine> updatePowerLine(int id, Map<String, dynamic> body) =>
      _rest.updatePowerLine(id, body);

  @override
  Future<void> deletePowerLine(int id) => _rest.deletePowerLine(id);

  @override
  Future<Pole> createPole(int powerLineId, PoleCreate poleData, {int? fromPoleId}) =>
      _rest.createPole(powerLineId, poleData, fromPoleId);

  @override
  Future<Pole> updatePole(int powerLineId, int poleId, PoleCreate poleData) =>
      _rest.updatePole(powerLineId, poleId, poleData);

  @override
  Future<List<Pole>> getPoles(int powerLineId) => _rest.getPoles(powerLineId);

  @override
  Future<Map<String, dynamic>> linkLineToSubstation(int powerLineId, Map<String, dynamic> body) =>
      _rest.linkLineToSubstation(powerLineId, body).then((j) => j.data);

  @override
  Future<void> deleteSpan(int powerLineId, int spanId) => _rest.deleteSpan(powerLineId, spanId);

  @override
  Future<Map<String, dynamic>> autoCreateSpans(int powerLineId) =>
      _rest.autoCreateSpans(powerLineId).then((j) => j.data);

  @override
  Future<List<Pole>> getAllPoles() => _rest.getAllPoles();

  @override
  Future<Pole> getPole(int id) => _rest.getPole(id);

  @override
  Future<void> deletePole(int id) => _rest.deletePole(id);

  @override
  Future<Equipment> createEquipment(int poleId, EquipmentCreate equipmentData) => _rest.createEquipment(poleId, equipmentData);

  @override
  Future<List<Equipment>> getPoleEquipment(int poleId) => _rest.getPoleEquipment(poleId);

  @override
  Future<void> deletePoleEquipment(int poleId, int equipmentId) =>
      _rest.deletePoleEquipment(poleId, equipmentId);

  @override
  Future<List<Equipment>> getAllEquipment() => _rest.getAllEquipment();

  @override
  Future<Equipment> getEquipment(int id) => _rest.getEquipment(id);

  @override
  Future<Equipment> updateEquipment(
    int id,
    EquipmentCreate equipmentData, {
    int? poleId,
  }) async {
    final body = Map<String, dynamic>.from(equipmentData.toJson())
      ..removeWhere((k, v) => v == null);
    if (poleId != null) {
      body['pole_id'] = poleId;
    }
    final response = await _dio.put<Map<String, dynamic>>(
      '/equipment/$id',
      data: body,
    );
    final data = response.data;
    if (data == null) {
      throw StateError('Пустой ответ при обновлении оборудования');
    }
    return Equipment.fromJson(data);
  }

  @override
  Future<Map<String, dynamic>> getPowerLinesGeoJSON() => _rest.getPowerLinesGeoJSON().then((j) => j.data);

  @override
  Future<Map<String, dynamic>> getTowersGeoJSON() => _rest.getTowersGeoJSON().then((j) => j.data);

  @override
  Future<Map<String, dynamic>> getTapsGeoJSON() => _rest.getTapsGeoJSON().then((j) => j.data);

  @override
  Future<Map<String, dynamic>> getSubstationsGeoJSON() =>
      _rest.getSubstationsGeoJSON().then((j) => j.data);

  @override
  Future<Map<String, dynamic>> getSpansGeoJSON() => _rest.getSpansGeoJSON().then((j) => j.data);

  @override
  Future<Map<String, dynamic>> getEquipmentGeoJSON() =>
      _rest.getEquipmentGeoJSON().then((j) => j.data);

  @override
  Future<Map<String, dynamic>?> findMapUid(String q) async {
    try {
      final j = await _rest.findMapUid(q.trim());
      return j.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> getAclineSegment(int segmentId) =>
      _rest.getAclineSegment(segmentId).then((j) => j.data);

  @override
  Future<Substation> createSubstation(SubstationCreate substationData) => _rest.createSubstation(substationData);

  @override
  Future<void> deleteSubstation(int id) => _rest.deleteSubstation(id);

  @override
  Future<Map<String, dynamic>> getDataBounds() => _rest.getDataBounds().then((j) => j.data);

  @override
  Future<List<PatrolSession>> getPatrolSessions(int? userId, int? lineId, int? limit, int? offset) =>
      _rest.getPatrolSessions(userId, lineId, limit, offset);

  @override
  Future<Map<String, dynamic>> createPatrolSession(Map<String, dynamic> body) =>
      _rest.createPatrolSession(body).then((j) => j.data);

  @override
  Future<Map<String, dynamic>> endPatrolSession(int id) =>
      _rest.endPatrolSession(id).then((j) => j.data);

  @override
  Future<List<Map<String, dynamic>>> getChangeLog(
    String? source,
    String? action,
    String? entityType,
    int? entityId,
    int? limit,
    int? offset,
  ) =>
      _rest
          .getChangeLog(source, action, entityType, entityId, limit, offset)
          .then((xs) => xs.map((x) => x.data).toList());

  @override
  Future<Map<String, dynamic>> uploadSyncBatch(Map<String, dynamic> batch) =>
      _rest.uploadSyncBatch(batch).then((j) => j.data);

  @override
  Future<Map<String, dynamic>> downloadSyncData(String lastSync) =>
      _rest.downloadSyncData(lastSync).then((j) => j.data);

  @override
  Future<Map<String, dynamic>> getAllSchemas() => _rest.getAllSchemas().then((j) => j.data);

  @override
  Future<Map<String, dynamic>> getEntitySchema(String entityType) =>
      _rest.getEntitySchema(entityType).then((j) => j.data);

  @override
  Future<List<Map<String, dynamic>>> getEquipmentCatalogRaw(
    String? typeCode,
    String? query,
    bool? isActive,
    int? skip,
    int? limit,
  ) =>
      _rest.getEquipmentCatalogRaw(typeCode, query, isActive, skip, limit).then(
            (xs) => xs.map((x) => x.data).toList(),
          );

  @override
  Future<Map<String, dynamic>> createEquipmentCatalogItemRaw(Map<String, dynamic> payload) =>
      _rest.createEquipmentCatalogItemRaw(payload).then((j) => j.data);

  @override
  Future<Map<String, dynamic>> importEquipmentCatalogRaw(
    MultipartFile file, {
    String mode = 'upsert',
  }) async {
    final formData = FormData.fromMap({'file': file});
    final response = await _dio.post<Map<String, dynamic>>(
      '/equipment-catalog/import',
      data: formData,
      queryParameters: {'mode': mode},
      options: Options(contentType: 'multipart/form-data'),
    );
    final data = response.data;
    if (data == null) {
      throw StateError('Пустой ответ equipment-catalog/import');
    }
    return data;
  }

  @override
  Future<Map<String, dynamic>> seedEquipmentCatalogDefaultsRaw() =>
      _rest.seedEquipmentCatalogDefaultsRaw().then((j) => j.data);

  @override
  Future<List<Map<String, dynamic>>> getLineConductorCatalogRaw(
    String? query,
    double? voltageKv,
    bool? isActive,
    int? skip,
    int? limit,
  ) async {
    final response = await _dio.get<List<dynamic>>(
      '/line-conductor-catalog',
      queryParameters: {
        if (query != null) 'q': query,
        if (voltageKv != null) 'voltage_kv': voltageKv,
        if (isActive != null) 'is_active': isActive,
        if (skip != null) 'skip': skip,
        if (limit != null) 'limit': limit,
      },
    );
    final data = response.data ?? const [];
    return data
        .whereType<Map>()
        .map((x) => Map<String, dynamic>.from(x))
        .toList();
  }

  @override
  Future<List<EquipmentCatalogItem>> getEquipmentCatalog({
    String? typeCode,
    String? query,
    bool? isActive,
    int? skip,
    int? limit,
  }) async {
    final raw = await _rest.getEquipmentCatalogRaw(typeCode, query, isActive, skip, limit);
    return raw.map((j) => EquipmentCatalogItem.fromJson(j.data)).toList();
  }

  @override
  Future<Map<String, dynamic>> createEquipmentCatalogItem(Map<String, dynamic> payload) async {
    final raw = await _rest.createEquipmentCatalogItemRaw(payload);
    return raw.data;
  }

  @override
  Future<Map<String, dynamic>> importEquipmentCatalog(
    List<int> fileBytes,
    String filename, {
    String mode = 'upsert',
  }) async {
    final part = MultipartFile.fromBytes(
      fileBytes,
      filename: filename,
      contentType: MediaType.parse('application/octet-stream'),
    );
    final raw = await importEquipmentCatalogRaw(part, mode: mode);
    return raw;
  }

  @override
  Future<Map<String, dynamic>> seedEquipmentCatalogDefaults() async {
    final raw = await _rest.seedEquipmentCatalogDefaultsRaw();
    return raw.data;
  }
}
