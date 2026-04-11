import 'package:dio/dio.dart';

/// Сообщение для SnackBar/плашки при сбое загрузки карты (без «простыни» DioException).
String userMessageForMapLoadError(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    String? detail;
    if (data is Map && data['detail'] != null) {
      detail = data['detail'].toString().trim();
      if (detail.length > 100) {
        detail = '${detail.substring(0, 97)}…';
      }
    }

    if (status == 500 || status == 502 || status == 503) {
      const hint =
          'Частая причина после обновления кода — не применены миграции БД (в каталоге backend: alembic upgrade head).';
      if (detail != null && detail.isNotEmpty) {
        return 'Ошибка сервера ($status): $detail $hint';
      }
      return 'Ошибка сервера ($status) при загрузке карты. $hint';
    }
    if (status == 404) {
      return 'API карты не найден (404). Проверьте адрес сервера в настройках.';
    }
    if (status == 401) {
      return 'Нужна авторизация или сессия истекла.';
    }
    if (status != null) {
      if (detail != null && detail.isNotEmpty) {
        return 'Не удалось загрузить карту ($status): $detail';
      }
      return 'Не удалось загрузить карту (код ответа $status).';
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'Нет связи с сервером.';
    }
  }
  return 'Не удалось загрузить данные карты. Проверьте сервер и сеть.';
}
