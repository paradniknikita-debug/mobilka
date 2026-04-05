import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/models/power_line.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/browser_download.dart';
import '../../../../core/utils/download_filename.dart';
import '../../../../core/utils/pole_card_attachment_codec.dart';

PoleCreate _poleCreateFromPole(Pole p, {String? cardCommentAttachment}) {
  return PoleCreate(
    poleNumber: p.poleNumber,
    xPosition: p.xPosition,
    yPosition: p.yPosition,
    poleType: p.poleType,
    height: p.height,
    foundationType: p.foundationType,
    material: p.material,
    yearInstalled: p.yearInstalled,
    condition: p.condition,
    notes: p.notes,
    isTap: p.isTapPole,
    conductorType: p.conductorType,
    conductorMaterial: p.conductorMaterial,
    conductorSection: p.conductorSection,
    cardComment: p.cardComment,
    cardCommentAttachment: cardCommentAttachment ?? p.cardCommentAttachment,
    tapPoleId: p.tapPoleId,
    branchType: p.branchType,
    tapBranchIndex: p.tapBranchIndex,
    startNewTap: false,
  );
}

String _displayName(Map<String, dynamic> m) {
  final orig = m['original_filename']?.toString().trim();
  if (orig != null && orig.isNotEmpty) return orig;
  final fn = m['filename']?.toString().trim();
  if (fn != null && fn.isNotEmpty) return fn;
  final url = (m['url'] ?? m['p'] ?? '').toString();
  if (url.isEmpty) return '—';
  return url.replaceAll(RegExp(r'/+$'), '').split('/').last;
}

String _extensionOf(String name) {
  final i = name.lastIndexOf('.');
  if (i <= 0 || i >= name.length - 1) return '—';
  return name.substring(i).toLowerCase();
}

String _typeRu(String? t) {
  switch (t) {
    case 'file':
      return 'Файл';
    case 'voice':
      return 'Аудио';
    case 'video':
      return 'Видео';
    case 'schema':
      return 'Схема';
    case 'photo':
      return 'Фото';
    default:
      return t?.isNotEmpty == true ? t! : 'Файл';
  }
}

/// Таблица вложений карточки опоры: двойной клик — скачать; при [poleId]/[lineId] — добавление и удаление с сохранением на сервере.
class PoleAttachmentsTableSheet extends ConsumerStatefulWidget {
  const PoleAttachmentsTableSheet({
    super.key,
    required this.rawJson,
    this.poleId,
    this.lineId,
    this.onRemoteUpdated,
  });

  final String? rawJson;
  final int? poleId;
  final int? lineId;
  final Future<void> Function()? onRemoteUpdated;

  @override
  ConsumerState<PoleAttachmentsTableSheet> createState() =>
      _PoleAttachmentsTableSheetState();
}

