import 'app_config.dart';

/// Единый источник подложки карты (онлайн, офлайн-кэш FMTC).
/// Выбор и автопереключение — [MapBasemapOption] в map_basemap.dart.
class MapTileConfig {
  MapTileConfig._();

  /// Основной шаблон: прокси OSM на бэкенде (Redis + тот же upstream, что и в settings).
  static String urlTemplate(String apiBaseUrl) =>
      '$apiBaseUrl/map/tiles/{z}/{x}/{y}.png';

  static String get primaryUrlTemplate => urlTemplate(AppConfig.apiBaseUrl);

  /// Буфер тайлов вокруг экрана: больше — плавнее панорамирование, меньше «серых дыр».
  static const int keepBuffer = 4;
  static const int panBuffer = 2;

  static const String userAgentPackageName = 'com.lepm.mobile';
}
