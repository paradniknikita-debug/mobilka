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
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      // Единое поле line_id, с поддержкой старого имени power_line_id
      lineId: ((json['line_id'] ?? json['power_line_id']) as num?)?.toInt() ?? 0,
      note: json['note'] as String?,
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      endedAt: json['ended_at'] != null
          ? DateTime.tryParse(json['ended_at'].toString())
          : null,
      userName: json['user_name']?.toString() ?? '',
      powerLineName: json['power_line_name']?.toString() ?? '',
    );
  }

  bool get isCompleted => endedAt != null;
}
