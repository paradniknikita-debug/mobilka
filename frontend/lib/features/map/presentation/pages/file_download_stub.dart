// Реализация для мобильных платформ и desktop (без dart:html)
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Сохраняет байты в файл в каталог загрузок (или документы приложения).
/// Возвращает путь к сохранённому файлу; выбрасывает исключение при ошибке.
Future<String?> saveFileBytes(String fileName, Uint8List bytes) async {
  final directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes);
  return file.path;
}
