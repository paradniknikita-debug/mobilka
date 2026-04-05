import 'dart:html' as html;
import 'dart:typed_data';

Future<List<int>> readAttachmentBytes(String path) async {
  final normalized = path.trim();
  if (normalized.isEmpty) return [];

  try {
    final request = await html.HttpRequest.request(
      normalized,
      method: 'GET',
      responseType: 'arraybuffer',
    );
    final response = request.response;
    if (response is ByteBuffer) {
      return Uint8List.view(response).toList();
    }
    if (response is Uint8List) {
      return response.toList();
    }
    return [];
  } catch (_) {
    return [];
  }
}
