import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Сохраняет вложение в каталог приложения; возвращает локальный путь.
Future<String?> persistCardAttachmentBytes(List<int> bytes, String fileName) async {
  final dir = await getApplicationDocumentsDirectory();
  final sub = Directory('${dir.path}/card_attachments');
  if (!await sub.exists()) {
    await sub.create(recursive: true);
  }
  final safe = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  final path = '${sub.path}/${DateTime.now().millisecondsSinceEpoch}_$safe';
  await File(path).writeAsBytes(bytes, flush: true);
  return path;
}
