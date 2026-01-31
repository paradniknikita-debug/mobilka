import 'package:flutter/material.dart';

enum ObjectType { pole, substation, tap }

class ObjectPropertiesPanel extends StatelessWidget {
  final Map<String, dynamic> objectProperties;
  final ObjectType objectType;
  final VoidCallback onClose;
  final VoidCallback? onStartLineFormation;
  final VoidCallback? onDelete;

  const ObjectPropertiesPanel({
    super.key,
    required this.objectProperties,
    required this.objectType,
    required this.onClose,
    this.onStartLineFormation,
    this.onDelete,
  });

  String get _title {
    switch (objectType) {
      case ObjectType.pole:
        return 'Опора ${objectProperties['pole_number']?.toString() ?? 'N/A'}';
      case ObjectType.substation:
        return 'Подстанция ${objectProperties['name']?.toString() ?? 'N/A'}';
      case ObjectType.tap:
        return 'Отпайка ${objectProperties['tap_number']?.toString() ?? 'N/A'}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final powerLineId = objectProperties['power_line_id'] as int?;

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
                  if (onStartLineFormation != null && powerLineId != null) ...[
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
                  if (onDelete != null) ...[
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
              child: SizedBox(
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
    }
  }

  List<Widget> _buildPoleProperties(BuildContext context) {
    final connectivityNodeId = objectProperties['connectivity_node_id'];
    final hasConnectivityNode = connectivityNodeId != null;

    final properties = <Widget>[
      _buildPropertyItem(
        context,
        'Название:',
        objectProperties['pole_number']?.toString() ?? 'N/A',
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
        'Координаты (ш,д):',
        '${(objectProperties['latitude'] as num?)?.toStringAsFixed(6) ?? 'N/A'}, '
        '${(objectProperties['longitude'] as num?)?.toStringAsFixed(6) ?? 'N/A'}',
      ),
      if (objectProperties['sequence_number'] != null)
        _buildPropertyItem(
          context,
          'Порядок в линии:',
          objectProperties['sequence_number'].toString(),
        ),
      _buildPropertyItem(
        context,
        'Узел соединения:',
        '',
        isLast: true,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: hasConnectivityNode
                ? Colors.green.shade50
                : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            hasConnectivityNode ? 'Есть' : 'Нет',
            style: TextStyle(
              color: hasConnectivityNode
                  ? Colors.green.shade700
                  : Colors.orange.shade700,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ),
    ];
    
    return properties;
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
        'Координаты (ш,д):',
        '${(objectProperties['latitude'] as num?)?.toStringAsFixed(6) ?? 'N/A'}, '
        '${(objectProperties['longitude'] as num?)?.toStringAsFixed(6) ?? 'N/A'}',
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
        'Координаты (ш,д):',
        '${(objectProperties['latitude'] as num?)?.toStringAsFixed(6) ?? 'N/A'}, '
        '${(objectProperties['longitude'] as num?)?.toStringAsFixed(6) ?? 'N/A'}',
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

