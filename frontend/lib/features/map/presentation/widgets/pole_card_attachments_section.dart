import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/models/power_line.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/attachment_reader.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/utils/attachment_urls.dart';
import '../../../../core/utils/pole_card_attachment_codec.dart';
import '../../../../core/utils/pole_card_comment_codec.dart';
import '../../../towers/presentation/widgets/pole_attachments_table_sheet.dart';

double? _toDoubleNullable(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse(v.toString());
}

/// Собрать тело обновления опоры из свойств GeoJSON / панели (без загрузки полной карточки).
PoleCreate? _poleCreateFromSelection(
  Map<String, dynamic> p, {
  required String cardCommentJson,
  String? cardCommentAttachment,
}) {
  final lineId = _toInt(p['line_id']);
  final poleId = _toInt(p['id']);
  if (lineId == null || poleId == null || poleId <= 0) return null;

  final poleNumber = (p['pole_number'] ?? p['poleNumber'])?.toString().trim() ?? '';
  if (poleNumber.isEmpty) return null;

  final x = _toDouble(p['x_position'] ?? p['longitude']);
  final y = _toDouble(p['y_position'] ?? p['latitude']);

  final poleTypeRaw = p['pole_type']?.toString().trim() ?? '';
  final poleType = poleTypeRaw.isNotEmpty ? poleTypeRaw : 'unknown';

  final condRaw = p['condition']?.toString().trim() ?? '';
  final condition = condRaw.isNotEmpty ? condRaw : 'good';

  final pn = poleNumber;
  final isTap = p['is_tap_pole'] == true ||
      p['is_tap'] == true ||
      pn.contains('/');

  final btRaw = p['branch_type']?.toString().trim() ?? '';
  final branchType = btRaw.isNotEmpty ? btRaw : 'main';

  return PoleCreate(
    poleNumber: poleNumber,
    xPosition: x,
    yPosition: y,
    poleType: poleType,
    height: _toDoubleNullable(p['height']),
    foundationType: p['foundation_type']?.toString(),
    material: p['material']?.toString(),
    yearInstalled: _toInt(p['year_installed']),
    condition: condition,
    notes: p['notes']?.toString(),
    isTap: isTap,
    conductorType: p['conductor_type']?.toString(),
    conductorMaterial: p['conductor_material']?.toString(),
    conductorSection: p['conductor_section']?.toString(),
    cardComment: cardCommentJson,
    cardCommentAttachment: cardCommentAttachment,
    tapPoleId: _toInt(p['tap_pole_id']),
    branchType: branchType,
    tapBranchIndex: _toInt(p['tap_branch_index']),
    startNewTap: false,
  );
}

String _voiceDurationLabel(dynamic d) {
  if (d == null) return '0:00';
  final sec = d is num ? d.toDouble() : double.tryParse(d.toString());
  if (sec == null || sec <= 0) return '0:00';
  final m = sec ~/ 60;
  final s = (sec % 60).floor();
  return '$m:${s.toString().padLeft(2, '0')}';
}

String _initials(String name) {
  final t = name.trim();
  if (t.isEmpty) return '?';
  final parts = t.split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    final a = parts[0].isNotEmpty ? parts[0][0] : '';
    final b = parts[1].isNotEmpty ? parts[1][0] : '';
    return ('$a$b').toUpperCase();
  }
  return t.length >= 2 ? t.substring(0, 2).toUpperCase() : t.toUpperCase();
}

/// Блок карточки опоры: история комментариев (чат) и ссылка на вложения.
class PoleCardAttachmentsSection extends ConsumerStatefulWidget {
  final Map<String, dynamic> objectProperties;
  final VoidCallback? onAttachmentsChanged;

  const PoleCardAttachmentsSection({
    super.key,
    required this.objectProperties,
    this.onAttachmentsChanged,
  });

  @override
  ConsumerState<PoleCardAttachmentsSection> createState() =>
      _PoleCardAttachmentsSectionState();
}

class _PoleCardAttachmentsSectionState extends ConsumerState<PoleCardAttachmentsSection> {
  final TextEditingController _composer = TextEditingController();
  bool _sending = false;
  final AudioRecorder _voiceRecorder = AudioRecorder();
  final AudioPlayer _voicePlayer = AudioPlayer();
  bool _recordingVoice = false;
  String? _voiceRecordPath;

  @override
  void dispose() {
    _voiceRecorder.dispose();
    _voicePlayer.dispose();
    _composer.dispose();
    super.dispose();
  }

