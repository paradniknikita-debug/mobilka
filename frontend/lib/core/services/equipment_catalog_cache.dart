import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/equipment_catalog.dart';

class EquipmentCatalogCache {
  static Future<void> save(
    SharedPreferences prefs,
    List<EquipmentCatalogItem> items,
  ) async {
    final payload = items
        .map(
          (e) => {
            'id': e.id,
            'type_code': e.typeCode,
            'brand': e.brand,
            'model': e.model,
            'full_name': e.fullName,
            'voltage_kv': e.voltageKv,
            'current_a': e.currentA,
            'manufacturer': e.manufacturer,
            'country': e.country,
            'description': e.description,
            'attrs_json': e.attrsJson,
            'is_active': e.isActive,
          },
        )
        .toList();
    await prefs.setString(AppConfig.equipmentCatalogCacheKey, jsonEncode(payload));
    await prefs.setString(
      AppConfig.equipmentCatalogCacheUpdatedAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  static List<EquipmentCatalogItem> loadAll(SharedPreferences prefs) {
    final raw = prefs.getString(AppConfig.equipmentCatalogCacheKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((m) => EquipmentCatalogItem.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static List<EquipmentCatalogItem> loadByType(
    SharedPreferences prefs,
    String typeCode,
  ) {
    final wanted = typeCode.trim().toLowerCase();
    if (wanted.isEmpty) return const [];
    final all = loadAll(prefs);
    return all.where((e) => e.typeCode.trim().toLowerCase() == wanted).toList();
  }

  /// Встроенный справочник из assets — для офлайна до первой синхронизации с сервером.
  static Future<List<EquipmentCatalogItem>> loadBundledDefaults() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/equipment/equipment_catalog_defaults.json',
      );
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((m) => EquipmentCatalogItem.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Если кэш пуст — подставляет встроенные марки (разъединители 10 кВ и др.).
  static Future<void> ensureBundledDefaults(SharedPreferences prefs) async {
    if (loadAll(prefs).isNotEmpty) return;
    final bundled = await loadBundledDefaults();
    if (bundled.isEmpty) return;
    await save(prefs, bundled);
  }

  /// Слияние: серверные записи + недостающие из bundled (по type/brand/model).
  static Future<void> mergeBundledIfMissing(SharedPreferences prefs) async {
    final existing = loadAll(prefs);
    if (existing.isEmpty) {
      await ensureBundledDefaults(prefs);
      return;
    }
    final bundled = await loadBundledDefaults();
    if (bundled.isEmpty) return;
    String key(EquipmentCatalogItem e) =>
        '${e.typeCode.trim().toLowerCase()}|${e.brand.trim().toLowerCase()}|${e.model.trim().toLowerCase()}';
    final seen = {for (final e in existing) key(e)};
    final merged = [...existing];
    for (final item in bundled) {
      if (seen.add(key(item))) merged.add(item);
    }
    if (merged.length > existing.length) {
      await save(prefs, merged);
    }
  }
}

