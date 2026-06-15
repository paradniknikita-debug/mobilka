import 'package:drift/drift.dart';

import '../database/database.dart';

/// Магистральная опора (не ветка отпайки).
bool isMagistralPole(Pole p) {
  final bt = (p.branchType ?? 'main').toLowerCase();
  return p.tapPoleId == null && bt != 'tap';
}

/// Опора в ветке отпайки.
bool isTapBranchPole(Pole p) {
  if (p.tapPoleId != null) return true;
  return (p.branchType ?? '').toLowerCase() == 'tap';
}

/// Следующий порядковый номер магистральной опоры на линии (как на сервере при create_pole).
int nextMainSequenceNumber(List<Pole> linePoles) {
  var maxSeq = 0;
  for (final p in linePoles) {
    if (!isMagistralPole(p)) continue;
    final sn = p.sequenceNumber;
    if (sn != null && sn > maxSeq) maxSeq = sn;
  }
  if (maxSeq > 0) return maxSeq + 1;
  final mainCount = linePoles.where(isMagistralPole).length;
  return mainCount + 1;
}

/// Следующий sequence_number в ветке отпайки (max + 1, как на backend).
int nextTapSequenceNumber(
  List<Pole> linePoles, {
  required int tapPoleId,
  int tapBranchIndex = 1,
}) {
  var maxSeq = 0;
  var count = 0;
  for (final p in linePoles) {
    if (p.tapPoleId != tapPoleId) continue;
    final bi = p.tapBranchIndex ?? 1;
    if (bi != tapBranchIndex) continue;
    count++;
    final sn = p.sequenceNumber;
    if (sn != null && sn > maxSeq) maxSeq = sn;
  }
  if (maxSeq > 0) return maxSeq + 1;
  return count + 1;
}

/// Единая точка расчёта sequence_number при создании опоры (офлайн и онлайн-кэш).
int computeNextSequenceNumber(
  List<Pole> linePoles, {
  required String branchType,
  int? tapPoleId,
  int? tapBranchIndex,
}) {
  if (branchType == 'tap' && tapPoleId != null) {
    return nextTapSequenceNumber(
      linePoles,
      tapPoleId: tapPoleId,
      tapBranchIndex: tapBranchIndex ?? 1,
    );
  }
  return nextMainSequenceNumber(linePoles);
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

int _backfillOrder(Pole a, Pole b) {
  final sa = a.sequenceNumber;
  final sb = b.sequenceNumber;
  if (sa != null && sb != null) return sa.compareTo(sb);
  if (sa != null) return -1;
  if (sb != null) return 1;
  return a.createdAt.compareTo(b.createdAt);
}

List<Pole> _polesWithPatches(List<Pole> poles, Map<int, int> patches) {
  return poles
      .map(
        (p) => patches.containsKey(p.id)
            ? p.copyWith(sequenceNumber: Value(patches[p.id]))
            : p,
      )
      .toList();
}

/// Проставляет sequence_number опорам без него по правилам сервера.
/// Ключ — id опоры, значение — новый sequence_number.
Map<int, int> computeMissingSequenceNumberPatches(List<Pole> linePoles) {
  final patches = <int, int>{};

  final main = linePoles.where(isMagistralPole).toList()
    ..sort(_backfillOrder);
  for (final p in main) {
    if (p.sequenceNumber != null) continue;
    patches[p.id] = _nextMainSeqFromWorking(_polesWithPatches(linePoles, patches));
  }

  final groups = <String, List<Pole>>{};
  for (final p in linePoles.where(isTapBranchPole)) {
    final tapId = p.tapPoleId;
    if (tapId == null) continue;
    final bi = p.tapBranchIndex ?? 1;
    groups.putIfAbsent('$tapId:$bi', () => []).add(p);
  }

  for (final entry in groups.entries) {
    final parts = entry.key.split(':');
    final tapId = int.parse(parts[0]);
    final branchIndex = int.parse(parts[1]);
    final group = entry.value..sort(_backfillOrder);
    for (final p in group) {
      if (p.sequenceNumber != null) continue;
      patches[p.id] = _nextTapSeqFromWorking(
        _polesWithPatches(linePoles, patches),
        tapPoleId: tapId,
        tapBranchIndex: branchIndex,
      );
    }
  }

  return patches;
}

int _nextMainSeqFromWorking(List<Pole> working) {
  var maxSeq = 0;
  for (final p in working.where(isMagistralPole)) {
    final sn = p.sequenceNumber;
    if (sn != null && sn > maxSeq) maxSeq = sn;
  }
  return maxSeq + 1;
}

int _nextTapSeqFromWorking(
  List<Pole> working, {
  required int tapPoleId,
  required int tapBranchIndex,
}) {
  var maxSeq = 0;
  for (final p in working) {
    if (p.tapPoleId != tapPoleId) continue;
    final bi = p.tapBranchIndex ?? 1;
    if (bi != tapBranchIndex) continue;
    final sn = p.sequenceNumber;
    if (sn != null && sn > maxSeq) maxSeq = sn;
  }
  return maxSeq + 1;
}

int _poleOrderFromNumber(String poleNumber) {
  final t = poleNumber.trim();
  if (t.isEmpty) return 0;
  final slash = t.indexOf('/');
  final head = slash >= 0 ? t.substring(0, slash) : t;
  final digits = RegExp(r'\d+').firstMatch(head.replaceAll(RegExp(r'[^\d/]'), ''));
  return int.tryParse(digits?.group(0) ?? '') ?? 0;
}
