import 'package:dio/dio.dart';

import '../database/database.dart' as drift_db;
import '../models/patrol_session.dart' as api;
import 'api_service.dart';

Future<void> cachePatrolSessionsFromApi(
  drift_db.AppDatabase db,
  List<api.PatrolSession> sessions,
) async {
  for (final s in sessions) {
    if (s.id <= 0) continue;
    await db.upsertPatrolSessionFromServer(
      serverId: s.id,
      lineId: s.lineId,
      userId: s.userId,
      startedAt: s.startedAt,
      endedAt: s.endedAt,
      note: s.note,
    );
  }
}

Future<List<api.PatrolSession>> patrolSessionsFromDbRows(
  drift_db.AppDatabase db,
  List<drift_db.PatrolSession> rows, {
  int? userId,
}) async {
  final result = <api.PatrolSession>[];
  for (final row in rows) {
    if (userId != null && row.userId != null && row.userId != userId) continue;
    final pl = await db.getPowerLine(row.lineId);
    final plName = pl == null
        ? ''
        : (pl.mrid != null && pl.mrid!.trim().isNotEmpty
            ? '${pl.name} (${pl.mrid})'
            : pl.name);
    result.add(
      api.PatrolSession(
        id: row.serverId ?? -row.id,
        userId: row.userId ?? 0,
        lineId: row.lineId,
        note: row.note,
        startedAt: row.startedAt,
        endedAt: row.endedAt,
        userName: '',
        powerLineName: plName,
      ),
    );
  }
  return result;
}

/// Обходы по ЛЭП: с сервера при наличии сети, иначе из локального кэша.
Future<List<api.PatrolSession>> loadPatrolSessionsForLine({
  required drift_db.AppDatabase db,
  required ApiServiceWithExport apiService,
  required int lineId,
  required int userId,
  required bool isAdmin,
  int limit = 50,
}) async {
  try {
    final fromApi = await apiService.getPatrolSessions(
      isAdmin ? null : userId,
      lineId,
      limit,
      0,
    );
    await cachePatrolSessionsFromApi(db, fromApi);
    return fromApi;
  } catch (_) {
    final rows = await db.getPatrolSessionsByLineId(lineId);
    return patrolSessionsFromDbRows(
      db,
      rows,
      userId: isAdmin ? null : userId,
    );
  }
}

/// Последние обходы пользователя: API + локальные pending, с кэшированием.
Future<List<api.PatrolSession>> loadRecentPatrolSessions({
  required drift_db.AppDatabase db,
  required ApiServiceWithExport apiService,
  required int userId,
  required bool isAdmin,
  int limit = 20,
}) async {
  List<api.PatrolSession> apiSessions = [];
  try {
    apiSessions = await apiService.getPatrolSessions(
      isAdmin ? null : userId,
      null,
      limit,
      0,
    );
    await cachePatrolSessionsFromApi(db, apiSessions);
  } catch (_) {}

  final apiIds = apiSessions.map((s) => s.id).toSet();
  final localRecent = await db.getRecentPatrolSessionsFromDb(limit * 2);
  final result = List<api.PatrolSession>.from(apiSessions);

  for (final row in localRecent) {
    if (!isAdmin && row.userId != null && row.userId != userId) continue;
    final displayId = row.serverId ?? -row.id;
    if (apiIds.contains(displayId)) continue;
    if (row.serverId != null && apiIds.contains(row.serverId!)) continue;
    final converted = await patrolSessionsFromDbRows(db, [row], userId: isAdmin ? null : userId);
    if (converted.isNotEmpty) result.add(converted.first);
  }

  result.sort((a, b) => b.startedAt.compareTo(a.startedAt));
  return result.take(limit).toList();
}

bool isServerUnavailableDio(DioException e) {
  final status = e.response?.statusCode;
  if (status == 502 || status == 503 || status == 504) return true;
  return e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.unknown;
}
