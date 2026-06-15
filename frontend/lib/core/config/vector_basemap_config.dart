/// Конфигурация векторных подложек (POC). Растровые варианты — [MapBasemapOption].
abstract final class VectorBasemapConfig {
  /// OpenFreeMap — бесплатный стиль без API-ключа (онлайн).
  static const String openFreeMapLibertyStyleUri =
      'https://tiles.openfreemap.org/styles/liberty';

  /// Запасной стиль MapLibre (демо-тайлы).
  static const String mapLibreDemoStyleUri =
      'https://demotiles.maplibre.org/style.json';
}
