import 'dart:convert';

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
}

