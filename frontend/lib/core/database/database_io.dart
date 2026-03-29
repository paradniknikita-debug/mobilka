// Реализация для нативных платформ (Android, iOS, Windows, Linux, macOS)
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../config/app_config.dart';

LazyDatabase createDatabaseConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, AppConfig.databaseName));
    final database = NativeDatabase.createInBackground(file);
    return database;
  });
}


