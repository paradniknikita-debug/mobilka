import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/power_line_edit_hint.dart';
import '../theme/app_theme.dart';
import 'api_service.dart';

/// Запрос edit-hint и UI-предупреждение (не блокирует — пользователь может продолжить).
class LineEditHintUi {
  LineEditHintUi._();

  static Future<PowerLineEditHint?> fetch(WidgetRef ref, int lineId) async {
    if (lineId <= 0) return null;
    try {
      return await ref.read(apiServiceProvider).getPowerLineEditHint(lineId);
    } catch (_) {
      return null;
    }
  }

  /// Диалог перед сохранением. `true` — продолжить, `false` — отмена.
  static Future<bool> confirmBeforeSave(
    BuildContext context,
    WidgetRef ref,
    int lineId,
  ) async {
    final hint = await fetch(ref, lineId);
    if (hint == null || !hint.warn) return true;
    if (!context.mounted) return true;
    return _showDialog(context, hint);
  }

  /// Баннерное сообщение при выборе линии (не модальный).
  static Future<String?> bannerMessage(WidgetRef ref, int lineId) async {
    final hint = await fetch(ref, lineId);
    if (hint == null || !hint.warn) return null;
    return _formatMessage(hint);
  }

  static String _formatMessage(PowerLineEditHint hint) {
    final base = hint.message?.trim();
    if (base != null && base.isNotEmpty) return base;
    final n = hint.recentEditors.length;
    if (n == 0) {
      return 'Недавно эту линию редактировали другие пользователи.';
    }
    return 'Недавно эту линию редактировали другие пользователи ($n). '
        'При сохранении побеждают последние изменения; разные поля объединяются.';
  }

  static Future<bool> _showDialog(BuildContext context, PowerLineEditHint hint) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PatrolColors.surfaceCard,
        icon: const Icon(Icons.people_outline, color: Colors.orange, size: 32),
        title: const Text(
          'Параллельное редактирование',
          style: TextStyle(color: PatrolColors.textPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatMessage(hint),
                style: const TextStyle(color: PatrolColors.textPrimary),
              ),
              if (hint.recentEditors.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Недавние правки:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: PatrolColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                ...hint.recentEditors.take(5).map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• Пользователь #${e.userId} (${e.sourceLabel})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: PatrolColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
