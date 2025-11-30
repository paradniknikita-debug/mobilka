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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    // Откладываем инициализацию до следующего кадра для быстрого отображения UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMap();
    });
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
      ]);

      final powerLinesData = futures[0] as Map<String, dynamic>;
      final polesData = futures[1] as Map<String, dynamic>;
      final tapsData = futures[2] as Map<String, dynamic>;
      final substationsData = futures[3] as Map<String, dynamic>;

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
              ],
            ),
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
                if (_powerLinesData != null)
                  _buildPowerLinesTree(),
                if (_substationsData != null)
                  _buildSubstationsTree(),
                if (_polesData != null)
                  _buildPolesTree(),
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

  Widget _buildPowerLinesTree() {
    final features = _powerLinesData?['features'] as List<dynamic>? ?? [];
    if (features.isEmpty) return const SizedBox.shrink();

    return ExpansionTile(
      leading: const Icon(Icons.electrical_services, color: Colors.red),
      title: Text('ЛЭП (${features.length})'),
      children: features.map<Widget>((feature) {
        final props = feature['properties'] as Map<String, dynamic>;
        return ListTile(
          dense: true,
          title: Text(props['name'] ?? 'Без названия'),
          subtitle: Text('${props['voltage_level']} кВ • ${props['pole_count'] ?? 0} опор'),
          onTap: () {
            Navigator.of(context).pop(); // Закрываем Drawer
            _centerOnFeature(feature);
          },
        );
      }).toList(),
    );
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

  void _showPoleInfo(Map<String, dynamic> properties) {
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
