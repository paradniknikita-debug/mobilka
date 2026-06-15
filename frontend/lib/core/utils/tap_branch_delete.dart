import '../database/database.dart';

/// Якорная опора отпайки из properties маркера (Tap geojson или опора-якорь).
int? tapAnchorPoleIdFromProperties(Map<String, dynamic> props) {
  final tapPoleId = _intFrom(props['tap_pole_id']);
  if (tapPoleId != null && tapPoleId > 0) return tapPoleId;
  final poleId = _intFrom(props['pole_id']);
  if (poleId != null && poleId > 0) return poleId;
  return null;
}

/// Индекс ветки отпайки; `null` — удалить все ветки от якоря.
int? tapBranchIndexFromProperties(Map<String, dynamic> props) {
  final bi = _intFrom(props['tap_branch_index']);
  if (bi != null && bi > 0) return bi;
  final tn = props['tap_number']?.toString().trim() ?? '';
  if (!tn.contains('/')) return null;
  final suffix = int.tryParse(tn.split('/').last.trim());
  if (suffix != null && suffix > 0) return suffix;
  return null;
}

/// Корень номера отпайки (левая часть N/M), если задан в tap_number.
String? tapRootPrefixFromProperties(Map<String, dynamic> props) {
  final tn = props['tap_number']?.toString().trim() ?? '';
  if (tn.isEmpty) return null;
  if (tn.contains('/')) return tn.split('/').first.trim();
  return tn;
}

/// Опоры ветки отпайки для удаления (без якорной опоры на магистрали).
List<Pole> polesForTapBranchDeletion(
  List<Pole> linePoles, {
  required int anchorPoleId,
  int? branchIndex,
  String? tapRootPrefix,
}) {
  final result = <Pole>[];
  for (final p in linePoles) {
    if (p.id == anchorPoleId) continue;
    var match = false;
    if (p.tapPoleId == anchorPoleId) {
      if (branchIndex == null || (p.tapBranchIndex ?? 1) == branchIndex) {
        match = true;
      }
    }
    if (!match && tapRootPrefix != null && tapRootPrefix.isNotEmpty) {
      final n = p.poleNumber.trim();
      if (n.startsWith('$tapRootPrefix/')) {
        if (branchIndex == null || (p.tapBranchIndex ?? 1) == branchIndex) {
          match = true;
        }
      }
    }
    if (match) result.add(p);
  }
  return result;
}

int? _intFrom(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
