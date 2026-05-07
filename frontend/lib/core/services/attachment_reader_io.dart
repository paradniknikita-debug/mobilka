import 'dart:io';

Future<List<int>> readAttachmentBytes(String path) async {
  final file = File(path);
  if (!await file.exists()) return [];
  return await file.readAsBytes();
}
