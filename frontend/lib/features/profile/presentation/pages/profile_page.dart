import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/services/sync_preferences.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/services/pending_sync_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../home/presentation/pages/home_page.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: PatrolColors.background,
      appBar: AppBar(
        backgroundColor: PatrolColors.background,
        elevation: 0,
        title: const Text('Профиль', style: TextStyle(color: PatrolColors.textPrimary)),
        iconTheme: const IconThemeData(color: PatrolColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: PatrolColors.textPrimary),
            onPressed: () => _showLogoutDialog(context, ref),
          ),
        ],
      ),
      body: switch (authState) {
        AuthStateAuthenticated(user: final user) => _buildUserProfile(context, ref, user),
        AuthStateLoading() => const Center(child: CircularProgressIndicator(color: PatrolColors.accent)),
        AuthStateError(message: final message) => Center(
          child: Text('Ошибка: $message', style: const TextStyle(color: PatrolColors.textPrimary)),
        ),
        AuthStateUnauthenticated() => Center(
          child: ElevatedButton(
            onPressed: () => context.go('/login'),
            style: ElevatedButton.styleFrom(backgroundColor: PatrolColors.accent),
            child: const Text('Войти'),
          ),
        ),
        _ => const Center(child: Text('Неизвестное состояние', style: TextStyle(color: PatrolColors.textPrimary))),
      },
    );
  }

  Widget _buildUserProfile(BuildContext context, WidgetRef ref, user) {
    final syncState = ref.watch(syncStateProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: PatrolColors.accent,
            child: Text(
              user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
              style: const TextStyle(
                fontSize: 32,
                color: PatrolColors.background,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user.fullName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: PatrolColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            user.email,
            style: const TextStyle(fontSize: 16, color: PatrolColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Chip(
            label: Text(_getRoleDisplayName(user.role), style: const TextStyle(color: PatrolColors.background)),
            backgroundColor: PatrolColors.accent.withOpacity(0.3),
          ),
          const SizedBox(height: 32),
          _profileCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Информация',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: PatrolColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoRow('Имя пользователя', user.username),
                _buildInfoRow('Email', user.email),
                _buildInfoRow('Роль', _getRoleDisplayName(user.role)),
                _buildInfoRow('Статус', user.isActive ? 'Активен' : 'Неактивен'),
                _buildInfoRow('Дата регистрации', _formatDate(user.createdAt)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _profileCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.sync, color: PatrolColors.accent),
                  title: const Text('Режим синхронизации', style: TextStyle(color: PatrolColors.textPrimary)),
                  subtitle: Text(ref.watch(syncModeProvider).subtitle, style: const TextStyle(color: PatrolColors.textSecondary)),
                  trailing: const Icon(Icons.chevron_right, color: PatrolColors.textSecondary),
                  onTap: () => _showSyncModeDialog(context, ref),
                ),
              ],
            ),
          ),
          if (syncState.whenOrNull(error: (m) => m) != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PatrolColors.statusPending.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PatrolColors.statusPending.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: PatrolColors.statusPending, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      syncState.when(idle: () => '', syncing: () => '', completed: () => '', error: (m) => m),
                      style: const TextStyle(fontSize: 13, color: PatrolColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _profileCard(
            child: Column(
              children: [
                if (user.role == 'admin')
                  ListTile(
                    leading: const Icon(Icons.assignment, color: PatrolColors.accent),
                    title: const Text('Данные по обходам', style: TextStyle(color: PatrolColors.textPrimary)),
                    subtitle: const Text('Просмотр сессий обхода ЛЭП', style: TextStyle(color: PatrolColors.textSecondary)),
                    onTap: () => context.push('/patrols'),
                  ),
                ListTile(
                  leading: const Icon(Icons.cloud_upload, color: PatrolColors.accent),
                  title: const Text('Синхронизировать сейчас', style: TextStyle(color: PatrolColors.textPrimary)),
                  subtitle: const Text('Отправить и загрузить данные вручную', style: TextStyle(color: PatrolColors.textSecondary)),
                  onTap: () => _runSync(context, ref),
                ),
                ListTile(
                  leading: const Icon(Icons.settings, color: PatrolColors.accent),
                  title: const Text('Настройки сервера', style: TextStyle(color: PatrolColors.textPrimary)),
                  subtitle: const Text('Настройка IP адреса сервера', style: TextStyle(color: PatrolColors.textSecondary)),
                  onTap: () => context.push('/settings/server'),
                ),
                ListTile(
                  leading: const Icon(Icons.help, color: PatrolColors.accent),
                  title: const Text('Помощь', style: TextStyle(color: PatrolColors.textPrimary)),
                  subtitle: const Text('Справка и поддержка', style: TextStyle(color: PatrolColors.textSecondary)),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Справка'), backgroundColor: PatrolColors.surfaceCard),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: PatrolColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: PatrolColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: PatrolColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'engineer':
        return 'Инженер';
      case 'dispatcher':
        return 'Диспетчер';
      case 'admin':
        return 'Администратор';
      default:
        return role;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  void _showSyncModeDialog(BuildContext context, WidgetRef ref) {
    final current = ref.read(syncModeProvider);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PatrolColors.surfaceCard,
        title: const Text('Режим синхронизации', style: TextStyle(color: PatrolColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SyncMode.values.map((mode) {
            return RadioListTile<SyncMode>(
              title: Text(mode.displayName, style: const TextStyle(color: PatrolColors.textPrimary)),
              subtitle: Text(mode.subtitle, style: const TextStyle(fontSize: 12, color: PatrolColors.textSecondary)),
              value: mode,
              groupValue: current,
              onChanged: (value) {
                if (value != null) ref.read(syncModeProvider.notifier).setMode(value);
                Navigator.of(context).pop();
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть', style: TextStyle(color: PatrolColors.accent)),
          ),
        ],
      ),
    );
  }

  Future<void> _runSync(BuildContext context, WidgetRef ref) async {
    final sync = ref.read(syncServiceProvider);
    await sync.syncData();
    ref.invalidate(pendingPatrolSessionsCountProvider);
    ref.invalidate(hasPendingSyncProvider);
    ref.invalidate(recentPatrolsProvider);
    if (!context.mounted) return;
    final state = ref.read(syncStateProvider);
    state.when(
      idle: () {},
      syncing: () {},
        completed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Синхронизация завершена. Данные сохранены на сервере.', style: TextStyle(color: PatrolColors.background)),
            backgroundColor: PatrolColors.statusSynced,
          ),
        );
      },
      error: (message) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $message', style: const TextStyle(color: PatrolColors.textPrimary)),
            backgroundColor: PatrolColors.statusPending,
          ),
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PatrolColors.surfaceCard,
        title: const Text('Выход', style: TextStyle(color: PatrolColors.textPrimary)),
        content: const Text(
          'Вы уверены, что хотите выйти из приложения?',
          style: TextStyle(color: PatrolColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена', style: TextStyle(color: PatrolColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(authServiceProvider.notifier).logout();
            },
            child: const Text('Выйти', style: TextStyle(color: PatrolColors.accent)),
          ),
        ],
      ),
    );
  }
}
