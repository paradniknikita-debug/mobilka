import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/login_form.dart';
import '../../../../core/services/auth_service.dart';

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
    final authState = ref.watch(authStateProvider);
    
    // Слушаем изменения состояния авторизации
    ref.listen<AuthState>(authStateProvider, (previous, next) {
      print('📢 [LoginPage] Изменение состояния авторизации:');
      print('   Предыдущее: ${previous.runtimeType}');
      print('   Текущее: ${next.runtimeType}');
      
      if (next is AuthStateAuthenticated) {
        print('✅ [LoginPage] Обнаружено состояние AuthStateAuthenticated');
        print('   Пользователь: ${next.user.username}');
        print('   ID: ${next.user.id}');
        
        // После успешной авторизации перенаправляем на карту
        if (mounted) {
          print('🔄 [LoginPage] Виджет mounted, начинаю перенаправление...');
          
          // Используем SchedulerBinding для гарантированного выполнения после кадра
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              print('🚀 [LoginPage] Выполняю context.go("/map")...');
              try {
                context.go('/map');
                print('✅ [LoginPage] Перенаправление на карту выполнено через context.go');
              } catch (e, stackTrace) {
                print('❌ [LoginPage] Ошибка навигации через context.go: $e');
                print('   Stack trace: $stackTrace');
                
                // Пробуем через роутер напрямую
                try {
                  final router = GoRouter.of(context);
                  router.go('/map');
                  print('✅ [LoginPage] Перенаправление выполнено через GoRouter.of');
                } catch (e2) {
                  print('❌ [LoginPage] Ошибка навигации через GoRouter.of: $e2');
                }
              }
            } else {
              print('⚠️ [LoginPage] Виджет не mounted в addPostFrameCallback');
            }
          });
        } else {
          print('⚠️ [LoginPage] Виджет не mounted');
        }
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
