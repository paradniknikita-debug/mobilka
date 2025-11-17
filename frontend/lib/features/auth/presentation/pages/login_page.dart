import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Логотип
              const Icon(
                Icons.electrical_services,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              
              // Заголовок
              Text(
                'ЛЭП Management',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              Text(
                'Система управления линиями электропередач',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Кнопка входа (для тестирования)
              ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('Войти (Тест)'),
              ),
              ElevatedButton(
                onPressed: () => context.go('/map'),
                child: const Text('Карта'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}