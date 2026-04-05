import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../../core/config/pole_reference_data.dart';
import '../../../../core/theme/app_theme.dart';

/// Один элемент вложения (голос или фото). В JSON: {"t":"voice"|"photo","p":"path"}
String? encodeDefectAttachmentList(List<Map<String, String>> list) {
  if (list.isEmpty) return null;
  return jsonEncode(list);
}

List<Map<String, String>> decodeDefectAttachmentList(String? json) {
  if (json == null || json.isEmpty) return [];
  try {
    final list = jsonDecode(json) as List<dynamic>?;
    if (list == null) return [];
    return list.map((e) => Map<String, String>.from(e as Map)).toList();
  } catch (_) {
    return [];
  }
}

/// Данные добавленного оборудования (для сохранения в карточке опоры).
class EquipmentFormData {
  const EquipmentFormData({
    required this.equipmentType,
    required this.name,
    required this.quantity,
    this.defect,
    this.criticality,
    this.categoryTitle,
    this.defectAttachment,
  });
  final String equipmentType;
  final String name;
  final int quantity;
  final String? defect;
  final String? criticality;
  /// Название категории для отображения в списке дефектов (Фундамент, Изоляторы и т.д.)
  final String? categoryTitle;
  /// Вложения к описанию иного дефекта: JSON [{"t":"voice"|"photo","p":"path"}]
  final String? defectAttachment;
}

/// Диалог добавления оборудования по макету: марка, количество, дефект, критичность.
/// Для категорий вроде «Фундамент» количество фиксировано 1.
class AddEquipmentDialog extends StatefulWidget {
  const AddEquipmentDialog({
    super.key,
    required this.categoryTitle,
    required this.equipmentType,
    this.lineVoltageKv,
    this.singleInstance = false,
    this.initialBrand,
  this.initialQuantity = 1,
  this.initialDefect,
  this.initialCriticality,
  this.initialDefectAttachment,
  });

  final String categoryTitle;
  final String equipmentType;
  final double? lineVoltageKv;
  final bool singleInstance;
  final String? initialBrand;
  final int initialQuantity;
  final String? initialDefect;
  final String? initialCriticality;
  final String? initialDefectAttachment;

  @override
  State<AddEquipmentDialog> createState() => _AddEquipmentDialogState();
}

