import 'app_config.dart';

/// Единый источник подложки карты (онлайн, офлайн-кэш FMTC, fallback).
/// Все URL должны отдавать один стиль OSM — иначе на разных зумах видны «разные карты».
class MapTileConfig {
  MapTileConfig._();

  /// Основной шаблон: прокси OSM на бэкенде (Redis + тот же upstream, что и в settings).
  static String urlTemplate(String apiBaseUrl) =>
      '$apiBaseUrl/map/tiles/{z}/{x}/{y}.png';

  static String get primaryUrlTemplate => urlTemplate(AppConfig.apiBaseUrl);

  /// Запасной источник — прямой OSM (тот же стиль, что проксирует backend).
  /// Не использовать Carto/другие CDN: у них другая отрисовка.
  static const String fallbackUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Буфер тайлов вокруг экрана: больше — плавнее панорамирование, меньше «серых дыр».
  static const int keepBuffer = 4;
  static const int panBuffer = 2;

  static const String userAgentPackageName = 'com.lepm.mobile';
}
