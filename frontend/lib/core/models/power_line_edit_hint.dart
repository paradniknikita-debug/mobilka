/// Ответ `GET /power-lines/{id}/edit-hint` — предупреждение о параллельном редактировании.
class PowerLineEditHint {
  const PowerLineEditHint({
    required this.warn,
    this.message,
    this.recentEditors = const [],
  });

  final bool warn;
  final String? message;
  final List<PowerLineRecentEditor> recentEditors;

  factory PowerLineEditHint.fromJson(Map<String, dynamic> json) {
    final editorsRaw = json['recent_editors'];
    final editors = <PowerLineRecentEditor>[];
    if (editorsRaw is List) {
      for (final e in editorsRaw) {
        if (e is Map<String, dynamic>) {
          editors.add(PowerLineRecentEditor.fromJson(e));
        } else if (e is Map) {
          editors.add(PowerLineRecentEditor.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return PowerLineEditHint(
      warn: json['warn'] == true,
      message: json['message'] as String?,
      recentEditors: editors,
    );
  }
}

class PowerLineRecentEditor {
  const PowerLineRecentEditor({
    required this.userId,
    this.source,
    this.lastEditAt,
  });

  final int userId;
  final String? source;
  final String? lastEditAt;

  factory PowerLineRecentEditor.fromJson(Map<String, dynamic> json) {
    return PowerLineRecentEditor(
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      source: json['source'] as String?,
      lastEditAt: json['last_edit_at'] as String?,
    );
  }

  String get sourceLabel {
    switch (source) {
      case 'web':
        return 'веб';
      case 'flutter':
        return 'мобильное';
      default:
        return source ?? 'неизвестно';
    }
  }
}
