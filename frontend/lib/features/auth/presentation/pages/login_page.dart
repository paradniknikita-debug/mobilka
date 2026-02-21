import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/login_form.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/base_url_manager.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authStateProvider);

    // Слушаем изменения состояния авторизации.
    // Редирект на /map выполняет роутер (app_router.dart), дублировать навигацию здесь не нужно —
    // иначе LoginPage размонтируется до срабатывания addPostFrameCallback и появляется предупреждение.
    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next is AuthStateAuthenticated) {
        // Роутер сам перенаправит на /map при AuthStateAuthenticated.
      } else if (next is AuthStateError) {
        print('❌ [LoginPage] Ошибка авторизации: ${next.message}');
        // Показываем ошибку
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    });
    
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Логотип
                const Icon(
                  Icons.electrical_services,
                  size: 100,
                  color: Colors.blue,
                ),
                const SizedBox(height: 24),
                
                // Заголовок
                Text(
                  'ЛЭП Management',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                
                Text(
                  'Система управления линиями электропередач',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Форма входа
                const LoginForm(),
                const SizedBox(height: 16),
                
                // Ссылка на регистрацию
                TextButton(
                  onPressed: () => context.go('/register'),
                  child: const Text('Нет аккаунта? Зарегистрироваться'),
                ),
                const SizedBox(height: 8),
                
                // Кнопка настроек сервера
                TextButton.icon(
                  onPressed: () => _showServerSettings(context),
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('Настройки сервера'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  void _showServerSettings(BuildContext context) {
    final urlManager = BaseUrlManager();
    final currentUrl = urlManager.getSavedServerUrl() ?? 'http://192.168.100.17:8000';
    
    final controller = TextEditingController(text: currentUrl);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Настройки сервера'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Введите URL сервера:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'URL сервера',
                hintText: 'http://192.168.100.17:8000',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                // Убеждаемся, что URL начинается с http:// или https://
                final normalizedUrl = url.startsWith('http://') || url.startsWith('https://')
                    ? url
                    : 'http://$url';
                
                await urlManager.setServerUrl(normalizedUrl);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('URL сервера сохранен: $normalizedUrl'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}
