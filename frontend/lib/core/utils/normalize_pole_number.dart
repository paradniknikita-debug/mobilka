/// Нормализация наименования опоры (как backend `normalize_pole_number`).
String normalizePoleNumber(String? raw) {
  var s = (raw ?? '').trim();
  if (s.isEmpty) return s;

  final low = s.toLowerCase();
  if (low.startsWith('оп.') || low == 'оп.') {
    final rest = s.replaceFirst(RegExp(r'^оп\.\s*', caseSensitive: false), '').trim();
    return rest.isEmpty ? 'Опора' : 'Опора $rest';
  }

  for (final prefix in ['опрора', 'опра', 'опора', 'опооа', 'опораа', 'опорра', 'опоро']) {
    if (low.startsWith(prefix) || low == prefix) {
      final rest = s.substring(prefix.length).trim();
      return rest.isEmpty ? 'Опора' : 'Опора $rest';
    }
  }

  if (RegExp(r'^\d+$').hasMatch(s)) {
    return 'Опора $s';
  }
  if (RegExp(r'^\d+/\s*\d+').hasMatch(s) || RegExp(r'^\d+\s*/\s*\d+').hasMatch(s)) {
    return 'Опора $s';
  }

  return s;
}
