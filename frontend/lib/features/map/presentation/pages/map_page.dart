import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../../core/services/connectivity_status.dart';

// Платформенное скачивание: веб — через dart:html, мобильные — через файл
import 'file_download_stub.dart' if (dart.library.html) 'file_download_web.dart' as file_download;

import '../../../../core/services/api_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/services/pending_sync_provider.dart';
import '../../../../core/services/offline_map_service.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/config/pole_reference_data.dart';
import '../../../../core/database/database.dart' as drift_db;
import '../../../../core/models/power_line.dart';
import '../../../../core/models/substation.dart';
import '../../../towers/presentation/widgets/create_pole_dialog.dart';
import '../../../home/presentation/pages/home_page.dart' show activeSessionProvider, recentPatrolsProvider;
import '../widgets/object_properties_panel.dart' show ObjectPropertiesPanel, ObjectType;

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  late MapController _mapController;
  LatLng? _currentLocation;
  bool _isLoading = true;
  Map<String, dynamic>? _powerLinesData;
  Map<String, dynamic>? _polesData;
  Map<String, dynamic>? _tapsData;
  Map<String, dynamic>? _substationsData;
  List<PowerLine>? _powerLinesList; // Полный список ЛЭП для дерева
  String? _errorMessage;
  
  // Окно свойств объекта
  Map<String, dynamic>? _selectedObjectProperties;
  ObjectType? _selectedObjectType;
  bool _showObjectProperties = false;
  
  // Режим навигатора для формирования линии
  bool _isNavigatorMode = false;
  int? _startingPoleId; // ID опоры, от которой начинаем формирование линии
  int? _currentPowerLineId; // ID текущей ЛЭП
  StreamSubscription<Position>? _positionSubscription; // Подписка на обновления GPS
  
  // Настройки для быстрого создания опоры в режиме навигатора
  String _quickPoleNumber = '';
  String _quickPoleType = PoleReferenceData.defaultPoleType;
  String _quickConductorType = PoleReferenceData.defaultConductorType;
  String _quickConductorMaterial = PoleReferenceData.defaultConductorMaterial;
  String _quickConductorSection = PoleReferenceData.defaultConductorSection;
  bool _isEndPole = false; // Конечная опора (завершает AClineSegment)
  bool _isTapPole = false; // Отпаечная опора

  /// ID ЛЭП, раскрытых в дереве объектов (при клике на опору на карте)
  final Set<int> _expandedPowerLineIds = {};
  /// Обновили ли карту после завершения синхронизации (чтобы не дергать при каждом build)
  bool _hasRefreshedAfterSyncCompleted = false;
  /// Карта готова к использованию MapController (вызван onMapReady).
  bool _mapReady = false;
  /// Отложенное центрирование на объектах — применить в onMapReady, т.к. MapController нельзя использовать до первого рендера FlutterMap.
  LatLng? _pendingCenterOnObjects;
  /// Зум для отложенного центрирования (например 18 для созданной опоры).
  double? _pendingCenterZoom;

  /// Название текущей ЛЭП для кнопки «Завершить обход ЛЭП «…»».
  String get _currentPowerLineDisplayName {
    if (_currentPowerLineId == null || _powerLinesList == null) return 'ЛЭП';
    final match = _powerLinesList!.where((pl) => pl.id == _currentPowerLineId);
    return match.isEmpty ? 'ЛЭП' : match.first.name;
  }
  /// Отложенное центрирование на текущее местоположение (пока карта не готова).
  LatLng? _pendingCenterOnLocation;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    // Откладываем инициализацию до следующего кадра для быстрого отображения UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMap();
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Загружаем местоположение и данные параллельно для ускорения
      await Future.wait([
        _getCurrentLocation(),
        _loadMapData(),
      ]);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Ошибка инициализации карты: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage ?? 'Ошибка инициализации карты'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Повторить',
              onPressed: _initializeMap,
            ),
          ),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _currentLocation = const LatLng(53.9045, 27.5615); // Минск по умолчанию
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _currentLocation = const LatLng(53.9045, 27.5615);
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _currentLocation = const LatLng(53.9045, 27.5615);
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });

      if (_mapReady) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _currentLocation != null) {
            try {
              _mapController.move(_currentLocation!, AppConfig.defaultZoom);
            } catch (e) {
              print('Ошибка центрирования карты: $e');
            }
          }
        });
      } else {
        _pendingCenterOnLocation = _currentLocation;
      }
    } catch (e) {
      print('Ошибка получения местоположения: $e');
      setState(() {
        _currentLocation = const LatLng(53.9045, 27.5615);
      });
    }
  }

  /// Загрузка данных карты из локальной БД (оффлайн-режим)
  Future<void> _loadMapDataFromLocal() async {
    if (!mounted) return;
    try {
      final db = ref.read(drift_db.databaseProvider);
      final allPoles = await db.getAllPoles();
      final allPowerLines = await db.getAllPowerLines();

      final poleFeatures = allPoles.map((p) => {
        'type': 'Feature',
        'geometry': {'type': 'Point', 'coordinates': [p.longitude, p.latitude]},
        'properties': {
          'id': p.id,
          'power_line_id': p.powerLineId,
          'pole_number': p.poleNumber,
          'pole_type': p.poleType,
          'condition': p.condition,
          'latitude': p.latitude,
          'longitude': p.longitude,
          'is_local': p.isLocal,
          'needs_sync': p.needsSync,
        },
      }).toList();

      final powerLineFeatures = <Map<String, dynamic>>[];
      for (final pl in allPowerLines) {
        final plPoles = allPoles.where((p) => p.powerLineId == pl.id).toList()
          ..sort((a, b) => a.poleNumber.compareTo(b.poleNumber));
        if (plPoles.length >= 2) {
          powerLineFeatures.add({
            'type': 'Feature',
            'geometry': {
              'type': 'LineString',
              'coordinates': plPoles.map((p) => [p.longitude, p.latitude]).toList(),
            },
            'properties': {'id': pl.id, 'name': pl.name, 'is_local': pl.isLocal},
          });
        }
      }

      if (mounted) {
        setState(() {
          _polesData = {'type': 'FeatureCollection', 'features': poleFeatures};
          _powerLinesData = {'type': 'FeatureCollection', 'features': powerLineFeatures};
          _tapsData = {'type': 'FeatureCollection', 'features': <dynamic>[]};
          _substationsData = {'type': 'FeatureCollection', 'features': <dynamic>[]};
          _powerLinesList = allPowerLines.map((pl) => PowerLine(
            id: pl.id,
            name: pl.name,
            code: pl.code,
            voltageLevel: pl.voltageLevel,
            length: pl.length,
            branchId: pl.branchId,
            createdBy: pl.createdBy,
            status: pl.status,
            description: pl.description,
            createdAt: pl.createdAt,
            updatedAt: pl.updatedAt,
            poles: null,
            aclineSegments: null,
          )).toList();
          _errorMessage = null;
        });
        _applyActiveSessionIfNeeded();
        _centerOnObjects();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Ошибка загрузки локальных данных: $e');
      }
    }
  }

  /// Устанавливает текущую ЛЭП из активной сессии обхода, если она есть в списке линий.
  void _applyActiveSessionIfNeeded() {
    final prefs = ref.read(prefsProvider);
    if (prefs == null) return;
    final sessionLineId = prefs.getInt(AppConfig.activeSessionPowerLineIdKey);
    if (sessionLineId == null) return;
    if (_powerLinesList != null &&
        _powerLinesList!.any((pl) => pl.id == sessionLineId)) {
      setState(() => _currentPowerLineId = sessionLineId);
    }
  }

  /// Сбросить активную сессию обхода, если она привязана к указанной линии (например, при удалении линии).
  Future<void> _clearActiveSessionIfLine(int powerLineId) async {
    final prefs = ref.read(prefsProvider);
    if (prefs == null) return;
    final sessionLineId = prefs.getInt(AppConfig.activeSessionPowerLineIdKey);
    if (sessionLineId != powerLineId) return;
    await prefs.remove(AppConfig.activeSessionPowerLineIdKey);
    await prefs.remove(AppConfig.activeSessionStartTimeKey);
    await prefs.remove(AppConfig.activeSessionNoteKey);
    await prefs.remove(AppConfig.activeSessionLatKey);
    await prefs.remove(AppConfig.activeSessionLonKey);
    if (mounted) setState(() => _currentPowerLineId = null);
  }

  /// Завершить текущий обход: сброс активной сессии и текущей ЛЭП.
  Future<void> _finishPatrol() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Завершить обход?'),
        content: const Text(
          'Текущая сессия обхода будет завершена. Вы сможете начать новый обход с главного экрана.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Завершить обход'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final prefs = ref.read(prefsProvider);
    final localSessionId = prefs?.getInt(AppConfig.activeSessionLocalIdKey);
    if (localSessionId != null) {
      final db = ref.read(drift_db.databaseProvider);
      final row = await db.getPatrolSession(localSessionId);
      if (row != null) {
        await db.setPatrolSessionEnded(localSessionId, DateTime.now());
        if (row.serverId != null) {
          try {
            final apiService = ref.read(apiServiceProvider);
            await apiService.endPatrolSession(row.serverId!);
          } catch (_) {
            // Офлайн: сессия помечена завершённой локально, уйдёт на сервер при синхронизации
          }
        }
      }
    }
    if (localSessionId == null) {
      final serverSessionId = prefs?.getInt(AppConfig.activeSessionServerIdKey);
      if (serverSessionId != null) {
        try {
          final apiService = ref.read(apiServiceProvider);
          await apiService.endPatrolSession(serverSessionId);
        } catch (_) {
          // Офлайн — сервер получит при следующей синхронизации (если сессия была создана с сервера)
        }
      }
    }
    if (prefs != null) {
      await prefs.remove(AppConfig.activeSessionPowerLineIdKey);
      await prefs.remove(AppConfig.activeSessionStartTimeKey);
      await prefs.remove(AppConfig.activeSessionNoteKey);
      await prefs.remove(AppConfig.activeSessionLatKey);
      await prefs.remove(AppConfig.activeSessionLonKey);
      await prefs.remove(AppConfig.activeSessionLocalIdKey);
      await prefs.remove(AppConfig.activeSessionServerIdKey);
    }
    ref.invalidate(pendingPatrolSessionsCountProvider);
    ref.invalidate(hasPendingSyncProvider);
    ref.invalidate(activeSessionProvider);
    if (!mounted) return;
    setState(() => _currentPowerLineId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Обход завершён'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _loadMapData() async {
    if (!mounted) return;
    
    try {
      // Проверяем авторизацию перед загрузкой данных
      final authState = ref.read(authStateProvider);
      if (authState is! AuthStateAuthenticated) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Требуется авторизация. Пожалуйста, войдите в систему.';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Требуется авторизация. Пожалуйста, войдите в систему.'),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'Войти',
                onPressed: () {
                  if (mounted) {
                    context.go('/login');
                  }
                },
              ),
            ),
          );
        }
        return;
      }

      final connectivityResult = await Connectivity().checkConnectivity();
      final isOffline = connectivityResult == ConnectivityResult.none;

      if (isOffline) {
        await _loadMapDataFromLocal();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Режим оффлайн: показаны локальные данные. Синхронизация при подключении.'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      
      final apiService = ref.read(apiServiceProvider);
      final db = ref.read(drift_db.databaseProvider);
      
      // Загружаем данные параллельно
      final futures = await Future.wait([
        apiService.getPowerLinesGeoJSON(),
        apiService.getTowersGeoJSON(),
        apiService.getTapsGeoJSON(),
        apiService.getSubstationsGeoJSON(),
        apiService.getPowerLines(), // Полные данные ЛЭП для дерева
      ]);

      var powerLinesData = futures[0] as Map<String, dynamic>;
      var polesData = futures[1] as Map<String, dynamic>;
      final tapsData = futures[2] as Map<String, dynamic>;
      final substationsData = futures[3] as Map<String, dynamic>;
      var powerLinesList = futures[4] as List<PowerLine>;

      // Добавляем локальные несинхронизированные опоры к данным с сервера
      final localPoles = await db.getPolesNeedingSync();
      if (localPoles.isNotEmpty) {
        final serverFeatures = List<dynamic>.from(polesData['features'] ?? []);
        for (final p in localPoles) {
          serverFeatures.add({
            'type': 'Feature',
            'geometry': {'type': 'Point', 'coordinates': [p.longitude, p.latitude]},
            'properties': {
              'id': p.id,
              'power_line_id': p.powerLineId,
              'pole_number': p.poleNumber,
              'pole_type': p.poleType,
              'condition': p.condition,
              'latitude': p.latitude,
              'longitude': p.longitude,
              'is_local': true,
              'needs_sync': true,
            },
          });
        }
        polesData = {'type': 'FeatureCollection', 'features': serverFeatures};
      }

      if (mounted) {
        // Уменьшаем логирование
        if (kDebugMode) {
          print('✅ Загружено: ЛЭП: ${(powerLinesData['features'] as List?)?.length ?? 0}, '
              'Опоры: ${(polesData['features'] as List?)?.length ?? 0}, '
              'Отпайки: ${(tapsData['features'] as List?)?.length ?? 0}, '
              'Подстанции: ${(substationsData['features'] as List?)?.length ?? 0}');
        }

        setState(() {
          _powerLinesData = powerLinesData;
          _polesData = polesData;
          _tapsData = tapsData;
          _substationsData = substationsData;
          _powerLinesList = powerLinesList;
          _errorMessage = null;
        });
        _applyActiveSessionIfNeeded();

        _centerOnObjects();
      }
    } catch (e) {
      print('❌ Ошибка загрузки данных карты: $e');

      // Ошибка соединения или таймаут — показываем карту из локальной БД (офлайн)
      final isConnectionError = e is DioException &&
          (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout);
      if (isConnectionError && mounted) {
        await _loadMapDataFromLocal();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Нет связи с сервером. Показаны локальные данные. Синхронизация при подключении.'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Проверяем, не ошибка ли авторизации (401)
      if (e is DioException && e.response?.statusCode == 401) {
        if (mounted) {
          final auth = ref.read(authServiceProvider.notifier);
          if (auth.getStayLoggedIn()) {
            // Режим «оставаться в системе»: не выходим, работаем оффлайн
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Нет связи с сервером. Данные будут загружены при подключении.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
            await _loadMapDataFromLocal();
          } else {
            await auth.logout();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Сессия истекла. Пожалуйста, войдите снова.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
        return;
      }
      
      if (mounted) {
        setState(() {
          _errorMessage = 'Ошибка загрузки данных: ${e.toString()}';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки данных: ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Повторить',
              onPressed: _loadMapData,
            ),
          ),
        );
      }
    }
  }

  void _centerOnObjects() {
    LatLng? center;
    
    if (_polesData != null) {
      final features = _polesData!['features'] as List<dynamic>?;
      if (features != null && features.isNotEmpty) {
        final firstFeature = features[0];
        final geometry = firstFeature['geometry'] as Map<String, dynamic>?;
        if (geometry != null && geometry['type'] == 'Point') {
          final coords = geometry['coordinates'] as List<dynamic>;
          center = LatLng(coords[1] as double, coords[0] as double);
        }
      }
    }
    
    if (center == null && _substationsData != null) {
      final features = _substationsData!['features'] as List<dynamic>?;
      if (features != null && features.isNotEmpty) {
        final firstFeature = features[0];
        final geometry = firstFeature['geometry'] as Map<String, dynamic>?;
        if (geometry != null && geometry['type'] == 'Point') {
          final coords = geometry['coordinates'] as List<dynamic>;
          center = LatLng(coords[1] as double, coords[0] as double);
        }
      }
    }

    if (center == null || !mounted) return;
    if (_mapReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _mapReady) {
          try {
            _mapController.move(center!, AppConfig.defaultZoom);
          } catch (e) {
            print('Ошибка центрирования на объектах: $e');
          }
        }
      });
    } else {
      _pendingCenterOnObjects = center;
    }
  }

  @override
  Widget build(BuildContext context) {
    // После успешной синхронизации обновляем карту (локальные ЛЭП/опоры уже в Drift и на сервере)
    ref.listen<SyncState>(syncStateProvider, (prev, next) {
      final nextCompleted = next.when(idle: () => false, syncing: () => false, completed: () => true, error: (_) => false);
      final prevCompleted = prev?.when(idle: () => false, syncing: () => false, completed: () => true, error: (_) => false) ?? false;
      if (!nextCompleted) _hasRefreshedAfterSyncCompleted = false;
      if (nextCompleted && !prevCompleted && mounted) {
        _hasRefreshedAfterSyncCompleted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadMapData());
      }
    });
    // Если открыли карту, а синхронизация уже завершена — один раз обновить данные
    final syncState = ref.watch(syncStateProvider);
    final syncCompleted = syncState.when(idle: () => false, syncing: () => false, completed: () => true, error: (_) => false);
    if (syncCompleted && !_hasRefreshedAfterSyncCompleted && mounted) {
      _hasRefreshedAfterSyncCompleted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadMapData());
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Карта'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportCimXml,
            tooltip: 'Экспорт в CIM XML',
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _centerOnCurrentLocation,
            tooltip: 'Мое местоположение',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMapData,
            tooltip: 'Обновить данные',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authServiceProvider.notifier).logout();
              if (mounted) {
                context.go('/login');
              }
            },
            tooltip: 'Выйти',
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation ?? const LatLng(53.9045, 27.5615),
                    initialZoom: AppConfig.defaultZoom,
                    minZoom: AppConfig.minZoom,
                    maxZoom: AppConfig.maxZoom,
                    onMapReady: () {
                      _mapReady = true;
                      try {
                        final target = _pendingCenterOnObjects ?? _pendingCenterOnLocation ?? _currentLocation;
                        final zoom = _pendingCenterZoom ?? AppConfig.defaultZoom;
                        if (target != null) {
                          _mapController.move(target, zoom);
                        }
                        _pendingCenterOnObjects = null;
                        _pendingCenterZoom = null;
                        _pendingCenterOnLocation = null;
                      } catch (e) {
                        print('Ошибка центрирования при готовности карты: $e');
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      tileProvider: OfflineMapService.instance.getTileProvider(),
                      errorTileCallback: (tile, error, stackTrace) {
                        final errorStr = error.toString().toLowerCase();
                        if (errorStr.contains('aborttrigger') ||
                            errorStr.contains('requestabortedexception') ||
                            errorStr.contains('request aborted') ||
                            errorStr.contains('fmctbrowsingerror') ||
                            errorStr.contains('noconnectionduringfetch')) {
                          return; // Ожидаемо при офлайне или отмене — не логируем
                        }
                        if (kDebugMode) {
                          print('⚠️ Ошибка загрузки тайла: $error');
                        }
                      },
                      maxNativeZoom: 19,
                      maxZoom: 18,
                      userAgentPackageName: 'com.lepm.mobile',
                    ),
                    
                    if (_powerLinesData != null)
                      PolylineLayer(
                        polylines: _buildPowerLinePolylines(),
                      ),
                    
                    if (_polesData != null)
                      MarkerLayer(
                        markers: _buildPoleMarkers(),
                      ),
                    
                    if (_tapsData != null)
                      MarkerLayer(
                        markers: _buildTapMarkers(),
                      ),
                    
                    if (_substationsData != null)
                      MarkerLayer(
                        markers: _buildSubstationMarkers(),
                      ),
                    
                    if (_currentLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentLocation!,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.blue,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                // Статус подключения (Онлайн / Офлайн / Нестабильно) сверху по центру
                Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _MapConnectionStatusBadge(status: ref.watch(connectivityStatusProvider)),
                  ),
                ),

                // Кнопка «Завершить обход ЛЭП «…»» — показывается при активной сессии
                if (_currentPowerLineId != null)
                  Positioned(
                    top: 50,
                    left: 16,
                    child: Material(
                      elevation: 2,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: _finishPatrol,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.stop_circle, size: 20, color: Colors.red.shade700),
                              const SizedBox(width: 6),
                              Text(
                                'Завершить обход ЛЭП «$_currentPowerLineDisplayName»',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                
                // Быстрое меню настроек в режиме навигатора (не блокирует экран)
                if (_isNavigatorMode)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 250, maxHeight: 400),
                        child: SingleChildScrollView(
                          child: _buildQuickSettingsMenu(),
                        ),
                      ),
                    ),
                  ),
                
                // Кнопка создания опоры / остановки навигатора
                // Позиционируем выше, если открыта панель свойств
                Positioned(
                  bottom: _showObjectProperties ? 300 : 16,
                  right: 16,
                  child: _isNavigatorMode
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            FloatingActionButton.extended(
                              onPressed: _createPoleInNavigatorMode,
                              icon: const Icon(Icons.add_location_alt),
                              label: const Text('Создать опору'),
                              tooltip: 'Создать опору и автоматически сформировать пролёт',
                              backgroundColor: Colors.green,
                            ),
                            const SizedBox(height: 8),
                            FloatingActionButton(
                              onPressed: _stopLineFormation,
                              tooltip: 'Остановить формирование линии',
                              backgroundColor: Colors.red,
                              child: const Icon(Icons.stop),
                            ),
                          ],
                        )
                      : FloatingActionButton.extended(
                          onPressed: _currentPowerLineId != null ? _showCreatePoleDialog : null,
                          icon: const Icon(Icons.add_location_alt),
                          label: const Text('Создать опору'),
                          tooltip: _currentPowerLineId != null
                              ? 'Создать опору в линии текущего обхода'
                              : 'Начните обход ЛЭП, чтобы создавать опоры',
                        ),
                ),
                
                // Окно свойств объекта
                if (_showObjectProperties && _selectedObjectProperties != null && _selectedObjectType != null)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    left: 0,
                    child: ObjectPropertiesPanel(
                      objectProperties: _selectedObjectProperties!,
                      objectType: _selectedObjectType!,
                      onClose: _closeObjectProperties,
                      onStartLineFormation: _selectedObjectType == ObjectType.pole
                          ? () {
                              final poleId = _selectedObjectProperties!['id'] as int?;
                              final powerLineId = _selectedObjectProperties!['power_line_id'] as int?;
                              if (poleId != null && powerLineId != null) {
                                _closeObjectProperties();
                                _startLineFormation(poleId, powerLineId);
                              }
                            }
                          : null,
                      onDelete: _handleDeleteObject,
                    ),
                  ),
              ],
            ),
      floatingActionButton: null, // Отключаем стандартный FAB, используем Positioned
    );
  }

  List<Polyline> _buildPowerLinePolylines() {
    final polylines = <Polyline>[];
    final features = _powerLinesData?['features'] as List<dynamic>? ?? [];
    final powerLineIdsWithGeometry = <int>{};

    for (final feature in features) {
      try {
        final geometry = feature['geometry'] as Map<String, dynamic>?;
        final props = feature['properties'] as Map<String, dynamic>?;
        if (geometry != null && geometry['type'] == 'LineString') {
          final coordinates = geometry['coordinates'] as List<dynamic>?;
          if (coordinates != null && coordinates.isNotEmpty) {
            final id = props != null ? _toInt(props['id']) : null;
            if (id != null) powerLineIdsWithGeometry.add(id);
            final points = coordinates.map((coord) => LatLng(
              (coord[1] as num).toDouble(),
              (coord[0] as num).toDouble(),
            )).toList();
            final isCurrentPatrol = id != null && id == _currentPowerLineId;
            polylines.add(
              Polyline(
                points: points,
                strokeWidth: isCurrentPatrol ? 5.0 : 3.0,
                color: isCurrentPatrol ? Colors.green : Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        print('Ошибка при построении полилинии ЛЭП: $e');
      }
    }

    // Опоры без связи: ЛЭП есть в опорах, но геометрии линии нет на сервере — строим линию по точкам опор
    final poleFeatures = _polesData?['features'] as List<dynamic>? ?? [];
    final polesByPowerLine = <int, List<Map<String, dynamic>>>{};
    for (final feature in poleFeatures) {
      try {
        final props = feature['properties'] as Map<String, dynamic>?;
        final geom = feature['geometry'] as Map<String, dynamic>?;
        final plId = props != null ? _toInt(props['power_line_id']) : null;
        if (plId == null || geom == null || geom['type'] != 'Point') continue;
        final coords = geom['coordinates'] as List<dynamic>?;
        if (coords == null || coords.length < 2) continue;
        polesByPowerLine.putIfAbsent(plId, () => []).add({
          'lat': (coords[1] as num).toDouble(),
          'lng': (coords[0] as num).toDouble(),
          'pole_number': props!['pole_number']?.toString() ?? '',
        });
      } catch (_) {}
    }
    for (final entry in polesByPowerLine.entries) {
      final powerLineId = entry.key;
      if (powerLineIdsWithGeometry.contains(powerLineId)) continue;
      final list = entry.value;
      if (list.length < 2) continue;
      list.sort((a, b) => (a['pole_number'] as String).compareTo(b['pole_number'] as String));
      final points = list.map((e) => LatLng(e['lat'] as double, e['lng'] as double)).toList();
      final isCurrentPatrol = powerLineId == _currentPowerLineId;
      polylines.add(
        Polyline(
          points: points,
          strokeWidth: isCurrentPatrol ? 5.0 : 3.0,
          color: isCurrentPatrol ? Colors.green : Colors.orange,
        ),
      );
    }

    return polylines;
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// Формат номинала напряжения: «н/д» при отсутствии или 0, иначе «X кВ».
  static String _formatVoltageDisplay(double? voltageLevel) {
    if (voltageLevel == null || voltageLevel == 0) return 'н/д';
    final v = voltageLevel == voltageLevel.roundToDouble()
        ? voltageLevel.toInt()
        : voltageLevel;
    return '$v кВ';
  }

  List<Marker> _buildPoleMarkers() {
    final markers = <Marker>[];
    final features = _polesData?['features'] as List<dynamic>? ?? [];

    for (final feature in features) {
      try {
        final geometry = feature['geometry'] as Map<String, dynamic>?;
        final properties = feature['properties'] as Map<String, dynamic>?;
        
        if (geometry != null && geometry['type'] == 'Point') {
          final coordinates = geometry['coordinates'] as List<dynamic>?;
          if (coordinates != null && coordinates.length >= 2) {
            final latLng = LatLng(
              (coordinates[1] as num).toDouble(),
              (coordinates[0] as num).toDouble(),
            );
            
            // Добавляем координаты в properties для использования в _showPoleInfo
            final poleProperties = Map<String, dynamic>.from(properties ?? {});
            poleProperties['latitude'] = latLng.latitude;
            poleProperties['longitude'] = latLng.longitude;

            final plId = _toInt(properties?['power_line_id']);
            final isCurrentPatrolLine = _currentPowerLineId != null && plId == _currentPowerLineId;

            markers.add(
              Marker(
                point: latLng,
                child: GestureDetector(
                  onTap: () => _showPoleInfo(poleProperties),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isCurrentPatrolLine ? Colors.green : Colors.blue,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white,
                        width: isCurrentPatrolLine ? 3 : 2,
                      ),
                      boxShadow: isCurrentPatrolLine
                          ? [BoxShadow(color: Colors.green.withOpacity(0.5), blurRadius: 6, spreadRadius: 1)]
                          : null,
                    ),
                    child: Icon(
                      MdiIcons.transmissionTower,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            );
          }
        }
      } catch (e) {
        print('Ошибка при построении маркера опоры: $e');
      }
    }

    return markers;
  }

  List<Marker> _buildTapMarkers() {
    final markers = <Marker>[];
    final features = _tapsData?['features'] as List<dynamic>? ?? [];

    for (final feature in features) {
      try {
        final geometry = feature['geometry'] as Map<String, dynamic>?;
        final properties = feature['properties'] as Map<String, dynamic>?;
        
        if (geometry != null && geometry['type'] == 'Point') {
          final coordinates = geometry['coordinates'] as List<dynamic>?;
          if (coordinates != null && coordinates.length >= 2) {
            final latLng = LatLng(
              (coordinates[1] as num).toDouble(),
              (coordinates[0] as num).toDouble(),
            );
            
            markers.add(
              Marker(
                point: latLng,
                child: GestureDetector(
                  onTap: () => _showTapInfo(properties ?? {}),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.electrical_services,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            );
          }
        }
      } catch (e) {
        print('Ошибка при построении маркера отпайки: $e');
      }
    }

    return markers;
  }

  List<Marker> _buildSubstationMarkers() {
    final markers = <Marker>[];
    final features = _substationsData?['features'] as List<dynamic>? ?? [];

    for (final feature in features) {
      try {
        final geometry = feature['geometry'] as Map<String, dynamic>?;
        final properties = feature['properties'] as Map<String, dynamic>?;
        
        if (geometry != null && geometry['type'] == 'Point') {
          final coordinates = geometry['coordinates'] as List<dynamic>?;
          if (coordinates != null && coordinates.length >= 2) {
            final latLng = LatLng(
              (coordinates[1] as num).toDouble(),
              (coordinates[0] as num).toDouble(),
            );
            
            markers.add(
              Marker(
                point: latLng,
                child: GestureDetector(
                  onTap: () => _showSubstationInfo(properties ?? {}),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.power,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            );
          }
        }
      } catch (e) {
        print('Ошибка при построении маркера подстанции: $e');
      }
    }

    return markers;
  }

  Widget _buildLegend() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Легенда',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildLegendItem(Icons.electrical_services, Colors.red, 'ЛЭП'),
            _buildLegendItem(MdiIcons.transmissionTower, Colors.blue, 'Опоры'),
            _buildLegendItem(Icons.electrical_services, Colors.orange, 'Отпайки'),
            _buildLegendItem(Icons.power, Colors.purple, 'Подстанции'),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Главная'),
            onTap: () {
              Navigator.of(context).pop();
              context.go('/');
            },
          ),
          const Divider(height: 1),
          // Блок "Обход" — начало/продолжение обхода (офлайн-сценарий).
          // Контейнер без фиксированной высоты, чтобы избежать BOTTOM OVERFLOW при переносе кнопок.
          Container(
            width: double.infinity,
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Обход',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Справочники доступны офлайн. Данные синхронизируются при появлении связи.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showCreatePowerLineDialog();
                        },
                        icon: const Icon(Icons.add_road, size: 20),
                        label: const Text('Новый обход'),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showContinuePatrolSheet();
                        },
                        icon: const Icon(Icons.play_arrow, size: 20),
                        label: const Text('Продолжить'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Линии и подстанции
          Expanded(
            child: GestureDetector(
              onLongPress: () => _showRootContextMenu(context),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (_powerLinesList != null && _powerLinesList!.isNotEmpty)
                    ..._powerLinesList!.map<Widget>((powerLine) =>
                        _buildPowerLineTreeItem(powerLine)),
                  if (_substationsData != null) ..._buildSubstationsList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Показать выбор линии для продолжения обхода (офлайн: список из локальной/загруженной модели).
  void _showContinuePatrolSheet() {
    final list = _powerLinesList ?? [];
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нет линий. Создайте новую через «Новый обход» или меню на карте.'),
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Продолжить обход по линии',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final pl = list[index];
                  return ListTile(
                    leading: const Icon(Icons.electrical_services),
                    title: Text(
                      pl.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${_formatVoltageDisplay(pl.voltageLevel)} • ${pl.code}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      setState(() {
                        _expandedPowerLineIds.add(pl.id);
                        _currentPowerLineId = pl.id;
                      });
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerLineTreeItem(PowerLine powerLine) {
    // Загружаем детали линии при разворачивании (lazy loading)
    final geoFeature = _findPowerLineInGeoJSON(powerLine.id);
    final initiallyExpanded = _expandedPowerLineIds.contains(powerLine.id);

    return GestureDetector(
      onLongPress: () => _showPowerLineContextMenu(powerLine),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        leading: const Icon(Icons.electrical_services, size: 14, color: Colors.red),
        title: Text(
          powerLine.name,
          style: const TextStyle(fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _formatVoltageDisplay(powerLine.voltageLevel),
          style: const TextStyle(fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
        // Список AClineSegments напрямую (без обобщения)
        ..._buildAClineSegmentsTree(powerLine.aclineSegments ?? []),
        // Опоры напрямую (без папки обобщения)
        ...(powerLine.poles ?? []).map<Widget>((pole) {
          final geoPole = _findPoleInGeoJSON(pole.id);
          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 32, right: 8),
            leading: Icon(MdiIcons.transmissionTower, size: 12, color: Colors.blue),
            title: Text(
              pole.poleNumber,
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${pole.poleType}',
              style: const TextStyle(fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              Navigator.of(context).pop();
              if (geoPole != null) {
                _centerOnFeature(geoPole);
                _showPoleInfo(geoPole['properties'] ?? {});
              }
            },
          );
        }),
      ],
      onExpansionChanged: (expanded) async {
        if (expanded && (powerLine.poles == null || powerLine.aclineSegments == null)) {
          // Lazy loading: загружаем детали только при разворачивании
          await _loadPowerLineDetails(powerLine.id);
        }
        if (expanded && geoFeature != null) {
          // Центрируем карту на линии при разворачивании
          _centerOnFeature(geoFeature);
        }
      },
      ),
    );
  }

  Map<String, dynamic>? _findPowerLineInGeoJSON(int powerLineId) {
    final features = _powerLinesData?['features'] as List<dynamic>? ?? [];
    for (final feature in features) {
      final props = feature['properties'] as Map<String, dynamic>?;
      if (props != null && props['id'] == powerLineId) {
        return feature as Map<String, dynamic>;
      }
    }
    return null;
  }

  Map<String, dynamic>? _findPoleInGeoJSON(int poleId) {
    final features = _polesData?['features'] as List<dynamic>? ?? [];
    for (final feature in features) {
      final props = feature['properties'] as Map<String, dynamic>?;
      if (props != null && props['id'] == poleId) {
        return feature as Map<String, dynamic>;
      }
    }
    return null;
  }

  Future<void> _loadPowerLineDetails(int powerLineId) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final powerLine = await apiService.getPowerLine(powerLineId);
      
      if (mounted) {
        setState(() {
          final index = _powerLinesList?.indexWhere((pl) => pl.id == powerLineId);
          if (index != null && index >= 0 && _powerLinesList != null) {
            _powerLinesList![index] = powerLine;
          }
        });
      }
    } catch (e) {
      print('Ошибка загрузки деталей ЛЭП: $e');
    }
  }

  List<Widget> _buildAClineSegmentsTree(List<dynamic> aclineSegments) {
    if (aclineSegments.isEmpty) {
      return [
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 32, right: 8),
          title: Text(
            'Участки не найдены',
            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey[600]),
          ),
        ),
      ];
    }

    return aclineSegments.map<Widget>((segment) {
      final segmentData = segment as Map<String, dynamic>;
      final segmentId = segmentData['id'] as int?;
      final segmentName = segmentData['name'] as String? ?? 'Без названия';
      final lineSections = segmentData['line_sections'] as List<dynamic>? ?? [];
      
      return ExpansionTile(
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        leading: Icon(
          segmentData['is_tap'] == true ? Icons.call_split : Icons.polyline,
          size: 12,
          color: segmentData['is_tap'] == true ? Colors.orange : Colors.green,
        ),
        title: Text(
          segmentName,
          style: const TextStyle(fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${lineSections.length} секций',
          style: const TextStyle(fontSize: 10),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: _buildLineSectionsTree(lineSections),
      );
    }).toList();
  }

  List<Widget> _buildLineSectionsTree(List<dynamic> lineSections) {
    if (lineSections.isEmpty) {
      return [
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 48, right: 8),
          title: Text(
            'Секции не найдены',
            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey[600]),
          ),
        ),
      ];
    }

    return lineSections.map<Widget>((section) {
      final sectionData = section as Map<String, dynamic>;
      final sectionId = sectionData['id'] as int?;
      final sectionName = sectionData['name'] as String? ?? 'Без названия';
      final spans = sectionData['spans'] as List<dynamic>? ?? [];
      
      return ExpansionTile(
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        leading: const Icon(Icons.segment, size: 12, color: Colors.blue),
        title: Text(
          sectionName,
          style: const TextStyle(fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${spans.length} пролётов • ${sectionData['conductor_type'] ?? 'N/A'}',
          style: const TextStyle(fontSize: 10),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: _buildSpansTree(spans),
      );
    }).toList();
  }

  List<Widget> _buildSpansTree(List<dynamic> spans) {
    if (spans.isEmpty) {
      return [
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 64, right: 8),
          title: Text(
            'Пролёты не найдены',
            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey[600]),
          ),
        ),
      ];
    }

    return spans.map<Widget>((span) {
      final spanData = span as Map<String, dynamic>;
      final spanNumber = spanData['span_number'] as String? ?? 'N/A';
      final spanLength = spanData['length'] as num? ?? 0;
      
      return ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 48, right: 8),
        leading: const Icon(Icons.arrow_forward, size: 10),
        title: Text(
          spanNumber,
          style: const TextStyle(fontSize: 11),
        ),
        subtitle: Text(
          '${(spanLength / 1000).toStringAsFixed(2)} км',
          style: const TextStyle(fontSize: 10),
        ),
        onTap: () {
          Navigator.of(context).pop();
          // TODO: Центрировать карту на пролёте
        },
      );
    }).toList();
  }

  List<Widget> _buildSubstationsList() {
    final features = _substationsData?['features'] as List<dynamic>? ?? [];
    if (features.isEmpty) return [];

    return features.map<Widget>((feature) {
      final props = feature['properties'] as Map<String, dynamic>;
      final voltageDisplay = props['voltage_level_display']?.toString() ??
          (props['voltage_level'] != null ? '${props['voltage_level']} кВ' : 'н/д');
      final voltageText = voltageDisplay.contains('кВ') ? voltageDisplay : '$voltageDisplay кВ';
      return ListTile(
        dense: true,
        leading: const Icon(Icons.power, size: 14, color: Colors.purple),
        title: Text(
          props['name'] ?? 'Без названия',
          style: const TextStyle(fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          voltageText,
          style: const TextStyle(fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () {
          Navigator.of(context).pop();
          _centerOnFeature(feature);
          _showObjectInfo(props, ObjectType.substation);
        },
      );
    }).toList();
  }

  Widget _buildPolesTree() {
    final features = _polesData?['features'] as List<dynamic>? ?? [];
    if (features.isEmpty) return const SizedBox.shrink();

    return ExpansionTile(
      controlAffinity: ListTileControlAffinity.leading,
      leading: Icon(MdiIcons.transmissionTower, color: Colors.blue),
      title: Text('Опоры (${features.length})'),
      children: features.map<Widget>((feature) {
        final props = feature['properties'] as Map<String, dynamic>;
        return ListTile(
          dense: true,
          title: Text(props['pole_number'] ?? 'N/A'),
          subtitle: Text('${props['pole_type'] ?? 'N/A'} • ${props['condition'] ?? 'N/A'}'),
          onTap: () {
            Navigator.of(context).pop(); // Закрываем Drawer
            _centerOnFeature(feature);
          },
        );
      }).toList(),
    );
  }

  Widget _buildTapsTree() {
    final features = _tapsData?['features'] as List<dynamic>? ?? [];
    if (features.isEmpty) return const SizedBox.shrink();

    return ExpansionTile(
      controlAffinity: ListTileControlAffinity.leading,
      leading: const Icon(Icons.electrical_services, color: Colors.orange),
      title: Text('Отпайки (${features.length})'),
      children: features.map<Widget>((feature) {
        final props = feature['properties'] as Map<String, dynamic>;
        return ListTile(
          dense: true,
          title: Text(props['tap_number'] ?? 'N/A'),
          subtitle: Text('${props['tap_type'] ?? 'N/A'} • ${props['voltage_level'] ?? 'N/A'} кВ'),
          onTap: () {
            Navigator.of(context).pop(); // Закрываем Drawer
            _centerOnFeature(feature);
          },
        );
      }).toList(),
    );
  }

  void _centerOnFeature(Map<String, dynamic> feature) {
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    if (geometry == null) return;

    LatLng? center;
    if (geometry['type'] == 'Point') {
      final coords = geometry['coordinates'] as List<dynamic>;
      center = LatLng(coords[1] as double, coords[0] as double);
    } else if (geometry['type'] == 'LineString') {
      final coords = geometry['coordinates'] as List<dynamic>;
      if (coords.isNotEmpty) {
        final midIndex = coords.length ~/ 2;
        final midCoord = coords[midIndex] as List<dynamic>;
        center = LatLng(midCoord[1] as double, midCoord[0] as double);
      }
    }

    if (center != null && mounted) {
      try {
        _mapController.move(center, AppConfig.defaultZoom);
      } catch (e) {
        print('Ошибка центрирования на объекте: $e');
      }
    }
  }

  Future<void> _exportCimXml() async {
    if (!mounted) return;
    
    // Показываем диалог выбора опций
    final result = await showDialog<Map<String, bool>>(
      context: context,
      builder: (context) => _ExportCimDialog(),
    );
    
    if (result == null) return;
    
    try {
      if (!mounted) return;
      
      // Показываем индикатор загрузки
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      final apiService = ref.read(apiServiceProvider);
      
      // Выполняем экспорт
      final response = await apiService.exportCimXml(
        true, // useCimpy
        result['substations'] ?? true,
        result['powerLines'] ?? true,
      );
      
      // Закрываем индикатор загрузки
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      // Сохраняем файл
      final fileName = 'cim_export_${DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0]}.xml';
      
      // Получаем данные из response
      final responseData = response.data;
      if (responseData == null) {
        throw Exception('Пустой ответ от сервера');
      }
      
      // Преобразуем в Uint8List
      // Для ResponseType.bytes данные приходят как List<int>
      final Uint8List bytes;
      if (responseData is List<int>) {
        bytes = Uint8List.fromList(responseData);
      } else if (responseData is Uint8List) {
        bytes = responseData;
      } else if (responseData is List) {
        // Fallback для других типов списков
        bytes = Uint8List.fromList((responseData as List).cast<int>());
      } else {
        throw Exception('Неожиданный тип данных ответа: ${responseData.runtimeType}');
      }
      
      final savedPath = await file_download.saveFileBytes(fileName, bytes);
      if (mounted) {
        if (savedPath != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Файл сохранен: $savedPath'),
              action: SnackBarAction(
                label: 'Открыть',
                onPressed: () async {
                  await OpenFile.open(savedPath);
                },
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Файл успешно скачан'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        // Закрываем индикатор загрузки если открыт
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка экспорта: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _centerOnCurrentLocation() {
    if (_currentLocation != null && mounted) {
      try {
        _mapController.move(_currentLocation!, AppConfig.defaultZoom);
      } catch (e) {
        print('Ошибка центрирования карты: $e');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Местоположение не определено'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _showCreatePoleDialog() async {
    // Создавать опору можно только в линии текущего обхода
    if (_currentPowerLineId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Начните или продолжите обход ЛЭП, чтобы создавать опоры в этой линии.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Проверяем, что местоположение получено
    if (_currentLocation == null) {
      await _getCurrentLocation();
      if (_currentLocation == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не удалось получить местоположение. Включите GPS или разрешите доступ к геолокации.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }

    // Используем только линию текущего обхода — выбор другой линии недоступен
    final selectedPowerLineId = _currentPowerLineId!;

    // Показываем диалог создания опоры с текущими GPS координатами
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => CreatePoleDialog(
        powerLineId: selectedPowerLineId,
        initialLatitude: _currentLocation!.latitude,
        initialLongitude: _currentLocation!.longitude,
      ),
    );

    // Если опора создана успешно, обновляем данные и центрируем карту на ней
    if (result != null && result['success'] == true && mounted) {
      await _loadMapData();
      final latRaw = result['latitude'];
      final lngRaw = result['longitude'];
      final lat = latRaw is num ? latRaw.toDouble() : (latRaw is double ? latRaw : null);
      final lng = lngRaw is num ? lngRaw.toDouble() : (lngRaw is double ? lngRaw : null);
      if (lat != null && lng != null) {
        final target = LatLng(lat, lng);
        if (_mapReady) {
          _mapController.move(target, 18.0);
        } else {
          setState(() {
            _pendingCenterOnObjects = target;
            _pendingCenterZoom = 18.0;
          });
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Опора успешно создана'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _showObjectInfo(Map<String, dynamic> properties, ObjectType objectType) {
    // Получаем координаты из properties или geometry
    final geometry = properties['geometry'] as Map<String, dynamic>?;
    double? lat;
    double? lng;
    
    if (geometry != null && geometry['type'] == 'Point') {
      final coordinates = geometry['coordinates'] as List<dynamic>?;
      if (coordinates != null && coordinates.length >= 2) {
        lat = (coordinates[1] as num).toDouble();
        lng = (coordinates[0] as num).toDouble();
        properties['latitude'] = lat;
        properties['longitude'] = lng;
      }
    } else if (properties['latitude'] != null && properties['longitude'] != null) {
      lat = (properties['latitude'] as num).toDouble();
      lng = (properties['longitude'] as num).toDouble();
    }
    
    setState(() {
      _selectedObjectProperties = properties;
      _selectedObjectType = objectType;
      _showObjectProperties = true;
      // При клике на опору — раскрываем её ЛЭП в дереве объектов
      if (objectType == ObjectType.pole) {
        final powerLineId = properties['power_line_id'] as int?;
        if (powerLineId != null) {
          _expandedPowerLineIds.add(powerLineId);
        }
      }
    });
    
    // Центрируем и приближаем карту на выбранном объекте
    if (lat != null && lng != null) {
      try {
        final targetLocation = LatLng(lat, lng);
        // Для опор используем зум 18, для других объектов - 16
        final zoom = objectType == ObjectType.pole ? 18.0 : 16.0;
        _mapController.move(targetLocation, zoom);
      } catch (e) {
        if (kDebugMode) {
          print('Ошибка центрирования на объекте: $e');
        }
      }
    }
  }
  
  void _closeObjectProperties() {
    setState(() {
      _showObjectProperties = false;
      _selectedObjectProperties = null;
      _selectedObjectType = null;
    });
  }
  
  void _showPoleInfo(Map<String, dynamic> properties) {
    _showObjectInfo(properties, ObjectType.pole);
  }
  
  void _handleConnectivityNode() {
    // TODO: Реализовать управление узлом соединения
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Функция управления узлом соединения будет реализована'),
        backgroundColor: Colors.orange,
      ),
    );
  }
  
  void _handlePoleSequence() {
    // TODO: Реализовать последовательность опор
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Функция последовательности опор будет реализована'),
        backgroundColor: Colors.orange,
      ),
    );
  }
  
  void _handleCreateSpan() {
    // TODO: Реализовать создание пролёта
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Функция создания пролёта будет реализована'),
        backgroundColor: Colors.orange,
      ),
    );
  }
  
  void _handleAutoCreateSpans() {
    // TODO: Реализовать автоматическое создание пролётов
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Функция автоматического создания пролётов будет реализована'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _handleDeleteObject() async {
    if (_selectedObjectProperties == null || _selectedObjectType == null) {
      return;
    }

    final objectId = _selectedObjectProperties!['id'] as int?;
    if (objectId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось определить ID объекта'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Определяем тип объекта и название для диалога
    String objectTypeLabel;
    String objectName;
    
    switch (_selectedObjectType!) {
      case ObjectType.pole:
        objectTypeLabel = 'опору';
        objectName = _selectedObjectProperties!['pole_number']?.toString() ?? 'N/A';
        break;
      case ObjectType.substation:
        objectTypeLabel = 'подстанцию';
        objectName = _selectedObjectProperties!['name']?.toString() ?? 'N/A';
        break;
      case ObjectType.tap:
        objectTypeLabel = 'отпайку';
        objectName = _selectedObjectProperties!['tap_number']?.toString() ?? 'N/A';
        break;
    }

    // Показываем диалог подтверждения
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить $objectTypeLabel?'),
        content: Text('Вы уверены, что хотите удалить $objectTypeLabel "$objectName"? Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    // Выполняем удаление
    try {
      final apiService = ref.read(apiServiceProvider);
      
      switch (_selectedObjectType!) {
        case ObjectType.pole:
          await apiService.deletePole(objectId);
          break;
        case ObjectType.substation:
          await apiService.deleteSubstation(objectId);
          break;
        case ObjectType.tap:
          // TODO: Добавить методы удаления для отпаек
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Удаление этого типа объектов пока не реализовано'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
      }

      // Закрываем панель свойств
      _closeObjectProperties();

      // Обновляем данные на карте
      await _loadMapData();

      if (mounted) {
        String successMessage;
        if (_selectedObjectType == ObjectType.pole) {
          successMessage = '$objectTypeLabel "$objectName" успешно удалена.\nПролёты, напрямую связанные с этой опорой, также удалены. Остальная структура линии сохранена.';
        } else if (_selectedObjectType == ObjectType.substation) {
          successMessage = 'Подстанция "$objectName" успешно удалена.';
        } else {
          successMessage = '$objectTypeLabel "$objectName" успешно удалена.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } on DioException catch (e) {
      // Обработка ошибок Dio
      String errorMessage = 'Ошибка удаления объекта';
      
      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final responseData = e.response!.data;
        
        if (statusCode == 409) {
          // 409 больше не должно возникать, так как связанные объекты удаляются автоматически
          // Но на всякий случай оставляем обработку
          if (responseData is Map && responseData['detail'] != null) {
            errorMessage = responseData['detail'] as String;
          } else {
            errorMessage = 'Не удалось удалить $objectTypeLabel "$objectName": существуют связанные объекты';
          }
        } else if (statusCode == 404) {
          errorMessage = 'Объект не найден';
        } else if (statusCode == 403) {
          errorMessage = 'Доступ запрещен. У вас нет прав для удаления этого объекта.';
        } else if (statusCode == 401) {
          errorMessage = 'Требуется авторизация. Войдите в систему заново.';
        } else if (responseData is Map && responseData['detail'] != null) {
          errorMessage = responseData['detail'] as String;
        } else {
          errorMessage = 'Ошибка сервера (${statusCode})';
        }
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'Ошибка соединения с сервером. Проверьте подключение к интернету.';
      } else {
        errorMessage = 'Ошибка удаления: ${e.message ?? e.toString()}';
      }
      
      if (kDebugMode) {
        print('Ошибка удаления объекта: $e');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 7),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      // Обработка других ошибок
      if (kDebugMode) {
        print('Ошибка удаления объекта: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка удаления объекта: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
  
  void _startLineFormation(int poleId, int powerLineId) async {
    // Закрываем панель свойств перед стартом режима навигатора
    if (_showObjectProperties) {
      _closeObjectProperties();
    }
    
    if (!mounted) return;
    
    setState(() {
      _isNavigatorMode = true;
      _startingPoleId = poleId;
      _currentPowerLineId = powerLineId;
      // Инициализируем номер опоры
      _quickPoleNumber = '';
      _isEndPole = false;
      _isTapPole = false;
    });
    
    // Получаем текущее местоположение перед началом отслеживания
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final location = LatLng(position.latitude, position.longitude);
      
      if (mounted) {
        setState(() {
          _currentLocation = location;
        });
        
        // Центрируем карту на текущем местоположении с зумом 18
        try {
          _mapController.move(location, 18.0);
        } catch (e) {
          print('Ошибка центрирования при старте навигатора: $e');
        }
      }
    } catch (e) {
      print('Ошибка получения местоположения: $e');
      // Продолжаем работу даже если не удалось получить местоположение
    }
    
    // Начинаем отслеживание GPS в реальном времени
    _startLocationTracking();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Режим навигатора включен. Карта будет следовать за вашим местоположением.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
  
  void _startLocationTracking() {
    // Отменяем предыдущую подписку, если есть
    _positionSubscription?.cancel();
    
    // Создаём поток обновлений GPS с оптимизацией
    DateTime? lastUpdate;
    DateTime? lastMapUpdate;
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15, // Обновлять каждые 15 метров (увеличено для стабильности)
      ),
    ).listen((Position position) {
      if (!mounted || !_isNavigatorMode) return;
      
      final now = DateTime.now();
      // Ограничиваем частоту обновлений состояния (не чаще чем раз в 1 секунду)
      if (lastUpdate != null && now.difference(lastUpdate!).inMilliseconds < 1000) {
        return;
      }
      lastUpdate = now;
      
      final newLocation = LatLng(position.latitude, position.longitude);
      
      // Обновляем состояние только если координаты изменились значительно
      final distanceChanged = _currentLocation == null ||
          Geolocator.distanceBetween(
            _currentLocation!.latitude,
            _currentLocation!.longitude,
            newLocation.latitude,
            newLocation.longitude,
          ) > 10; // Увеличено до 10 метров для уменьшения частоты обновлений
      
      if (distanceChanged) {
        // Обновляем состояние синхронно, без addPostFrameCallback
        if (mounted && _isNavigatorMode) {
          setState(() {
            _currentLocation = newLocation;
          });
          
          // Обновляем карту не чаще чем раз в 2 секунды
          if (lastMapUpdate == null || now.difference(lastMapUpdate!).inSeconds >= 2) {
            lastMapUpdate = now;
            
            // Центрируем карту на текущем местоположении с задержкой
            // Используем более длительную задержку для стабильности
            Future.delayed(const Duration(milliseconds: 300), () {
              if (!mounted || !_isNavigatorMode) return;
              
              try {
                final currentZoom = _mapController.camera.zoom;
                // В режиме навигатора используем зум 18 для детального просмотра
                final targetZoom = currentZoom < 18 ? 18.0 : currentZoom;
                _mapController.move(newLocation, targetZoom);
              } catch (e) {
                // Игнорируем ошибки центрирования, но логируем их
                print('Ошибка центрирования карты: $e');
              }
            });
          }
        }
      }
    }, onError: (error) {
      print('Ошибка GPS: $error');
      if (mounted && _isNavigatorMode) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка GPS: $error'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }
  
  void _stopLineFormation() {
    // Отменяем подписку на GPS
    _positionSubscription?.cancel();
    _positionSubscription = null;
    
    // Закрываем панель свойств, если открыта
    if (_showObjectProperties) {
      _closeObjectProperties();
    }
    
    // Обновляем состояние
    if (mounted) {
      setState(() {
        _isNavigatorMode = false;
        _startingPoleId = null;
        _currentPowerLineId = null;
        _isEndPole = false;
        _isTapPole = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Режим навигатора выключен.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  
  Widget _buildQuickSettingsMenu() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Настройки',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  // Меню можно скрывать/показывать при необходимости
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 200,
            child: TextField(
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                labelText: 'Номер опоры',
                labelStyle: TextStyle(fontSize: 12),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: _quickPoleNumber)..selection = TextSelection.fromPosition(TextPosition(offset: _quickPoleNumber.length)),
              onChanged: (value) {
                setState(() => _quickPoleNumber = value);
              },
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _quickPoleType,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              labelText: 'Тип опоры',
              labelStyle: TextStyle(fontSize: 12),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(),
            ),
            items: PoleReferenceData.poleTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _quickPoleType = value);
              }
            },
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _quickConductorType,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              labelText: 'Марка провода',
              labelStyle: TextStyle(fontSize: 12),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(),
            ),
            items: PoleReferenceData.conductorTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _quickConductorType = value);
              }
            },
          ),
          const SizedBox(height: 6),
          CheckboxListTile(
            dense: true,
            title: const Text('Конечная опора', style: TextStyle(fontSize: 12)),
            subtitle: const Text('Завершит сегмент', style: TextStyle(fontSize: 10)),
            value: _isEndPole,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) {
              setState(() {
                _isEndPole = value ?? false;
                if (_isEndPole) _isTapPole = false;
              });
            },
          ),
          CheckboxListTile(
            dense: true,
            title: const Text('Отпаечная опора', style: TextStyle(fontSize: 12)),
            subtitle: const Text('Создаст отпайку', style: TextStyle(fontSize: 10)),
            value: _isTapPole,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) {
              setState(() {
                _isTapPole = value ?? false;
                if (_isTapPole) _isEndPole = false;
              });
            },
          ),
        ],
      ),
    );
  }
  
  Future<void> _createPoleInNavigatorMode() async {
    if (_currentLocation == null || _currentPowerLineId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось определить местоположение или ЛЭП'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    if (_quickPoleNumber.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Введите номер опоры в меню настроек'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    try {
      final apiService = ref.read(apiServiceProvider);
      final poleData = PoleCreate(
        poleNumber: _quickPoleNumber,
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
        poleType: _quickPoleType,
        condition: 'good',
        isTap: _isTapPole,
        conductorType: _quickConductorType,
        conductorMaterial: _quickConductorMaterial,
        conductorSection: _quickConductorSection,
      );

      await apiService.createPole(_currentPowerLineId!, poleData);

      _refreshPolesData().catchError((e) {
        print('Ошибка обновления опор: $e');
      });

      if (mounted) {
        setState(() {
          _quickPoleNumber = '';
          _isEndPole = false;
          if (_isTapPole) _isTapPole = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Опора создана и пролёт сформирован'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on DioException catch (e) {
      final isOffline = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout || e.response == null;
      if (isOffline && mounted) {
        final saved = await _saveNavigatorPoleToLocalDb();
        if (mounted && saved) {
          setState(() {
            _quickPoleNumber = '';
            _isEndPole = false;
            if (_isTapPole) _isTapPole = false;
          });
          await _loadMapDataFromLocal();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Нет связи. Опора сохранена локально и будет синхронизирована при подключении.'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка создания опоры: ${e.message}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка создания опоры: ${e.message ?? e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Ошибка создания опоры: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка создания опоры: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<bool> _saveNavigatorPoleToLocalDb() async {
    if (_currentLocation == null || _currentPowerLineId == null) return false;
    try {
      final db = ref.read(drift_db.databaseProvider);
      final prefs = ref.read(prefsProvider);
      int localId = prefs.getInt(AppConfig.lastLocalPoleIdKey) ?? -1;
      localId--;
      await prefs.setInt(AppConfig.lastLocalPoleIdKey, localId);
      final userId = prefs.getInt(AppConfig.userIdKey) ?? 0;
      final now = DateTime.now();
      await db.insertPole(drift_db.PolesCompanion.insert(
        id: drift.Value(localId),
        powerLineId: _currentPowerLineId!,
        poleNumber: _quickPoleNumber,
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
        poleType: _quickPoleType,
        height: const drift.Value.absent(),
        foundationType: const drift.Value.absent(),
        material: const drift.Value.absent(),
        yearInstalled: const drift.Value.absent(),
        condition: 'good',
        notes: const drift.Value.absent(),
        createdBy: userId,
        createdAt: now,
        updatedAt: drift.Value(now),
        isLocal: const drift.Value(true),
        needsSync: const drift.Value(true),
      ));
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Оптимизированное обновление только опор (без перезагрузки всех данных)
  Future<void> _refreshPolesData() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final polesData = await apiService.getTowersGeoJSON();
      
      if (mounted) {
        setState(() {
          _polesData = polesData as Map<String, dynamic>?;
        });
      }
    } catch (e) {
      print('Ошибка обновления опор: $e');
      // В случае ошибки обновляем все данные
      if (mounted) {
        await _loadMapData();
      }
    }
  }

  void _showTapInfo(Map<String, dynamic> properties) {
    _showObjectInfo(properties, ObjectType.tap);
  }

  void _showSubstationInfo(Map<String, dynamic> properties) {
    _showObjectInfo(properties, ObjectType.substation);
  }

  void _showRootContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Создать линию'),
              onTap: () {
                Navigator.of(context).pop();
                _showCreatePowerLineDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.power),
              title: const Text('Создать подстанцию'),
              onTap: () {
                Navigator.of(context).pop();
                _showCreateSubstationDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPowerLineContextMenu(PowerLine powerLine) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Удалить линию'),
              onTap: () {
                Navigator.of(context).pop();
                _deletePowerLine(powerLine);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePowerLine(PowerLine powerLine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить линию?'),
        content: Text('Вы уверены, что хотите удалить линию "${powerLine.name}"? Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.deletePowerLine(powerLine.id);

      final db = ref.read(drift_db.databaseProvider);
      await db.deletePatrolSessionsByPowerLineId(powerLine.id);
      await db.deletePowerLine(powerLine.id);
      final linePoles = await db.getPolesByPowerLine(powerLine.id);
      for (final p in linePoles) {
        await db.deletePole(p.id);
      }

      await _clearActiveSessionIfLine(powerLine.id);
      ref.invalidate(recentPatrolsProvider);
      await _loadMapData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Линия успешно удалена'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on DioException catch (e) {
      final isOffline = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout;
      if (isOffline) {
        await _deletePowerLineOffline(powerLine);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка удаления линии: ${e.message ?? e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка удаления линии: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Удаление линии локально (офлайн): из Drift и при необходимости в очередь на удаление на сервере.
  Future<void> _deletePowerLineOffline(PowerLine powerLine) async {
    final db = ref.read(drift_db.databaseProvider);
    final prefs = ref.read(prefsProvider);

    if (powerLine.id < 0) {
      // Локально созданная линия — просто удаляем из БД
      await db.deletePatrolSessionsByPowerLineId(powerLine.id);
      await db.deletePowerLine(powerLine.id);
      final linePoles = await db.getPolesByPowerLine(powerLine.id);
      for (final p in linePoles) {
        await db.deletePole(p.id);
      }
    } else {
      // Линия с сервера — добавляем в очередь отложенного удаления и убираем из локального кэша
      final key = AppConfig.pendingDeletePowerLineIdsKey;
      final list = prefs.getStringList(key) ?? [];
      list.add(powerLine.id.toString());
      await prefs.setStringList(key, list);
      await db.deletePatrolSessionsByPowerLineId(powerLine.id);
      await db.deletePowerLine(powerLine.id);
      final linePoles = await db.getPolesByPowerLine(powerLine.id);
      for (final p in linePoles) {
        await db.deletePole(p.id);
      }
    }

    await _clearActiveSessionIfLine(powerLine.id);
    ref.invalidate(recentPatrolsProvider);
    await _loadMapDataFromLocal();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            powerLine.id < 0
                ? 'Линия удалена (офлайн).'
                : 'Линия удалена локально. Удаление на сервере произойдёт при синхронизации.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showCreatePowerLineDialog() {
    final nameController = TextEditingController();
    final voltageController = TextEditingController();
    final lengthController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Создать линию'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Название *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: voltageController,
                decoration: const InputDecoration(
                  labelText: 'Напряжение (кВ)',
                  hintText: '0.4, 6, 10, 35, 110, 220, 330, 500, 750',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: lengthController,
                decoration: const InputDecoration(
                  labelText: 'Длина (км)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Описание',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Название обязательно для заполнения'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                final apiService = ref.read(apiServiceProvider);
                final name = nameController.text.trim();
                final code = name;
                final voltageLevel = double.tryParse(voltageController.text) ?? 0.0;
                final length = double.tryParse(lengthController.text);
                final branchId = 1; // TODO: Получить реальный branchId
                final status = 'active';
                final description = descriptionController.text.trim().isEmpty
                    ? null
                    : descriptionController.text.trim();

                final powerLineData = PowerLineCreate(
                  name: name,
                  code: code,
                  voltageLevel: voltageLevel,
                  length: length,
                  branchId: branchId,
                  status: status,
                  description: description,
                );

                try {
                  await apiService.createPowerLine(powerLineData);
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  await _loadMapData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Линия успешно создана'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                  return;
                } on DioException catch (e) {
                  final isOffline = e.type == DioExceptionType.connectionError ||
                      e.type == DioExceptionType.connectionTimeout ||
                      e.type == DioExceptionType.unknown;
                  if (!isOffline) rethrow;
                  // Сохраняем ЛЭП локально для последующей синхронизации
                  final prefs = ref.read(prefsProvider);
                  final db = ref.read(drift_db.databaseProvider);
                  int localId = prefs.getInt(AppConfig.lastLocalPowerLineIdKey) ?? -1;
                  localId--;
                  await prefs.setInt(AppConfig.lastLocalPowerLineIdKey, localId);
                  final userId = prefs.getInt(AppConfig.userIdKey) ?? 0;
                  final now = DateTime.now();
                  await db.insertPowerLine(drift_db.PowerLinesCompanion.insert(
                    id: drift.Value(localId),
                    name: name,
                    code: code,
                    voltageLevel: voltageLevel,
                    length: length != null ? drift.Value(length) : const drift.Value.absent(),
                    branchId: branchId,
                    createdBy: userId,
                    status: status,
                    description: drift.Value(description),
                    createdAt: now,
                    updatedAt: drift.Value(now),
                    isLocal: const drift.Value(true),
                    needsSync: const drift.Value(true),
                  ));
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  await _loadMapDataFromLocal();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'ЛЭП сохранена локально. Будет синхронизирована при появлении связи.',
                        ),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 4),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ошибка создания линии: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  void _showCreateSubstationDialog() async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final voltageController = TextEditingController();
    final addressController = TextEditingController();
    final descriptionController = TextEditingController();

    // Получаем текущие координаты, если доступны
    double? latitude;
    double? longitude;
    try {
      if (_currentLocation != null) {
        latitude = _currentLocation!.latitude;
        longitude = _currentLocation!.longitude;
      } else {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        latitude = position.latitude;
        longitude = position.longitude;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Не удалось получить GPS координаты: $e');
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Создать подстанцию'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Название *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Диспетчерское наименование *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: voltageController,
                decoration: const InputDecoration(
                  labelText: 'Напряжение (кВ) *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              if (latitude != null && longitude != null)
                Text(
                  'Позиция (X, Y): ${longitude!.toStringAsFixed(6)}, ${latitude!.toStringAsFixed(6)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Адрес',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Описание',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Название обязательно для заполнения'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (codeController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Диспетчерское наименование обязательно для заполнения'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (voltageController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Напряжение обязательно для заполнения'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (latitude == null || longitude == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Не удалось получить позицию (X, Y). Включите GPS.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                final apiService = ref.read(apiServiceProvider);
                final substationData = SubstationCreate(
                  name: nameController.text.trim(),
                  dispatcherName: codeController.text.trim(),
                  voltageLevel: double.tryParse(voltageController.text) ?? 0.0,
                  latitude: latitude!,
                  longitude: longitude!,
                  address: addressController.text.trim().isEmpty 
                      ? null 
                      : addressController.text.trim(),
                  branchId: null, // Опциональное поле
                  description: descriptionController.text.trim().isEmpty 
                      ? null 
                      : descriptionController.text.trim(),
                );

                await apiService.createSubstation(substationData);
                
                Navigator.of(context).pop();
                
                await _loadMapData();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Подстанция успешно создана'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ошибка создания подстанции: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }
}

class _ExportCimDialog extends StatefulWidget {
  @override
  State<_ExportCimDialog> createState() => _ExportCimDialogState();
}

class _ExportCimDialogState extends State<_ExportCimDialog> {
  bool _includeSubstations = true;
  bool _includePowerLines = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Экспорт в CIM XML'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CheckboxListTile(
            title: const Text('Включить подстанции'),
            value: _includeSubstations,
            onChanged: (value) {
              setState(() {
                _includeSubstations = value ?? true;
              });
            },
          ),
          CheckboxListTile(
            title: const Text('Включить ЛЭП'),
            value: _includePowerLines,
            onChanged: (value) {
              setState(() {
                _includePowerLines = value ?? true;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop({
              'substations': _includeSubstations,
              'powerLines': _includePowerLines,
            });
          },
          child: const Text('Экспортировать'),
        ),
      ],
    );
  }
}

/// Индикатор статуса подключения на карте: Онлайн / Офлайн / Нестабильно.
class _MapConnectionStatusBadge extends StatelessWidget {
  const _MapConnectionStatusBadge({required this.status});

  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, label, bgColor, fgColor) = switch (status) {
      ConnectionStatus.online => (
          Icons.cloud_done,
          'Онлайн',
          Colors.green.shade100,
          Colors.green.shade800,
        ),
      ConnectionStatus.offline => (
          Icons.cloud_off,
          'Офлайн',
          Colors.orange.shade100,
          Colors.orange.shade800,
        ),
      ConnectionStatus.unstable => (
          Icons.cloud_queue,
          'Нестабильно',
          Colors.amber.shade100,
          Colors.amber.shade900,
        ),
    };
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: fgColor,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: fgColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fgColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
