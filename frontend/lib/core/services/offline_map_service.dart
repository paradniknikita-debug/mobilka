import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';
import '../config/map_tile_config.dart';

/// Офлайн-карта (мобильные платформы): FMTC с тем же URL, что и [MapTileConfig.primaryUrlTemplate].
/// На web FMTC недоступен — тайлы кэшируются браузером по Cache-Control от API.
class OfflineMapService {
  OfflineMapService._();
  static final OfflineMapService _instance = OfflineMapService._();
  static OfflineMapService get instance => _instance;

  bool _initialized = false;
  bool _downloadStarted = false;

  static TileLayer _tileLayerForStore(String apiBaseUrl) => TileLayer(
        urlTemplate: MapTileConfig.urlTemplate(apiBaseUrl),
        userAgentPackageName: MapTileConfig.userAgentPackageName,
        maxNativeZoom: 19,
        maxZoom: 19,
      );

  /// FMTC поддерживается только на iOS/Android/desktop (не web).
  static bool get supportsFmtc => !kIsWeb;

  /// Вызвать при старте приложения (main).
  static Future<void> init() async {
    if (!supportsFmtc) {
      if (kDebugMode) {
        print(
          'OfflineMapService: web — FMTC недоступен, тайлы по сети + HTTP-кэш браузера.',
        );
      }
      return;
    }
    try {
      await FMTCObjectBoxBackend().initialise();
      _instance._initialized = true;
      if (kDebugMode) {
        print('OfflineMapService: FMTC инициализирован');
      }
      unawaited(_instance._ensureStoreAndDownloadBelarus());
    } catch (e) {
      if (kDebugMode) {
        print('OfflineMapService: ошибка инициализации $e');
      }
    }
  }

  bool get isInitialized => _initialized;

  /// Слой тайлов: кэш FMTC + при онлайне догрузка с API.
  /// [offline] — только чтение кэша, без сетевых запросов (нет зависаний).
  TileProvider? getTileProvider({bool offline = false}) {
    if (!_initialized) return null;
    try {
      return FMTCTileProvider(
        stores: {
          AppConfig.mapStoreName: offline
              ? BrowseStoreStrategy.read
              : BrowseStoreStrategy.readUpdateCreate,
        },
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _ensureStoreAndDownloadBelarus() async {
    if (!_initialized || _downloadStarted) return;
    try {
      final store = const FMTCStore(AppConfig.mapStoreName);
      final exists = await store.manage.ready;
      if (!exists) {
        await store.manage.create();
        if (kDebugMode) {
          print('OfflineMapService: хранилище ${AppConfig.mapStoreName} создано');
        }
      }

      _downloadStarted = true;
      await _downloadBelarusRegion(store);
    } catch (e) {
      if (kDebugMode) print('OfflineMapService: ошибка загрузки тайлов $e');
      _downloadStarted = false;
    }
  }

  /// Предзагрузка тайлов Беларуси (тот же URL, что на карте).
  Future<void> _downloadBelarusRegion(FMTCStore store) async {
    try {
      final bounds = LatLngBounds(
        const LatLng(AppConfig.belarusSouth, AppConfig.belarusWest),
        const LatLng(AppConfig.belarusNorth, AppConfig.belarusEast),
      );
      final apiBase = AppConfig.apiBaseUrl;
      final region = RectangleRegion(bounds).toDownloadable(
        minZoom: AppConfig.offlineMinZoom,
        maxZoom: AppConfig.offlineMaxZoom,
        options: _tileLayerForStore(apiBase),
      );

      final result = store.download.startForeground(region: region);
      if (kDebugMode) {
        print(
          'OfflineMapService: загрузка тайлов ($apiBase) зум '
          '${AppConfig.offlineMinZoom}-${AppConfig.offlineMaxZoom}',
        );
      }
      await result.downloadProgress.last;
      if (kDebugMode) {
        print('OfflineMapService: предзагрузка тайлов Беларуси завершена');
      }
    } catch (e) {
      if (kDebugMode) print('OfflineMapService: _downloadBelarusRegion $e');
    } finally {
      _downloadStarted = false;
    }
  }
}