  Future<void> _playVoiceUrl(String relativeUrl) async {
    try {
      final prefs = ref.read(prefsProvider);
      final token = prefs.getString(AppConfig.authTokenKey);
      final uri = Uri.parse(resolveAttachmentAbsoluteUrl(relativeUrl));
      await _voicePlayer.stop();
      await _voicePlayer.setAudioSource(
        AudioSource.uri(
          uri,
          headers: token != null && token.isNotEmpty
              ? {'Authorization': 'Bearer $token'}
              : null,
        ),
      );
      await _voicePlayer.play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Воспроизведение: $e')),
        );
      }
    }
  }

  Future<void> _uploadVoiceBytes(List<int> bytes, String filename) async {
    final p = widget.objectProperties;
    final poleId = _toInt(p['id']);
    final lineId = _toInt(p['line_id']);
    if (poleId == null || lineId == null || poleId <= 0 || bytes.isEmpty) return;

    final rawComment = p['card_comment']?.toString();
    final existing = PoleCardCommentCodec.parse(rawComment);
    final attachRaw = p['card_comment_attachment']?.toString();

    setState(() => _sending = true);
    try {
      final api = ref.read(apiServiceProvider);
      final user = await api.getCurrentUser();
      if (!mounted) return;
      final name =
          user.fullName.trim().isNotEmpty ? user.fullName : user.username;
      final upload = await api.uploadPoleAttachment(poleId, 'file', bytes, filename);
      final rel = upload['url']?.toString();
      if (rel == null || rel.isEmpty) return;

      final appended = PoleCardCommentCodec.appendVoice(
        List<Map<String, dynamic>>.from(existing),
        voiceUrl: rel,
        userId: user.id,
        userName: name,
      );
      final jsonStr = PoleCardCommentCodec.serialize(appended);
      if (jsonStr == null) return;

      final body = _poleCreateFromSelection(
        p,
        cardCommentJson: jsonStr,
        cardCommentAttachment: attachRaw,
      );
      if (body == null) return;

      await api.updatePole(lineId, poleId, body);
      if (!mounted) return;
      widget.onAttachmentsChanged?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Голосовое сообщение: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleVoiceRecording() async {
    if (_recordingVoice) {
      try {
        final path = await _voiceRecorder.stop();
        if (!mounted) return;
        setState(() => _recordingVoice = false);
        if (path != null && path.isNotEmpty) {
          final bytes = await readAttachmentBytes(path);
          if (bytes.isNotEmpty) {
            await _uploadVoiceBytes(bytes, 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a');
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Запись: $e')),
          );
        }
        setState(() => _recordingVoice = false);
      }
      return;
    }
    try {
      final ok = await _voiceRecorder.hasPermission();
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет разрешения на микрофон')),
        );
        return;
      }
      final dir = await getTemporaryDirectory();
      _voiceRecordPath = '${dir.path}/chat_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _voiceRecorder.start(const RecordConfig(), path: _voiceRecordPath!);
      if (mounted) setState(() => _recordingVoice = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Микрофон: $e')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending) return;

    final p = widget.objectProperties;
    final poleId = _toInt(p['id']);
    final lineId = _toInt(p['line_id']);
    if (poleId == null || lineId == null || poleId <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Синхронизируйте опору с сервером, чтобы отправлять сообщения')),
        );
      }
      return;
    }

    final rawComment = p['card_comment']?.toString();
    final existing = PoleCardCommentCodec.parse(rawComment);
    final attachRaw = p['card_comment_attachment']?.toString();

    setState(() => _sending = true);
    try {
      final api = ref.read(apiServiceProvider);
      final user = await api.getCurrentUser();
      if (!mounted) return;
      final name = user.fullName.trim().isNotEmpty ? user.fullName : user.username;
      final appended = PoleCardCommentCodec.append(
        List<Map<String, dynamic>>.from(existing),
        text,
        userId: user.id,
        userName: name,
      );
      final jsonStr = PoleCardCommentCodec.serialize(appended);
      if (jsonStr == null) return;

      final body = _poleCreateFromSelection(
        p,
        cardCommentJson: jsonStr,
        cardCommentAttachment: attachRaw,
      );
      if (body == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не хватает данных опоры для сохранения')),
          );
        }
        return;
      }

      await api.updatePole(lineId, poleId, body);
      if (!mounted) return;
      _composer.clear();
      widget.onAttachmentsChanged?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось отправить: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.objectProperties;
    final rawComment = p['card_comment']?.toString();
    final raw = p['card_comment_attachment']?.toString();
    final messages = PoleCardCommentCodec.parse(rawComment);
    final items = PoleCardAttachmentCodec.parseItemsJson(raw);
    final last = PoleCardAttachmentCodec.parseLastEdit(raw);

    final poleId = _toInt(p['id']);
    final lineId = _toInt(p['line_id']);
    final canUseServerChat = poleId != null && lineId != null && poleId > 0;

    final showCardBlock =
        canUseServerChat || messages.isNotEmpty || items.isNotEmpty;
    if (!showCardBlock) {
      return const SizedBox.shrink();
    }

    final auth = ref.watch(authStateProvider);
    final myUserId = auth is AuthStateAuthenticated ? auth.user.id : null;

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canUseServerChat || messages.isNotEmpty) ...[
          Text(
            'Комментарий и медиа карточки',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 260),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: messages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Пока нет сообщений',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          itemCount: messages.length,
                          itemBuilder: (context, i) {
                            final m = messages[i];
                            final whoRaw = (m['user_name'] as String?)?.trim();
                            final who = whoRaw != null && whoRaw.isNotEmpty
                                ? whoRaw
                                : (m['user_id'] != null ? 'id ${m['user_id']}' : '—');
                            final when = PoleCardCommentCodec.formatDateTime(m['at'] as String?);
                            final uid = _toInt(m['user_id']);
                            final isMine = myUserId != null && uid != null && uid == myUserId;
                            final bubbleColor =
                                isMine ? cs.primaryContainer.withValues(alpha: 0.85) : Colors.white;
                            final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
                                children: [
                                  if (!isMine) ...[
                                    CircleAvatar(
                                      radius: 17,
                                      backgroundColor: cs.primary.withValues(alpha: 0.2),
                                      child: Text(
                                        _initials(who),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: cs.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: align,
                                      children: [
                                        Container(
                                          constraints: const BoxConstraints(maxWidth: 320),
                                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                          decoration: BoxDecoration(
                                            color: bubbleColor,
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(14),
                                              topRight: const Radius.circular(14),
                                              bottomLeft: Radius.circular(isMine ? 14 : 4),
                                              bottomRight: Radius.circular(isMine ? 4 : 14),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.06),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      who,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 12,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    when,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey.shade700,
                                                      fontFeatures: const [
                                                        FontFeature.tabularFigures(),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              if ((m['voice_url'] as String?)
                                                      ?.trim()
                                                      .isNotEmpty ==
                                                  true) ...[
                                                Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    onTap: () => _playVoiceUrl(
                                                      (m['voice_url'] as String).trim(),
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                        vertical: 4,
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons.play_circle_filled,
                                                            size: 34,
                                                            color: cs.primary,
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Text(
                                                            _voiceDurationLabel(
                                                              m['duration_sec'],
                                                            ),
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight.w500,
                                                              color: Colors
                                                                  .grey.shade800,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            'Голосовое',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors
                                                                  .grey.shade600,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                if ('${m['text'] ?? ''}'
                                                    .trim()
                                                    .isNotEmpty)
                                                  const SizedBox(height: 8),
                                              ],
                                              if ('${m['text'] ?? ''}'
                                                  .trim()
                                                  .isNotEmpty)
                                                SelectableText(
                                                  '${m['text']}',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    height: 1.4,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isMine) ...[
                                    const SizedBox(width: 8),
                                    CircleAvatar(
                                      radius: 17,
                                      backgroundColor: cs.primary.withValues(alpha: 0.2),
                                      child: Text(
                                        _initials(who),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: cs.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
                if (canUseServerChat)
                  Material(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(13),
                      bottomRight: Radius.circular(13),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 6, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _composer,
                              minLines: 1,
                              maxLines: 4,
                              textInputAction: TextInputAction.newline,
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'Сообщение…',
                                filled: true,
                                fillColor: const Color(0xFFF8F9FA),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: _sending ? null : _toggleVoiceRecording,
                            icon: Icon(
                              _recordingVoice
                                  ? Icons.stop_circle
                                  : Icons.mic_none_rounded,
                              color: _recordingVoice ? Colors.red : null,
                            ),
                            tooltip: _recordingVoice
                                ? 'Остановить и отправить голосовое'
                                : 'Голосовое сообщение',
                          ),
                          IconButton.filled(
                            onPressed: _sending ? null : _sendMessage,
                            icon: _sending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.send_rounded, size: 20),
                            tooltip: 'Отправить',
                          ),
                        ],
                      ),
                    ),
                  )
                else if (messages.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Text(
                      'Сообщения доступны только для просмотра до синхронизации опоры с сервером.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                  ),
              ],
            ),
          ),
          if (last != null) ...[
            const SizedBox(height: 6),
            Text(
              _lastEditLine(last),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 12),
        ],
        if (items.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                await showPoleAttachmentsTable(
                  context,
                  ref,
                  raw,
                  poleId: poleId,
                  lineId: lineId,
                  onRemoteUpdated: widget.onAttachmentsChanged != null
                      ? () async {
                          widget.onAttachmentsChanged!();
                        }
                      : null,
                );
              },
              icon: const Icon(Icons.folder_open, size: 20),
              label: Text('Вложения (${items.length})'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Откроется список файлов: имя, тип, дата, автор. Двойной клик — скачать.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }

  String _lastEditLine(Map<String, dynamic> last) {
    final kind = last['kind']?.toString() ?? '';
    final at = last['at']?.toString() ?? '';
    final uid = last['user_id'];
    final un = last['user_name']?.toString();
    final who = un ?? (uid != null ? 'id $uid' : '—');
    return 'Медиа карточки: последнее изменение $kind • $who • $at';
  }
}
