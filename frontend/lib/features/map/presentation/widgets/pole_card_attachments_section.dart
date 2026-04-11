import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/utils/attachment_urls.dart';
import '../../../../core/utils/pole_card_comment_codec.dart';
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

/// Блок «Комментарий карточки» и превью вложений (с Bearer для API).
class PoleCardAttachmentsSection extends ConsumerWidget {
  final Map<String, dynamic> objectProperties;

  const PoleCardAttachmentsSection({
    super.key,
    required this.objectProperties,
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

    List<Map<String, dynamic>>? items;
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          items = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      } catch (_) {
        items = null;
      }
    }

    if (commentThread.isEmpty && (items == null || items.isEmpty)) {
      return const SizedBox.shrink();
    }

    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final rows = <DataRow>[];
    if (items != null) {
      for (var i = 0; i < items.length; i++) {
        final m = items[i];
        final t = m['t']?.toString() ?? '';
        final url = m['url']?.toString();
        if (url == null || url.isEmpty) continue;
        final thumb = m['thumbnail_url']?.toString();
        rows.add(
          DataRow(
            cells: [
              DataCell(Text('${i + 1}', style: const TextStyle(fontSize: 13))),
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
                    constraints: const BoxConstraints(minWidth: 140, maxWidth: 280),
                    child: _AttachmentRow(
                      type: t,
                      relativeUrl: url,
                      thumbnailUrl: thumb,
                      authHeaders: headers,
                      dio: dio,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }
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
  final String? thumbnailUrl;
  final Map<String, String> authHeaders;
  final Dio dio;

  const _AttachmentRow({
    required this.type,
    required this.relativeUrl,
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
        return _fallbackChip(context, type.isEmpty ? 'Вложение' : type);
    }
  }

  Widget _fallbackChip(BuildContext context, String text) {
    return Chip(
      label: Text(text),
      backgroundColor: Colors.grey.shade200,
    );
  }

  Future<void> _openMediaFile(BuildContext context, String rel) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Скачивание медиа в браузере пока не поддерживается')),
      );
      return;
    }
    try {
      // Относительный путь API: baseUrl уже содержит /api/v1
      var apiPath = rel.trim();
      if (apiPath.startsWith('/api/${AppConfig.apiVersion}/')) {
        apiPath = apiPath.substring('/api/${AppConfig.apiVersion}'.length);
      } else if (apiPath.startsWith('api/${AppConfig.apiVersion}/')) {
        apiPath = '/${apiPath.substring('api/${AppConfig.apiVersion}'.length)}';
      }
      if (!apiPath.startsWith('/')) apiPath = '/$apiPath';

      final resp = await dio.get<List<int>>(
        apiPath,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = resp.data;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Пустой ответ');
      }
      final parts = rel.split('/');
      final name = parts.isNotEmpty ? parts.last : 'attachment.bin';
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/$name';
      final f = File(path);
      await f.writeAsBytes(bytes, flush: true);
      await OpenFile.open(path);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось открыть файл: $e')),
        );
      }
    }
  }
}
