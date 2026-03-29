import 'dart:convert';

import 'package:uuid/uuid.dart';

/// Формат хранения вложений карточки опоры в [Poles.cardCommentAttachment].
/// Legacy: JSON-массив `[{t,p|url,...}]`.
/// Расширение: объект `{ "schema": 2, "items": [...], "last_edit": {...} }`.
class PoleCardAttachmentCodec {
  PoleCardAttachmentCodec._();

  static const int schemaV2 = 2;

  /// Разбор в список элементов (массив или `items` у schema v2).
  static List<Map<String, dynamic>> parseItemsJson(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (decoded is Map && decoded['items'] is List) {
        return (decoded['items'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Map<String, dynamic>? parseLastEdit(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['last_edit'] is Map) {
        return Map<String, dynamic>.from(decoded['last_edit'] as Map);
      }
    } catch (_) {}
    return null;
  }

  /// Сериализация для локальной БД / синка (с метаданными последнего изменения).
  static String encodeForStorage(
    List<Map<String, dynamic>> items, {
    required int userId,
    String? userName,
    String lastKind = 'edit',
  }) {
    if (items.isEmpty) return '';
    final now = DateTime.now().toUtc().toIso8601String();
    return jsonEncode({
      'schema': schemaV2,
      'items': items,
      'last_edit': {
        'kind': lastKind,
        'at': now,
        'user_id': userId,
        if (userName != null && userName.isNotEmpty) 'user_name': userName,
      },
    });
  }

  static Map<String, dynamic> newPhotoAttachment(
    String path, {
    required int userId,
    String? userName,
  }) {
    return {
      'id': const Uuid().v4(),
      't': 'photo',
      'p': path,
      'added_by': userId,
      'added_at': DateTime.now().toUtc().toIso8601String(),
      if (userName != null && userName.isNotEmpty) 'added_by_name': userName,
    };
  }

  static Map<String, dynamic> newVoiceAttachment(
    String path, {
    required int userId,
    String? userName,
  }) {
    return {
      'id': const Uuid().v4(),
      't': 'voice',
      'p': path,
      'added_by': userId,
      'added_at': DateTime.now().toUtc().toIso8601String(),
      if (userName != null && userName.isNotEmpty) 'added_by_name': userName,
    };
  }
}
