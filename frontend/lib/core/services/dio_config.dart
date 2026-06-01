import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

import 'base_url_manager.dart';

/// Настройка Dio: на мобильных платформах проверка сертификата зависит от настройки пользователя.
void configureDioSslTrust(Dio dio) {
  if (kIsWeb) {
    return;
  }

  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      client.badCertificateCallback = (_, __, ___) =>
          BaseUrlManager().shouldTrustSelfSignedCert;
      return client;
    },
  );
}

bool isSslCertificateError(DioException error) {
  if (error.type == DioExceptionType.badCertificate) {
    return true;
  }

  final details = '${error.message ?? ''} ${error.error ?? ''}'.toLowerCase();
  return details.contains('certificate') ||
      details.contains('handshake') ||
      details.contains('cert_authority') ||
      details.contains('untrusted') ||
      details.contains('ssl') ||
      details.contains('sec_e_untrusted_root');
}

String sslCertificateErrorMessage({required bool trustEnabled}) {
  if (trustEnabled) {
    return 'Не удалось установить защищённое соединение с сервером. '
        'Проверьте URL и доступность сервера.';
  }

  return 'Сервер использует самоподписанный SSL-сертификат.\n\n'
      'В «Настройках сервера» включите «Доверять самоподписанному сертификату» '
      'и сохраните URL заново.\n\n'
      'Либо установите сертификат Let\'s Encrypt на сервер (нужен домен).';
}
