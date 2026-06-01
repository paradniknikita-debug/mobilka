import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../config/map_bounds.dart';
import '../config/map_tile_config.dart';

/// Офлайн-карта (мобильные платформы): FMTC.
/// Базовая подложка (z4–8) — при первом запуске приложения, без авторизации.
/// Детальные тайлы (z9–14) — фоном после входа, с прокси API.
class OfflineMapService {
  OfflineMapService._();
  static final OfflineMapService _instance = OfflineMapService._();
  static OfflineMapService get instance => _instance;

  bool _initialized = false;
  bool _bundledSeedStarted = false;
  bool _detailDownloadStarted = false;

  static TileLayer _tileLayerForTemplate(String urlTemplate) => TileLayer(
        urlTemplate: urlTemplate,
        userAgentPackageName: MapTileConfig.userAgentPackageName,
        maxNativeZoom: 19,
        maxZoom: 19,
      );

  /// FMTC поддерживается только на iOS/Android/desktop (не web).
  static bool get supportsFmtc => !kIsWeb;

  /// Инициализация FMTC + фоновая базовая подложка (не ждём завершения).
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
      unawaited(_instance.seedBundledBasemapIfNeeded());
    } catch (e) {
      if (kDebugMode) {
        print('OfflineMapService: ошибка инициализации $e');
      }
    }
  }

  /// Базовая подложка OSM DE (z4–8) — один раз при первом запуске, до входа в аккаунт.
  Future<void> seedBundledBasemapIfNeeded() async {
    if (!_initialized || _bundledSeedStarted) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(AppConfig.bundledBasemapReadyKey) == true) {
      return;
    }
    _bundledSeedStarted = true;
    try {
      const store = FMTCStore(AppConfig.bundledMapStoreName);
      if (!await store.manage.ready) {
        await store.manage.create();
      }
      if (kDebugMode) {
        print(
          'OfflineMapService: загрузка базовой подложки z'
          '${AppConfig.offlineMinZoom}-${AppConfig.bundledBasemapMaxZoom}…',
        );
      }
      await _downloadRegion(
        store: store,
        urlTemplate: AppConfig.bundledBasemapUrlTemplate,
        minZoom: AppConfig.offlineMinZoom,
        maxZoom: AppConfig.bundledBasemapMaxZoom,
      );
      await prefs.setBool(AppConfig.bundledBasemapReadyKey, true);
      if (kDebugMode) {
        print('OfflineMapService: базовая подложка готова');
      }
    } catch (e) {
      if (kDebugMode) {
        print('OfflineMapService: seedBundledBasemapIfNeeded $e');
      }
    } finally {
      _bundledSeedStarted = false;
    }
  }

  /// Детальные тайлы (z9–14) с прокси сервера — фоном, не блокирует UI.
  Future<void> enhanceOfflineTilesInBackground() async {
    if (!_initialized || _detailDownloadStarted) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(AppConfig.offlineTilesReadyKey) == true) {
      return;
    }
    _detailDownloadStarted = true;
    try {
      const store = FMTCStore(AppConfig.mapStoreName);
      if (!await store.manage.ready) {
        await store.manage.create();
      }
      if (kDebugMode) {
        print(
          'OfflineMapService: фоновая догрузка z'
          '${AppConfig.bundledBasemapMaxZoom + 1}-${AppConfig.offlineMaxZoom}…',
        );
      }
      await _downloadRegion(
        store: store,
        urlTemplate: MapTileConfig.urlTemplate(AppConfig.apiBaseUrl),
        minZoom: AppConfig.bundledBasemapMaxZoom + 1,
        maxZoom: AppConfig.offlineMaxZoom,
      );
      await prefs.setBool(AppConfig.offlineTilesReadyKey, true);
    } catch (e) {
      if (kDebugMode) {
        print('OfflineMapService: enhanceOfflineTilesInBackground $e');
      }
    } finally {
      _detailDownloadStarted = false;
    }
  }

  bool get isInitialized => _initialized;

  Future<bool> isBundledBasemapReady() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConfig.bundledBasemapReadyKey) == true;
  }

  /// Слой тайлов: встроенная подложка + кэш сервера.
  TileProvider? getTileProvider({bool offline = false}) {
    if (!_initialized) return null;
    try {
      return FMTCTileProvider(
        stores: {
          AppConfig.bundledMapStoreName: BrowseStoreStrategy.read,
          AppConfig.mapStoreName: offline
              ? BrowseStoreStrategy.read
              : BrowseStoreStrategy.readUpdateCreate,
        },
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _downloadRegion({
    required FMTCStore store,
    required String urlTemplate,
    required int minZoom,
    required int maxZoom,
  }) async {
    final bounds = MapBounds.belarus;
    final region = RectangleRegion(bounds).toDownloadable(
      minZoom: minZoom,
      maxZoom: maxZoom,
      options: _tileLayerForTemplate(urlTemplate),
    );
    final result = store.download.startForeground(region: region);
    await result.downloadProgress.last;
  }
}
