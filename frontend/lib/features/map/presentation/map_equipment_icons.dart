import 'package:flutter_svg/flutter_svg.dart';

/// Пути к SVG и прекэш иконок линейного оборудования (мобильная карта).
class MapEquipmentIcons {
  MapEquipmentIcons._();

  static const Map<String, String> assetByKey = {
    'recloser': 'assets/equipment/recloser/recloser.svg',
    'breaker': 'assets/equipment/breaker/breaker.svg',
    'zn': 'assets/equipment/zn/zn.svg',
    'disconnector': 'assets/equipment/disconnector/disconnector.svg',
    'arrester': 'assets/equipment/arrester/arrester.svg',
  };

  static const String breakerOutline =
      'assets/equipment/breaker/breaker_outline.svg';

  static bool _precached = false;

  /// Ключ с API (`icon`) или полный путь `assets/...` → путь к SVG.
  static String? assetPathFromIconProperty(dynamic icon) {
    if (icon == null) return null;
    final s = icon.toString().trim();
    if (s.isEmpty) return null;
    if (s.startsWith('assets/')) return s;
    return assetByKey[s.toLowerCase()];
  }

  /// Нормализует GeoJSON оборудования с сервера: `icon` → полный путь в properties.
  static Map<String, dynamic> normalizeEquipmentGeoJson(
    Map<String, dynamic> raw,
  ) {
    final features = raw['features'];
    if (features is! List) return raw;
    final out = <dynamic>[];
    for (final f in features) {
      if (f is! Map) {
        out.add(f);
        continue;
      }
      final props = f['properties'];
      if (props is Map<String, dynamic>) {
        final path = assetPathFromIconProperty(props['icon']);
        if (path != null) {
          props['icon'] = path;
        }
      } else if (props is Map) {
        final m = Map<String, dynamic>.from(props);
        final path = assetPathFromIconProperty(m['icon']);
        if (path != null) m['icon'] = path;
        out.add({...f, 'properties': m});
        continue;
      }
      out.add(f);
    }
    return {'type': raw['type'] ?? 'FeatureCollection', 'features': out};
  }

  static Future<void> precache() async {
    if (_precached) return;
    _precached = true;
    for (final path in [...assetByKey.values, breakerOutline]) {
      try {
        final loader = SvgAssetLoader(path);
        await svg.cache.putIfAbsent(
          loader.cacheKey(null),
          () => loader.loadBytes(null),
        );
      } catch (_) {}
    }
  }
}
