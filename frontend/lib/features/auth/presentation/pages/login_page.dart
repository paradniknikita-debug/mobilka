import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
              duration: Duration(seconds: next.message.contains('\n') ? 8 : 4),
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
                  'Система ЛЭП',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                
                Text(
                  'Система управления линиями электропередачи',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Форма входа
                const LoginForm(),
                const SizedBox(height: 12),
                Text(
                  'Учётную запись выдаёт администратор системы',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

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
    final currentUrl = urlManager.getSavedServerUrl() ?? 'https://85.239.48.199';
    var trustSelfSigned = urlManager.shouldTrustSelfSignedCert;

    final controller = TextEditingController(text: currentUrl);
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Настройки сервера'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Введите URL сервера (без /api/v1):'),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'URL сервера',
                    hintText: 'https://85.239.48.199',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: trustSelfSigned,
                  onChanged: (value) {
                    setDialogState(() {
                      trustSelfSigned = value ?? false;
                    });
                  },
                  title: const Text('Доверять самоподписанному сертификату'),
                  subtitle: const Text(
                    'Нужно для VPS без домена. HTTP на prod не работает — nginx перенаправляет на HTTPS.',
                  ),
                ),
              ],
            ),
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
                  final hasScheme =
                      url.startsWith('http://') || url.startsWith('https://');
                  final normalizedUrl = hasScheme ? url : 'https://$url';

                  await urlManager.setServerUrl(normalizedUrl);
                  await urlManager.setTrustSelfSignedCert(trustSelfSigned);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          trustSelfSigned
                              ? 'Сервер сохранён: $normalizedUrl (самоподписанный SSL разрешён)'
                              : 'URL сервера сохранен: $normalizedUrl',
                        ),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}
