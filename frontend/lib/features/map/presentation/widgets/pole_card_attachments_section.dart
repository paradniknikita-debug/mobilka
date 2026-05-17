import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/utils/pole_card_attachment_codec.dart';
import '../../../../core/utils/attachment_urls.dart';
import '../../../../core/utils/pole_card_comment_codec.dart';
import '../pages/file_download_stub.dart'
    if (dart.library.html) '../pages/file_download_web.dart' as file_download;
import 'package:url_launcher/url_launcher.dart';

String _attachmentTypeRu(String? raw) {
  switch ((raw ?? '').toLowerCase().trim()) {
    case 'photo':
      return 'Фото';
    case 'schema':
      return 'Схема';
    case 'voice':
      return 'Голос';
    case 'video':
      return 'Видео';
    case 'file':
      return 'Файл';
    default:
      return raw == null || raw.isEmpty ? 'Вложение' : raw;
  }
}

String _basenameFromUrl(String rel) {
  final t = rel.trim();
  if (t.isEmpty) return 'attachment.bin';
  final seg = t.replaceAll(RegExp(r'/+$'), '').split('/');
  return seg.isNotEmpty ? seg.last : 'attachment.bin';
}

String _displayNameForAttachment(Map<String, dynamic> m, String url) {
  final o = m['original_filename']?.toString().trim();
  if (o != null && o.isNotEmpty) return o;
  final fn = m['filename']?.toString().trim();
  if (fn != null && fn.isNotEmpty) return fn;
  return _basenameFromUrl(url);
}

/// Относительный URL вложения → путь для [Dio] (baseUrl уже `/api/v1`).
String _attachmentPathForDio(String rel) {
  var apiPath = rel.trim();
  if (apiPath.startsWith('/api/${AppConfig.apiVersion}/')) {
    apiPath = apiPath.substring('/api/${AppConfig.apiVersion}'.length);
  } else if (apiPath.startsWith('api/${AppConfig.apiVersion}/')) {
    apiPath = '/${apiPath.substring('api/${AppConfig.apiVersion}'.length)}';
  }
  if (!apiPath.startsWith('/')) apiPath = '/$apiPath';
  return apiPath;
}

Future<void> _downloadLocalAttachmentFile({
  required BuildContext context,
  required String localPath,
  String? suggestedDownloadName,
}) async {
  try {
    final f = File(localPath);
    if (!await f.exists()) {
      throw Exception('Локальный файл не найден');
    }
    final bytes = await f.readAsBytes();
    if (bytes.isEmpty) throw Exception('Пустой файл');
    final name = (suggestedDownloadName != null && suggestedDownloadName.trim().isNotEmpty)
        ? suggestedDownloadName.trim()
        : localPath.split(RegExp(r'[\\/]')).last;
    final u8 = Uint8List.fromList(bytes);
    if (kIsWeb) {
      await file_download.saveFileBytes(name, u8);
    } else {
      final saved = await file_download.saveFileBytes(name, u8);
      if (saved != null && saved.isNotEmpty) {
        await OpenFile.open(saved);
      } else {
        await OpenFile.open(localPath);
      }
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(kIsWeb ? 'Файл загружен браузером' : 'Файл сохранён'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть файл: $e')),
      );
    }
  }
}

Future<void> _downloadAttachmentFile({
  required BuildContext context,
  required Dio dio,
  required Map<String, String> authHeaders,
  required String relativeUrl,
  String? suggestedDownloadName,
}) async {
  final apiPath = _attachmentPathForDio(relativeUrl);
  try {
    final resp = await dio.get<List<int>>(
      apiPath,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = resp.data;
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Пустой ответ');
    }
    final name = (suggestedDownloadName != null && suggestedDownloadName.trim().isNotEmpty)
        ? suggestedDownloadName.trim()
        : _basenameFromUrl(relativeUrl);
    final u8 = Uint8List.fromList(bytes);
    if (kIsWeb) {
      await file_download.saveFileBytes(name, u8);
    } else {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/$name';
      final f = File(path);
      await f.writeAsBytes(u8, flush: true);
      await OpenFile.open(path);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(kIsWeb ? 'Файл загружен браузером' : 'Файл открыт'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось скачать: $e')),
      );
    }
  }
}

/// Блок «Комментарий карточки» и превью вложений (с Bearer для API).
class PoleCardAttachmentsSection extends ConsumerWidget {
  final Map<String, dynamic> objectProperties;
  /// Добавить файл на сервер и в карточку (опора / оборудование с id).
  final Future<void> Function()? onAddAttachment;

