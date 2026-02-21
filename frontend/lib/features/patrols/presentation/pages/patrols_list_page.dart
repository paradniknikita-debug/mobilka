import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/patrol_session.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/auth_service.dart';

/// Провайдер списка сессий обхода (с сервера).
final patrolSessionsProvider = FutureProvider<List<PatrolSession>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return api.getPatrolSessions(null, null, 200, 0);
});

/// Страница «Данные по обходам» — только для администратора.
class PatrolsListPage extends ConsumerWidget {
  const PatrolsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final isAdmin = authState is AuthStateAuthenticated &&
        authState.user.role == 'admin';

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Обходы')),
        body: const Center(
          child: Text('Доступ только для администратора'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Данные по обходам'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: ref.watch(patrolSessionsProvider).when(
            data: (sessions) => _PatrolsList(
              sessions: sessions,
              onRefresh: () async {
                ref.invalidate(patrolSessionsProvider);
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red[700]),
                    const SizedBox(height: 16),
                    Text(
                      'Не удалось загрузить данные',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      err.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}

class _PatrolsList extends StatelessWidget {
  const _PatrolsList({required this.sessions, required this.onRefresh});

  final List<PatrolSession> sessions;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Нет данных по обходам',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        itemCount: sessions.length,
        itemBuilder: (context, index) {
          final s = sessions[index];
          return _PatrolSessionCard(session: s);
        },
      ),
    );
  }
}

class _PatrolSessionCard extends StatelessWidget {
  const _PatrolSessionCard({required this.session});

  final PatrolSession session;

  @override
  Widget build(BuildContext context) {
    final started = session.startedAt.toLocal();
    final ended = session.endedAt?.toLocal();
    final startedStr =
        '${started.day.toString().padLeft(2, '0')}.${started.month.toString().padLeft(2, '0')}.${started.year} ${started.hour.toString().padLeft(2, '0')}:${started.minute.toString().padLeft(2, '0')}';
    final endedStr = ended != null
        ? '${ended.day.toString().padLeft(2, '0')}.${ended.month.toString().padLeft(2, '0')}.${ended.year} ${ended.hour.toString().padLeft(2, '0')}:${ended.minute.toString().padLeft(2, '0')}'
        : '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: session.isCompleted
              ? Colors.green.shade100
              : Colors.orange.shade100,
          child: Icon(
            session.isCompleted ? Icons.check : Icons.pending,
            color: session.isCompleted ? Colors.green.shade800 : Colors.orange.shade800,
          ),
        ),
        title: Text(
          session.powerLineName.isNotEmpty
              ? session.powerLineName
              : 'ЛЭП #${session.powerLineId}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            Text('Исполнитель: ${session.userName.isNotEmpty ? session.userName : "id ${session.userId}"}'),
            Text('Начало: $startedStr'),
            Text('Окончание: $endedStr'),
            if (session.note != null && session.note!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Примечание: ${session.note}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
