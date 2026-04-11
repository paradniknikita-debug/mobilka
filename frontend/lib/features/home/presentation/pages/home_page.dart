import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/connectivity_status.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/pending_sync_provider.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/database/database.dart' as drift_db;
import '../../../../core/models/patrol_session.dart';
import '../../../../core/theme/app_theme.dart';

/// Локальная сессия ещё не полностью отражена на сервере (новая или завершение не дошло).
bool patrolSessionRowNeedsSyncUpload(drift_db.PatrolSession row) =>
    row.syncStatus == 'pending' ||
    row.syncStatus == AppConfig.patrolSessionSyncStatusPendingEnd;

/// Информация об активной (незавершённой) сессии обхода.
class ActiveSessionInfo {
  final int lineId;
  final String lineName;
  final DateTime? startTime;
  final String note;

  ActiveSessionInfo({
    required this.lineId,
    required this.lineName,
    required this.startTime,
    required this.note,
  });
}

/// Провайдер, читающий из SharedPreferences и (при отсутствии) из API
/// сведения о незавершённом обходе (если есть).
final activeSessionProvider = FutureProvider<ActiveSessionInfo?>((ref) async {
  final prefs = ref.watch(prefsProvider);
  Future<void> clearActiveSessionPrefs() async {
    await prefs.remove(AppConfig.activeSessionPowerLineIdKey);
    await prefs.remove(AppConfig.activeSessionStartTimeKey);
    await prefs.remove(AppConfig.activeSessionNoteKey);
    await prefs.remove(AppConfig.activeSessionLatKey);
    await prefs.remove(AppConfig.activeSessionLonKey);
    await prefs.remove(AppConfig.activeSessionLocalIdKey);
    await prefs.remove(AppConfig.activeSessionServerIdKey);
  }
  int? lineId = prefs.getInt(AppConfig.activeSessionPowerLineIdKey);
  String? startIso = prefs.getString(AppConfig.activeSessionStartTimeKey);
  String note = prefs.getString(AppConfig.activeSessionNoteKey) ?? '';
  DateTime? startTime = startIso != null ? DateTime.tryParse(startIso) : null;
  String? restoredLineName;

  // Валидируем сохранённую активную сессию: показываем кнопку «Продолжить»
  // только если сессия действительно не завершена.
  if (lineId != null) {
    final db = ref.read(drift_db.databaseProvider);
    final localSessionId = prefs.getInt(AppConfig.activeSessionLocalIdKey);
    if (localSessionId != null) {
      final localSession = await db.getPatrolSession(localSessionId);
      if (localSession == null || localSession.endedAt != null) {
        await clearActiveSessionPrefs();
        lineId = null;
        startIso = null;
        startTime = null;
        note = '';
      }
    }
  }

  // Если в prefs нет активной сессии — пробуем восстановить по незавершённому обходу с сервера
  if (lineId == null) {
    final authState = ref.read(authStateProvider);
    if (authState is AuthStateAuthenticated) {
      try {
        final api = ref.read(apiServiceProvider);
        final sessions = await api.getPatrolSessions(authState.user.id, null, 20, 0);
        final unfinished = sessions.where((s) => s.endedAt == null).toList();
        if (unfinished.isNotEmpty) {
          final s = unfinished.first;
          lineId = s.lineId;
          startTime = s.startedAt;
          note = s.note ?? '';
          startIso = s.startedAt.toIso8601String();
          restoredLineName = s.powerLineName.isNotEmpty ? s.powerLineName : null;
          await prefs.setInt(AppConfig.activeSessionPowerLineIdKey, lineId);
          await prefs.setString(AppConfig.activeSessionStartTimeKey, startIso);
          await prefs.setInt(AppConfig.activeSessionServerIdKey, s.id);
          if (note.isNotEmpty) {
            await prefs.setString(AppConfig.activeSessionNoteKey, note);
          }
        }
      } catch (_) {
        // Офлайн или ошибка — оставляем null
      }
    }
    if (lineId == null) return null;
  }

  String lineName = restoredLineName ?? 'Линия $lineId';
  if (lineName == 'Линия $lineId') {
    try {
      final db = ref.read(drift_db.databaseProvider);
      final line = await db.getPowerLine(lineId);
      if (line != null) {
        lineName = line.name;
        if (line.mrid != null && line.mrid!.trim().isNotEmpty) lineName += ' (${line.mrid})';
      }
    } catch (_) {
      // БД может быть ещё не готова — всё равно показываем кнопку возобновления
    }
  }

  return ActiveSessionInfo(
    lineId: lineId,
    lineName: lineName,
    startTime: startTime,
    note: note,
  );
});

