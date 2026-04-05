import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// На web пакет [record] после [AudioRecorder.stop] возвращает `blob:` URL, не путь в ФС.
Future<List<int>> readAttachmentBytes(String path) async {
  if (!path.startsWith('blob:')) {
    throw UnsupportedError(
      'Чтение вложения по пути не поддерживается на web (ожидался blob URL)',
    );
  }
  final resp = await web.window.fetch(path.toJS).toDart;
  if (!resp.ok) return [];
  final jsBytes = await resp.bytes().toDart;
  final dart = jsBytes.toDart;
  final out = Uint8List.fromList(dart);
  web.URL.revokeObjectURL(path);
  return out;
}
