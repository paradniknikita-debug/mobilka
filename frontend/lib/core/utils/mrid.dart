import 'package:uuid/uuid.dart';

/// mRID по IEC 61970 — как [generate_mrid] на бэкенде.
String generateMrid() => const Uuid().v4();

String? normalizeMridDisplay(dynamic value) {
  final s = value?.toString().trim();
  if (s == null || s.isEmpty) return null;
  return s;
}