/// Кнопка «Продолжить» только при незавершённом обходе (не из‑за одной лишь очереди синхронизации).
final showContinuePatrolButtonProvider = FutureProvider<bool>((ref) async {
  final active = await ref.watch(activeSessionProvider.future);
  if (active == null) return false;
  final prefs = ref.read(prefsProvider);
  final localId = prefs.getInt(AppConfig.activeSessionLocalIdKey);
  if (localId != null) {
    final row = await ref.read(drift_db.databaseProvider).getPatrolSession(localId);
    if (row != null && row.endedAt == null) return true;
    return false;
  }
  return prefs.getInt(AppConfig.activeSessionServerIdKey) != null;
});

/// Есть ли у пользователя незавершённый обход (для напоминания при входе).
final hasUnfinishedPatrolAnywhereProvider = FutureProvider<bool>((ref) async {
  final authState = ref.watch(authStateProvider);
  if (authState is! AuthStateAuthenticated) return false;
  final uid = authState.user.id;
  final db = ref.read(drift_db.databaseProvider);
  final recent = await db.getRecentPatrolSessionsFromDb(120);
  for (final r in recent) {
    if (r.endedAt != null) continue;
    if (r.userId != null && r.userId != uid) continue;
    return true;
  }
  final prefs = ref.read(prefsProvider);
  if (prefs.getInt(AppConfig.activeSessionServerIdKey) != null) return true;
  final lid = prefs.getInt(AppConfig.activeSessionLocalIdKey);
  if (lid != null) {
    final row = await db.getPatrolSession(lid);
    if (row != null && row.endedAt == null) return true;
  }
  return false;
});

/// Элемент списка «Последние обходы»: сессия + признак «ожидает синхронизации» (офлайн).
class RecentPatrolItem {
  const RecentPatrolItem({required this.session, this.isPendingSync = false});
  final PatrolSession session;
  final bool isPendingSync;
}

