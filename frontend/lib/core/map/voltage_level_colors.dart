import 'package:flutter/material.dart';

/// Цвета линий и подстанций по номиналу напряжения (кВ) — единая схема с веб-клиентом.
class VoltageLevelColors {
  VoltageLevelColors._();

  static const double strokeWidthMain = 4.0;
  static const double strokeWidthTap = 3.0;
  static const double strokeWidthPatrolExtra = 1.5;

  /// Номиналы и hex (как в легенде ГИС). Не const Map: ключи double.
  static final Map<double, Color> _byNominal = <double, Color>{
    750: const Color(0xFF008000),
    330: const Color(0xFF00A500),
    220: const Color(0xFFC0C000),
    110: const Color(0xFF17A2B8),
    35: const Color(0xFF96854F),
    10: const Color(0xFFA668A6),
    6: const Color(0xFFF5B88A),
    0.4: const Color(0xFFB0B0B0),
  };

  static const List<double> _nominals = [750, 330, 220, 110, 35, 10, 6, 0.4];

  /// Ближайший номинал и цвет (при null/0 — 0.4 кВ, серый).
  static Color colorForVoltageKv(double? kv) {
    if (kv == null || kv <= 0) {
      return _byNominal[0.4]!;
    }
    var best = 0.4;
    var bestDiff = double.infinity;
    for (final n in _nominals) {
      final d = (kv - n).abs();
      if (d < bestDiff) {
        bestDiff = d;
        best = n;
      }
    }
    return _byNominal[best]!;
  }

  static double strokeWidthForLine({required bool isTap, required bool isPatrol}) {
    final base = isTap ? strokeWidthTap : strokeWidthMain;
    return isPatrol ? base + strokeWidthPatrolExtra : base;
  }

  /// Подписи для мини-легенды (кВ → цвет)
  static List<MapEntry<String, Color>> get legendEntries => [
        const MapEntry('750', Color(0xFF008000)),
        const MapEntry('330', Color(0xFF00A500)),
        const MapEntry('220', Color(0xFFC0C000)),
        const MapEntry('110', Color(0xFF17A2B8)),
        const MapEntry('35', Color(0xFF96854F)),
        const MapEntry('10', Color(0xFFA668A6)),
        const MapEntry('6', Color(0xFFF5B88A)),
        const MapEntry('0.4', Color(0xFFB0B0B0)),
      ];
}
