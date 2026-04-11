import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/database/database.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/auth_service.dart';
import 'core/services/api_service.dart';
import 'core/services/session_expiry.dart';
import 'core/services/sync_service.dart';
import 'core/services/sync_scheduler.dart';
import 'core/services/base_url_manager.dart';
import 'core/services/offline_map_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Подавляем массовый вывод FMTC-ошибок при офлайне (тайл не в кэше и нет сети)
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final str = details.exception.toString();
    if (str.contains('FMTCBrowsingError') && str.contains('noConnectionDuringFetch')) {
      return; // Ожидаемо в офлайне — не засоряем консоль
    }
    originalOnError?.call(details);
  };

  // Офлайн-карта: инициализация FMTC и фоновая загрузка тайлов Беларуси
  // FMTC не поддерживается на web без FFI, поэтому на web пропускаем инициализацию.
  if (!kIsWeb) {
    await OfflineMapService.init();
  }

  // Минимальная инициализация для быстрого старта
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

class LepmApp extends ConsumerStatefulWidget {
  const LepmApp({super.key});

  @override
  ConsumerState<LepmApp> createState() => _LepmAppState();
}

class _LepmAppState extends ConsumerState<LepmApp> {
  @override
  void initState() {
    super.initState();
    registerSessionExpiredHandler(() async {
      await ref.read(authServiceProvider.notifier).logout();
    });
  }

  @override
  void dispose() {
    registerSessionExpiredHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return SyncScheduler(
      child: MaterialApp.router(
        title: 'ЛЭП Management',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