/// Последние обходы: с сервера + локальные с ожиданием синхронизации (офлайн).
final recentPatrolsProvider = FutureProvider<List<RecentPatrolItem>>((ref) async {
  try {
    final authState = ref.watch(authStateProvider);
    if (authState is! AuthStateAuthenticated) return [];
    final api = ref.read(apiServiceProvider);
    final db = ref.read(drift_db.databaseProvider);
    final userId = authState.user.id;

    List<PatrolSession> apiSessions = [];
    try {
      apiSessions = await api.getPatrolSessions(userId, null, 10, 0);
    } catch (_) {
      // Офлайн или ошибка — только локальные
    }

    final localRecent = await db.getRecentPatrolSessionsFromDb(15);
    final localPending = localRecent.where(patrolSessionRowNeedsSyncUpload).toList();
    final apiIds = apiSessions.map((s) => s.id).toSet();

    final List<RecentPatrolItem> items = [];
    for (final row in apiSessions.isEmpty ? localRecent : localPending) {
      if (row.userId != null && row.userId != userId) continue;
      final pl = await db.getPowerLine(row.lineId);
      if (pl == null) continue;
      if (apiSessions.isNotEmpty && apiIds.contains(row.serverId ?? -row.id)) continue;
      final powerLineDisplayName = pl.mrid != null && pl.mrid!.trim().isNotEmpty
          ? '${pl.name} (${pl.mrid})'
          : pl.name;
      items.add(RecentPatrolItem(
        session: PatrolSession(
          id: row.serverId ?? -row.id,
          userId: row.userId ?? userId,
          lineId: row.lineId,
          note: row.note,
          startedAt: row.startedAt,
          endedAt: row.endedAt,
          userName: '',
          powerLineName: powerLineDisplayName,
        ),
        isPendingSync: patrolSessionRowNeedsSyncUpload(row),
      ));
    }

    for (final s in apiSessions) {
      items.add(RecentPatrolItem(session: s, isPendingSync: false));
    }
    items.sort((a, b) => b.session.startedAt.compareTo(a.session.startedAt));
    return items.take(10).toList();
  } catch (_) {
    return [];
  }
});

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(recentPatrolsProvider);
      ref.read(connectivityStatusProvider.notifier).refresh();
      _tryShowUnfinishedPatrolBanner();
    });
  }

  Future<void> _tryShowUnfinishedPatrolBanner() async {
    if (!mounted) return;
    final auth = ref.read(authStateProvider);
    if (auth is! AuthStateAuthenticated) return;
    final has = await ref.read(hasUnfinishedPatrolAnywhereProvider.future);
    if (!mounted || !has) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.clearMaterialBanners();
    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: PatrolColors.surfaceCard,
        content: const Text(
          'У вас есть незавершённый обход. Откройте карту, чтобы продолжить, или завершите сессию там.',
          style: TextStyle(color: PatrolColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
              if (!mounted) return;
              context.go('/map');
            },
            child: const Text('К карте', style: TextStyle(color: PatrolColors.accent)),
          ),
          TextButton(
            onPressed: () => messenger.hideCurrentMaterialBanner(),
            child: const Text('Закрыть', style: TextStyle(color: PatrolColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(activeSessionProvider);
      ref.invalidate(showContinuePatrolButtonProvider);
      ref.invalidate(hasUnfinishedPatrolAnywhereProvider);
      ref.invalidate(recentPatrolsProvider);
      ref.invalidate(hasPendingSyncProvider);
      ref.read(connectivityStatusProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SyncState>(syncStateProvider, (prev, next) {
      next.when(
        idle: () {},
        syncing: () {},
        completed: () {
          ref.invalidate(hasPendingSyncProvider);
          ref.invalidate(pendingPatrolSessionsCountProvider);
          ref.invalidate(recentPatrolsProvider);
          ref.invalidate(activeSessionProvider);
          ref.invalidate(showContinuePatrolButtonProvider);
          ref.invalidate(hasUnfinishedPatrolAnywhereProvider);
          ref.read(connectivityStatusProvider.notifier).refresh();
        },
        error: (_) {},
      );
    });
    final connectionStatus = ref.watch(connectivityStatusProvider);
    final activeSessionAsync = ref.watch(activeSessionProvider);
    final activeSession = activeSessionAsync.asData?.value;
    final showPatrolContinue = ref.watch(showContinuePatrolButtonProvider).asData?.value ?? false;
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: PatrolColors.background,
      appBar: AppBar(
        backgroundColor: PatrolColors.background,
        elevation: 0,
        title: const Text('Главная', style: TextStyle(color: PatrolColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment, color: PatrolColors.textPrimary),
            onPressed: () => context.push('/patrols'),
            tooltip: 'История обходов',
          ),
          IconButton(
            icon: const Icon(Icons.person, color: PatrolColors.textPrimary),
            onPressed: () => context.go('/settings'),
            tooltip: 'Настройки',
          ),
          IconButton(
            icon: const Icon(Icons.map, color: PatrolColors.textPrimary),
            onPressed: () => context.go('/map'),
            tooltip: 'Карта',
          ),
        ],
      ),
      body: Column(
        children: [
          _TopStatusBar(status: connectionStatus),
          _PendingSyncBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _UserCard(authState: authState),
                  const SizedBox(height: 24),
                  _PatrolMainButton(
                    icon: Icons.play_arrow,
                    title: 'НОВЫЙ ОБХОД',
                    subtitle: 'НАЧАТЬ СЕССИЮ',
                    onPressed: () => context.go('/session/new'),
                  ),
                  const SizedBox(height: 12),
                  if (showPatrolContinue && activeSession != null)
                    _PatrolMainButton(
                      icon: Icons.refresh,
                      title: 'Продолжить',
                      subtitle: 'НЕЗАВЕРШЕННЫЙ ОБХОД',
                      onPressed: () => context.go('/map'),
                    ),
                  if (showPatrolContinue && activeSession != null) ...[
                    const SizedBox(height: 12),
                    _ActiveSessionCard(info: activeSession),
                  ],
                  const SizedBox(height: 24),
                  _SyncedCountCard(),
                  const SizedBox(height: 24),
                  _SectionTitle(title: 'ПОСЛЕДНИЕ ОБХОДЫ'),
                  const SizedBox(height: 12),
                  _RecentPatrolsSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingSyncBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Статус «Ожидает синхронизации» по запросу заказчика скрыт из UI.
    // Провайдер всё равно читаем, чтобы при изменениях не было неиспользуемого состояния.
    ref.watch(hasPendingSyncProvider);
    return const SizedBox.shrink();
  }
}

class _TopStatusBar extends StatelessWidget {
  const _TopStatusBar({required this.status});

  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (status) {
      ConnectionStatus.online => (Icons.wifi, 'ОНЛАЙН'),
      ConnectionStatus.offline => (Icons.wifi_off, 'ОФЛАЙН'),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      color: PatrolColors.surface,
      child: Row(
        children: [
          Icon(icon, size: 18, color: PatrolColors.accent),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: PatrolColors.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Text(
            'Точность GPS: ±5м',
            style: const TextStyle(
              fontSize: 12,
              color: PatrolColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.authState});

  final AuthState authState;

  @override
  Widget build(BuildContext context) {
    String name = 'Пользователь';
    String role = 'ИНЖЕНЕР';
    if (authState is AuthStateAuthenticated) {
      final user = (authState as AuthStateAuthenticated).user;
      name = user.fullName.isNotEmpty ? user.fullName : user.username;
      role = user.role == 'admin' ? 'АДМИНИСТРАТОР' : 'ИНЖЕНЕР';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: PatrolColors.surfaceCard,
            child: Icon(Icons.person, color: PatrolColors.textSecondary, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role,
                  style: const TextStyle(
                    fontSize: 12,
                    color: PatrolColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: PatrolColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.menu, color: PatrolColors.textPrimary),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
    );
  }
}

class _PatrolMainButton extends StatelessWidget {
  const _PatrolMainButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PatrolColors.surfaceCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: PatrolColors.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: PatrolColors.accent, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: PatrolColors.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: PatrolColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncedCountCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentPatrolsProvider);
    final list = recentAsync.asData?.value ?? [];
    final syncedCount = list.where((item) => !item.isPendingSync && item.session.isCompleted).length;
    final completedTotal = list.where((item) => item.session.isCompleted).length;
    final displayText = completedTotal > 0 ? '$syncedCount из $completedTotal' : '$syncedCount';
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: PatrolColors.surfaceCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.check_circle_outline, color: PatrolColors.statusSynced, size: 28),
                const SizedBox(height: 8),
                Text(
                  displayText,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: PatrolColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'СИНХРОНИЗИРОВАНО',
                  style: TextStyle(
                    fontSize: 11,
                    color: PatrolColors.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.diamond, size: 16, color: PatrolColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: PatrolColors.textPrimary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.diamond, size: 16, color: PatrolColors.textSecondary),
      ],
    );
  }
}

class _RecentPatrolsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSessions = ref.watch(recentPatrolsProvider);
    return asyncSessions.when(
      data: (sessions) {
        if (sessions.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: PatrolColors.surfaceCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.history, size: 48, color: PatrolColors.textSecondary),
                const SizedBox(height: 12),
                const Text(
                  'Нет последних обходов',
                  style: TextStyle(
                    fontSize: 14,
                    color: PatrolColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...sessions.take(5).map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _RecentPatrolCard(item: item),
                  ),
                ),
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: SizedBox(
            height: 32,
            width: 32,
            child: CircularProgressIndicator(strokeWidth: 2, color: PatrolColors.accent),
          ),
        ),
      ),
      error: (_, __) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: PatrolColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Не удалось загрузить обходы',
          style: TextStyle(fontSize: 14, color: PatrolColors.textSecondary),
        ),
      ),
    );
  }
}

