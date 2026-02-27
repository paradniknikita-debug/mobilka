import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/services/api_service.dart';
import '../../../../core/database/database.dart';
import '../../../../core/models/power_line.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/config/pole_reference_data.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/auth_service.dart';
import 'add_equipment_dialog.dart';

/// Категории оборудования на опоре (по макету карточки опоры).
class _EquipmentCategory {
  const _EquipmentCategory(this.title, this.icon);
  final String title;
  final IconData icon;
}

const List<_EquipmentCategory> _equipmentCategories = [
  _EquipmentCategory('Фундамент', Icons.anchor),
  _EquipmentCategory('Изоляторы', Icons.bolt),
  _EquipmentCategory('Траверсы', Icons.settings),
  _EquipmentCategory('Грозоотвод', Icons.flash_on),
  _EquipmentCategory('Разрядники', Icons.shield_outlined),
  _EquipmentCategory('Разъединители', Icons.power),
  _EquipmentCategory('Выключатели', Icons.toggle_on),
  _EquipmentCategory('Реклоузеры', Icons.settings_input_component),
  _EquipmentCategory('ЗН', Icons.electrical_services),
];

class CreatePoleDialog extends ConsumerStatefulWidget {
  final int powerLineId;
  final double? initialLatitude;
  final double? initialLongitude;
  final int? poleSequenceNumber;
  /// Автоподстановка номера опоры, например ОП-001, ОП-002
  final String? initialPoleNumber;
  /// Количество уже существующих опор на линии (0 = первая опора; при 0 автозаполнение отключено).
  final int existingPolesCount;

  const CreatePoleDialog({
    super.key,
    required this.powerLineId,
    this.initialLatitude,
    this.initialLongitude,
    this.poleSequenceNumber,
    this.initialPoleNumber,
    this.existingPolesCount = 0,
  });

  @override
  ConsumerState<CreatePoleDialog> createState() => _CreatePoleDialogState();
}

