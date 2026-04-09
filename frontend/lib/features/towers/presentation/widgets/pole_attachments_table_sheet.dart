import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/pole_card_attachment_codec.dart';

/// Таблица вложений карточки опоры: сортировка по дате и по пользователю.
class PoleAttachmentsTableSheet extends StatefulWidget {
  const PoleAttachmentsTableSheet({super.key, required this.rawJson});

  final String? rawJson;

  @override
  State<PoleAttachmentsTableSheet> createState() =>
      _PoleAttachmentsTableSheetState();
}

enum _SortKey { date, user }

class _PoleAttachmentsTableSheetState extends State<PoleAttachmentsTableSheet> {
  _SortKey _sortKey = _SortKey.date;
  bool _ascending = false;

  List<Map<String, dynamic>> get _items =>
      PoleCardAttachmentCodec.parseItemsJson(widget.rawJson);

  List<Map<String, dynamic>> get _sorted {
    final list = List<Map<String, dynamic>>.from(_items);
    int cmp(Map<String, dynamic> a, Map<String, dynamic> b) {
      if (_sortKey == _SortKey.user) {
        final ua = '${a['added_by_name'] ?? a['added_by'] ?? ''}';
        final ub = '${b['added_by_name'] ?? b['added_by'] ?? ''}';
        return ua.compareTo(ub);
      }
      final da = a['added_at'] as String? ?? '';
      final db = b['added_at'] as String? ?? '';
      return da.compareTo(db);
    }

    list.sort(cmp);
    if (!_ascending) {
      return list.reversed.toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final last = PoleCardAttachmentCodec.parseLastEdit(widget.rawJson);
    final rows = _sorted;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Material(
          color: PatrolColors.surfaceCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      'Вложения карточки',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: PatrolColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              if (last != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _lastEditLabel(last),
                    style: const TextStyle(
                      fontSize: 13,
                      color: PatrolColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('По дате'),
                      selected: _sortKey == _SortKey.date,
                      onSelected: (_) =>
                          setState(() => _sortKey = _SortKey.date),
                    ),
                    ChoiceChip(
                      label: const Text('По пользователю'),
                      selected: _sortKey == _SortKey.user,
                      onSelected: (_) =>
                          setState(() => _sortKey = _SortKey.user),
                    ),
                    FilterChip(
                      label: Text(_ascending ? 'По возрастанию' : 'По убыванию'),
                      selected: true,
                      onSelected: (_) =>
                          setState(() => _ascending = !_ascending),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: rows.isEmpty
                    ? const Center(
                        child: Text(
                          'Нет вложений',
                          style: TextStyle(color: PatrolColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: rows.length,
                        itemBuilder: (context, i) {
                          final m = rows[i];
                          final t = (m['t'] as String?) ?? 'photo';
                          final typeLabel = t == 'voice'
                              ? 'Аудио'
                              : t == 'schema'
                                  ? 'Схема'
                                  : 'Фото';
                          final who = m['added_by_name']?.toString() ??
                              (m['added_by'] != null
                                  ? 'id ${m['added_by']}'
                                  : '—');
                          final when = m['added_at']?.toString() ?? '—';
                          final ref = m['url'] ?? m['p'] ?? '';
                          return ListTile(
                            leading: Icon(
                              t == 'voice' ? Icons.mic : Icons.image,
                              color: PatrolColors.textPrimary,
                            ),
                            title: Text(typeLabel),
                            subtitle: Text(
                              '$who • $when\n${ref.toString().length > 60 ? '${ref.toString().substring(0, 60)}…' : ref}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            isThreeLine: true,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _lastEditLabel(Map<String, dynamic> last) {
    final kind = last['kind']?.toString() ?? '';
    final at = last['at']?.toString() ?? '';
    final uid = last['user_id'];
    final un = last['user_name']?.toString();
    final who = un ?? (uid != null ? 'id $uid' : '—');
    return 'Последнее изменение: $kind • $who • $at';
  }
}

Future<void> showPoleAttachmentsTable(
  BuildContext context,
  String? rawJson,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => PoleAttachmentsTableSheet(rawJson: rawJson),
  );
}