class _RecentPatrolCard extends StatelessWidget {
  const _RecentPatrolCard({required this.item});

  final RecentPatrolItem item;

  @override
  Widget build(BuildContext context) {
    final session = item.session;
    final started = session.startedAt.toLocal();
    final ended = session.endedAt?.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(started.year, started.month, started.day);
    String dateStr;
    if (ended != null) {
      final startStr = '${started.hour.toString().padLeft(2, '0')}:${started.minute.toString().padLeft(2, '0')}';
      final endStr = '${ended.hour.toString().padLeft(2, '0')}:${ended.minute.toString().padLeft(2, '0')}';
      if (startDay == today) {
        dateStr = 'Сегодня, $startStr – $endStr';
      } else if (startDay == today.subtract(const Duration(days: 1))) {
        dateStr = 'Вчера, $startStr – $endStr';
      } else {
        dateStr = '${started.day.toString().padLeft(2, '0')}.${started.month.toString().padLeft(2, '0')}.${started.year} $startStr – $endStr';
      }
    } else {
      if (startDay == today) {
        dateStr = 'Сегодня, ${started.hour.toString().padLeft(2, '0')}:${started.minute.toString().padLeft(2, '0')}';
      } else if (startDay == today.subtract(const Duration(days: 1))) {
        dateStr = 'Вчера, ${started.hour.toString().padLeft(2, '0')}:${started.minute.toString().padLeft(2, '0')}';
      } else {
        dateStr = '${started.day.toString().padLeft(2, '0')}.${started.month.toString().padLeft(2, '0')}.${started.year} ${started.hour.toString().padLeft(2, '0')}:${started.minute.toString().padLeft(2, '0')}';
      }
    }
    final String statusText;
    final Color statusColor;
    final IconData statusIcon;
    if (item.isPendingSync) {
      statusText = 'НЕ СИНХРОНИЗИРОВАН';
      statusColor = PatrolColors.statusPending;
      statusIcon = Icons.cloud_upload;
    } else if (!session.isCompleted) {
      // Сессия уже может быть создана на сервере, но ещё не завершена пользователем.
      statusText = 'НЕ ЗАВЕРШЕН';
      statusColor = PatrolColors.accent;
      statusIcon = Icons.hourglass_top;
    } else {
      statusText = 'СИНХРОНИЗИРОВАН';
      statusColor = PatrolColors.statusSynced;
      statusIcon = Icons.cloud_done;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: PatrolColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.powerLineName.isNotEmpty
                      ? session.powerLineName
                      : 'ЛЭП #${session.lineId}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: PatrolColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: PatrolColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      dateStr,
                      style: const TextStyle(fontSize: 12, color: PatrolColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          Icon(statusIcon, color: statusColor, size: 24),
        ],
      ),
    );
  }
}

class _ActiveSessionCard extends StatelessWidget {
  const _ActiveSessionCard({required this.info});

  final ActiveSessionInfo info;

  @override
  Widget build(BuildContext context) {
    final startText = info.startTime != null
        ? 'Начат: ${info.startTime!.toLocal().day.toString().padLeft(2, '0')}.${info.startTime!.toLocal().month.toString().padLeft(2, '0')}.${info.startTime!.toLocal().year} ${info.startTime!.toLocal().hour.toString().padLeft(2, '0')}:${info.startTime!.toLocal().minute.toString().padLeft(2, '0')}'
        : 'Начат: неизвестно';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PatrolColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_walk, size: 20, color: PatrolColors.accent),
              const SizedBox(width: 8),
              const Text(
                'Незавершённый обход',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: PatrolColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            info.lineName,
            style: const TextStyle(
              fontSize: 16,
              color: PatrolColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            startText,
            style: const TextStyle(
              fontSize: 12,
              color: PatrolColors.textSecondary,
            ),
          ),
          if (info.note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Примечание: ${info.note}',
              style: const TextStyle(fontSize: 12, color: PatrolColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