class _AddEquipmentDialogState extends State<AddEquipmentDialog> {
  final _brandController = TextEditingController();
  final _otherDefectController = TextEditingController();
  late int _quantity;
  String? _selectedDefect;
  String? _selectedCriticality;
  bool _isOtherDefect = false;
  final List<Map<String, String>> _defectAttachments = [];
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _brandController.text = widget.initialBrand ?? '';
    _quantity = widget.initialQuantity.clamp(1, 999);
    _selectedDefect = widget.initialDefect;
    _selectedCriticality = widget.initialCriticality;
    if (_selectedDefect == DefectReferenceData.otherDefectKey ||
        (_selectedDefect != null && _selectedDefect!.isNotEmpty && !DefectReferenceData.defectItemsForCategory(widget.categoryTitle).any((e) => e.name == _selectedDefect))) {
      _isOtherDefect = true;
      _otherDefectController.text = _selectedDefect == DefectReferenceData.otherDefectKey ? '' : (_selectedDefect ?? '');
    }
    if (_selectedDefect != null && _selectedDefect!.isNotEmpty) {
      final list = DefectReferenceData.defectItemsForCategory(widget.categoryTitle).where((e) => e.name == _selectedDefect).toList();
      if (list.isNotEmpty) _selectedCriticality = list.first.criticality;
    }
    final decoded = decodeDefectAttachmentList(widget.initialDefectAttachment);
    _defectAttachments.addAll(decoded);
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _brandController.dispose();
    _otherDefectController.dispose();
    super.dispose();
  }

  List<EquipmentBrandSpec> get _brandSuggestionSpecs =>
      EquipmentReferenceData.getBrandSpecsForCategoryAndVoltage(
        widget.categoryTitle,
        widget.lineVoltageKv,
      );

  bool get _strictVoltageValidation =>
      widget.lineVoltageKv != null &&
      EquipmentReferenceData.hasVoltageSpecificBrands(widget.categoryTitle);

  String _formatBrandSpec(EquipmentBrandSpec spec) {
    final parts = <String>[];
    final kv = spec.nominalVoltageKv;
    if (kv != null) {
      final kvLabel = kv % 1 == 0 ? kv.toStringAsFixed(0) : kv.toStringAsFixed(1);
      parts.add('$kvLabel кВ');
    }
    if (spec.nominalCurrentA != null) {
      parts.add('${spec.nominalCurrentA} А');
    }
    if (parts.isEmpty) return spec.brand;
    return '${spec.brand} (${parts.join(', ')})';
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null || !mounted) return;
      setState(() => _defectAttachments.add({'t': 'photo', 'p': file.path}));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _recordVoice() async {
    if (_isRecording) {
      try {
        final path = await _audioRecorder.stop();
        if (path != null && path.isNotEmpty && mounted) {
          setState(() {
            _defectAttachments.add({'t': 'voice', 'p': path});
            _isRecording = false;
          });
        }
      } catch (_) {}
      return;
    }
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Нет разрешения на запись с микрофона'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(), path: path);
      if (mounted) setState(() { _isRecording = true; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка записи: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String get _previewText {
    final brand = _brandController.text.trim().isEmpty ? '(не указано)' : _brandController.text.trim();
    return '${widget.categoryTitle}: $brand x $_quantity шт.';
  }

  void _save() {
    final brand = _brandController.text.trim();
    if (brand.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Укажите марку оборудования'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_strictVoltageValidation &&
        !EquipmentReferenceData.isBrandAllowedForCategoryAndVoltage(
          widget.categoryTitle,
          widget.lineVoltageKv,
          brand,
        )) {
      final kv = widget.lineVoltageKv!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Марка "$brand" не подходит для линии ${kv.toStringAsFixed(kv % 1 == 0 ? 0 : 1)} кВ',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    String? defect;
    String? criticality = _selectedCriticality;
    if (_isOtherDefect) {
      defect = _otherDefectController.text.trim().isEmpty ? 'Иной дефект' : _otherDefectController.text.trim();
      criticality = _selectedCriticality ?? 'low';
    } else if (_selectedDefect != null && _selectedDefect!.isNotEmpty) {
      defect = _selectedDefect;
      if (criticality == null) {
        final list = DefectReferenceData.defectItemsForCategory(widget.categoryTitle).where((e) => e.name == _selectedDefect).toList();
        if (list.isNotEmpty) criticality = list.first.criticality;
      }
    }
    Navigator.of(context).pop(EquipmentFormData(
      equipmentType: widget.equipmentType,
      name: brand,
      quantity: _quantity,
      defect: defect?.isEmpty == true ? null : defect,
      criticality: criticality,
      categoryTitle: widget.categoryTitle,
      defectAttachment: encodeDefectAttachmentList(_defectAttachments),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: PatrolColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.inventory_2_outlined, color: PatrolColors.statusSynced, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.categoryTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: PatrolColors.textPrimary,
                          ),
                        ),
                        Text(
                          'ПАРАМЕТРЫ ОБОРУДОВАНИЯ',
                          style: TextStyle(
                            fontSize: 11,
                            color: PatrolColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: PatrolColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _brandController,
                decoration: InputDecoration(
                  labelText: 'Марка оборудования *',
                  hintText: 'Введите марку',
                  helperText: _strictVoltageValidation
                      ? 'Доступны только марки для ${widget.lineVoltageKv?.toStringAsFixed((widget.lineVoltageKv ?? 0) % 1 == 0 ? 0 : 1)} кВ'
                      : 'Выберите из справочника или введите вручную',
                  helperStyle: TextStyle(fontSize: 11, color: PatrolColors.textSecondary),
                  filled: true,
                  fillColor: PatrolColors.surfaceCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                style: const TextStyle(color: PatrolColors.textPrimary),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _brandSuggestionSpecs.map((s) {
                  final selected = _brandController.text.trim() == s.brand;
                  return FilterChip(
                    label: Text(_formatBrandSpec(s)),
                    selected: selected,
                    onSelected: (v) {
                      setState(() => _brandController.text = v ? s.brand : '');
                    },
                    selectedColor: PatrolColors.accentBlue.withOpacity(0.3),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Количество *', style: TextStyle(fontSize: 12, color: PatrolColors.textSecondary)),
                  const Spacer(),
                  if (widget.singleInstance)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: PatrolColors.surfaceCard,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('1', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                        ),
                        SizedBox(
                          width: 48,
                          child: Text(
                            '$_quantity',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => setState(() => _quantity++),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Укажите количество единиц оборудования',
                style: TextStyle(fontSize: 11, color: PatrolColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Text('Дефект', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: PatrolColors.textSecondary)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                isExpanded: true,
                value: _isOtherDefect ? DefectReferenceData.otherDefectKey : _selectedDefect,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: PatrolColors.surfaceCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                hint: const Text('Выберите дефект или «Иной дефект»'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Нет дефекта', overflow: TextOverflow.ellipsis)),
                  ...DefectReferenceData.defectItemsForCategory(widget.categoryTitle).map((e) => DropdownMenuItem<String?>(
                    value: e.name,
                    child: Text(
                      '${e.name} (${DefectReferenceData.criticalityLabels[e.criticality] ?? e.criticality})',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  )),
                  const DropdownMenuItem<String?>(
                    value: DefectReferenceData.otherDefectKey,
                    child: Text('Иной дефект', overflow: TextOverflow.ellipsis),
                  ),
                ],
                onChanged: (v) {
                  setState(() {
                    _isOtherDefect = v == DefectReferenceData.otherDefectKey;
                    _selectedDefect = v?.isEmpty == true ? null : v;
                    if (!_isOtherDefect && v != null && v.isNotEmpty) {
                      final list = DefectReferenceData.defectItemsForCategory(widget.categoryTitle).where((e) => e.name == v).toList();
                      if (list.isNotEmpty) _selectedCriticality = list.first.criticality;
                    }
                  });
                },
              ),
              if (_isOtherDefect) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _otherDefectController,
                  decoration: InputDecoration(
                    labelText: 'Описание дефекта',
                    hintText: 'Опишите дефект',
                    filled: true,
                    fillColor: PatrolColors.surfaceCard,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  style: const TextStyle(color: PatrolColors.textPrimary),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Text(
                  'Голосовое сообщение или фото',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: PatrolColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_library, size: 20),
                      label: const Text('Фото'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PatrolColors.textPrimary,
                      ),
                    ),
                    if (!kIsWeb) ...[
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _recordVoice,
                        icon: Icon(_isRecording ? Icons.stop : Icons.mic, size: 20),
                        label: Text(_isRecording ? 'Стоп' : 'Голос'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _isRecording ? Colors.red : PatrolColors.textPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
                if (_defectAttachments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _defectAttachments.asMap().entries.map((e) {
                      final isVoice = e.value['t'] == 'voice';
                      return Chip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(isVoice ? Icons.mic : Icons.photo, size: 16, color: PatrolColors.textPrimary),
                            const SizedBox(width: 4),
                            Text(isVoice ? 'Голос' : 'Фото', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () => setState(() => _defectAttachments.removeAt(e.key)),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 12),
                Text('Критичность', style: TextStyle(fontSize: 12, color: PatrolColors.textSecondary)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: _selectedCriticality,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: PatrolColors.surfaceCard,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: DefectReferenceData.criticalityLevels.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(DefectReferenceData.criticalityLabels[c] ?? c),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedCriticality = v),
                ),
              ] else if (_selectedDefect != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Критичность: ${DefectReferenceData.criticalityLabels[_selectedCriticality] ?? _selectedCriticality ?? "—"}',
                    style: TextStyle(fontSize: 12, color: PatrolColors.textSecondary),
                  ),
                ),
              const SizedBox(height: 20),
              Text('ПРЕДПРОСМОТР', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PatrolColors.textSecondary)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PatrolColors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_previewText, style: const TextStyle(color: PatrolColors.textPrimary)),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PatrolColors.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('ОТМЕНА'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PatrolColors.statusSynced,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.save, size: 20),
                      label: const Text('СОХРАНИТЬ'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
