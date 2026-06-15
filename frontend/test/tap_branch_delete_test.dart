import 'package:flutter_test/flutter_test.dart';
import 'package:lepm_mobile/core/database/database.dart';
import 'package:lepm_mobile/core/utils/tap_branch_delete.dart';

Pole _pole({
  required int id,
  required String poleNumber,
  int? tapPoleId,
  int? tapBranchIndex,
}) {
  return Pole(
    id: id,
    lineId: 1,
    poleNumber: poleNumber,
    tapPoleId: tapPoleId,
    tapBranchIndex: tapBranchIndex,
    createdBy: 1,
    createdAt: DateTime(2024),
    isLocal: false,
    needsSync: false,
  );
}

void main() {
  test('polesForTapBranchDeletion by tap_pole_id and branch index', () {
    final poles = [
      _pole(id: 10, poleNumber: '3', tapPoleId: null),
      _pole(id: 11, poleNumber: '1/1', tapPoleId: 10, tapBranchIndex: 1),
      _pole(id: 12, poleNumber: '1/2', tapPoleId: 10, tapBranchIndex: 1),
      _pole(id: 13, poleNumber: '2/1', tapPoleId: 10, tapBranchIndex: 2),
    ];
    final branch1 = polesForTapBranchDeletion(
      poles,
      anchorPoleId: 10,
      branchIndex: 1,
    );
    expect(branch1.map((p) => p.id).toList(), [11, 12]);

    final allBranches = polesForTapBranchDeletion(
      poles,
      anchorPoleId: 10,
      branchIndex: null,
    );
    expect(allBranches.map((p) => p.id).toList(), [11, 12, 13]);
  });

  test('tapAnchorPoleIdFromProperties prefers tap_pole_id over pole_id', () {
    expect(
      tapAnchorPoleIdFromProperties({'tap_pole_id': 5, 'pole_id': 99}),
      5,
    );
    expect(
      tapAnchorPoleIdFromProperties({'pole_id': 99}),
      99,
    );
  });
}
