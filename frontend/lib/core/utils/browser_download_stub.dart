import 'dart:typed_data';

/// Скачивание в браузере (реализация только для web).
Future<void> triggerBrowserDownload(
  String fileName,
  List<int> bytes, {
  String mimeType = 'application/octet-stream',
}) async {
  throw UnsupportedError('triggerBrowserDownload только для Flutter Web');
}
