import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../config/map_bounds.dart';
import '../config/map_tile_config.dart';

/// Офлайн-карта (мобильные платформы):
/// — встроенный MBTiles в APK (z4–10, без интернета, как у офлайн-карт Яндекса);
/// — FMTC-кэш для онлайн и опциональной догрузки детальных тайлов.
class OfflineMapService {
  OfflineMapService._();
  static final OfflineMapService _instance = OfflineMapService._();
  static OfflineMapService get instance => _instance;

  bool _initialized = false;
  bool _bundledSeedStarted = false;
  bool _detailDownloadStarted = false;
  bool _mbtilesCopyStarted = false;

  MbTilesTileProvider? _bundledMbtilesProvider;
  int _bundledMbtilesMaxZoom = AppConfig.bundledBasemapMaxZoom;

  static TileLayer _tileLayerForTemplate(String urlTemplate) => TileLayer(
        urlTemplate: urlTemplate,
        userAgentPackageName: MapTileConfig.userAgentPackageName,
        maxNativeZoom: 19,
        maxZoom: 19,
      );

  /// FMTC поддерживается только на iOS/Android/desktop (не web).
  static bool get supportsFmtc => !kIsWeb;

  /// Инициализация FMTC + копирование встроенного MBTiles (не ждём завершения seed).
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
      await _instance._ensureBundledMbtilesReady();
      unawaited(_instance.seedBundledBasemapIfNeeded());
    } catch (e) {
      if (kDebugMode) {
        print('OfflineMapService: ошибка инициализации $e');
      }
    }
  }

  /// Копирует MBTiles из assets в documents (один раз). Работает без сети.
  Future<void> _ensureBundledMbtilesReady() async {
    if (_mbtilesCopyStarted && _bundledMbtilesProvider != null) {
      return;
    }
    _mbtilesCopyStarted = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${AppConfig.bundledMbtilesFileName}');
      final installedVersion =
          prefs.getInt(AppConfig.bundledMbtilesInstalledVersionKey) ?? 0;
      final needsCopy = installedVersion < AppConfig.bundledMbtilesAssetVersion ||
          !await file.exists() ||
          await file.length() < 1024;
      if (needsCopy) {
        if (kDebugMode) {
          print('OfflineMapService: копирование региональной подложки из assets…');
        }
        final data = await rootBundle.load(AppConfig.bundledMbtilesAssetPath);
        await file.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
        await prefs.setInt(
          AppConfig.bundledMbtilesInstalledVersionKey,
          AppConfig.bundledMbtilesAssetVersion,
        );
        _bundledMbtilesProvider?.dispose();
        _bundledMbtilesProvider = null;
      }
      _bundledMbtilesProvider ??=
          MbTilesTileProvider.fromPath(path: file.path);
      _bundledMbtilesMaxZoom = AppConfig.bundledBasemapMaxZoom;
      if (kDebugMode) {
        print(
          'OfflineMapService: региональная подложка готова '
          '(z${AppConfig.offlineMinZoom}–z$_bundledMbtilesMaxZoom, '
          '${(await file.length()) ~/ (1024 * 1024)} МБ)',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('OfflineMapService: _ensureBundledMbtilesReady $e');
      }
    }
  }

  /// Провайдер встроенной подложки — всегда доступен офлайн после [init].
  TileProvider? getBundledMbtilesProvider() => _bundledMbtilesProvider;

  int get bundledMbtilesMaxZoom => _bundledMbtilesMaxZoom;

  /// Дополнительная догрузка в FMTC (онлайн) — z4–10, если MBTiles по какой-то причине недоступен.
  Future<void> seedBundledBasemapIfNeeded() async {
    if (!_initialized || _bundledSeedStarted || _bundledMbtilesProvider != null) {
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
        print('OfflineMapService: базовая подложка FMTC готова');
      }
    } catch (e) {
      if (kDebugMode) {
        print('OfflineMapService: seedBundledBasemapIfNeeded $e');
      }
    } finally {
      _bundledSeedStarted = false;
    }
  }

  /// Детальные тайлы (z11–14) с прокси сервера — только по явному запросу (настройки).
  /// Не запускать автоматически: для всей РБ это ~3 ГБ.
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
          'OfflineMapService: догрузка детальных тайлов z'
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
    if (_bundledMbtilesProvider != null) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConfig.bundledBasemapReadyKey) == true;
  }

  /// Онлайн: FMTC read/update. Офлайн: только встроенный MBTiles + FMTC read.
  TileProvider? getTileProvider({bool offline = false}) {
    if (offline) {
      return _bundledMbtilesProvider;
    }
    if (!_initialized) return _bundledMbtilesProvider;
    try {
      return FMTCTileProvider(
        stores: {
          AppConfig.bundledMapStoreName: BrowseStoreStrategy.read,
          AppConfig.mapStoreName: BrowseStoreStrategy.readUpdateCreate,
        },
      );
    } catch (_) {
      return _bundledMbtilesProvider;
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
