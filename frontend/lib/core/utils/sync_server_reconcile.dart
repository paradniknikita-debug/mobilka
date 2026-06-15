import '../database/database.dart';
import '../models/power_line.dart' as api;
import 'mrid.dart';
import 'normalize_pole_number.dart';

/// Найти опору на сервере, соответствующую локальной (mRID или номер).
api.Pole? findServerPoleMatch({
  required String? localMrid,
  required String localPoleNumber,
  required List<api.Pole> serverPoles,
}) {
  final normMrid = normalizeMridDisplay(localMrid);
  if (normMrid != null) {
    for (final s in serverPoles) {
      if (normalizeMridDisplay(s.mrid) == normMrid) return s;
    }
  }
  final normNum = normalizePoleNumber(localPoleNumber);
  if (normNum.isEmpty) return null;
  for (final s in serverPoles) {
    if (normalizePoleNumber(s.poleNumber) == normNum) return s;
  }
  return null;
}

/// Найти оборудование на сервере (mRID или тип+название на той же опоре).
api.Equipment? findServerEquipmentMatch({
  required EquipmentData local,
  required List<api.Equipment> serverList,
}) {
  final normMrid = normalizeMridDisplay(local.mrid);
  if (normMrid != null) {
    for (final s in serverList) {
      if (normalizeMridDisplay(s.mrid) == normMrid) return s;
    }
  }
  final localKey =
      '${local.equipmentType.trim().toLowerCase()}|${local.name.trim().toLowerCase()}';
  if (localKey == '|') return null;
  for (final s in serverList) {
    final sk =
        '${s.equipmentType.trim().toLowerCase()}|${s.name.trim().toLowerCase()}';
    if (sk == localKey) return s;
  }
  return null;
}
