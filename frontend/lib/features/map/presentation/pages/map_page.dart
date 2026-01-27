import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/api_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/models/power_line.dart';
import '../../../towers/presentation/widgets/create_pole_dialog.dart';

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
  
  // Режим навигатора для формирования линии
  bool _isNavigatorMode = false;
  int? _startingPoleId; // ID опоры, от которой начинаем формирование линии
  int? _currentPowerLineId; // ID текущей ЛЭП
  StreamSubscription<Position>? _positionSubscription; // Подписка на обновления GPS
  
  // Настройки для быстрого создания опоры в режиме навигатора
  String _quickPoleNumber = '';
  String _quickPoleType = 'промежуточная';
  String _quickConductorType = 'AC-70';
  String _quickConductorMaterial = 'алюминий';
  String _quickConductorSection = '70';
  bool _isEndPole = false; // Конечная опора (завершает AClineSegment)
  bool _isTapPole = false; // Отпаечная опора

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

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentLocation != null) {
          try {
            _mapController.move(_currentLocation!, AppConfig.defaultZoom);
          } catch (e) {
            print('Ошибка центрирования карты: $e');
          }
        }
      });
    } catch (e) {
      print('Ошибка получения местоположения: $e');
      setState(() {
        _currentLocation = const LatLng(53.9045, 27.5615);
      });
    }
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
      
      final apiService = ref.read(apiServiceProvider);
      
      // Загружаем данные параллельно
      final futures = await Future.wait([
        apiService.getPowerLinesGeoJSON(),
        apiService.getTowersGeoJSON(),
        apiService.getTapsGeoJSON(),
        apiService.getSubstationsGeoJSON(),
        apiService.getPowerLines(), // Полные данные ЛЭП для дерева
      ]);

      final powerLinesData = futures[0] as Map<String, dynamic>;
      final polesData = futures[1] as Map<String, dynamic>;
      final tapsData = futures[2] as Map<String, dynamic>;
      final substationsData = futures[3] as Map<String, dynamic>;
      final powerLinesList = futures[4] as List<PowerLine>;

      if (mounted) {
        print('✅ Загружено данных:');
        print('  ЛЭП: ${(powerLinesData['features'] as List?)?.length ?? 0}');
        print('  Опоры: ${(polesData['features'] as List?)?.length ?? 0}');
        print('  Отпайки: ${(tapsData['features'] as List?)?.length ?? 0}');
        print('  Подстанции: ${(substationsData['features'] as List?)?.length ?? 0}');

        setState(() {
          _powerLinesData = powerLinesData;
          _polesData = polesData;
          _tapsData = tapsData;
          _substationsData = substationsData;
          _powerLinesList = powerLinesList;
          _errorMessage = null;
        });

        _centerOnObjects();
      }
    } catch (e) {
      print('❌ Ошибка загрузки данных карты: $e');
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

    if (center != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          try {
            _mapController.move(center!, AppConfig.defaultZoom);
          } catch (e) {
            print('Ошибка центрирования на объектах: $e');
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Карта'),
        actions: [
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
                      if (_currentLocation != null) {
                        try {
                          _mapController.move(_currentLocation!, AppConfig.defaultZoom);
                        } catch (e) {
                          print('Ошибка центрирования при готовности карты: $e');
                        }
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                
                Positioned(
                  top: 16,
                  right: 16,
                  child: _buildLegend(),
                ),
                
                // Быстрое меню настроек в режиме навигатора
                if (_isNavigatorMode)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: _buildQuickSettingsMenu(),
                  ),
                
                // Кнопка создания опоры / остановки навигатора
                Positioned(
                  bottom: 16,
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
                              icon: const Icon(Icons.stop),
                              tooltip: 'Остановить формирование линии',
                              backgroundColor: Colors.red,
                            ),
                          ],
                        )
                      : FloatingActionButton.extended(
                          onPressed: _showCreatePoleDialog,
                          icon: const Icon(Icons.add_location_alt),
                          label: const Text('Создать опору'),
                          tooltip: 'Создать опору с текущими GPS координатами',
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

    for (final feature in features) {
      try {
        final geometry = feature['geometry'] as Map<String, dynamic>?;
        if (geometry != null && geometry['type'] == 'LineString') {
          final coordinates = geometry['coordinates'] as List<dynamic>?;
          if (coordinates != null) {
            final points = coordinates.map((coord) => LatLng(
              (coord[1] as num).toDouble(),
              (coord[0] as num).toDouble(),
            )).toList();
            
            polylines.add(
              Polyline(
                points: points,
                strokeWidth: 3.0,
                color: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        print('Ошибка при построении полилинии ЛЭП: $e');
      }
    }

    return polylines;
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
            
            markers.add(
              Marker(
                point: latLng,
                child: GestureDetector(
                  onTap: () => _showPoleInfo(properties ?? {}),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white, width: 2),
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
          // Заголовок Drawer
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.electrical_services,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Text(
                  'Объекты',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Дерево объектов на карте',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          
          // Содержимое Drawer
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (_powerLinesList != null && _powerLinesList!.isNotEmpty)
                  _buildPowerLinesTreeHierarchical(),
                if (_substationsData != null)
                  _buildSubstationsTree(),
                if (_tapsData != null)
                  _buildTapsTree(),
              ],
            ),
          ),
          
          // Кнопка выхода
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Выйти'),
            onTap: () async {
              await ref.read(authServiceProvider.notifier).logout();
              if (mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPowerLinesTreeHierarchical() {
    if (_powerLinesList == null || _powerLinesList!.isEmpty) {
      return const SizedBox.shrink();
    }

    return ExpansionTile(
      leading: const Icon(Icons.electrical_services, color: Colors.red),
      title: Text('ЛЭП (${_powerLinesList!.length})'),
      children: _powerLinesList!.map<Widget>((powerLine) {
        // Получаем AClineSegments и poles из данных (если они загружены)
        // Пока используем динамические данные из JSON
        return _buildPowerLineTreeItem(powerLine);
      }).toList(),
    );
  }

  Widget _buildPowerLineTreeItem(PowerLine powerLine) {
    // Загружаем детали линии при разворачивании (lazy loading)
    // Пока используем данные из GeoJSON для отображения на карте
    final geoFeature = _findPowerLineInGeoJSON(powerLine.id);
    
    return ExpansionTile(
      leading: const Icon(Icons.electrical_services, size: 20),
      title: Text(powerLine.name),
      subtitle: Text('${powerLine.voltageLevel ?? 0} кВ • ${powerLine.poles?.length ?? 0} опор'),
      children: [
        // АЦЛС
        ExpansionTile(
          leading: const Icon(Icons.polyline, size: 18, color: Colors.orange),
          title: Text('Участки линии (АЦЛС) (${(powerLine.aclineSegments as List?)?.length ?? 0})'),
          children: _buildAClineSegmentsTree(powerLine.aclineSegments ?? []),
        ),
        // Опоры
        ExpansionTile(
          leading: Icon(MdiIcons.transmissionTower, size: 18, color: Colors.blue),
          title: Text('Опоры (${powerLine.poles?.length ?? 0})'),
          children: (powerLine.poles ?? []).map<Widget>((pole) {
            final geoPole = _findPoleInGeoJSON(pole.id);
            return ListTile(
              dense: true,
              leading: Icon(MdiIcons.transmissionTower, size: 16),
              title: Text(pole.poleNumber),
              subtitle: Text('${pole.poleType} • ${pole.condition}'),
              onTap: () {
                Navigator.of(context).pop();
                if (geoPole != null) {
                  _centerOnFeature(geoPole);
                }
              },
            );
          }).toList(),
        ),
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
        const ListTile(
          dense: true,
          title: Text('Участки не найдены', style: TextStyle(fontStyle: FontStyle.italic)),
        ),
      ];
    }

    return aclineSegments.map<Widget>((segment) {
      final segmentData = segment as Map<String, dynamic>;
      final segmentId = segmentData['id'] as int?;
      final segmentName = segmentData['name'] as String? ?? 'Без названия';
      final lineSections = segmentData['line_sections'] as List<dynamic>? ?? [];
      
      return ExpansionTile(
        leading: Icon(
          segmentData['is_tap'] == true ? Icons.call_split : Icons.polyline,
          size: 16,
          color: segmentData['is_tap'] == true ? Colors.orange : Colors.green,
        ),
        title: Text(segmentName),
        subtitle: Text('${lineSections.length} секций • ${segmentData['length'] ?? 0} км'),
        children: _buildLineSectionsTree(lineSections),
      );
    }).toList();
  }

  List<Widget> _buildLineSectionsTree(List<dynamic> lineSections) {
    if (lineSections.isEmpty) {
      return [
        const ListTile(
          dense: true,
          title: Text('Секции не найдены', style: TextStyle(fontStyle: FontStyle.italic)),
        ),
      ];
    }

    return lineSections.map<Widget>((section) {
      final sectionData = section as Map<String, dynamic>;
      final sectionId = sectionData['id'] as int?;
      final sectionName = sectionData['name'] as String? ?? 'Без названия';
      final spans = sectionData['spans'] as List<dynamic>? ?? [];
      
      return ExpansionTile(
        leading: const Icon(Icons.segment, size: 16, color: Colors.blue),
        title: Text(sectionName),
        subtitle: Text('${spans.length} пролётов • ${sectionData['conductor_type'] ?? 'N/A'}'),
        children: _buildSpansTree(spans),
      );
    }).toList();
  }

  List<Widget> _buildSpansTree(List<dynamic> spans) {
    if (spans.isEmpty) {
      return [
        const ListTile(
          dense: true,
          title: Text('Пролёты не найдены', style: TextStyle(fontStyle: FontStyle.italic)),
        ),
      ];
    }

    return spans.map<Widget>((span) {
      final spanData = span as Map<String, dynamic>;
      final spanNumber = spanData['span_number'] as String? ?? 'N/A';
      final spanLength = spanData['length'] as num? ?? 0;
      
      return ListTile(
        dense: true,
        leading: const Icon(Icons.arrow_forward, size: 14),
        title: Text(spanNumber),
        subtitle: Text('${(spanLength / 1000).toStringAsFixed(2)} км • ${spanData['conductor_type'] ?? 'N/A'}'),
        onTap: () {
          Navigator.of(context).pop();
          // TODO: Центрировать карту на пролёте
        },
      );
    }).toList();
  }

  Widget _buildSubstationsTree() {
    final features = _substationsData?['features'] as List<dynamic>? ?? [];
    if (features.isEmpty) return const SizedBox.shrink();

    return ExpansionTile(
      leading: const Icon(Icons.power, color: Colors.purple),
      title: Text('Подстанции (${features.length})'),
      children: features.map<Widget>((feature) {
        final props = feature['properties'] as Map<String, dynamic>;
        return ListTile(
          dense: true,
          title: Text(props['name'] ?? 'Без названия'),
          subtitle: Text('${props['voltage_level']} кВ'),
          onTap: () {
            Navigator.of(context).pop(); // Закрываем Drawer
            _centerOnFeature(feature);
          },
        );
      }).toList(),
    );
  }

  Widget _buildPolesTree() {
    final features = _polesData?['features'] as List<dynamic>? ?? [];
    if (features.isEmpty) return const SizedBox.shrink();

    return ExpansionTile(
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
    // Проверяем, что местоположение получено
    if (_currentLocation == null) {
      // Пытаемся получить местоположение
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

    // Загружаем список ЛЭП для выбора
    List<PowerLine> powerLines = [];
    try {
      final apiService = ref.read(apiServiceProvider);
      powerLines = await apiService.getPowerLines();
      
      if (powerLines.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Нет доступных ЛЭП. Создайте ЛЭП сначала.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки ЛЭП: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Если только одна ЛЭП, используем её, иначе показываем выбор
    int? selectedPowerLineId;
    if (powerLines.length == 1) {
      selectedPowerLineId = powerLines.first.id;
    } else {
      // Показываем диалог выбора ЛЭП
      selectedPowerLineId = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Выберите ЛЭП'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: powerLines.length,
              itemBuilder: (context, index) {
                final powerLine = powerLines[index];
                return ListTile(
                  title: Text(powerLine.name),
                  subtitle: Text('${powerLine.code} • ${powerLine.voltageLevel} кВ'),
                  onTap: () => Navigator.of(context).pop(powerLine.id),
                );
              },
            ),
          ),
        ),
      );

      if (selectedPowerLineId == null) {
        return; // Пользователь отменил выбор
      }
    }

    // Показываем диалог создания опоры с текущими GPS координатами
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => CreatePoleDialog(
        powerLineId: selectedPowerLineId!,
        initialLatitude: _currentLocation!.latitude,
        initialLongitude: _currentLocation!.longitude,
      ),
    );

    // Если опора создана успешно, обновляем данные на карте
    if (result == true && mounted) {
      await _loadMapData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Опора успешно создана'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showPoleInfo(Map<String, dynamic> properties) {
    final poleId = properties['id'] as int?;
    final powerLineId = properties['power_line_id'] as int?;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Опора ${properties['pole_number'] ?? 'N/A'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Тип: ${properties['pole_type'] ?? 'Не указан'}'),
            Text('Высота: ${properties['height'] ?? 'Не указана'} м'),
            Text('Состояние: ${properties['condition'] ?? 'Не указано'}'),
            Text('Материал: ${properties['material'] ?? 'Не указан'}'),
            const SizedBox(height: 16),
            if (poleId != null && powerLineId != null)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _startLineFormation(poleId, powerLineId);
                },
                icon: const Icon(Icons.navigation),
                label: const Text('Начать формирование линии'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
  
  void _startLineFormation(int poleId, int powerLineId) {
    setState(() {
      _isNavigatorMode = true;
      _startingPoleId = poleId;
      _currentPowerLineId = powerLineId;
      // Инициализируем номер опоры
      _quickPoleNumber = '';
    });
    
    // Начинаем отслеживание GPS в реальном времени
    _startLocationTracking();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Режим навигатора включен. Карта будет следовать за вашим местоположением.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }
  
  void _startLocationTracking() {
    // Отменяем предыдущую подписку, если есть
    _positionSubscription?.cancel();
    
    // Создаём поток обновлений GPS
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Обновлять каждые 10 метров
      ),
    ).listen((Position position) {
      if (mounted && _isNavigatorMode) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        
        // Центрируем карту на текущем местоположении
        try {
          _mapController.move(_currentLocation!, AppConfig.defaultZoom);
        } catch (e) {
          print('Ошибка центрирования карты в режиме навигатора: $e');
        }
      }
    });
  }
  
  void _stopLineFormation() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    
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
      ),
    );
  }
  
  Widget _buildQuickSettingsMenu() {
    return Card(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Быстрые настройки',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  iconSize: 20,
                  onPressed: () {
                    // Меню можно скрывать/показывать при необходимости
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 200,
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Номер опоры',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(text: _quickPoleNumber)..selection = TextSelection.fromPosition(TextPosition(offset: _quickPoleNumber.length)),
                onChanged: (value) {
                  setState(() => _quickPoleNumber = value);
                },
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _quickPoleType,
              decoration: const InputDecoration(
                labelText: 'Тип опоры',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'промежуточная', child: Text('Промежуточная')),
                DropdownMenuItem(value: 'анкерная', child: Text('Анкерная')),
                DropdownMenuItem(value: 'угловая', child: Text('Угловая')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _quickPoleType = value);
                }
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _quickConductorType,
              decoration: const InputDecoration(
                labelText: 'Марка провода',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'AC-70', child: Text('AC-70')),
                DropdownMenuItem(value: 'AC-95', child: Text('AC-95')),
                DropdownMenuItem(value: 'AC-120', child: Text('AC-120')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _quickConductorType = value);
                }
              },
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text('Конечная опора'),
              subtitle: const Text('Завершит текущий сегмент'),
              value: _isEndPole,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              onChanged: (value) {
                setState(() {
                  _isEndPole = value ?? false;
                  if (_isEndPole) _isTapPole = false; // Взаимоисключающие
                });
              },
            ),
            CheckboxListTile(
              title: const Text('Отпаечная опора'),
              subtitle: const Text('Создаст отпайку'),
              value: _isTapPole,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              onChanged: (value) {
                setState(() {
                  _isTapPole = value ?? false;
                  if (_isTapPole) _isEndPole = false; // Взаимоисключающие
                });
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _createPoleInNavigatorMode() async {
    if (_currentLocation == null || _currentPowerLineId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось определить местоположение или ЛЭП'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_quickPoleNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите номер опоры в меню настроек'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
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
      
      // Обновляем данные на карте
      await _loadMapData();
      
      // Сбрасываем номер опоры для следующей опоры
      setState(() {
        _quickPoleNumber = '';
        _isEndPole = false;
        if (_isTapPole) {
          _isTapPole = false;
          // После создания отпаечной опоры можно завершить режим навигатора
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Опора создана и пролёт сформирован'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка создания опоры: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showTapInfo(Map<String, dynamic> properties) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Отпайка ${properties['tap_number'] ?? 'N/A'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Тип: ${properties['tap_type'] ?? 'Не указан'}'),
            Text('Напряжение: ${properties['voltage_level'] ?? 'Не указано'} кВ'),
            Text('Мощность: ${properties['power_rating'] ?? 'Не указана'} кВт'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  void _showSubstationInfo(Map<String, dynamic> properties) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Подстанция ${properties['name'] ?? 'N/A'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Код: ${properties['code'] ?? 'Не указан'}'),
            Text('Напряжение: ${properties['voltage_level'] ?? 'Не указано'} кВ'),
            Text('Адрес: ${properties['address'] ?? 'Не указан'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
}
