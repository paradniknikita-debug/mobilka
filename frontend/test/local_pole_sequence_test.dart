import 'package:flutter_test/flutter_test.dart';
import 'package:lepm_mobile/core/database/database.dart';
import 'package:lepm_mobile/core/utils/local_pole_sequence.dart';

Pole _pole({
  required int id,
  required int lineId,
  required String poleNumber,
  int? sequenceNumber,
  String? branchType,
  int? tapPoleId,
  int? tapBranchIndex,
  bool isTapPole = false,
  DateTime? createdAt,
}) {
  return Pole(
    id: id,
    lineId: lineId,
    poleNumber: poleNumber,
    sequenceNumber: sequenceNumber,
    branchType: branchType,
    tapPoleId: tapPoleId,
    tapBranchIndex: tapBranchIndex,
    isTapPole: isTapPole,
    createdBy: 1,
    createdAt: createdAt ?? DateTime(2025, 1, 1),
    isLocal: false,
    needsSync: false,
  );
}

void main() {
  group('nextMainSequenceNumber', () {
    test('returns max + 1 when sequence numbers exist', () {
      final poles = [
        _pole(id: 1, lineId: 10, poleNumber: '1', sequenceNumber: 1),
        _pole(id: 2, lineId: 10, poleNumber: '2', sequenceNumber: 3),
      ];
      expect(nextMainSequenceNumber(poles), 4);
    });

    test('ignores tap branch poles', () {
      final poles = [
        _pole(id: 1, lineId: 10, poleNumber: '3', sequenceNumber: 2),
        _pole(
          id: 2,
          lineId: 10,
          poleNumber: '3/1',
          branchType: 'tap',
          tapPoleId: 1,
          sequenceNumber: 1,
        ),
      ];
      expect(nextMainSequenceNumber(poles), 3);
    });
  });

  group('nextTapSequenceNumber', () {
    test('returns max + 1 within branch', () {
      final poles = [
        _pole(
          id: 1,
          lineId: 10,
          poleNumber: '3/1',
          branchType: 'tap',
          tapPoleId: 100,
          tapBranchIndex: 1,
          sequenceNumber: 1,
        ),
        _pole(
          id: 2,
          lineId: 10,
          poleNumber: '3/2',
          branchType: 'tap',
          tapPoleId: 100,
          tapBranchIndex: 1,
          sequenceNumber: 2,
        ),
      ];
      expect(
        nextTapSequenceNumber(poles, tapPoleId: 100, tapBranchIndex: 1),
        3,
      );
    });

    test('branches are isolated by tapBranchIndex', () {
      final poles = [
        _pole(
          id: 1,
          lineId: 10,
          poleNumber: '3/1',
          branchType: 'tap',
          tapPoleId: 100,
          tapBranchIndex: 2,
          sequenceNumber: 1,
        ),
      ];
      expect(
        nextTapSequenceNumber(poles, tapPoleId: 100, tapBranchIndex: 1),
        1,
      );
    });
  });

  group('computeMissingSequenceNumberPatches', () {
    test('fills main poles in createdAt order', () {
      final poles = [
        _pole(
          id: 1,
          lineId: 10,
          poleNumber: '1',
          createdAt: DateTime(2025, 1, 1),
        ),
        _pole(
          id: 2,
          lineId: 10,
          poleNumber: '2',
          createdAt: DateTime(2025, 1, 2),
        ),
      ];
      final patches = computeMissingSequenceNumberPatches(poles);
      expect(patches, {1: 1, 2: 2});
    });

    test('respects existing sequence numbers', () {
      final poles = [
        _pole(id: 1, lineId: 10, poleNumber: '1', sequenceNumber: 5),
        _pole(
          id: 2,
          lineId: 10,
          poleNumber: '2',
          createdAt: DateTime(2025, 1, 2),
        ),
      ];
      final patches = computeMissingSequenceNumberPatches(poles);
      expect(patches, {2: 6});
    });
  });

  group('comparePolesForLineOrder', () {
    test('sorts by sequence_number first', () {
      final a = _pole(id: 1, lineId: 10, poleNumber: '10', sequenceNumber: 2);
      final b = _pole(id: 2, lineId: 10, poleNumber: '2', sequenceNumber: 1);
      expect(comparePolesForLineOrder(a, b), greaterThan(0));
    });
  });
}
