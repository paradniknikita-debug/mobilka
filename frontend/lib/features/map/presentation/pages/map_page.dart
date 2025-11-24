import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/services/api_service.dart';
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
  bool _showObjectTree = false;
  Map<String, dynamic>? _powerLinesData;
  Map<String, dynamic>? _towersData;
  Map<String, dynamic>? _tapsData;
  Map<String, dynamic>? _substationsData;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      // Получаем текущее местоположение
      await _getCurrentLocation();
      
      // Загружаем данные с сервера
      await _loadMapData();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки карты: $e')),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requestResult = await Geolocator.requestPermission();
        if (requestResult == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });

      // Центрируем карту на текущем местоположении после построения виджета
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentLocation != null) {
          _mapController.move(_currentLocation!, AppConfig.defaultZoom);
        }
      });
    } catch (e) {
      // Используем координаты по умолчанию (Минск)
      setState(() {
        // Минск: 53.9045, 27.5615
        _currentLocation = const LatLng(53.9045, 27.5615);
      });
      // Центрируем карту после построения виджета
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentLocation != null) {
          _mapController.move(_currentLocation!, AppConfig.defaultZoom);
        }
      });
    }
  }

  Future<void> _loadMapData() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      
      // Загружаем данные параллельно
      final futures = await Future.wait([
        apiService.getPowerLinesGeoJSON(),
        apiService.getTowersGeoJSON(),
        apiService.getTapsGeoJSON(),
        apiService.getSubstationsGeoJSON(),
      ]);

      final powerLinesData = futures[0] as Map<String, dynamic>;
      final towersData = futures[1] as Map<String, dynamic>;
      final tapsData = futures[2] as Map<String, dynamic>;
      final substationsData = futures[3] as Map<String, dynamic>;

      // Отладочная информация
      print('Загружено данных:');
      print('  ЛЭП: ${(powerLinesData['features'] as List?)?.length ?? 0}');
      print('  Опоры: ${(towersData['features'] as List?)?.length ?? 0}');
      print('  Отпайки: ${(tapsData['features'] as List?)?.length ?? 0}');
      print('  Подстанции: ${(substationsData['features'] as List?)?.length ?? 0}');

      setState(() {
        _powerLinesData = powerLinesData;
        _towersData = towersData;
        _tapsData = tapsData;
        _substationsData = substationsData;
      });

      // Центрируем карту на объектах, если они есть
      _centerOnObjects();
    } catch (e) {
      print('Ошибка загрузки данных карты: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки данных: $e')),
        );
      }
    }
  }

  void _centerOnObjects() {
    // Пытаемся найти первую опору или подстанцию для центрирования
    LatLng? center;
    
    if (_towersData != null) {
      final features = _towersData!['features'] as List<dynamic>?;
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
            icon: Icon(_showObjectTree ? Icons.close : Icons.list),
            onPressed: () {
              setState(() {
                _showObjectTree = !_showObjectTree;
              });
            },
            tooltip: _showObjectTree ? 'Скрыть дерево объектов' : 'Показать дерево объектов',
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
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Карта
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    // Минск: 53.9045, 27.5615 (по умолчанию, если нет текущего местоположения)
                    initialCenter: _currentLocation ?? const LatLng(53.9045, 27.5615),
                    initialZoom: AppConfig.defaultZoom,
                    minZoom: AppConfig.minZoom,
                    maxZoom: AppConfig.maxZoom,
                    onMapReady: () {
                      // Карта готова, можно безопасно использовать контроллер
                      if (_currentLocation != null) {
                        _mapController.move(_currentLocation!, AppConfig.defaultZoom);
                      }
                    },
                  ),
                  children: [
                    // Тайлы карты (CartoDB Positron - легкий стиль без POI)
                    TileLayer(
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.lepm.mobile',
                      maxZoom: 19,
                    ),
                    
                    // ЛЭП
                    if (_powerLinesData != null)
                      PolylineLayer(
                        polylines: _buildPowerLinePolylines(),
                      ),
                    
                    // Опоры
                    if (_towersData != null)
                      MarkerLayer(
                        markers: _buildTowerMarkers(),
                      ),
                    
                    // Отпайки
                    if (_tapsData != null)
                      MarkerLayer(
                        markers: _buildTapMarkers(),
                      ),
                    
                    // Подстанции
                    if (_substationsData != null)
                      MarkerLayer(
                        markers: _buildSubstationMarkers(),
                      ),
                  ],
                ),
                
                // Легенда
                Positioned(
                  top: 16,
                  right: 16,
                  child: _buildLegend(),
                ),
                
                // Дерево объектов
                if (_showObjectTree)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: _buildObjectTree(),
                  ),
              ],
            ),
    );
  }

  List<Polyline> _buildPowerLinePolylines() {
    final polylines = <Polyline>[];
    final features = _powerLinesData?['features'] as List<dynamic>? ?? [];

    for (final feature in features) {
      final geometry = feature['geometry'];
      final properties = feature['properties'];
      
      if (geometry['type'] == 'LineString') {
        final coordinates = geometry['coordinates'] as List<dynamic>;
        final points = coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();
        
        polylines.add(
          Polyline(
            points: points,
            strokeWidth: 3.0,
            color: Colors.red,
          ),
        );
      }
    }

    return polylines;
  }

  List<Marker> _buildTowerMarkers() {
    final markers = <Marker>[];
    final features = _towersData?['features'] as List<dynamic>? ?? [];

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
                  onTap: () => _showTowerInfo(properties ?? {}),
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
      final geometry = feature['geometry'];
      final properties = feature['properties'];
      
      if (geometry['type'] == 'Point') {
        final coordinates = geometry['coordinates'];
        final latLng = LatLng(coordinates[1], coordinates[0]);
        
        markers.add(
          Marker(
            point: latLng,
            child: GestureDetector(
              onTap: () => _showTapInfo(properties),
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

    return markers;
  }

  List<Marker> _buildSubstationMarkers() {
    final markers = <Marker>[];
    final features = _substationsData?['features'] as List<dynamic>? ?? [];

    for (final feature in features) {
      final geometry = feature['geometry'];
      final properties = feature['properties'];
      
      if (geometry['type'] == 'Point') {
        final coordinates = geometry['coordinates'];
        final latLng = LatLng(coordinates[1], coordinates[0]);
        
        markers.add(
          Marker(
            point: latLng,
            child: GestureDetector(
              onTap: () => _showSubstationInfo(properties),
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

  Widget _buildObjectTree() {
    return Card(
      child: Container(
        width: 280,
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Text(
                    'Объекты',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      setState(() {
                        _showObjectTree = false;
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ЛЭП
                    if (_powerLinesData != null)
                      _buildPowerLinesTree(),
                    
                    // Подстанции
                    if (_substationsData != null)
                      _buildSubstationsTree(),
                    
                    // Опоры
                    if (_towersData != null)
                      _buildPolesTree(),
                    
                    // Отпайки
                    if (_tapsData != null)
                      _buildTapsTree(),
                  ],
                ),
              ),
            ),
          ],
        ),
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
          onTap: () => _centerOnFeature(feature),
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
          onTap: () => _centerOnFeature(feature),
        );
      }).toList(),
    );
  }

  Widget _buildPolesTree() {
    final features = _towersData?['features'] as List<dynamic>? ?? [];
    if (features.isEmpty) return const SizedBox.shrink();

    return ExpansionTile(
      leading: Icon(MdiIcons.transmissionTower, color: Colors.blue),
      title: Text('Опоры (${features.length})'),
      children: features.map<Widget>((feature) {
        final props = feature['properties'] as Map<String, dynamic>;
        return ListTile(
          dense: true,
          title: Text(props['pole_number'] ?? props['tower_number'] ?? 'N/A'),
          subtitle: Text('${props['pole_type'] ?? props['tower_type'] ?? 'N/A'} • ${props['condition'] ?? 'N/A'}'),
          onTap: () => _centerOnFeature(feature),
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
          onTap: () => _centerOnFeature(feature),
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
        // Берем среднюю точку линии
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
        // Игнорируем ошибки, если контроллер еще не готов
        print('Ошибка центрирования карты: $e');
      }
    }
  }

  void _showTowerInfo(Map<String, dynamic> properties) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Опора ${properties['pole_number'] ?? properties['tower_number'] ?? 'N/A'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Тип: ${properties['pole_type'] ?? properties['tower_type'] ?? 'Не указан'}'),
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
        title: Text('Отпайка ${properties['tap_number']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Тип: ${properties['tap_type']}'),
            Text('Напряжение: ${properties['voltage_level']} кВ'),
            Text('Мощность: ${properties['power_rating'] ?? 'Не указана'} кВА'),
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
        title: Text(properties['name']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Код: ${properties['code']}'),
            Text('Напряжение: ${properties['voltage_level']} кВ'),
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
