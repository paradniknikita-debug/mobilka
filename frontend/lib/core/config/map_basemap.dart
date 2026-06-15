import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

import 'vector_basemap_config.dart';

/// Вариант подложки карты. Порядок в [rasterChain] — цепочка автопереключения растра.
class MapBasemapOption {
  const MapBasemapOption({
    required this.id,
    required this.label,
    required this.urlTemplate,
    this.vectorStyleUri,
  });

  final String id;
  final String label;
  /// Шаблон URL растровых тайлов; для вектора пустой.
  final String urlTemplate;
  /// URI MapLibre style JSON (только для векторных подложек).
  final String? vectorStyleUri;

  bool get isVector => vectorStyleUri != null && vectorStyleUri!.isNotEmpty;

  static bool isVectorId(String id) => id.startsWith('vector-');

  static const storageKey = 'map_basemap_id';
  /// OSM DE — совпадает с встроенной офлайн-подложкой приложения
  static const defaultId = 'osm-de';

  static const String vectorLibertyId = 'vector-liberty';
  static const String vectorMapLibreDemoId = 'vector-maplibre-demo';

  static String proxyTemplate(String apiBase) =>
      '$apiBase/map/tiles/{z}/{x}/{y}.png';

  static List<MapBasemapOption> vectorOptions() => [
        const MapBasemapOption(
          id: vectorLibertyId,
          label: 'Вектор OpenFreeMap (POC)',
          urlTemplate: '',
          vectorStyleUri: VectorBasemapConfig.openFreeMapLibertyStyleUri,
        ),
        const MapBasemapOption(
          id: vectorMapLibreDemoId,
          label: 'Вектор MapLibre demo (POC)',
          urlTemplate: '',
          vectorStyleUri: VectorBasemapConfig.mapLibreDemoStyleUri,
        ),
      ];

  static List<MapBasemapOption> rasterChain(String apiBase) => [
        const MapBasemapOption(
          id: 'osm',
          label: 'OpenStreetMap',
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        ),
        MapBasemapOption(
          id: 'proxy',
          label: 'Кэш сервера',
          urlTemplate: proxyTemplate(apiBase),
        ),
        const MapBasemapOption(
          id: 'osm-de',
          label: 'OpenStreetMap (DE)',
          urlTemplate: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
        ),
        const MapBasemapOption(
          id: 'osm-hot',
          label: 'OSM Humanitarian',
          urlTemplate: 'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
        ),
        const MapBasemapOption(
          id: 'arcgis',
          label: 'ArcGIS World',
          urlTemplate:
              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
        ),
        const MapBasemapOption(
          id: 'carto',
          label: 'Carto Voyager',
          urlTemplate:
              'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
        ),
      ];

  /// Все варианты для UI (растр + вектор POC).
  static List<MapBasemapOption> allOptions(String apiBase) => [
        ...rasterChain(apiBase),
        ...vectorOptions(),
      ];

  /// @deprecated Используйте [allOptions] или [rasterChain].
  static List<MapBasemapOption> chain(String apiBase) => allOptions(apiBase);

  static MapBasemapOption byId(String id, {String? apiBase}) {
    final items = allOptions(apiBase ?? AppConfig.apiBaseUrl);
    for (final o in items) {
      if (o.id == id) return o;
    }
    return items.first;
  }

  static MapBasemapOption? nextInChain(String currentId, {String? apiBase}) {
    if (isVectorId(currentId)) {
      return byId(defaultId, apiBase: apiBase);
    }
    final items = rasterChain(apiBase ?? AppConfig.apiBaseUrl);
    final idx = items.indexWhere((o) => o.id == currentId);
    if (idx < 0 || idx >= items.length - 1) return null;
    return items[idx + 1];
  }

  static Future<String> loadSavedId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(storageKey) ?? defaultId;
  }

  static Future<void> saveId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, id);
  }
}
