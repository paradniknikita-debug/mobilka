import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/equipment_catalog.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'equipment_catalog_cache.dart';

/// Результат сравнения локального кэша марок с сервером.
class EquipmentCatalogUpdateDiff {
  const EquipmentCatalogUpdateDiff({
    required this.localCount,
    required this.serverCount,
    required this.addedCount,
    required this.removedCount,
    required this.changedCount,
    required this.serverFingerprint,
    required this.serverItems,
  });

  final int localCount;
  final int serverCount;
  final int addedCount;
  final int removedCount;
  final int changedCount;
  final String serverFingerprint;
  final List<EquipmentCatalogItem> serverItems;

  bool get hasChanges => addedCount > 0 || removedCount > 0 || changedCount > 0;
}

/// Сравнение и обновление справочника марок оборудования.
class EquipmentCatalogUpdateService {
  EquipmentCatalogUpdateService(this._api, this._prefs);

  final ApiServiceWithExport _api;
  final SharedPreferences _prefs;

  static String itemKey(EquipmentCatalogItem item) =>
      '${item.typeCode.trim().toLowerCase()}|'
      '${item.brand.trim().toLowerCase()}|'
      '${item.model.trim().toLowerCase()}';

  static Map<String, dynamic> _itemSnapshot(EquipmentCatalogItem item) => {
        'type_code': item.typeCode.trim().toLowerCase(),
        'brand': item.brand.trim(),
        'model': item.model.trim(),
        'full_name': (item.fullName ?? '').trim(),
        'voltage_kv': item.voltageKv,
        'current_a': item.currentA,
        'manufacturer': (item.manufacturer ?? '').trim(),
        'country': (item.country ?? '').trim(),
        'description': (item.description ?? '').trim(),
        'attrs_json': (item.attrsJson ?? '').trim(),
        'is_active': item.isActive,
      };

  static String fingerprint(List<EquipmentCatalogItem> items) {
    final rows = items.map(_itemSnapshot).toList()
      ..sort((a, b) {
        final ka =
            '${a['type_code']}|${a['brand']}|${a['model']}'.toLowerCase();
        final kb =
            '${b['type_code']}|${b['brand']}|${b['model']}'.toLowerCase();
        return ka.compareTo(kb);
      });
    return jsonEncode(rows);
  }

  static EquipmentCatalogUpdateDiff diff({
    required List<EquipmentCatalogItem> local,
    required List<EquipmentCatalogItem> server,
  }) {
    final localMap = {for (final e in local) itemKey(e): _itemSnapshot(e)};
    final serverMap = {for (final e in server) itemKey(e): _itemSnapshot(e)};

    var added = 0;
    var changed = 0;
    for (final key in serverMap.keys) {
      final localRow = localMap[key];
      if (localRow == null) {
        added++;
      } else if (jsonEncode(localRow) != jsonEncode(serverMap[key])) {
        changed++;
      }
    }
    var removed = 0;
    for (final key in localMap.keys) {
      if (!serverMap.containsKey(key)) removed++;
    }

    return EquipmentCatalogUpdateDiff(
      localCount: local.length,
      serverCount: server.length,
      addedCount: added,
      removedCount: removed,
      changedCount: changed,
      serverFingerprint: fingerprint(server),
      serverItems: server,
    );
  }

  String? get dismissedFingerprint =>
      _prefs.getString(AppConfig.equipmentCatalogDismissedFingerprintKey);

  Future<void> dismissPrompt(String serverFingerprint) async {
    await _prefs.setString(
      AppConfig.equipmentCatalogDismissedFingerprintKey,
      serverFingerprint,
    );
  }

  /// Загружает серверный справочник и сравнивает с локальным кэшем.
  Future<EquipmentCatalogUpdateDiff?> checkForUpdates() async {
    final server = await _api.getEquipmentCatalog(limit: 5000, isActive: true);
    if (server.isEmpty) return null;

    final local = EquipmentCatalogCache.loadAll(_prefs);
    final result = diff(local: local, server: server);
    if (!result.hasChanges) return null;

    final dismissed = dismissedFingerprint;
    if (dismissed != null && dismissed == result.serverFingerprint) {
      return null;
    }
    return result;
  }

  Future<int> applyUpdate(List<EquipmentCatalogItem> serverItems) async {
    await EquipmentCatalogCache.save(_prefs, serverItems);
    await _prefs.setString(
      AppConfig.equipmentCatalogDismissedFingerprintKey,
      fingerprint(serverItems),
    );
    return serverItems.length;
  }
}

final equipmentCatalogUpdateServiceProvider =
    Provider<EquipmentCatalogUpdateService>((ref) {
  return EquipmentCatalogUpdateService(
    ref.watch(apiServiceProvider),
    ref.watch(prefsProvider),
  );
});
