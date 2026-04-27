import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pole_card_attachments_section.dart';

enum ObjectType { pole, substation, tap, equipment }

class ObjectPropertiesPanel extends ConsumerWidget {
  final Map<String, dynamic> objectProperties;
  final ObjectType objectType;
  final VoidCallback onClose;
  final VoidCallback? onStartLineFormation;
  final VoidCallback? onAutoCreateSpans;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onShowHistory;
  /// Открыть диалог «Начать отпайку» — только у опоры с флагом «Точка отпайки» в карточке.
  final VoidCallback? onStartTapPole;
  /// Открыть диалог добавления следующей опоры в отпайку (опора уже в отпайке: 3/1, 3/2 и т.д.).
  final VoidCallback? onAddPoleToTap;

  const ObjectPropertiesPanel({
    super.key,
    required this.objectProperties,
    required this.objectType,
    required this.onClose,
    this.onStartLineFormation,
    this.onAutoCreateSpans,
    this.onEdit,
    this.onDelete,
    this.onShowHistory,
    this.onStartTapPole,
    this.onAddPoleToTap,
  });

  /// Безопасное форматирование числа для отображения координат.
  static String _formatCoord(dynamic v) {
    if (v == null) return 'N/A';
    if (v is num) return v.toStringAsFixed(6);
    if (v is String) {
      final n = num.tryParse(v);
      return n != null ? n.toStringAsFixed(6) : v;
    }
    return v.toString();
  }

  /// Как на Angular (`map.component.html`): подпись и порядок **широта, долгота**
  /// (в БД/CIM: `y_position` = широта, `x_position` = долгота).
  static const String _coordsLabel = 'Координаты (x, y / ш, д):';

  static String _coordsLatLonValue(Map<String, dynamic> props) {
    final lat = props['y_position'] ?? props['latitude'];
    final lon = props['x_position'] ?? props['longitude'];
    return '${_formatCoord(lat)}, ${_formatCoord(lon)}';
  }

  /// «Начать отпайку» только если в карточке опоры включено «Точка отпайки» ([is_tap_pole]).
  static bool _canStartTapBranch(Map<String, dynamic> props) {
    if (props['id'] == null) return false;
    return props['is_tap_pole'] == true;
  }

