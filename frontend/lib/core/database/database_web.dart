// Реализация для Web: WasmDatabase в главном потоке (без воркера).
// Избегает ошибки "localtime: function import requires a callable", т.к. импорты
// WASM предоставляет само приложение. Требуется sqlite3.wasm в web/ (см. web/README.md).
import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:sqlite3/wasm.dart';
import '../config/app_config.dart';

LazyDatabase createDatabaseConnection() {
  return LazyDatabase(() async {
    try {
      // Загрузка WASM в главном потоке — импорты (в т.ч. localtime) даёт наше приложение.
      final sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
      final fs = await IndexedDbFileSystem.open(
        dbName: 'drift_${AppConfig.databaseName.replaceAll(RegExp(r'\.\w+$'), '')}',
      );
      sqlite3.registerVirtualFileSystem(fs, makeDefault: true);

      final db = WasmDatabase(
        sqlite3: sqlite3,
        path: '/${AppConfig.databaseName}',
        fileSystem: fs,
      );
      return db;
    } catch (e) {
      throw UnsupportedError(
        'Не удалось открыть локальную БД на веб. '
        'Убедитесь, что в папке web/ есть sqlite3.wasm (версия 2.9.3, см. web/README.md). '
        'Ошибка: $e',
      );
    }
  });
}
