/// Сессия обхода ЛЭП (ответ API с именами пользователя и ЛЭП).
class PatrolSession {
  final int id;
  final int userId;
  /// ID линии (ЛЭП). Единое поле line_id.
  final int lineId;
  final String? note;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String userName;
  final String powerLineName;

  const PatrolSession({
    required this.id,
    required this.userId,
    required this.lineId,
    this.note,
    required this.startedAt,
    this.endedAt,
    this.userName = '',
    this.powerLineName = '',
  });

  factory PatrolSession.fromJson(Map<String, dynamic> json) {
    return PatrolSession(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      lineId: ((json['line_id'] ?? json['power_line_id']) as num).toInt(),
      note: json['note'] as String?,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      userName: json['user_name'] as String? ?? '',
      powerLineName: json['power_line_name'] as String? ?? '',
    );
  }

  bool get isCompleted => endedAt != null;
}
