import 'package:flutter/material.dart';

import '../../../../core/services/equipment_catalog_update_service.dart';
import '../../../../core/theme/app_theme.dart';

Future<bool?> showEquipmentCatalogUpdateDialog(
  BuildContext context,
  EquipmentCatalogUpdateDiff diff,
) {
  final parts = <String>[];
  if (diff.addedCount > 0) {
    parts.add('новых марок: ${diff.addedCount}');
  }
  if (diff.changedCount > 0) {
    parts.add('изменено: ${diff.changedCount}');
  }
  if (diff.removedCount > 0) {
    parts.add('удалено на сервере: ${diff.removedCount}');
  }
  final summary = parts.isEmpty ? 'есть отличия' : parts.join(', ');

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: PatrolColors.surfaceCard,
      title: const Text(
        'Обновить справочник марок?',
        style: TextStyle(color: PatrolColors.textPrimary),
      ),
      content: Text(
        'На сервере обновлён справочник оборудования ($summary).\n\n'
        'Локально: ${diff.localCount} поз., на сервере: ${diff.serverCount} поз.\n\n'
        'Обновить марки на этом устройстве для работы офлайн?',
        style: const TextStyle(color: PatrolColors.textSecondary, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text(
            'Позже',
            style: TextStyle(color: PatrolColors.textSecondary),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: PatrolColors.accentBlue,
          ),
          child: const Text('Обновить'),
        ),
      ],
    ),
  );
}
