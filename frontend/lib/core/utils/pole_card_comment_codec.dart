import 'dart:convert';

import 'package:uuid/uuid.dart';

/// История комментариев в [Pole.cardComment]: JSON-массив или устаревший plain text.
class PoleCardCommentCodec {
  PoleCardCommentCodec._();

  static const _uuid = Uuid();

  /// Снимает BOM, внешние кавычки и одно уровень JSON-string (`"[{...}]"` → массив).
  static String _normalizeRaw(String raw) {
    var s = raw.trim();
    if (s.startsWith('\ufeff')) s = s.substring(1).trim();
    // Двойное кодирование: строка, внутри которой снова JSON.
    for (var i = 0; i < 3; i++) {
      if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
        try {
          final inner = jsonDecode(s);
          if (inner is String) {
            s = inner.trim();
            continue;
          }
        } catch (_) {}
      }
      break;
    }
    return s;
  }

  static List<Map<String, dynamic>> parse(String? raw) {
    if (raw == null) return [];
    var s = raw.toString().trim();
    if (s.isEmpty) return [];

    s = _normalizeRaw(s);

    dynamic decoded;
    for (var attempt = 0; attempt < 4; attempt++) {
      if (!s.startsWith('[') && !s.startsWith('{')) break;
      try {
        decoded = jsonDecode(s);
      } catch (_) {
        decoded = null;
        break;
      }
      if (decoded is String) {
        final t = decoded.trim();
        if (t.startsWith('[') || t.startsWith('{')) {
          s = t;
          continue;
        }
        decoded = null;
        break;
      }
      break;
    }

    if (decoded != null) {
      List<dynamic>? arr;
      if (decoded is List) {
        arr = decoded;
      } else if (decoded is Map && decoded['messages'] is List) {
        arr = decoded['messages'] as List<dynamic>;
      }
      if (arr != null) {
        final out = <Map<String, dynamic>>[];
        for (final e in arr) {
          if (e is! Map) continue;
          final m = Map<String, dynamic>.from(e);
          final text = (m['text'] as String?)?.trim() ?? '';
          final voiceUrl = (m['voice_url'] as String?)?.trim() ?? '';
          if (text.isEmpty && voiceUrl.isEmpty) continue;
          out.add({
            'id': m['id']?.toString() ?? _uuid.v4(),
            'text': text,
            'at': m['at']?.toString() ?? '',
            if (m['user_id'] != null) 'user_id': m['user_id'],
            'user_name': m['user_name']?.toString() ?? '',
            if (voiceUrl.isNotEmpty) 'voice_url': voiceUrl,
            if (m['duration_sec'] != null) 'duration_sec': m['duration_sec'],
          });
        }
        out.sort((a, b) => '${a['at']}'.compareTo('${b['at']}'));
        if (out.isNotEmpty) return out;
      }
    }

    // Один неразобранный фрагмент — как старый текстовый комментарий (не JSON-массив).
    return [
      {
        'id': _uuid.v4(),
        'text': s,
        'at': '',
        'user_name': '',
      }
    ];
  }

  static String? serialize(List<Map<String, dynamic>> messages) {
    if (messages.isEmpty) return null;
    return jsonEncode(messages);
  }

  static List<Map<String, dynamic>> append(
    List<Map<String, dynamic>> messages,
    String text, {
    required int userId,
    required String userName,
  }) {
    final t = text.trim();
    if (t.isEmpty) return messages;
    final now = DateTime.now().toUtc().toIso8601String();
    return [
      ...messages,
      {
        'id': _uuid.v4(),
        'text': t,
        'at': now,
        'user_id': userId,
        'user_name': userName,
      }
    ];
  }

  /// Голосовое сообщение в том же JSON, что и текстовые комментарии.
  static List<Map<String, dynamic>> appendVoice(
    List<Map<String, dynamic>> messages, {
    required String voiceUrl,
    double? durationSec,
    String caption = '',
    required int userId,
    required String userName,
  }) {
    final u = voiceUrl.trim();
    if (u.isEmpty) return messages;
    final now = DateTime.now().toUtc().toIso8601String();
    final cap = caption.trim();
    return [
      ...messages,
      {
        'id': _uuid.v4(),
        'text': cap,
        'at': now,
        'user_id': userId,
        'user_name': userName,
        'voice_url': u,
        if (durationSec != null) 'duration_sec': durationSec,
      }
    ];
  }

  /// Дата/время в московской зоне (UTC+3), независимо от часового пояса устройства.
  static String formatDateTime(String? at) {
    if (at == null || at.trim().isEmpty) return '—';
    final d = DateTime.tryParse(at);
    if (d == null) return at;
    final msk = d.toUtc().add(const Duration(hours: 3));
    final dd = msk.day.toString().padLeft(2, '0');
    final mm = msk.month.toString().padLeft(2, '0');
    final yyyy = msk.year;
    final hh = msk.hour.toString().padLeft(2, '0');
    final min = msk.minute.toString().padLeft(2, '0');
    return '$dd.$mm.$yyyy $hh:$min МСК';
  }
}
