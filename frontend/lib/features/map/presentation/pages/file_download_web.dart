// Реализация для веб-платформы (использует dart:html)
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show Blob, Url, AnchorElement;

/// Инициирует скачивание файла в браузере. Возвращает null (файл не сохраняется на диск в вебе).
/// Выбрасывает исключение при ошибке.
Future<String?> saveFileBytes(String fileName, Uint8List bytes) async {
  final blob = html.Blob([bytes], 'application/xml');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
  return null;
}
