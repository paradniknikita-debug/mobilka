// Заглушка для платформ, которые не поддерживаются
import 'package:drift/drift.dart';

LazyDatabase createDatabaseConnection() {
  throw UnsupportedError('Платформа не поддерживается');
}


