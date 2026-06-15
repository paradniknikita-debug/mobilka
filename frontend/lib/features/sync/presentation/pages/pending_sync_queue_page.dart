import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/pending_sync_queue.dart';
import '../../../../core/services/pending_sync_provider.dart';
import '../../../../core/services/pending_sync_queue_service.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/theme/app_theme.dart';

class PendingSyncQueuePage extends ConsumerWidget {
  const PendingSyncQueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(pendingSyncQueueProvider);
    final syncState = ref.watch(syncStateProvider);
    final isSyncing = syncState.maybeWhen(syncing: () => true, orElse: () => false);
    final lastError = syncState.maybeWhen(error: (m) => m, orElse: () => null);

    return Scaffold(
      backgroundColor: PatrolColors.background,
      appBar: AppBar(
        backgroundColor: PatrolColors.surface,
        foregroundColor: PatrolColors.textPrimary,
        title: const Text('Очередь синхронизации'),
      ),
      body: Column(
        children: [
          if (lastError != null && lastError.isNotEmpty)
            Material(
              color: PatrolColors.surfaceCard,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, color: PatrolColors.statusPending, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lastError,
                        style: const TextStyle(color: PatrolColors.textPrimary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: queueAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: PatrolColors.accent)),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Ошибка загрузки: $e', style: const TextStyle(color: PatrolColors.textPrimary)),
                ),
              ),
              data: (queue) => _QueueBody(queue: queue, isSyncing: isSyncing),
            ),
          ),
        ],
      ),
      floatingActionButton: queueAsync.maybeWhen(
        data: (queue) => queue.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: isSyncing ? null : () => _uploadAll(context, ref),
                backgroundColor: PatrolColors.accent,
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Отправить всё'),
              ),
        orElse: () => null,
      ),
    );
  }

  Future<void> _uploadAll(BuildContext context, WidgetRef ref) async {
    await ref.read(syncStateProvider.notifier).pushLocalChangesOnly();
    ref.invalidate(pendingSyncQueueProvider);
    ref.invalidate(hasPendingSyncProvider);
    if (!context.mounted) return;
    final state = ref.read(syncStateProvider);
    state.when(
      idle: () {},
      syncing: () {},
      completed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Данные отправлены на сервер'),
            backgroundColor: PatrolColors.surfaceCard,
          ),
        );
      },
      error: (msg) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: PatrolColors.surfaceCard),
        );
      },
    );
  }
}

class _QueueBody extends ConsumerWidget {
  const _QueueBody({required this.queue, required this.isSyncing});

  final PendingSyncQueue queue;
  final bool isSyncing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (queue.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_done, size: 56, color: PatrolColors.textSecondary),
              SizedBox(height: 16),
              Text(
                'Нет данных, ожидающих отправки',
                textAlign: TextAlign.center,
                style: TextStyle(color: PatrolColors.textSecondary, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: PatrolColors.accent,
      onRefresh: () async {
        ref.invalidate(pendingSyncQueueProvider);
        ref.invalidate(hasPendingSyncProvider);
        await ref.read(pendingSyncQueueProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          Text(
            'Всего: ${queue.totalItems} ${_pluralItems(queue.totalItems)}',
            style: const TextStyle(
              color: PatrolColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...queue.lineGroups.map((g) => _LineGroupCard(group: g, isSyncing: isSyncing)),
          if (queue.patrolSessions.isNotEmpty) ...[
            const SizedBox(height: 8),
            _PatrolSection(sessions: queue.patrolSessions),
          ],
        ],
      ),
    );
  }

  static String _pluralItems(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'элементов';
    if (mod10 == 1) return 'элемент';
    if (mod10 >= 2 && mod10 <= 4) return 'элемента';
    return 'элементов';
  }
}

class _LineGroupCard extends ConsumerWidget {
  const _LineGroupCard({required this.group, required this.isSyncing});

  final PendingLineSyncGroup group;
  final bool isSyncing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: PatrolColors.surfaceCard,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    group.lineName,
                    style: const TextStyle(
                      color: PatrolColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${group.itemCount}',
                  style: const TextStyle(color: PatrolColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
            if (group.linePending)
              const _QueueRow(icon: Icons.edit_road, label: 'Изменения ЛЭП'),
            for (final p in group.poles)
              _QueueRow(
                icon: p.isNew ? Icons.add_location_alt : Icons.location_on,
                label: p.isNew
                    ? 'Новая опора ${p.poleNumber}'
                    : 'Опора ${p.poleNumber}${p.sequenceNumber != null ? ' (№${p.sequenceNumber})' : ''}',
              ),
            for (final e in group.equipment)
              _QueueRow(
                icon: e.isNew ? Icons.add_circle_outline : Icons.electrical_services,
                label: e.isNew ? 'Новое: ${e.name}' : 'Обновление: ${e.name}',
              ),
            for (final d in group.deletes)
              _QueueRow(icon: Icons.delete_outline, label: d.label, muted: true),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isSyncing
                    ? null
                    : () async {
                        await ref.read(syncStateProvider.notifier).pushLocalChangesForLine(group.lineId);
                        ref.invalidate(pendingSyncQueueProvider);
                        ref.invalidate(hasPendingSyncProvider);
                        if (!context.mounted) return;
                        final state = ref.read(syncStateProvider);
                        state.when(
                          idle: () {},
                          syncing: () {},
                          completed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('«${group.lineName}» отправлена на сервер'),
                                backgroundColor: PatrolColors.surfaceCard,
                              ),
                            );
                          },
                          error: (msg) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(msg), backgroundColor: PatrolColors.surfaceCard),
                            );
                          },
                        );
                      },
                icon: const Icon(Icons.upload, size: 18),
                label: const Text('Отправить эту ЛЭП'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PatrolColors.accent,
                  side: const BorderSide(color: PatrolColors.accent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatrolSection extends StatelessWidget {
  const _PatrolSection({required this.sessions});

  final List<PendingPatrolSyncItem> sessions;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: PatrolColors.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Обходы',
              style: TextStyle(
                color: PatrolColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            for (final s in sessions)
              _QueueRow(
                icon: Icons.directions_walk,
                label: s.lineId > 0 ? '${s.lineName}: ${s.statusLabel}' : s.statusLabel,
              ),
            const SizedBox(height: 4),
            const Text(
              'Обходы отправляются кнопкой «Отправить всё» или полной синхронизацией',
              style: TextStyle(color: PatrolColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.icon, required this.label, this.muted = false});

  final IconData icon;
  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: muted ? PatrolColors.textSecondary : PatrolColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: muted ? PatrolColors.textSecondary : PatrolColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
