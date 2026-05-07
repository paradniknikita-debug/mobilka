import 'package:flutter/foundation.dart';

import '../services/base_url_manager.dart';

/// Относительный путь API вложения → абсолютный URL для [Image.network] / Dio.
/// Пример: `/api/v1/attachments/poles/1/abc.jpg` + base `http://host:8000`
String resolveAttachmentAbsoluteUrl(String relativePath) {
  final p = relativePath.startsWith('/') ? relativePath : '/$relativePath';
  final base = BaseUrlManager().getBaseUrl();
  if (base.isEmpty) {
    // Production Flutter Web за nginx: тот же origin
    final origin = Uri.base.origin;
    return '$origin$p';
  }
  return '$base$p';
}

/// Удобно для логов (без утечки токена).
String describeAttachmentUrl(String relativePath) {
  if (kDebugMode) {
    return resolveAttachmentAbsoluteUrl(relativePath);
  }
  return relativePath;
}