  const PoleCardAttachmentsSection({
    super.key,
    required this.objectProperties,
    this.onAddAttachment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rawComment = objectProperties['card_comment']?.toString().trim();
    final commentThread = (rawComment == null || rawComment.isEmpty)
        ? <Map<String, dynamic>>[]
        : PoleCardCommentCodec.parse(rawComment);
    final raw = objectProperties['card_comment_attachment']?.toString();
    final prefs = ref.watch(prefsProvider);
    final token = prefs.getString(AppConfig.authTokenKey);
    final dio = ref.watch(dioProvider);

    final items = (raw == null || raw.isEmpty)
        ? <Map<String, dynamic>>[]
        : PoleCardAttachmentCodec.parseItemsJson(raw);

    if (commentThread.isEmpty && items.isEmpty && onAddAttachment == null) {
      return const SizedBox.shrink();
    }

    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    final hasAuth = headers.isNotEmpty;

    final rows = <DataRow>[];
    var rowNum = 0;
    for (var i = 0; i < items.length; i++) {
      final m = items[i];
      final t = m['t']?.toString() ?? '';
      final url = m['url']?.toString();
      final localPath = m['p']?.toString();
      final hasUrl = url != null && url.isNotEmpty;
      final hasLocal = !kIsWeb && localPath != null && localPath.isNotEmpty;
      if (!hasUrl && !hasLocal) continue;
      rowNum++;
      final thumb = m['thumbnail_url']?.toString();
      final ref = hasUrl ? url! : localPath!;
      final displayName = _displayNameForAttachment(m, ref);
      rows.add(
        DataRow(
          cells: [
            DataCell(Text('$rowNum', style: const TextStyle(fontSize: 13))),
            DataCell(
              Text(
                _attachmentTypeRu(t),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            DataCell(
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 160, maxWidth: 320),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: hasUrl
                            ? _AttachmentRow(
                                type: t,
                                relativeUrl: url!,
                                displayFilename: displayName,
                                thumbnailUrl: thumb,
                                authHeaders: headers,
                                dio: dio,
                              )
                            : Text(
                                displayName,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      IconButton(
                        tooltip: hasUrl ? 'Скачать' : 'Открыть файл',
                        icon: const Icon(Icons.download, size: 20),
                        onPressed: () {
                          if (hasUrl && hasAuth) {
                            _downloadAttachmentFile(
                              context: context,
                              dio: dio,
                              authHeaders: headers,
                              relativeUrl: url!,
                              suggestedDownloadName: displayName,
                            );
                          } else if (hasLocal) {
                            _downloadLocalAttachmentFile(
                              context: context,
                              localPath: localPath!,
                              suggestedDownloadName: displayName,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Комментарии и вложения к объекту',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 10),
        if (onAddAttachment != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () async {
                try {
                  await onAddAttachment!();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ошибка: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.attach_file, size: 18),
              label: const Text('Добавить вложение'),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (commentThread.isNotEmpty) ...[
          Text(
            'Сообщения (текст и голос)',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          ...commentThread.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CardCommentBubble(message: m),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (rows.isNotEmpty) ...[
          Text(
            'Вложения (общая таблица, MinIO)',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 36,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 140,
              columnSpacing: 12,
              columns: const [
                DataColumn(label: Text('№')),
                DataColumn(label: Text('Тип')),
                DataColumn(label: Text('Содержимое')),
              ],
              rows: rows,
            ),
          ),
        ],
      ],
    );
  }
}

/// Одно сообщение истории карточки (как пузырьки на Angular `map.component.html`).
class _CardCommentBubble extends StatelessWidget {
  final Map<String, dynamic> message;

  const _CardCommentBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final nameRaw = message['user_name']?.toString().trim() ?? '';
    final name = nameRaw.isEmpty ? 'Пользователь' : nameRaw;
    final at = message['at']?.toString();
    final text = (message['text'] as String?)?.trim() ?? '';
    final voiceUrl = (message['voice_url'] as String?)?.trim() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
              Text(
                PoleCardCommentCodec.formatDateTime(at),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(text, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.35)),
          ],
          if (voiceUrl.isNotEmpty) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () => _openVoice(context, voiceUrl),
              icon: const Icon(Icons.mic, size: 18),
              label: const Text('Голосовое сообщение'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openVoice(BuildContext context, String rel) async {
    final abs = resolveAttachmentAbsoluteUrl(rel);
    final uri = Uri.tryParse(abs);
    if (uri == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Некорректная ссылка на аудио')),
        );
      }
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть аудио')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть аудио')),
        );
      }
    }
  }
}

class _AttachmentRow extends StatelessWidget {
  final String type;
  final String relativeUrl;
  final String displayFilename;
  final String? thumbnailUrl;
  final Map<String, String> authHeaders;
  final Dio dio;

  const _AttachmentRow({
    required this.type,
    required this.relativeUrl,
    required this.displayFilename,
    this.thumbnailUrl,
    required this.authHeaders,
    required this.dio,
  });

  String get _loadPath {
    final th = thumbnailUrl?.trim();
    if (th != null && th.isNotEmpty) return th;
    return relativeUrl;
  }

  @override
  Widget build(BuildContext context) {
    final abs = resolveAttachmentAbsoluteUrl(_loadPath);
    switch (type) {
      case 'photo':
      case 'schema':
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            abs,
            height: type == 'schema' ? 120 : 100,
            fit: BoxFit.cover,
            headers: authHeaders.isEmpty ? null : authHeaders,
            errorBuilder: (_, __, ___) => _fallbackChip(context, 'Не удалось загрузить'),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return SizedBox(
                height: 100,
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
          ),
        );
      case 'voice':
      case 'video':
        return OutlinedButton.icon(
          onPressed: authHeaders.isEmpty
              ? null
              : () => _openMediaFile(context, relativeUrl),
          icon: Icon(type == 'voice' ? Icons.mic : Icons.videocam),
          label: Text(type == 'voice' ? 'Воспроизвести запись' : 'Открыть видео'),
        );
      default:
        return Row(
          children: [
            Expanded(
              child: Text(
                displayFilename,
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
    }
  }

  Widget _fallbackChip(BuildContext context, String text) {
    return Chip(
      label: Text(text),
      backgroundColor: Colors.grey.shade200,
    );
  }

  Future<void> _openMediaFile(BuildContext context, String rel) async {
    await _downloadAttachmentFile(
      context: context,
      dio: dio,
      authHeaders: authHeaders,
      relativeUrl: rel,
      suggestedDownloadName: displayFilename,
    );
  }
}
