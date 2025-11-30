import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/config/app_config.dart';

class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isLoading = authState is AuthStateLoading;

    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Поле имени пользователя
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Имя пользователя',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
            autofillHints: const [AutofillHints.username],
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.text,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Введите имя пользователя';
              }
              return null;
            },
            enabled: !isLoading,
          ),
          const SizedBox(height: 16),

          // Поле пароля
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Пароль',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: const OutlineInputBorder(),
            ),
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.visiblePassword,
            onFieldSubmitted: (_) => _handleLogin(),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Введите пароль';
              }
              if (value.length < AppConfig.minPasswordLength) {
                return 'Пароль должен содержать минимум ${AppConfig.minPasswordLength} символов';
              }
              return null;
            },
            enabled: !isLoading,
          ),
          const SizedBox(height: 24),

          // Кнопка входа
          ElevatedButton(
            onPressed: isLoading ? null : _handleLogin,
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Войти'),
          ),
        ],
      ),
    ),
    );
  }

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      ref.read(authServiceProvider.notifier).login(
        _usernameController.text.trim(),
        _passwordController.text,
      );
    }
  }
}
