import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/app_config.dart';
import 'core/database/database.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/auth_service.dart';
import 'core/services/api_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/base_url_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Минимальная инициализация для быстрого старта
  // Только SharedPreferences - остальное загрузится лениво
  final prefs = await SharedPreferences.getInstance();
  
  // Инициализируем BaseUrlManager с SharedPreferences
  final urlManager = BaseUrlManager();
  await urlManager.init(prefs);
  // Принудительно обновляем протокол из конфига при старте
  urlManager.updateProtocolFromConfig();
  
  final apiService = ApiServiceProvider.create(prefs: prefs);
  ApiServiceProvider.updatePrefs(prefs);
  
  // База данных и SyncService инициализируются лениво (при первом использовании)
  // Это ускоряет стартовую загрузку приложения
  final database = AppDatabase();
  final syncService = SyncService(database, apiService, prefs);
  
  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(database),
        apiServiceProvider.overrideWithValue(apiService),
        syncServiceProvider.overrideWithValue(syncService),
      ],
      child: const LepmApp(),
    ),
  );
}

class LepmApp extends ConsumerWidget {
  const LepmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: 'ЛЭП Management',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}