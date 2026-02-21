import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';

/// Сервис офлайн-карты: инициализация FMTC, загрузка тайлов Беларуси при старте.
class OfflineMapService {
  OfflineMapService._();
  static final OfflineMapService _instance = OfflineMapService._();
  static OfflineMapService get instance => _instance;

  bool _initialized = false;
  bool _downloadStarted = false;

  static final TileLayer _osmTileLayer = TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.lepm.mobile',
    maxNativeZoom: 19,
    maxZoom: 18,
  );

  /// Вызвать при старте приложения (main). Инициализирует FMTC и при первом запуске
  /// создаёт хранилище и запускает фоновую загрузку тайлов Беларуси.
  static Future<void> init() async {
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

  /// Слой тайлов с кэшем (сначала кэш, при отсутствии — сеть).
  /// Возвращает null до инициализации или при ошибке.
  TileProvider? getTileProvider() {
    if (!_initialized) return null;
    try {
      return FMTCTileProvider(
        stores: const {'osm_belarus': BrowseStoreStrategy.readUpdateCreate},
      );
    } catch (_) {
      return null;
    }
  }

  /// Создаёт хранилище при необходимости и запускает загрузку региона Беларуси.
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

  /// Загрузка тайлов для территории Беларуси (в фоне).
  Future<void> _downloadBelarusRegion(FMTCStore store) async {
    try {
      final bounds = LatLngBounds(
        const LatLng(AppConfig.belarusSouth, AppConfig.belarusWest),
        const LatLng(AppConfig.belarusNorth, AppConfig.belarusEast),
      );
      final region = RectangleRegion(bounds).toDownloadable(
        minZoom: AppConfig.offlineMinZoom,
        maxZoom: AppConfig.offlineMaxZoom,
        options: _osmTileLayer,
      );

      final result = store.download.startForeground(region: region);
      if (kDebugMode) {
        print('OfflineMapService: загрузка тайлов Беларуси запущена (зум ${AppConfig.offlineMinZoom}-${AppConfig.offlineMaxZoom})');
      }
      await result.downloadProgress.last;
      if (kDebugMode) {
        print('OfflineMapService: загрузка тайлов Беларуси завершена');
      }
    } catch (e) {
      if (kDebugMode) print('OfflineMapService: ошибка _downloadBelarusRegion $e');
    } finally {
      _downloadStarted = false;
    }
  }
}