  /// Опора уже в отпайке (номер N/M, N/M/…).
  static bool _isPoleInTapBranch(Map<String, dynamic> props) {
    final n = props['pole_number'] ?? props['poleNumber'];
    return n is String && n.contains('/');
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static String _normalizePoleTitle(dynamic value) {
    final raw = (value?.toString() ?? '').trim();
    if (raw.isEmpty) return 'N/A';
    const prefix = 'Опора ';
    if (raw.toLowerCase().startsWith(prefix.toLowerCase())) {
      final cut = raw.substring(prefix.length).trim();
      return cut.isEmpty ? 'N/A' : cut;
    }
    return raw;
  }

  String get _title {
    switch (objectType) {
      case ObjectType.pole:
        return 'Опора ${_normalizePoleTitle(objectProperties['pole_number'] ?? objectProperties['poleNumber'])}';
      case ObjectType.substation:
        return 'Подстанция ${objectProperties['name']?.toString() ?? 'N/A'}';
      case ObjectType.tap:
        return 'Отпайка ${objectProperties['tap_number']?.toString() ?? 'N/A'}';
      case ObjectType.equipment:
        return 'Оборудование ${objectProperties['name']?.toString() ?? 'N/A'}';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final lineId = _toInt(objectProperties['line_id']);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Заголовок
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.12),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  iconSize: 20,
                  onPressed: onClose,
                ),
              ],
            ),
          ),

          // Содержимое
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildProperties(context),
              ),
            ),
          ),

          // Действия (только для опор)
          if (objectType == ObjectType.pole)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.12),
                  ),
                ),
              ),
              child: Column(
                children: [
                  if (onEdit != null && lineId != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit),
                        label: const Text('Редактировать'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (onStartLineFormation != null && lineId != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onStartLineFormation,
                        icon: const Icon(Icons.navigation),
                        label: const Text('Начать формирование линии'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (onStartTapPole != null &&
                      lineId != null &&
                      objectProperties['id'] != null &&
                      _canStartTapBranch(objectProperties)) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onStartTapPole,
                        icon: const Icon(Icons.call_split),
                        label: const Text('Начать отпайку'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (onAddPoleToTap != null &&
                      lineId != null &&
                      objectProperties['id'] != null &&
                      _isPoleInTapBranch(objectProperties)) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onAddPoleToTap,
                        icon: const Icon(Icons.add_road),
                        label: const Text('Добавить опору в отпайку'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (onAutoCreateSpans != null && lineId != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onAutoCreateSpans,
                        icon: const Icon(Icons.auto_fix_high),
                        label: const Text('Создать пролёты автоматически'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (onDelete != null) ...[
                    if (onShowHistory != null) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: onShowHistory,
                          icon: const Icon(Icons.history),
                          label: const Text('История объекта'),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete),
                        label: const Text('Удалить'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          // Кнопка удаления для всех типов объектов (внизу панели)
          if (onDelete != null && objectType != ObjectType.pole)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.12),
                  ),
                ),
              ),
              child: Column(
                children: [
                  if (onEdit != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit),
                        label: const Text('Редактировать'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (onShowHistory != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onShowHistory,
                        icon: const Icon(Icons.history),
                        label: const Text('История объекта'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete),
                      label: const Text('Удалить'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildProperties(BuildContext context) {
    switch (objectType) {
      case ObjectType.pole:
        return _buildPoleProperties(context);
      case ObjectType.substation:
        return _buildSubstationProperties(context);
      case ObjectType.tap:
        return _buildTapProperties(context);
      case ObjectType.equipment:
        return _buildEquipmentProperties(context);
    }
  }

  List<Widget> _buildPoleProperties(BuildContext context) {
    final seq = objectProperties['sequence_number'];
    return [
      _buildPropertyItem(
        context,
        'Название:',
        objectProperties['pole_number']?.toString() ?? objectProperties['poleNumber']?.toString() ?? 'N/A',
      ),
      _buildPropertyItem(
        context,
        'UID (MRID):',
        objectProperties['mrid']?.toString() ?? 'N/A',
      ),
      _buildPropertyItem(
        context,
        'Участок линии:',
        objectProperties['segment_name']?.toString() ??
            objectProperties['power_line_name']?.toString() ??
            'N/A',
      ),
      _buildPropertyItem(
        context,
        _coordsLabel,
        _coordsLatLonValue(objectProperties),
        isLast: seq == null,
      ),
      if (seq != null)
        _buildPropertyItem(
          context,
          'Порядок в линии:',
          seq.toString(),
          isLast: true,
        ),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: PoleCardAttachmentsSection(objectProperties: objectProperties),
      ),
    ];
  }

  List<Widget> _buildSubstationProperties(BuildContext context) {
    return [
      _buildPropertyItem(
        context,
        'Диспетчерское наименование:',
        objectProperties['dispatcher_name']?.toString() ?? 'N/A',
      ),
      _buildPropertyItem(
        context,
        'Напряжение:',
        '${objectProperties['voltage_level']?.toString() ?? 'N/A'} кВ',
      ),
      _buildPropertyItem(
        context,
        'Адрес:',
        objectProperties['address']?.toString() ?? 'N/A',
      ),
      _buildPropertyItem(
        context,
        _coordsLabel,
        _coordsLatLonValue(objectProperties),
      ),
    ];
  }

  List<Widget> _buildTapProperties(BuildContext context) {
    return [
      _buildPropertyItem(
        context,
        'Тип:',
        objectProperties['tap_type']?.toString() ?? 'N/A',
      ),
      _buildPropertyItem(
        context,
        'Напряжение:',
        '${objectProperties['voltage_level']?.toString() ?? 'N/A'} кВ',
      ),
      if (objectProperties['power_rating'] != null)
        _buildPropertyItem(
          context,
          'Мощность:',
          '${objectProperties['power_rating']} кВт',
        ),
      _buildPropertyItem(
        context,
        _coordsLabel,
        _coordsLatLonValue(objectProperties),
      ),
    ];
  }

  List<Widget> _buildEquipmentProperties(BuildContext context) {
    final uid = objectProperties['mrid']?.toString();
    final fallbackUid = objectProperties['equipment_id']?.toString() ??
        objectProperties['id']?.toString() ??
        'N/A';
    return [
      _buildPropertyItem(
        context,
        'UID (MRID):',
        (uid != null && uid.trim().isNotEmpty) ? uid : fallbackUid,
      ),
      _buildPropertyItem(
        context,
        'Тип:',
        objectProperties['equipment_type']?.toString() ?? 'N/A',
      ),
      _buildPropertyItem(
        context,
        'Опора ID:',
        objectProperties['pole_id']?.toString() ?? 'N/A',
      ),
      _buildPropertyItem(
        context,
        _coordsLabel,
        _coordsLatLonValue(objectProperties),
      ),
      _buildPropertyItem(
        context,
        'Состояние:',
        objectProperties['condition']?.toString() ?? 'N/A',
      ),
      _buildPropertyItem(
        context,
        'Примечания:',
        objectProperties['notes']?.toString() ?? 'N/A',
      ),
    ];
  }

  Widget _buildPropertyItem(
    BuildContext context,
    String label,
    String value, {
    Widget? child,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.only(bottom: 12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: isLast ? null : BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: child ??
                Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.black87,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

