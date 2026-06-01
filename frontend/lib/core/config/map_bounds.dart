import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'app_config.dart';

/// Границы карты приложения — только территория РБ (подложка, офлайн-кэш, pan/zoom).
abstract final class MapBounds {
  static LatLngBounds get belarus => LatLngBounds(
        const LatLng(AppConfig.belarusSouth, AppConfig.belarusWest),
        const LatLng(AppConfig.belarusNorth, AppConfig.belarusEast),
      );
}
