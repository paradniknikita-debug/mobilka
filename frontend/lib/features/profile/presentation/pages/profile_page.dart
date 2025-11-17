import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/auth_service.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context, ref),
          ),
        ],
      ),
      body: authState.when(
        authenticated: (user) => _buildUserProfile(context, user),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (message) => Center(
          child: Text('Ошибка: $message'),
        ),
        unauthenticated: () => Center(
          child: ElevatedButton(
            onPressed: () => context.go('/login'),
            child: const Text('Войти'),
          ),
        ),
      ),
    );
  }

  Widget _buildUserProfile(BuildContext context, user) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Аватар
          CircleAvatar(
            radius: 50,
            backgroundColor: Theme.of(context).primaryColor,
            child: Text(
              user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
              style: const TextStyle(
                fontSize: 32,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Имя пользователя
          Text(
            user.fullName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Email
          Text(
            user.email,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),

          // Роль
          Chip(
            label: Text(_getRoleDisplayName(user.role)),
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          ),
          const SizedBox(height: 32),

          // Информация о пользователе
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Информация',
                    style: Theme.of(context).textTheme.titleLarge,
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
          ),

          const SizedBox(height: 16),

          // Действия
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.sync),
                  title: const Text('Синхронизация'),
                  subtitle: const Text('Синхронизировать данные'),
                  onTap: () {
                    // TODO: Запустить синхронизацию
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Синхронизация запущена')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Настройки'),
                  subtitle: const Text('Настройки приложения'),
                  onTap: () {
                    // TODO: Открыть настройки
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Настройки')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.help),
                  title: const Text('Помощь'),
                  subtitle: const Text('Справка и поддержка'),
                  onTap: () {
                    // TODO: Открыть справку
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Справка')),
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
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
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

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход'),
        content: const Text('Вы уверены, что хотите выйти из приложения?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(authServiceProvider).logout();
            },
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }
}
