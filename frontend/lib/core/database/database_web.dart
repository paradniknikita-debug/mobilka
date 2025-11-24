// Реализация для Web платформы
import 'package:drift/drift.dart';
import 'package:drift/web.dart';
import '../config/app_config.dart';

LazyDatabase createDatabaseConnection() {
  // Для Web используем IndexedDB через WebDatabase
  // Данные сохраняются между сессиями
  return LazyDatabase(() async {
    return DatabaseConnection.fromExecutor(
      WebDatabase(AppConfig.databaseName),
    );
  });
}

