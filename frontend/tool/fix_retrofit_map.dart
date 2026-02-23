// После build_runner retrofit_generator 10 генерирует для Future<Map<String, dynamic>>
// неверный код (dynamic.fromJson). Скрипт заменяет его на простой return.
// Запуск из корня frontend: dart run tool/fix_retrofit_map.dart
// В CI вызывается после: dart run build_runner build --delete-conflicting-outputs

import 'dart:io';

void main() {
  final path = 'lib/core/services/api_service.g.dart';
  final file = File(path);
  if (!file.existsSync()) {
    print('$path not found, skip fix');
    exit(0);
  }
  const bad = r'''_value = _result.data!.map(
        (k, dynamic v) =>
            MapEntry(k, dynamic.fromJson(v as Map<String, dynamic>)),
      );''';
  const good = '_value = _result.data!;';
  var content = file.readAsStringSync();
  if (!content.contains('dynamic.fromJson')) {
    print('api_service.g.dart: no fix needed');
    exit(0);
  }
  final newContent = content.replaceAll(bad, good);
  if (newContent == content) {
    print('Pattern not found, check script');
    exit(1);
  }
  file.writeAsStringSync(newContent);
  print('Fixed Map<String, dynamic> deserialization in $path');
}
