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

      // Центрируем карту на текущем местоположении
      _mapController.move(_currentLocation!, AppConfig.defaultZoom);
    } catch (e) {
      // Используем координаты по умолчанию (Москва)
      setState(() {
        // Минск: 53.9045, 27.5615
        _currentLocation = const LatLng(53.9045, 27.5615);
      });
      _mapController.move(_currentLocation!, AppConfig.defaultZoom);
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

      setState(() {
        _powerLinesData = futures[0] as Map<String, dynamic>;
        _towersData = futures[1] as Map<String, dynamic>;
        _tapsData = futures[2] as Map<String, dynamic>;
        _substationsData = futures[3] as Map<String, dynamic>;
      });
    } catch (e) {
      print('Ошибка загрузки данных карты: $e');
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
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMapData,
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
                  ),
                  children: [
                    // Тайлы карты
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.lepm.mobile',
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
      final geometry = feature['geometry'];
      final properties = feature['properties'];
      
      if (geometry['type'] == 'Point') {
        final coordinates = geometry['coordinates'];
        final latLng = LatLng(coordinates[1], coordinates[0]);
        
        markers.add(
          Marker(
            point: latLng,
            child: GestureDetector(
              onTap: () => _showTowerInfo(properties),
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

  void _centerOnCurrentLocation() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, AppConfig.defaultZoom);
    }
  }

  void _showTowerInfo(Map<String, dynamic> properties) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Опора ${properties['tower_number']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Тип: ${properties['tower_type']}'),
            Text('Высота: ${properties['height'] ?? 'Не указана'} м'),
            Text('Состояние: ${properties['condition']}'),
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
