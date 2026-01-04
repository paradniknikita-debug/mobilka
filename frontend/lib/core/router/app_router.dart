import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/map/presentation/pages/map_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/settings/presentation/pages/server_settings_page.dart';
import '../../core/services/auth_service.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  
  // Создаем ValueNotifier для обновления роутера
  final authNotifier = ValueNotifier(authState);
  
  // Обновляем ValueNotifier при изменении состояния
  ref.listen<AuthState>(authStateProvider, (previous, next) {
    if (authNotifier.value != next) {
      authNotifier.value = next;
    }
  });
  
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final currentAuthState = authNotifier.value;
      final isAuthenticated = currentAuthState is AuthStateAuthenticated;
      final isLoading = currentAuthState is AuthStateLoading;
      final isInitial = currentAuthState is AuthStateInitial;
      final currentPath = state.uri.path;
      final isLoggingIn = state.matchedLocation == '/login' || currentPath == '/login';
      
      if (kDebugMode) {
        print('🔄 [Router] redirect проверка:');
        print('   Текущий путь: $currentPath');
        print('   matchedLocation: ${state.matchedLocation}');
        print('   Состояние авторизации: ${currentAuthState.runtimeType}');
        print('   isAuthenticated: $isAuthenticated');
        print('   isLoading: $isLoading');
        print('   isInitial: $isInitial');
        print('   isLoggingIn: $isLoggingIn');
      }
      
      // Если идет загрузка или начальное состояние - разрешаем оставаться на текущей странице
      if (isLoading || isInitial) {
        if (kDebugMode) {
          print('   → [Router] Разрешаем навигацию (загрузка или начальное состояние)');
        }
        return null;
      }
      
      final isRegistering = state.matchedLocation == '/register' || currentPath == '/register';
      
      // Если не авторизован и не на странице логина/регистрации - перенаправляем на логин
      if (!isAuthenticated && !isLoggingIn && !isRegistering) {
        if (kDebugMode) {
          print('   → [Router] Перенаправление на /login (не авторизован)');
        }
        return '/login';
      }
      
      // Если авторизован и на странице логина/регистрации - перенаправляем на карту
      if (isAuthenticated && (isLoggingIn || isRegistering)) {
        if (kDebugMode) {
          print('   → [Router] Перенаправление на /map (авторизован на странице логина/регистрации)');
        }
        return '/map';
      }
      
      if (kDebugMode) {
        print('   → [Router] Разрешаем навигацию (нет редиректа)');
      }
      return null; // Разрешаем навигацию
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/map',
        builder: (context, state) => const MapPage(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/settings/server',
        builder: (context, state) => const ServerSettingsPage(),
      ),
    ],
  );
});