class _CreatePoleDialogState extends ConsumerState<CreatePoleDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isGettingLocation = false;
  bool _autofill = false;

  String _poleNumber = '';
  String _poleType = PoleReferenceData.defaultPoleType;
  double? _latitude;
  double? _longitude;
  double? _height;
  String? _foundationType;
  String? _material;
  int? _yearInstalled;
  String _condition = PoleReferenceData.defaultCondition;
  String? _notes;
  String? _conductorType = PoleReferenceData.defaultConductorType;
  String? _conductorMaterial = PoleReferenceData.defaultConductorMaterial;
  String? _conductorSection = PoleReferenceData.defaultConductorSection;
  bool _isTap = false;

  final _cardCommentController = TextEditingController();
  final List<Map<String, String>> _cardCommentAttachments = [];
  final AudioRecorder _cardCommentRecorder = AudioRecorder();
  bool _cardCommentRecording = false;

  /// Количество «установленного» оборудования по категориям (для отображения 0 из N).
  final List<bool> _equipmentInstalled = List.filled(_equipmentCategories.length, false);
  /// Оборудование, добавленное через форму (до сохранения опоры).
  final List<EquipmentFormData> _pendingEquipment = [];

  static const Set<String> _autofillCategories = {
    'Фундамент',
    'Изоляторы',
    'Траверсы',
    'Грозоотвод',
  };

  /// Возвращает true, если был загружен и применён хотя бы один элемент шаблона.
  bool _loadAutofillTemplate() {
    if (widget.existingPolesCount == 0) return false;
    final prefs = ref.read(prefsProvider);
    final jsonStr = prefs.getString(AppConfig.autofillEquipmentTemplateKey);
    if (jsonStr == null || jsonStr.isEmpty) return false;
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>?;
      if (list == null || list.isEmpty) return false;
      if (!mounted) return false;
      var added = 0;
      setState(() {
        for (final e in list) {
          final map = e as Map<String, dynamic>;
          final eq = EquipmentFormData(
            equipmentType: map['equipmentType'] as String? ?? '',
            name: map['name'] as String? ?? '',
            quantity: (map['quantity'] as num?)?.toInt() ?? 1,
            defect: null,
            criticality: null,
            categoryTitle: map['categoryTitle'] as String?,
          );
          if (eq.name.isEmpty) continue;
          _pendingEquipment.add(eq);
          added++;
          final catTitle = eq.categoryTitle;
          if (catTitle != null) {
            final idx = _equipmentCategories.indexWhere((c) => c.title == catTitle);
            if (idx >= 0) _equipmentInstalled[idx] = true;
          }
        }
      });
      return added > 0;
    } catch (_) {
      return false;
    }
  }

  void _saveAutofillTemplate() {
    final prefs = ref.read(prefsProvider);
    final toSave = _pendingEquipment
        .where((e) => e.categoryTitle != null && _autofillCategories.contains(e.categoryTitle))
        .map((e) => {
              'equipmentType': e.equipmentType,
              'name': e.name,
              'quantity': e.quantity,
              'defect': e.defect,
              'criticality': e.criticality,
              'categoryTitle': e.categoryTitle,
            })
        .toList();
    prefs.setString(AppConfig.autofillEquipmentTemplateKey, jsonEncode(toSave));
  }

  Future<void> _pickCommentImage() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null || !mounted) return;
      setState(() => _cardCommentAttachments.add({'t': 'photo', 'p': file.path}));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _recordCommentVoice() async {
    if (_cardCommentRecording) {
      try {
        final path = await _cardCommentRecorder.stop();
        if (path != null && path.isNotEmpty && mounted) {
          setState(() {
            _cardCommentAttachments.add({'t': 'voice', 'p': path});
            _cardCommentRecording = false;
          });
        }
      } catch (_) {}
      return;
    }
    try {
      final hasPermission = await _cardCommentRecorder.hasPermission();
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
      await _cardCommentRecorder.start(const RecordConfig(), path: path);
      if (mounted) setState(() => _cardCommentRecording = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка записи: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Удаление только дефекта у оборудования; марка и количество сохраняются.
  void _removeDefect(EquipmentFormData item) {
    setState(() {
      final i = _pendingEquipment.indexWhere((e) =>
          e.equipmentType == item.equipmentType &&
          e.name == item.name &&
          e.defect == item.defect &&
          e.criticality == item.criticality);
      if (i >= 0) {
        final eq = _pendingEquipment[i];
        _pendingEquipment[i] = EquipmentFormData(
          equipmentType: eq.equipmentType,
          name: eq.name,
          quantity: eq.quantity,
          defect: null,
          criticality: null,
          categoryTitle: eq.categoryTitle,
          defectAttachment: null,
        );
      }
    });
  }

  static Color _criticalityColor(String? c) {
    switch (c?.toLowerCase()) {
      case 'high': return Colors.red;
      case 'medium': return Colors.orange;
      case 'low': return Colors.amber;
      default: return PatrolColors.textSecondary;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialPoleNumber != null && widget.initialPoleNumber!.isNotEmpty) {
      _poleNumber = widget.initialPoleNumber!;
    } else if (widget.poleSequenceNumber != null) {
      // Если номер не передан явно, подставляем следующий порядковый (например, 16 для 16‑й опоры)
      _poleNumber = widget.poleSequenceNumber!.toString();
    }
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _latitude = widget.initialLatitude;
      _longitude = widget.initialLongitude;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _getCurrentLocation());
    }

    // Для второй и последующих опор по линии автоматически включаем автозаполнение
    // (использование последних значений и шаблона оборудования с предыдущей опоры).
    if (widget.existingPolesCount > 0) {
      _autofill = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadAutofillTemplate();
      });
    }
  }

  @override
  void dispose() {
    _cardCommentController.dispose();
    _cardCommentRecorder.dispose();
    super.dispose();
  }

  Future<bool> _savePoleToLocalDb() async {
    try {
      final db = ref.read(databaseProvider);
      final prefs = ref.read(prefsProvider);
      int localId = prefs.getInt(AppConfig.lastLocalPoleIdKey) ?? -1;
      localId--;
      await prefs.setInt(AppConfig.lastLocalPoleIdKey, localId);
      final userId = prefs.getInt(AppConfig.userIdKey) ?? 0;
      final now = DateTime.now();
      await db.insertPole(PolesCompanion.insert(
        id: drift.Value(localId),
        powerLineId: widget.powerLineId,
        poleNumber: _poleNumber,
        xPosition: _longitude!,
        yPosition: _latitude!,
        poleType: _poleType,
        height: drift.Value(_height),
        foundationType: drift.Value(_foundationType),
        material: drift.Value(_material),
        yearInstalled: drift.Value(_yearInstalled),
        condition: _condition,
        notes: drift.Value(_notes),
        cardComment: _cardCommentController.text.trim().isEmpty
            ? const drift.Value.absent()
            : drift.Value(_cardCommentController.text.trim()),
        cardCommentAttachment: _cardCommentAttachments.isEmpty
            ? const drift.Value.absent()
            : drift.Value(jsonEncode(_cardCommentAttachments)),
        createdBy: userId,
        createdAt: now,
        updatedAt: drift.Value(now),
        isLocal: const drift.Value(true),
        needsSync: const drift.Value(true),
      ));
      for (final eq in _pendingEquipment) {
        int eqLocalId = prefs.getInt(AppConfig.lastLocalEquipmentIdKey) ?? -1;
        eqLocalId--;
        await prefs.setInt(AppConfig.lastLocalEquipmentIdKey, eqLocalId);
        await db.insertEquipment(EquipmentCompanion.insert(
          id: drift.Value(eqLocalId),
          poleId: localId,
          equipmentType: eq.equipmentType,
          name: eq.name,
          quantity: drift.Value(eq.quantity),
          defect: eq.defect != null && eq.defect!.isNotEmpty ? drift.Value(eq.defect!) : const drift.Value.absent(),
          criticality: eq.criticality != null && eq.criticality!.isNotEmpty ? drift.Value(eq.criticality!) : const drift.Value.absent(),
          defectAttachment: eq.defectAttachment != null && eq.defectAttachment!.isNotEmpty
              ? drift.Value(eq.defectAttachment!)
              : const drift.Value.absent(),
          condition: 'good',
          notes: drift.Value(null),
          createdBy: userId,
          createdAt: now,
          updatedAt: const drift.Value.absent(),
          isLocal: const drift.Value(true),
          needsSync: const drift.Value(true),
        ));
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Включите геолокацию в настройках.'), backgroundColor: Colors.orange),
          );
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Нет разрешения на геолокацию.'), backgroundColor: Colors.orange),
          );
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Местоположение получено'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _showManualCoordinatesDialog() async {
    final latController = TextEditingController(text: _latitude?.toString() ?? '');
    final lonController = TextEditingController(text: _longitude?.toString() ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Координаты вручную'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: latController,
                  decoration: const InputDecoration(labelText: 'Широта'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lonController,
                  decoration: const InputDecoration(labelText: 'Долгота'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () {
                final lat = double.tryParse(latController.text.replaceAll(',', '.').trim());
                final lon = double.tryParse(lonController.text.replaceAll(',', '.').trim());
                if (lat == null || lon == null || lat < -90 || lat > 90 || lon < -180 || lon > 180) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Введите корректные широту (-90…90) и долготу (-180…180).'), backgroundColor: Colors.orange),
                  );
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    final latVal = double.tryParse(latController.text.replaceAll(',', '.').trim());
    final lonVal = double.tryParse(lonController.text.replaceAll(',', '.').trim());
    latController.dispose();
    lonController.dispose();
    if (result == true && latVal != null && lonVal != null && latVal >= -90 && latVal <= 90 && lonVal >= -180 && lonVal <= 180) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _latitude = latVal;
          _longitude = lonVal;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Координаты обновлены'), backgroundColor: Colors.green),
        );
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите координаты или получите местоположение.'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final apiService = ref.read(apiServiceProvider);
      final poleData = PoleCreate(
        poleNumber: _poleNumber,
        xPosition: _longitude!,
        yPosition: _latitude!,
        poleType: _poleType,
        height: _height,
        foundationType: _foundationType?.isEmpty ?? true ? null : _foundationType,
        material: _material?.isEmpty ?? true ? null : _material,
        yearInstalled: _yearInstalled,
        condition: _condition,
        notes: _notes?.isEmpty ?? true ? null : _notes,
        isTap: _isTap,
        conductorType: _conductorType,
        conductorMaterial: _conductorMaterial,
        conductorSection: _conductorSection,
      );
      final createdPole = await apiService.createPole(widget.powerLineId, poleData);
      // Сохраняем опору и оборудование в локальную БД, чтобы сразу после возврата на карту
      // они участвовали в отрисовке (в т.ч. SVG-иконки на линии).
      try {
        final db = ref.read(databaseProvider);
        final dbPowerLineId =
            (createdPole.powerLineId != 0 && createdPole.powerLineId == widget.powerLineId)
                ? createdPole.powerLineId
                : widget.powerLineId;
        await db.insertPoleOrReplace(PolesCompanion.insert(
          id: drift.Value(createdPole.id),
          powerLineId: dbPowerLineId,
          poleNumber: createdPole.poleNumber,
          xPosition: createdPole.xPosition,
          yPosition: createdPole.yPosition,
          poleType: createdPole.poleType,
          height: drift.Value(createdPole.height),
          foundationType: drift.Value(createdPole.foundationType),
          material: drift.Value(createdPole.material),
          yearInstalled: drift.Value(createdPole.yearInstalled),
          condition: createdPole.condition,
          notes: drift.Value(createdPole.notes),
          cardComment: _cardCommentController.text.trim().isEmpty
              ? const drift.Value.absent()
              : drift.Value(_cardCommentController.text.trim()),
          cardCommentAttachment: _cardCommentAttachments.isEmpty
              ? const drift.Value.absent()
              : drift.Value(jsonEncode(_cardCommentAttachments)),
          createdBy: createdPole.createdBy,
          createdAt: createdPole.createdAt,
          updatedAt: drift.Value(createdPole.updatedAt),
          isLocal: const drift.Value(false),
          needsSync: const drift.Value(false),
        ));

        for (final eq in _pendingEquipment) {
          try {
            final notesParts = <String>[];
            if (eq.quantity > 1) notesParts.add('количество: ${eq.quantity}');
            if (eq.defect != null && eq.defect!.isNotEmpty) {
              notesParts.add('дефект: ${eq.defect}');
              if (eq.criticality != null) notesParts.add('критичность: ${eq.criticality}');
            }
            final createdEq = await apiService.createEquipment(
              createdPole.id,
              EquipmentCreate(
                equipmentType: eq.equipmentType,
                name: eq.name,
                condition: 'good',
                notes: notesParts.isEmpty ? null : notesParts.join('; '),
              ),
            );
            await db.insertEquipmentOrReplace(EquipmentCompanion.insert(
              id: drift.Value(createdEq.id),
              poleId: createdEq.poleId,
              equipmentType: eq.equipmentType,
              name: eq.name,
              quantity: drift.Value(eq.quantity),
              defect: eq.defect != null && eq.defect!.isNotEmpty
                  ? drift.Value(eq.defect!)
                  : const drift.Value.absent(),
              criticality: eq.criticality != null && eq.criticality!.isNotEmpty
                  ? drift.Value(eq.criticality!)
                  : const drift.Value.absent(),
              defectAttachment: eq.defectAttachment != null && eq.defectAttachment!.isNotEmpty
                  ? drift.Value(eq.defectAttachment!)
                  : const drift.Value.absent(),
              condition: createdEq.condition,
              notes: drift.Value(createdEq.notes),
              createdBy: createdEq.createdBy,
              createdAt: createdEq.createdAt,
              updatedAt: drift.Value(createdEq.updatedAt),
              isLocal: const drift.Value(false),
              needsSync: const drift.Value(false),
            ));
          } catch (_) {}
        }
      } catch (_) {}
      if (mounted) {
        _saveAutofillTemplate();
        Navigator.of(context).pop(<String, dynamic>{'success': true, 'x_position': _longitude!, 'y_position': _latitude!});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Опора успешно создана'), backgroundColor: Colors.green),
        );
      }
    } on DioException catch (e) {
      final isOffline = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.response == null;
      if (isOffline && mounted) {
        final saved = await _savePoleToLocalDb();
        if (mounted && saved) {
          _saveAutofillTemplate();
          Navigator.of(context).pop(<String, dynamic>{'success': true, 'x_position': _longitude!, 'y_position': _latitude!});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Опора сохранена локально. Синхронизация при подключении.'),
              backgroundColor: Colors.blue,
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: ${e.message}'), backgroundColor: Colors.red),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${e.message ?? e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seq = widget.poleSequenceNumber ?? 1;
    final installedCount = _equipmentInstalled.where((e) => e).length;

    return Dialog(
      backgroundColor: PatrolColors.background,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Шапка: номер в круге + "Карточка опоры" + закрыть (без статуса ОФФЛАЙН ГОТОВ)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                              child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: PatrolColors.accentBlue,
                      child: Text('$seq', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Карточка опоры',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: PatrolColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: PatrolColors.textPrimary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Координаты + ИЗМЕНИТЬ
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: PatrolColors.surfaceCard,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                            Icon(Icons.location_on, color: PatrolColors.accentBlue, size: 24),
                            const SizedBox(width: 12),
                  Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _latitude != null && _longitude != null
                                        ? '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}'
                                        : '—',
                                    style: const TextStyle(fontSize: 13, color: PatrolColors.textPrimary),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('ТОЧНОСТЬ: ±2 М', style: TextStyle(fontSize: 11, color: PatrolColors.textSecondary)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                TextButton(
                          onPressed: _isGettingLocation ? null : _getCurrentLocation,
                                  child: _isGettingLocation
                                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Text('ИЗМЕНИТЬ'),
                                ),
                                TextButton(
                                  onPressed: () => _showManualCoordinatesDialog(),
                                  child: Text('Ввести вручную', style: TextStyle(fontSize: 12, color: PatrolColors.accent)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Основные параметры + АВТОЗАПОЛНЕНИЕ
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('ОСНОВНЫЕ ПАРАМЕТРЫ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PatrolColors.textSecondary)),
                          Row(
                            children: [
                              Text('АВТОЗАПОЛНЕНИЕ', style: TextStyle(fontSize: 11, color: PatrolColors.textSecondary)),
                              const SizedBox(width: 6),
                              Switch(
                                value: _autofill && widget.existingPolesCount > 0,
                                onChanged: widget.existingPolesCount == 0
                                    ? null
                                    : (v) {
                                        setState(() => _autofill = v);
                                        if (v) {
                                          // Откладываем загрузку шаблона на следующий кадр, чтобы setState не вызывался во время обработки переключателя
                                          WidgetsBinding.instance.addPostFrameCallback((_) {
                                            if (!mounted) return;
                                            final loaded = _loadAutofillTemplate();
                                            if (!loaded && mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Нет сохранённого шаблона с предыдущей опоры. Заполните оборудование и сохраните опору — шаблон сохранится для следующей.'),
                                                  backgroundColor: Colors.orange,
                                                  duration: Duration(seconds: 4),
                                                ),
                                              );
                                            }
                                          });
                                        }
                                      },
                                activeColor: PatrolColors.accent,
                              ),
                            ],
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Автозаполнение с предыдущей опоры',
                          style: TextStyle(fontSize: 11, color: PatrolColors.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Номер опоры (скрытое поле для валидации)
                      TextFormField(
                        initialValue: _poleNumber,
                        decoration: const InputDecoration(
                          labelText: 'Номер опоры *',
                          hintText: 'ОП-001',
                          filled: true,
                          fillColor: PatrolColors.surfaceCard,
                        ),
                        style: const TextStyle(color: PatrolColors.textPrimary),
                        validator: (v) => (v == null || v.isEmpty) ? 'Введите номер опоры' : null,
                        onSaved: (v) => _poleNumber = v ?? '',
                        onChanged: (v) => _poleNumber = v,
                      ),
                      const SizedBox(height: 12),

                      // Тип опоры: 3 кнопки по макету
                      Text('Тип опоры', style: TextStyle(fontSize: 12, color: PatrolColors.textSecondary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildPoleTypeChip('анкерная', 'АНКЕРНАЯ'),
                          const SizedBox(width: 8),
                          _buildPoleTypeChip('промежуточная', 'ПРОМЕЖУТ.'),
                  const SizedBox(width: 8),
                          _buildPoleTypeChip('угловая', 'УГЛОВАЯ'),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Марка опоры
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Марка опоры',
                          hintText: 'CB-95-1',
                          prefixIcon: const Icon(Icons.search, size: 20, color: PatrolColors.textSecondary),
                          filled: true,
                          fillColor: PatrolColors.surfaceCard,
                        ),
                        style: const TextStyle(color: PatrolColors.textPrimary),
                        onChanged: (v) {},
                      ),
                      const SizedBox(height: 20),

                      // Оборудование на опоре: 0 из 6
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('ОБОРУДОВАНИЕ НА ОПОРЕ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PatrolColors.textSecondary)),
                          Text('$installedCount из 6', style: TextStyle(fontSize: 12, color: PatrolColors.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(_equipmentCategories.length, (i) {
                        final cat = _equipmentCategories[i];
                        final installed = _equipmentInstalled[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: PatrolColors.surfaceCard,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(cat.icon, color: PatrolColors.textSecondary, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(cat.title, style: const TextStyle(fontWeight: FontWeight.w600, color: PatrolColors.textPrimary)),
                                      Text(
                                        installed ? 'Установлено' : 'Не установлено',
                                        style: TextStyle(fontSize: 12, color: PatrolColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Material(
                                  color: installed ? PatrolColors.surface : PatrolColors.statusSynced.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () async {
                                      final eqType = EquipmentReferenceData.categoryToEquipmentType[cat.title] ?? cat.title.toLowerCase();
                                      final singleInstance = EquipmentReferenceData.isSingleInstance(cat.title);
                                      final existingList = _pendingEquipment.where((e) => e.equipmentType == eqType).toList();
                                      final existing = existingList.isEmpty ? null : existingList.first;

                                      if (installed && existing != null) {
                                        // Даём выбор: редактировать или удалить.
                                        final action = await showDialog<String>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: Text(cat.title),
                                            content: Text('Оборудование уже добавлено. Что сделать?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(ctx).pop('delete'),
                                                child: const Text('Удалить'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.of(ctx).pop('edit'),
                                                child: const Text('Редактировать'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.of(ctx).pop(),
                                                child: const Text('Отмена'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (!mounted || action == null) return;
                                        if (action == 'delete') {
                                          setState(() {
                                            _equipmentInstalled[i] = false;
                                            _pendingEquipment.removeWhere((e) => e.equipmentType == eqType);
                                          });
                                          return;
                                        }
                                        if (action == 'edit') {
                                          final result = await showDialog<EquipmentFormData>(
                                            context: context,
                                            builder: (ctx) => AddEquipmentDialog(
                                              categoryTitle: cat.title,
                                              equipmentType: eqType,
                                              singleInstance: singleInstance,
                                              initialBrand: existing.name,
                                              initialQuantity: existing.quantity,
                                              initialDefect: existing.defect,
                                              initialCriticality: existing.criticality,
                                              initialDefectAttachment: existing.defectAttachment,
                                            ),
                                          );
                                          if (result != null && mounted) {
                                            setState(() {
                                              _pendingEquipment.removeWhere((e) => e.equipmentType == eqType);
                                              _pendingEquipment.add(result);
                                            });
                                          }
                                          return;
                                        }
                                        return;
                                      }

                                      if (installed) {
                                        setState(() {
                                          _equipmentInstalled[i] = false;
                                          _pendingEquipment.removeWhere((e) => e.equipmentType == eqType);
                                        });
                                        return;
                                      }

                                      final result = await showDialog<EquipmentFormData>(
                                        context: context,
                                        builder: (ctx) => AddEquipmentDialog(
                                          categoryTitle: cat.title,
                                          equipmentType: eqType,
                                          singleInstance: singleInstance,
                                          initialQuantity: singleInstance ? 1 : 1,
                                        ),
                                      );
                                      if (result != null && mounted) {
                                        setState(() {
                                          _pendingEquipment.add(result);
                                          _equipmentInstalled[i] = true;
                                        });
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Icon(installed ? Icons.edit : Icons.add, color: installed ? PatrolColors.textSecondary : PatrolColors.statusSynced, size: 22),
                                    ),
                                  ),
                                ),
                ],
              ),
                          ),
                        );
                      }),
                      if (_pendingEquipment.any((e) => e.defect != null && e.defect!.isNotEmpty)) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Список дефектов (${_pendingEquipment.where((e) => e.defect != null && e.defect!.isNotEmpty).length})',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PatrolColors.textSecondary),
              ),
              const SizedBox(height: 8),
                        ..._pendingEquipment
                            .where((e) => e.defect != null && e.defect!.isNotEmpty)
                            .map((item) {
                          final critLabel = DefectReferenceData.criticalityLabels[item.criticality] ?? item.criticality ?? '—';
                          final catLabel = item.categoryTitle ?? item.equipmentType;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: PatrolColors.surfaceCard,
                              borderRadius: BorderRadius.circular(12),
                              child: IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      width: 6,
                                      decoration: BoxDecoration(
                                        color: _criticalityColor(item.criticality),
                                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.defect!,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: PatrolColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${catLabel.toUpperCase()} • ${critLabel.toUpperCase()}',
                                              style: TextStyle(fontSize: 11, color: PatrolColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: PatrolColors.textSecondary),
                                      onPressed: () => _removeDefect(item),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        'КОММЕНТАРИЙ К ОПОРЕ',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PatrolColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _cardCommentController,
                        decoration: InputDecoration(
                          hintText: 'Текст комментария',
                          filled: true,
                          fillColor: PatrolColors.surfaceCard,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        style: const TextStyle(color: PatrolColors.textPrimary),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickCommentImage,
                            icon: const Icon(Icons.photo_library, size: 20),
                            label: const Text('Фото'),
                            style: OutlinedButton.styleFrom(foregroundColor: PatrolColors.textPrimary),
                          ),
                          if (!kIsWeb) ...[
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: _recordCommentVoice,
                              icon: Icon(_cardCommentRecording ? Icons.stop : Icons.mic, size: 20),
                              label: Text(_cardCommentRecording ? 'Стоп' : 'Голос'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _cardCommentRecording ? Colors.red : PatrolColors.textPrimary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_cardCommentAttachments.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _cardCommentAttachments.asMap().entries.map((e) {
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
                              onDeleted: () => setState(() => _cardCommentAttachments.removeAt(e.key)),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Подвал: ОТМЕНА, ЗАФИКСИРОВАТЬ ОПОРУ
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: PatrolColors.surfaceCard,
                          foregroundColor: PatrolColors.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('ОТМЕНА'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PatrolColors.accentBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: _isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save, size: 20),
                        label: const Text('ЗАФИКСИРОВАТЬ ОПОРУ'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPoleTypeChip(String value, String label) {
    final selected = _poleType == value;
    return Expanded(
      child: Material(
        color: PatrolColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _poleType = value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? PatrolColors.accentBlue : PatrolColors.surfaceCard,
                width: selected ? 2 : 0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.settings, size: 16, color: selected ? PatrolColors.accentBlue : PatrolColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? PatrolColors.accentBlue : PatrolColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
