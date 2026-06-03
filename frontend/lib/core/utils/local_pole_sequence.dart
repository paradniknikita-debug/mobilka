import '../database/database.dart';

/// Следующий порядковый номер магистральной опоры на линии (как на сервере при create_pole).
int nextMainSequenceNumber(List<Pole> linePoles) {
  var maxSeq = 0;
  for (final p in linePoles) {
    if (p.poleNumber.contains('/')) continue;
    if (p.tapPoleId != null) continue;
    final sn = p.sequenceNumber;
    if (sn != null && sn > maxSeq) maxSeq = sn;
  }
  if (maxSeq > 0) return maxSeq + 1;
  final mainCount = linePoles.where((p) {
    if (p.poleNumber.contains('/')) return false;
    if (p.tapPoleId != null) return false;
    return true;
  }).length;
  return mainCount + 1;
}

/// Сортировка опор линии для отображения (sequence_number, затем номер).
int comparePolesForLineOrder(Pole a, Pole b) {
  final snA = a.sequenceNumber;
  final snB = b.sequenceNumber;
  if (snA != null && snB != null) return snA.compareTo(snB);
  if (snA != null) return -1;
  if (snB != null) return 1;
  final oa = _poleOrderFromNumber(a.poleNumber);
  final ob = _poleOrderFromNumber(b.poleNumber);
  if (oa != ob) return oa.compareTo(ob);
  return a.poleNumber.compareTo(b.poleNumber);
}

int _poleOrderFromNumber(String poleNumber) {
  final t = poleNumber.trim();
  if (t.isEmpty) return 0;
  final slash = t.indexOf('/');
  final head = slash >= 0 ? t.substring(0, slash) : t;
  final digits = RegExp(r'\d+').firstMatch(head.replaceAll(RegExp(r'[^\d/]'), ''));
  return int.tryParse(digits?.group(0) ?? '') ?? 0;
}
