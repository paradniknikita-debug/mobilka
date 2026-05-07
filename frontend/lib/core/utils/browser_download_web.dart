import 'dart:typed_data';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show AnchorElement, Blob, Url;

/// Скачивание файла в браузере (Blob + ссылка с download).
Future<void> triggerBrowserDownload(
  String fileName,
  List<int> bytes, {
  String mimeType = 'application/octet-stream',
}) async {
  final u8 = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  final blob = html.Blob([u8], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
