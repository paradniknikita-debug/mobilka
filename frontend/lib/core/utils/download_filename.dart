/// MIME по расширению для Blob при скачивании в браузере.
String mimeTypeForDownloadFilename(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.xlsx')) {
    return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  }
  if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
  if (lower.endsWith('.csv')) return 'text/csv; charset=utf-8';
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.svg')) return 'image/svg+xml';
  if (lower.endsWith('.mp3')) return 'audio/mpeg';
  if (lower.endsWith('.m4a')) return 'audio/mp4';
  if (lower.endsWith('.wav')) return 'audio/wav';
  if (lower.endsWith('.webm')) return 'video/webm';
  if (lower.endsWith('.mp4')) return 'video/mp4';
  if (lower.endsWith('.docx')) {
    return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  }
  if (lower.endsWith('.doc')) return 'application/msword';
  if (lower.endsWith('.pptx')) {
    return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
  }
  if (lower.endsWith('.zip')) return 'application/zip';
  if (lower.endsWith('.txt')) return 'text/plain; charset=utf-8';
  return 'application/octet-stream';
}

/// Имя «как у пользователя» без конфликтов: `схема.xlsx`, `схема (1).xlsx`, …
String uniqueDisplayFilename(String desired, Iterable<String> existingLowercase) {
  var name = desired.trim();
  if (name.isEmpty) name = 'file';
  final lower = name.toLowerCase();
  if (!existingLowercase.contains(lower)) return name;

  final dot = name.lastIndexOf('.');
  String base;
  String ext;
  if (dot > 0 && dot < name.length - 1) {
    base = name.substring(0, dot);
    ext = name.substring(dot);
  } else {
    base = name;
    ext = '';
  }

  for (var i = 1; i < 10000; i++) {
    final candidate = '$base ($i)$ext';
    if (!existingLowercase.contains(candidate.toLowerCase())) {
      return candidate;
    }
  }
  return '$base (${DateTime.now().millisecondsSinceEpoch})$ext';
}
