import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../database/database.dart';
import 'auth_service.dart';

/// Количество сессий обхода со статусом «Ожидает синхронизации».
/// Инвалидировать после создания/завершения сессии и после синхронизации.
final pendingPatrolSessionsCountProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseProvider);
  final list = await db.getPendingPatrolSessions();
  final prefs = ref.watch(prefsProvider);
  final queuedEnds = prefs.getStringList(AppConfig.pendingEndPatrolServerIdsKey) ?? [];
  return list.length + queuedEnds.length;
});

/// Есть ли несинхронизированные данные (сессии обхода или другие сущности).
final hasPendingSyncProvider = FutureProvider<bool>((ref) async {
  final db = ref.watch(databaseProvider);
  final pendingPatrols = await db.getPendingPatrolSessions();
  if (pendingPatrols.isNotEmpty) return true;
  final prefs = ref.watch(prefsProvider);
  final queuedEnds = prefs.getStringList(AppConfig.pendingEndPatrolServerIdsKey) ?? [];
  if (queuedEnds.isNotEmpty) return true;
  final pl = await db.getPowerLinesNeedingSync();
  if (pl.isNotEmpty) return true;
  final poles = await db.getPolesNeedingSync();
  if (poles.isNotEmpty) return true;
  final eq = await db.getEquipmentNeedingSync();
  return eq.isNotEmpty;
});