class _PoleAttachmentsTableSheetState
    extends ConsumerState<PoleAttachmentsTableSheet> {
  late List<Map<String, dynamic>> _rows;
  bool _busy = false;
  _SortKey _sortKey = _SortKey.date;
  bool _ascending = false;

  @override
  void initState() {
    super.initState();
    _rows = List<Map<String, dynamic>>.from(
      PoleCardAttachmentCodec.parseItemsJson(widget.rawJson),
    );
  }

  @override
  void didUpdateWidget(covariant PoleAttachmentsTableSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawJson != widget.rawJson) {
      _rows = List<Map<String, dynamic>>.from(
        PoleCardAttachmentCodec.parseItemsJson(widget.rawJson),
      );
    }
  }

  /// Уникальное имя для отображения/скачивания: «схема.xlsx», «схема (1).xlsx», …
  String _allocateOriginalFilename(String preferred) {
    final existing = <String>{};
    for (final r in _rows) {
      final o = r['original_filename']?.toString().trim();
      if (o != null && o.isNotEmpty) {
        existing.add(o.toLowerCase());
      } else {
        existing.add(_displayName(r).toLowerCase());
      }
    }
    return uniqueDisplayFilename(preferred, existing);
  }

  List<Map<String, dynamic>> get _sorted {
    final list = List<Map<String, dynamic>>.from(_rows);
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

  Future<void> _persistRows([List<Map<String, dynamic>>? rowsToSave]) async {
    final pid = widget.poleId;
    final lid = widget.lineId;
    if (pid == null || lid == null) return;
    final list = rowsToSave ?? _rows;
    setState(() => _busy = true);
    try {
      final api = ref.read(apiServiceProvider);
      final pole = await api.getPole(pid);
      final enc = list.isEmpty ? null : jsonEncode(list);
      await api.updatePole(lid, pid, _poleCreateFromPole(pole, cardCommentAttachment: enc));
      await widget.onRemoteUpdated?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось сохранить: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download(Map<String, dynamic> row) async {
    final rel = (row['url'] ?? row['p'] ?? '').toString();
    if (rel.isEmpty) return;
    final dio = ref.read(dioProvider);
    final prefs = ref.read(prefsProvider);
    final token = prefs.getString(AppConfig.authTokenKey);
    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    try {
      var apiPath = rel.trim();
      if (apiPath.startsWith('/api/${AppConfig.apiVersion}/')) {
        apiPath = apiPath.substring('/api/${AppConfig.apiVersion}'.length);
      } else if (apiPath.startsWith('api/${AppConfig.apiVersion}/')) {
        apiPath = '/${apiPath.substring('api/${AppConfig.apiVersion}'.length)}';
      }
      if (!apiPath.startsWith('/')) apiPath = '/$apiPath';

      final resp = await dio.get<List<int>>(
        apiPath,
        options: Options(
          responseType: ResponseType.bytes,
          headers: headers.isEmpty ? null : headers,
        ),
      );
      final bytes = resp.data;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Пустой ответ');
      }
      final name = _displayName(row);
      final safeName = name == '—' ? 'attachment.bin' : name;
      if (kIsWeb) {
        await triggerBrowserDownload(
          safeName,
          bytes,
          mimeType: mimeTypeForDownloadFilename(safeName),
        );
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/$safeName';
      final f = File(path);
      await f.writeAsBytes(bytes, flush: true);
      await OpenFile.open(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<void> _pickAndUpload(String attachmentType) async {
    final pid = widget.poleId;
    final lid = widget.lineId;
    if (pid == null || lid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сначала сохраните опору, чтобы добавлять вложения')),
        );
      }
      return;
    }
    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.single;
    if (file == null) return;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось прочитать файл')),
        );
      }
      return;
    }
    final preferred = file.name.isNotEmpty ? file.name : 'upload.bin';
    final uniqueClientName = _allocateOriginalFilename(preferred);
    setState(() => _busy = true);
    try {
      final api = ref.read(apiServiceProvider);
      final upload = await api.uploadPoleAttachment(
        pid,
        attachmentType,
        bytes,
        uniqueClientName,
      );
      final orig = upload['original_filename']?.toString().trim();
      final item = <String, dynamic>{
        't': upload['type'] ?? attachmentType,
        'url': upload['url'],
        'filename': upload['filename'],
        'original_filename': (orig != null && orig.isNotEmpty) ? orig : uniqueClientName,
        if (upload['thumbnail_url'] != null) 'thumbnail_url': upload['thumbnail_url'],
        if (upload['added_at'] != null) 'added_at': upload['added_at'],
        if (upload['added_by_id'] != null) 'added_by_id': upload['added_by_id'],
        if (upload['added_by_name'] != null) 'added_by_name': upload['added_by_name'],
      };
      final newRows = [..._rows, item];
      setState(() => _rows = newRows);
      await _persistRows(newRows);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Загрузка не удалась: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(Map<String, dynamic> row) async {
    final u = (row['url'] ?? row['p'])?.toString();
    final next = _rows.where((e) => (e['url'] ?? e['p']).toString() != u).toList();
    setState(() => _rows = next);
    if (widget.poleId != null && widget.lineId != null) {
      await _persistRows(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = PoleCardAttachmentCodec.parseLastEdit(widget.rawJson);
    final rows = _sorted;
    final dateFmt = DateFormat('dd.MM.yyyy HH:mm');

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.58,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Material(
          color: PatrolColors.surfaceCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_busy) const LinearProgressIndicator(minHeight: 2),
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
                      onPressed: _busy ? null : () => Navigator.pop(context),
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
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('По дате'),
                      selected: _sortKey == _SortKey.date,
                      onSelected: (_) => setState(() => _sortKey = _SortKey.date),
                    ),
                    ChoiceChip(
                      label: const Text('По пользователю'),
                      selected: _sortKey == _SortKey.user,
                      onSelected: (_) => setState(() => _sortKey = _SortKey.user),
                    ),
                    FilterChip(
                      label: Text(_ascending ? 'По возрастанию' : 'По убыванию'),
                      selected: true,
                      onSelected: (_) => setState(() => _ascending = !_ascending),
                    ),
                  ],
                ),
              ),
              if (widget.poleId != null && widget.lineId != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _pickAndUpload('file'),
                      icon: const Icon(Icons.attach_file, size: 20),
                      label: const Text('Добавить файл'),
                    ),
                  ),
                ),
              ],
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
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: rows.length + 2,
                        itemBuilder: (context, i) {
                          if (i == 0) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: DefaultTextStyle(
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(width: 56, child: Text('Тип')),
                                    Expanded(flex: 3, child: Text('Имя')),
                                    SizedBox(width: 44, child: Text('Расш.')),
                                    Expanded(flex: 2, child: Text('Дата')),
                                    Expanded(flex: 2, child: Text('Кто добавил')),
                                    SizedBox(width: 40, child: SizedBox()),
                                  ],
                                ),
                              ),
                            );
                          }
                          if (i == 1) {
                            return const Divider(height: 1);
                          }
                          final m = rows[i - 2];
                          final name = _displayName(m);
                          final whenRaw = m['added_at']?.toString();
                          String when = '—';
                          if (whenRaw != null && whenRaw.isNotEmpty) {
                            final d = DateTime.tryParse(whenRaw);
                            when = d != null ? dateFmt.format(d.toLocal()) : whenRaw;
                          }
                          final who = m['added_by_name']?.toString() ??
                              (m['added_by'] != null ? 'id ${m['added_by']}' : '—');
                          return InkWell(
                            onDoubleTap: _busy ? null : () => _download(m),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 56,
                                    child: Text(
                                      _typeRu(m['t']?.toString()),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      name,
                                      style: const TextStyle(fontSize: 13),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 44,
                                    child: Text(
                                      _extensionOf(name),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      when,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      who,
                                      style: const TextStyle(fontSize: 11),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 40,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      icon: const Icon(Icons.delete_outline, size: 20),
                                      onPressed: _busy ? null : () => _remove(m),
                                      tooltip: 'Удалить',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (rows.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    'Двойной клик по строке — скачать и открыть файл',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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

enum _SortKey { date, user }

Future<void> showPoleAttachmentsTable(
  BuildContext context,
  WidgetRef ref,
  String? rawJson, {
  int? poleId,
  int? lineId,
  Future<void> Function()? onRemoteUpdated,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => PoleAttachmentsTableSheet(
      rawJson: rawJson,
      poleId: poleId,
      lineId: lineId,
      onRemoteUpdated: onRemoteUpdated,
    ),
  );
}
