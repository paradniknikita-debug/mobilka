import '../database/database.dart';

/// Результат слияния полей опоры при download (last-write-wins + доп. поля).
class SyncPoleMergeResult {
  const SyncPoleMergeResult({
    required this.xPosition,
    required this.yPosition,
    required this.poleNumber,
    required this.poleType,
    required this.height,
    required this.foundationType,
    required this.material,
    required this.yearInstalled,
    required this.condition,
    required this.notes,
    required this.structuralDefect,
    required this.structuralDefectCriticality,
    required this.cardComment,
    required this.sequenceNumber,
    required this.branchType,
    required this.tapPoleId,
    required this.tapBranchIndex,
    required this.isTapPole,
    required this.conductorType,
    required this.conductorMaterial,
    required this.conductorSection,
  });

  final double xPosition;
  final double yPosition;
  final String poleNumber;
  final String? poleType;
  final double? height;
  final String? foundationType;
  final String? material;
  final int? yearInstalled;
  final String condition;
  final String? notes;
  final String? structuralDefect;
  final String? structuralDefectCriticality;
  final String? cardComment;
  final int? sequenceNumber;
  final String? branchType;
  final int? tapPoleId;
  final int? tapBranchIndex;
  final bool isTapPole;
  final String? conductorType;
  final String? conductorMaterial;
  final String? conductorSection;
}

bool _coordsMeaningful(double? x, double? y) =>
    x != null && y != null && (x != 0 || y != 0);

/// Слияние серверной записи с локальной: pending локальные не трогаем (вызывать снаружи).
/// Для синхронизированных записей — last-write-wins по группам; координаты и комментарии можно совместить.
SyncPoleMergeResult mergePoleFromServerDownload({
  required Pole? local,
  required Map<String, dynamic> server,
  required double serverX,
  required double serverY,
  required bool serverSentCoords,
  required int? mergedSequenceNumber,
  required String? mergedBranchType,
  required int? mergedTapPoleId,
  required int? mergedTapBranchIndex,
  required bool mergedIsTapPole,
}) {
  final localU = local?.updatedAt ?? local?.createdAt;
  final serverU = _parseDate(server['updated_at']) ?? _parseDate(server['created_at']);
  final serverNewer = localU == null ||
      (serverU != null && serverU.isAfter(localU));

  final localCoords = _coordsMeaningful(local?.xPosition, local?.yPosition);
  final serverCoords = serverSentCoords;

  double xFinal;
  double yFinal;
  if (localCoords && serverCoords) {
    if (serverNewer) {
      xFinal = serverX;
      yFinal = serverY;
    } else {
      xFinal = local!.xPosition ?? serverX;
      yFinal = local.yPosition ?? serverY;
    }
  } else if (serverCoords) {
    xFinal = serverX;
    yFinal = serverY;
  } else {
    xFinal = local?.xPosition ?? serverX;
    yFinal = local?.yPosition ?? serverY;
  }

  String? pickString(String? serverVal, String? localVal) {
    final s = serverVal?.trim();
    final l = localVal?.trim();
    if (s == null || s.isEmpty) return localVal;
    if (l == null || l.isEmpty) return serverVal;
    return serverNewer ? serverVal : localVal;
  }

  final serverNotes = server['notes'] as String?;
  final serverDefect = server['structural_defect'] as String?;
  final serverCrit = server['structural_defect_criticality'] as String?;

  return SyncPoleMergeResult(
    xPosition: xFinal,
    yPosition: yFinal,
    poleNumber: serverNewer
        ? (server['pole_number'] as String? ?? local?.poleNumber ?? '')
        : (local?.poleNumber ?? server['pole_number'] as String? ?? ''),
    poleType: pickString(
      server['pole_type'] as String?,
      local?.poleType,
    ),
    height: serverNewer
        ? _toDouble(server['height'])
        : (local?.height ?? _toDouble(server['height'])),
    foundationType: pickString(
      server['foundation_type'] as String?,
      local?.foundationType,
    ),
    material: pickString(server['material'] as String?, local?.material),
    yearInstalled: serverNewer
        ? _toInt(server['year_installed'])
        : (local?.yearInstalled ?? _toInt(server['year_installed'])),
    condition: serverNewer
        ? (server['condition'] as String? ?? local?.condition ?? 'good')
        : (local?.condition ?? server['condition'] as String? ?? 'good'),
    notes: pickString(serverNotes, local?.notes),
    structuralDefect: pickString(serverDefect, local?.structuralDefect),
    structuralDefectCriticality: pickString(serverCrit, local?.structuralDefectCriticality),
    cardComment: pickString(
      server['card_comment'] as String?,
      local?.cardComment,
    ),
    sequenceNumber: mergedSequenceNumber,
    branchType: mergedBranchType,
    tapPoleId: mergedTapPoleId,
    tapBranchIndex: mergedTapBranchIndex,
    isTapPole: mergedIsTapPole,
    conductorType: pickString(
      server['conductor_type'] as String?,
      local?.conductorType,
    ),
    conductorMaterial: pickString(
      server['conductor_material'] as String?,
      local?.conductorMaterial,
    ),
    conductorSection: pickString(
      server['conductor_section'] as String?,
      local?.conductorSection,
    ),
  );
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString());
}

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse(v.toString());
}
