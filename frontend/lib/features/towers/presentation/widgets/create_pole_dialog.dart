import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/services/api_service.dart';
import '../../../../core/services/attachment_reader.dart';
import '../../../../core/database/database.dart' hide Equipment, Pole;
import '../../../../core/models/power_line.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/config/pole_reference_data.dart';
import '../../../../core/utils/pole_number_mask.dart';
import '../../../../core/theme/app_theme.dart';
import 'pole_number_mask_field.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/utils/pole_card_attachment_codec.dart';
import 'add_equipment_dialog.dart';
import 'pole_attachments_table_sheet.dart';

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
  /// ID линии (ЛЭП). Единое поле line_id.
  final int lineId;
  /// Режим редактирования: ID существующей опоры (null — режим создания).
  final int? poleId;
  final double? initialLatitude;
  final double? initialLongitude;
  final int? poleSequenceNumber;
  final String? initialPoleNumber;
  final int existingPolesCount;
  /// ID отпаечной опоры: при открытии сценария «Начать отпайку» или «Добавить в отпайку».
  final int? tapPoleId;
  /// Номер ветки от одной отпаечной (1, 2, …); при «Добавить в отпайку» — ветка выбранной опоры.
  final int? tapBranchIndex;
  /// true = открыт сценарий «Начать новую отпайку» от отпаечной опоры (вторая/третья ветка).
  final bool startNewTap;

  const CreatePoleDialog({
    super.key,
    required this.lineId,
    this.poleId,
    this.initialLatitude,
    this.initialLongitude,
    this.poleSequenceNumber,
    this.initialPoleNumber,
    this.existingPolesCount = 0,
    this.tapPoleId,
    this.tapBranchIndex,
    this.startNewTap = false,
  });

  bool get isEditMode => poleId != null;

  @override
  ConsumerState<CreatePoleDialog> createState() => _CreatePoleDialogState();
}

class _CreatePoleDialogState extends ConsumerState<CreatePoleDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isGettingLocation = false;
  bool _autofill = false;

  String _poleNumber = '';
  late PoleNumberMask _poleMask;
  PoleNumberMask? _suggestedMask;
  /// Сброс полей маски при подсказке / загрузке опоры (см. [PoleNumberMaskField]).
  int _poleMaskKey = 0;
  /// При редактировании: id отпаечной опоры-якоря (для «Начать отпайку» с опоры 3/1 — это id опоры 3).
  int? _editTapAnchorId;
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

  /// Показывать выбор «Магистраль» / «Отпайка от X — ветка N» (как в Angular).
  bool _showBranchChoice = false;
  /// Список веток для выбора: value = "tapPoleId:tapBranchIndex", label = "Отпайка от X — ветка N".
  List<MapEntry<String, String>> _tapBranchesInLine = [];
  /// Отпаечные опоры линии (id, pole_number) для подписей.
  List<MapEntry<int, String>> _tapPolesInLine = [];
  /// Выбранная ветка: null = магистраль, иначе "tapPoleId:tapBranchIndex".
  String? _branchSelection;

  final _cardCommentController = TextEditingController();
  final List<Map<String, dynamic>> _cardCommentAttachments = [];
  final AudioRecorder _cardCommentRecorder = AudioRecorder();
  bool _cardCommentRecording = false;

  /// Контроллеры для полей, подставляемых при загрузке в режиме редактирования.
  late final TextEditingController _materialController;

  /// Количество «установленного» оборудования по категориям (для отображения 0 из N).
  final List<bool> _equipmentInstalled = List.filled(_equipmentCategories.length, false);
  /// Оборудование, добавленное через форму (до сохранения опоры).
  final List<EquipmentFormData> _pendingEquipment = [];
  /// Оборудование, загруженное с сервера при открытии в режиме редактирования (имеет id).
  List<Equipment> _loadedEquipment = [];

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

  String? _encodeCardAttachmentsForDb() {
    return _encodeAttachmentListForDb(_cardCommentAttachments);
  }

  String? _encodeAttachmentListForDb(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return null;
    final uid = ref.read(prefsProvider).getInt(AppConfig.userIdKey) ?? 0;
    final auth = ref.read(authServiceProvider);
    String? uname;
    if (auth is AuthStateAuthenticated) {
      uname = auth.user.fullName.isNotEmpty ? auth.user.fullName : auth.user.username;
    }
    final enc = PoleCardAttachmentCodec.encodeForStorage(
      List<Map<String, dynamic>>.from(
        items.map((e) => Map<String, dynamic>.from(e)),
      ),
      userId: uid,
      userName: uname,
      lastKind: 'edit',
    );
    return enc.isEmpty ? null : enc;
  }

  Future<void> _pickCommentImage() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null || !mounted) return;
      final uid = ref.read(prefsProvider).getInt(AppConfig.userIdKey) ?? 0;
      final auth = ref.read(authServiceProvider);
      String? uname;
      if (auth is AuthStateAuthenticated) {
        uname = auth.user.fullName.isNotEmpty ? auth.user.fullName : auth.user.username;
      }
      setState(() => _cardCommentAttachments.add(
            PoleCardAttachmentCodec.newPhotoAttachment(
              file.path,
              userId: uid,
              userName: uname,
            ),
          ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Загружает вложения с локальным путём (p) на сервер и возвращает список с url.
  Future<List<Map<String, dynamic>>> _resolveCardCommentAttachments(
    ApiServiceWithExport api,
    int? poleId,
  ) async {
    if (poleId == null) return List.from(_cardCommentAttachments);
    final resolved = <Map<String, dynamic>>[];
    for (final m in _cardCommentAttachments) {
      if (m['url'] != null) {
        resolved.add(Map<String, dynamic>.from(m));
        continue;
      }
      final path = m['p'] as String?;
      if (path == null || path.isEmpty) continue;
      final type = m['t'] as String? ?? 'photo';
      try {
        final bytes = await readAttachmentBytes(path);
        if (bytes.isEmpty) continue;
        final ext = path.contains('.') ? path.split('.').last : 'jpg';
        final result = await api.uploadPoleAttachment(poleId, type, bytes, 'upload.$ext');
        final url = result['url'] as String?;
        if (url != null) {
          final entry = <String, dynamic>{'t': type, 'url': url};
          if (result['thumbnail_url'] != null) entry['thumbnail_url'] = result['thumbnail_url'];
          resolved.add(entry);
        }
      } catch (_) {}
    }
    return resolved;
  }

  /// Загружает мультимедиа дефекта оборудования (из JSON {"t","p"}) и
  /// возвращает JSON со ссылками {"t","url","thumbnail_url?"}.
  Future<String?> _resolveEquipmentDefectAttachmentJson(
    ApiServiceWithExport api,
    int poleId,
    String? rawJson,
  ) async {
    if (rawJson == null || rawJson.isEmpty) return null;
    try {
      final decoded = decodeDefectAttachmentList(rawJson);
      if (decoded.isEmpty) return null;
      final resolved = <Map<String, dynamic>>[];
      for (final m in decoded) {
        final type = (m['t'] ?? 'photo').toString();
        final existingUrl = m['url']?.toString();
        if (existingUrl != null && existingUrl.isNotEmpty) {
          resolved.add({'t': type, 'url': existingUrl});
          continue;
        }
        final path = m['p']?.toString();
        if (path == null || path.isEmpty) continue;
        try {
          final bytes = await readAttachmentBytes(path);
          if (bytes.isEmpty) continue;
          final ext = path.contains('.') ? path.split('.').last : 'jpg';
          final uploaded = await api.uploadPoleAttachment(poleId, type, bytes, 'defect.$ext');
          final url = uploaded['url']?.toString();
          if (url == null || url.isEmpty) continue;
          final entry = <String, dynamic>{'t': type, 'url': url};
          final thumb = uploaded['thumbnail_url']?.toString();
          if (thumb != null && thumb.isNotEmpty) {
            entry['thumbnail_url'] = thumb;
          }
          resolved.add(entry);
        } catch (_) {}
      }
      if (resolved.isEmpty) return null;
      return jsonEncode(resolved);
    } catch (_) {
      return rawJson;
    }
  }

  Future<void> _recordCommentVoice() async {
    if (_cardCommentRecording) {
      try {
        final path = await _cardCommentRecorder.stop();
        if (path != null && path.isNotEmpty && mounted) {
          final uid = ref.read(prefsProvider).getInt(AppConfig.userIdKey) ?? 0;
          final auth = ref.read(authServiceProvider);
          String? uname;
          if (auth is AuthStateAuthenticated) {
            uname = auth.user.fullName.isNotEmpty ? auth.user.fullName : auth.user.username;
          }
          setState(() {
            _cardCommentAttachments.add(
              PoleCardAttachmentCodec.newVoiceAttachment(
                path,
                userId: uid,
                userName: uname,
              ),
            );
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
    _materialController = TextEditingController();
    if (widget.isEditMode && widget.poleId != null) {
      _poleMask = PoleNumberMask();
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPoleForEdit());
      return;
    }
    if (widget.initialPoleNumber != null && widget.initialPoleNumber!.isNotEmpty) {
      _poleMask = PoleNumberMask.parse(widget.initialPoleNumber!);
      _poleNumber = _poleMask.apiString;
    } else if (widget.poleSequenceNumber != null) {
      _poleMask = PoleNumberMask(mainDigits: widget.poleSequenceNumber!.toString());
      _poleNumber = _poleMask.apiString;
    } else if (widget.existingPolesCount > 0) {
      _poleMask = PoleNumberMask(mainDigits: '${widget.existingPolesCount + 1}');
      _poleNumber = _poleMask.apiString;
    } else {
      _poleMask = PoleNumberMask(mainDigits: '1');
      _poleNumber = _poleMask.apiString;
    }
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _latitude = widget.initialLatitude;
      _longitude = widget.initialLongitude;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _getCurrentLocation());
    }
    if (widget.existingPolesCount > 0) {
      _autofill = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadAutofillTemplate();
      });
    }
    if (!widget.isEditMode && !widget.startNewTap) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadTapBranchesForLine();
        _loadPoleNumberSuggestion();
      });
    }
    if (widget.tapPoleId != null && widget.tapBranchIndex != null) {
      _branchSelection = '${widget.tapPoleId}:${widget.tapBranchIndex}';
    }
  }

  void _applyLoadedPoleToState(Pole pole, List<Equipment> equipmentList) {
    if (!mounted) return;
    setState(() {
      _poleMask = PoleNumberMask.parse(pole.poleNumber);
      _poleNumber = _poleMask.apiString;
      _poleMaskKey++;
      _editTapAnchorId = pole.tapPoleId;
      _materialController.text = pole.material ?? '';
      _poleType = pole.poleType;
      _latitude = pole.yPosition;
      _longitude = pole.xPosition;
      _height = pole.height;
      _foundationType = pole.foundationType;
      _material = pole.material;
      _yearInstalled = pole.yearInstalled;
      _condition = pole.condition;
      _notes = pole.notes;
      _conductorType = pole.conductorType;
      _conductorMaterial = pole.conductorMaterial;
      _conductorSection = pole.conductorSection;
      _isTap = pole.isTapPole;
      if (pole.tapPoleId != null && pole.tapBranchIndex != null) {
        _branchSelection = '${pole.tapPoleId}:${pole.tapBranchIndex}';
      } else {
        _branchSelection = null;
      }
      _loadedEquipment = equipmentList;
      _cardCommentController.text = pole.cardComment ?? '';
      _cardCommentAttachments
        ..clear()
        ..addAll(PoleCardAttachmentCodec.parseItemsJson(pole.cardCommentAttachment));
      for (final eq in equipmentList) {
        final typeLower = eq.equipmentType.trim().toLowerCase();
        for (var i = 0; i < _equipmentCategories.length; i++) {
          final catTitle = _equipmentCategories[i].title;
          final catType = EquipmentReferenceData.categoryToEquipmentType[catTitle]?.trim().toLowerCase();
          if (catType != null && (typeLower == catType || typeLower.contains(catType) || catType.contains(typeLower))) {
            _equipmentInstalled[i] = true;
            break;
          }
        }
      }
      _isLoading = false;
    });
  }

  /// Загружает список отпаечных опор и веток линии для выбора «Магистраль / Отпайка» (как в Angular).
  Future<void> _loadTapBranchesForLine() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final poles = await apiService.getPoles(widget.lineId);
      if (!mounted) return;
      final tapPoles = poles.where((p) => p.isTapPole).toList();
      final tapPoleNames = <int, String>{};
      for (final p in tapPoles) {
        tapPoleNames[p.id] = p.poleNumber;
      }
      final branchSet = <String>{};
      for (final p in poles) {
        if (p.tapPoleId != null) {
          final bi = p.tapBranchIndex ?? 1;
          branchSet.add('${p.tapPoleId}:$bi');
        }
      }
      // Защита от дублей/рассинхрона: формируем уникальный список веток.
      final byKey = <String, String>{};
      for (final s in branchSet) {
        final parts = s.split(':');
        final pid = int.tryParse(parts[0]) ?? 0;
        final bi = int.tryParse(parts[1]) ?? 1;
        final label = 'Отпайка от ${tapPoleNames[pid] ?? 'опора $pid'} — ветка $bi';
        byKey[s] = label;
      }
      final branches = byKey.entries.map((e) => MapEntry(e.key, e.value)).toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final allowedValues = branches.map((e) => e.key).toSet();
      setState(() {
        _tapPolesInLine = tapPoles.map((p) => MapEntry(p.id, p.poleNumber)).toList();
        _tapBranchesInLine = branches;
        _showBranchChoice = _tapBranchesInLine.isNotEmpty || _tapPolesInLine.isNotEmpty;
        // Если текущего значения нет среди items, сбрасываем в магистраль,
        // чтобы DropdownButton не падал с assertion.
        if (_branchSelection != null && !allowedValues.contains(_branchSelection)) {
          _branchSelection = null;
        }
      });
    } catch (_) {
      if (mounted) setState(() {
        _tapBranchesInLine = [];
        _tapPolesInLine = [];
        _showBranchChoice = false;
      });
    }
  }

  /// Подсказка следующего номера по последним созданным опорам линии (API или локальная БД).
  Future<void> _loadPoleNumberSuggestion() async {
    if (widget.isEditMode) return;
    try {
      final apiService = ref.read(apiServiceProvider);
      final db = ref.read(databaseProvider);
      final List<String> numbers = [];
      try {
        final poles = await apiService.getPoles(widget.lineId);
        poles.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        numbers.addAll(poles.map((p) => p.poleNumber));
      } catch (_) {
        final rows = await db.getPolesByLine(widget.lineId);
        rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        numbers.addAll(rows.map((p) => p.poleNumber));
      }
      if (numbers.isEmpty) return;
      final sug = PoleNumberSuggestion.suggestNext(numbers);
      if (mounted && sug != null) setState(() => _suggestedMask = sug);
    } catch (_) {}
  }

  Future<void> _loadPoleForEdit() async {
    if (widget.poleId == null || !mounted) return;
    setState(() => _isLoading = true);
    try {
      final apiService = ref.read(apiServiceProvider);
      final pole = await apiService.getPole(widget.poleId!);
      List<Equipment> equipmentList = [];
      if (pole.equipment != null && pole.equipment!.isNotEmpty) {
        equipmentList = pole.equipment!;
      } else {
        try {
          equipmentList = await apiService.getPoleEquipment(widget.poleId!);
        } catch (e) {
          if (kDebugMode) {
            print('CreatePoleDialog: не удалось загрузить оборудование опоры: $e');
          }
        }
      }
      _applyLoadedPoleToState(pole, equipmentList);
      if (mounted) _loadTapBranchesForLine();
    } catch (e) {
      // Офлайн или ошибка API — загружаем из локальной БД
      if (kDebugMode) {
        print('CreatePoleDialog: загрузка опоры из БД (офлайн): $e');
      }
      try {
        final db = ref.read(databaseProvider);
        final driftPole = await db.getPole(widget.poleId!);
        if (driftPole == null || !mounted) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Опора не найдена в локальных данных'), backgroundColor: Colors.red),
            );
          }
          return;
        }
        final equipmentDataList = await db.getEquipmentByPole(widget.poleId!);
        final equipmentList = equipmentDataList.map((eq) => Equipment(
          id: eq.id,
          poleId: eq.poleId,
          equipmentType: eq.equipmentType,
          name: eq.name,
          manufacturer: eq.manufacturer,
          model: eq.model,
          serialNumber: eq.serialNumber,
          yearManufactured: eq.yearManufactured,
          installationDate: eq.installationDate,
          condition: eq.condition,
          notes: eq.notes,
          createdBy: eq.createdBy,
          createdAt: eq.createdAt,
          updatedAt: eq.updatedAt,
        )).toList();
        final poleApi = Pole(
          id: driftPole.id,
          lineId: driftPole.lineId,
          poleNumber: driftPole.poleNumber ?? '',
          xPosition: driftPole.xPosition ?? 0.0,
          yPosition: driftPole.yPosition ?? 0.0,
          poleType: driftPole.poleType ?? '',
          height: driftPole.height,
          foundationType: driftPole.foundationType,
          material: driftPole.material,
          yearInstalled: driftPole.yearInstalled,
          condition: driftPole.condition ?? 'good',
          notes: driftPole.notes,
          cardComment: driftPole.cardComment,
          cardCommentAttachment: driftPole.cardCommentAttachment,
          createdBy: driftPole.createdBy,
          createdAt: driftPole.createdAt,
          updatedAt: driftPole.updatedAt,
          isTapPole: (driftPole.poleNumber ?? '').contains('/'),
        );
        _applyLoadedPoleToState(poleApi, equipmentList);
        if (mounted) _loadTapBranchesForLine();
      } catch (dbErr) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка загрузки опоры: $dbErr'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  /// Сохранить редактирование опоры в локальную БД (офлайн).
  Future<void> _savePoleEditToLocalDb() async {
    final db = ref.read(databaseProvider);
    final prefs = ref.read(prefsProvider);
    final userId = prefs.getInt(AppConfig.userIdKey) ?? 0;
    final now = DateTime.now();
    final poleId = widget.poleId!;

    final existing = await db.getPole(poleId);
    if (existing == null) return;

    final cardAttJson = _encodeCardAttachmentsForDb();
    await db.updatePole(PolesCompanion(
      id: drift.Value(poleId),
      lineId: drift.Value(widget.lineId),
      poleNumber: drift.Value(_poleNumber),
      xPosition: drift.Value(_longitude!),
      yPosition: drift.Value(_latitude!),
      poleType: drift.Value(_poleType),
      height: drift.Value(_height),
      foundationType: drift.Value(_foundationType),
      material: drift.Value(_material),
      yearInstalled: drift.Value(_yearInstalled),
      condition: drift.Value(_condition),
      notes: drift.Value(_notes),
      cardComment: _cardCommentController.text.trim().isEmpty
          ? const drift.Value.absent()
          : drift.Value(_cardCommentController.text.trim()),
      cardCommentAttachment: cardAttJson == null
          ? const drift.Value.absent()
          : drift.Value(cardAttJson),
      createdBy: drift.Value(existing.createdBy),
      createdAt: drift.Value(existing.createdAt),
      updatedAt: drift.Value(now),
      isLocal: drift.Value(existing.isLocal),
      needsSync: const drift.Value(true),
    ));

    // Удаляем оборудование, снятое с опоры
    for (final eq in _loadedEquipment) {
      final kept = _pendingEquipment.any((p) =>
          p.equipmentType == eq.equipmentType && p.name == eq.name);
      if (!kept) {
        await db.deleteEquipment(eq.id);
      }
    }

    // Обновляем или добавляем оборудование
    for (final eq in _pendingEquipment) {
      final matching = _loadedEquipment.where((e) =>
          e.equipmentType == eq.equipmentType && e.name == eq.name).toList();
      final existingEq = matching.isEmpty ? null : matching.first;
      final existingEqData = existingEq != null ? await db.getEquipment(existingEq.id) : null;
      final notesParts = <String>[];
      if (eq.quantity > 1) notesParts.add('количество: ${eq.quantity}');
      if (eq.defect != null && eq.defect!.isNotEmpty) {
        notesParts.add('дефект: ${eq.defect}');
        if (eq.criticality != null) notesParts.add('критичность: ${eq.criticality}');
      }
      final notesStr = notesParts.isEmpty ? null : notesParts.join('; ');

      if (existingEqData != null) {
        await db.updateEquipment(EquipmentCompanion(
          id: drift.Value(existingEqData.id),
          poleId: drift.Value(poleId),
          equipmentType: drift.Value(eq.equipmentType),
          name: drift.Value(eq.name),
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
          manufacturer: drift.Value(existingEqData.manufacturer),
          model: drift.Value(existingEqData.model),
          serialNumber: drift.Value(existingEqData.serialNumber),
          yearManufactured: drift.Value(existingEqData.yearManufactured),
          installationDate: drift.Value(existingEqData.installationDate),
          condition: const drift.Value('good'),
          notes: drift.Value(notesStr),
          createdBy: drift.Value(existingEqData.createdBy),
          createdAt: drift.Value(existingEqData.createdAt),
          updatedAt: drift.Value(now),
          isLocal: drift.Value(existingEqData.isLocal),
          needsSync: const drift.Value(true),
        ));
      } else {
        int eqLocalId = prefs.getInt(AppConfig.lastLocalEquipmentIdKey) ?? -1;
        eqLocalId--;
        await prefs.setInt(AppConfig.lastLocalEquipmentIdKey, eqLocalId);
        await db.insertEquipment(EquipmentCompanion.insert(
          id: drift.Value(eqLocalId),
          poleId: poleId,
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
          condition: 'good',
          notes: drift.Value(notesStr),
          createdBy: userId,
          createdAt: now,
          updatedAt: drift.Value(now),
          isLocal: const drift.Value(true),
          needsSync: const drift.Value(true),
        ));
      }
    }

    if (mounted) {
      _saveAutofillTemplate();
      Navigator.of(context).pop(<String, dynamic>{'success': true, 'x_position': _longitude!, 'y_position': _latitude!});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Изменения опоры сохранены (офлайн). Синхронизация при подключении.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _materialController.dispose();
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
      final newPoleCardAtt = _encodeCardAttachmentsForDb();
      await db.insertPole(PolesCompanion.insert(
        id: drift.Value(localId),
        lineId: widget.lineId,
        poleNumber: _poleNumber,
        xPosition: drift.Value(_longitude!),  // CIM: x = долгота
        yPosition: drift.Value(_latitude!),   // CIM: y = широта
        poleType: drift.Value(_poleType),
        height: drift.Value(_height),
        foundationType: drift.Value(_foundationType),
        material: drift.Value(_material),
        yearInstalled: drift.Value(_yearInstalled),
        condition: drift.Value(_condition),
        notes: drift.Value(_notes),
        cardComment: _cardCommentController.text.trim().isEmpty
            ? const drift.Value.absent()
            : drift.Value(_cardCommentController.text.trim()),
        cardCommentAttachment: newPoleCardAtt == null
            ? const drift.Value.absent()
            : drift.Value(newPoleCardAtt),
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
    if (!_poleMask.isValidForSave) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Укажите основной номер опоры (первый блок — цифры).'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите координаты или получите местоположение.'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final apiService = ref.read(apiServiceProvider);
      _poleNumber = _poleMask.apiString;
      _material = _materialController.text.trim().isEmpty ? null : _materialController.text.trim();
      final cardCommentText = _cardCommentController.text.trim();

      // Логика ветки как в Angular: startNewTap | tapPoleId+tapBranchIndex | branch_selection
      int? tapPoleId;
      int? tapBranchIndex;
      String? branchType;
      bool startNewTap = false;
      if (widget.startNewTap && widget.tapPoleId != null) {
        tapPoleId = widget.tapPoleId;
        startNewTap = true;
        branchType = 'tap';
      } else if (widget.tapPoleId != null && widget.tapBranchIndex != null) {
        tapPoleId = widget.tapPoleId;
        tapBranchIndex = widget.tapBranchIndex;
        branchType = 'tap';
      } else if (_branchSelection != null && _branchSelection!.contains(':')) {
        final parts = _branchSelection!.split(':');
        tapPoleId = int.tryParse(parts[0]);
        tapBranchIndex = parts.length > 1 ? int.tryParse(parts[1]) : 1;
        if (tapPoleId != null) branchType = 'tap';
      }
      if (branchType == null) branchType = 'main';

      final poleData = PoleCreate(
        poleNumber: _poleNumber,
        xPosition: _longitude!,  // x_position = долгота
        yPosition: _latitude!,   // y_position = широта
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
        cardComment: cardCommentText.isEmpty ? null : cardCommentText,
        cardCommentAttachment: null, // заполняется после загрузки вложений
        tapPoleId: tapPoleId,
        branchType: branchType,
        tapBranchIndex: tapBranchIndex,
        startNewTap: startNewTap,
      );

      if (widget.isEditMode && widget.poleId != null) {
        // Редактирование: загружаем вложения, затем обновляем опору
        final resolvedAttachments = await _resolveCardCommentAttachments(apiService, widget.poleId);
        final attJsonResolved = _encodeAttachmentListForDb(resolvedAttachments);
        final poleDataWithAttachments = PoleCreate(
          poleNumber: poleData.poleNumber,
          xPosition: poleData.xPosition,
          yPosition: poleData.yPosition,
          poleType: poleData.poleType,
          height: poleData.height,
          foundationType: poleData.foundationType,
          material: poleData.material,
          yearInstalled: poleData.yearInstalled,
          condition: poleData.condition,
          notes: poleData.notes,
          isTap: poleData.isTap,
          conductorType: poleData.conductorType,
          conductorMaterial: poleData.conductorMaterial,
          conductorSection: poleData.conductorSection,
          cardComment: poleData.cardComment,
          cardCommentAttachment: attJsonResolved,
          tapPoleId: poleData.tapPoleId,
          branchType: poleData.branchType,
          tapBranchIndex: poleData.tapBranchIndex,
          startNewTap: poleData.startNewTap,
        );
        final updatedPole =
            await apiService.updatePole(widget.lineId, widget.poleId!, poleDataWithAttachments);
        try {
          final db = ref.read(databaseProvider);
          await db.updatePole(PolesCompanion(
            id: drift.Value(updatedPole.id),
            lineId: drift.Value(updatedPole.lineId),
            poleNumber: drift.Value(updatedPole.poleNumber),
            xPosition: drift.Value(updatedPole.xPosition),
            yPosition: drift.Value(updatedPole.yPosition),
            poleType: drift.Value(updatedPole.poleType),
            height: drift.Value(updatedPole.height),
            foundationType: drift.Value(updatedPole.foundationType),
            material: drift.Value(updatedPole.material),
            yearInstalled: drift.Value(updatedPole.yearInstalled),
            condition: drift.Value(updatedPole.condition),
            notes: drift.Value(updatedPole.notes),
            cardComment: cardCommentText.isEmpty
                ? const drift.Value.absent()
                : drift.Value(cardCommentText),
            cardCommentAttachment: attJsonResolved == null
                ? const drift.Value.absent()
                : drift.Value(attJsonResolved),
            createdBy: drift.Value(updatedPole.createdBy),
            createdAt: drift.Value(updatedPole.createdAt),
            updatedAt: drift.Value(updatedPole.updatedAt),
            isLocal: const drift.Value(false),
            needsSync: const drift.Value(false),
          ));
          for (final eq in _pendingEquipment) {
            try {
              final notesParts = <String>[];
              if (eq.quantity > 1) notesParts.add('количество: ${eq.quantity}');
              if (eq.defect != null && eq.defect!.isNotEmpty) {
                notesParts.add('дефект: ${eq.defect}');
                if (eq.criticality != null) {
                  notesParts.add('критичность: ${eq.criticality}');
                }
              }
              final createdEq = await apiService.createEquipment(
                updatedPole.id,
                EquipmentCreate(
                  equipmentType: eq.equipmentType,
                  name: eq.name,
                  condition: 'good',
                  notes: notesParts.isEmpty ? null : notesParts.join('; '),
                  defect: eq.defect,
                  criticality: eq.criticality,
                  defectAttachment: await _resolveEquipmentDefectAttachmentJson(
                    apiService,
                    updatedPole.id,
                    eq.defectAttachment,
                  ),
                ),
              );
              final db2 = ref.read(databaseProvider);
              await db2.insertEquipmentOrReplace(EquipmentCompanion.insert(
                id: drift.Value(createdEq.id),
                poleId: createdEq.poleId,
                equipmentType: createdEq.equipmentType,
                name: createdEq.name,
                quantity: drift.Value(eq.quantity),
                defect: eq.defect != null && eq.defect!.isNotEmpty
                    ? drift.Value(eq.defect!)
                    : const drift.Value.absent(),
                criticality: eq.criticality != null && eq.criticality!.isNotEmpty
                    ? drift.Value(eq.criticality!)
                    : const drift.Value.absent(),
                defectAttachment:
                    eq.defectAttachment != null && eq.defectAttachment!.isNotEmpty
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
          Navigator.of(context).pop(<String, dynamic>{
            'success': true,
            'x_position': _longitude!,
            'y_position': _latitude!,
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Изменения опоры сохранены'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // При «Начать отпайку» или «Добавить в отпайку» новая опора связывается с опорой tapPoleId.
      final createdPole = await apiService.createPole(
        widget.lineId,
        poleData,
        fromPoleId: widget.tapPoleId,
      );
      // Загружаем вложения на сервер и обновляем опору
      List<Map<String, dynamic>> resolvedAttachmentsCreate = [];
      String? attJsonCreate;
      if (_cardCommentAttachments.isNotEmpty) {
        resolvedAttachmentsCreate = await _resolveCardCommentAttachments(apiService, createdPole.id);
        if (resolvedAttachmentsCreate.isNotEmpty) {
          try {
            attJsonCreate = _encodeAttachmentListForDb(resolvedAttachmentsCreate);
            final poleDataWithAttachments = PoleCreate(
              poleNumber: createdPole.poleNumber,
              xPosition: createdPole.xPosition,
              yPosition: createdPole.yPosition,
              poleType: createdPole.poleType,
              height: createdPole.height,
              foundationType: createdPole.foundationType,
              material: createdPole.material,
              yearInstalled: createdPole.yearInstalled,
              condition: createdPole.condition,
              notes: createdPole.notes,
              isTap: poleData.isTap,
              conductorType: poleData.conductorType,
              conductorMaterial: poleData.conductorMaterial,
              conductorSection: poleData.conductorSection,
              cardComment: cardCommentText.isEmpty ? null : cardCommentText,
              cardCommentAttachment: attJsonCreate,
              tapPoleId: poleData.tapPoleId,
              branchType: poleData.branchType,
              tapBranchIndex: poleData.tapBranchIndex,
              startNewTap: poleData.startNewTap,
            );
            await apiService.updatePole(widget.lineId, createdPole.id, poleDataWithAttachments);
          } catch (_) {}
        }
      }
      // Сохраняем опору и оборудование в локальную БД, чтобы сразу после возврата на карту
      // они участвовали в отрисовке (в т.ч. SVG-иконки на линии).
      try {
        final db = ref.read(databaseProvider);
        final dbLineId =
            (createdPole.lineId != 0 && createdPole.lineId == widget.lineId)
                ? createdPole.lineId
                : widget.lineId;
        await db.insertPoleOrReplace(PolesCompanion.insert(
          id: drift.Value(createdPole.id),
          lineId: dbLineId,
          poleNumber: createdPole.poleNumber,
          xPosition: drift.Value(createdPole.xPosition),
          yPosition: drift.Value(createdPole.yPosition),
          poleType: drift.Value(createdPole.poleType),
          height: drift.Value(createdPole.height),
          foundationType: drift.Value(createdPole.foundationType),
          material: drift.Value(createdPole.material),
          yearInstalled: drift.Value(createdPole.yearInstalled),
          condition: drift.Value(createdPole.condition),
          notes: drift.Value(createdPole.notes),
          cardComment: cardCommentText.isEmpty
              ? const drift.Value.absent()
              : drift.Value(cardCommentText),
          cardCommentAttachment: attJsonCreate == null
              ? const drift.Value.absent()
              : drift.Value(attJsonCreate),
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
                defect: eq.defect,
                criticality: eq.criticality,
                defectAttachment: await _resolveEquipmentDefectAttachmentJson(
                  apiService,
                  createdPole.id,
                  eq.defectAttachment,
                ),
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
        Navigator.of(context).pop(<String, dynamic>{
          'success': true,
          'x_position': _longitude!,
          'y_position': _latitude!,
        });
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
          Navigator.of(context).pop(<String, dynamic>{
            'success': true,
            'x_position': _longitude!,
            'y_position': _latitude!,
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Нет связи. Опора сохранена локально и будет синхронизирована при подключении.'),
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
        child: Stack(
          children: [
            Form(
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
                          child: Text(
                            widget.isEditMode
                                ? (_poleNumber.isEmpty ? '...' : (_poleNumber.length > 4 ? '${_poleNumber.substring(0, 4)}…' : _poleNumber))
                                : (_poleNumber.isNotEmpty ? (_poleNumber.length > 4 ? '${_poleNumber.substring(0, 4)}…' : _poleNumber) : '$seq'),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
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
                      const SizedBox(height: 8),
                      // Как в Angular: чекбокс задаёт `is_tap` ("Точка отпайки")
                      Row(
                        children: [
                          Checkbox(
                            value: _isTap,
                            onChanged: (v) => setState(() => _isTap = v ?? false),
                          ),
                          Expanded(
                            child: Text(
                              'Точка отпайки',
                              style: TextStyle(fontSize: 12, color: PatrolColors.textSecondary),
                            ),
                          ),
                        ],
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

                      // Маска номера опоры → в API уходит строка вида 15, 15а, 15/1, 14/12/2
                      PoleNumberMaskField(
                        key: ValueKey(_poleMaskKey),
                        initial: _poleMask,
                        suggestion: _suggestedMask,
                        onApplySuggestion: _suggestedMask == null
                            ? null
                            : () {
                                setState(() {
                                  _poleMask = _suggestedMask!;
                                  _poleNumber = _poleMask.apiString;
                                  _suggestedMask = null;
                                  _poleMaskKey++;
                                });
                              },
                        onChanged: (m) {
                          setState(() {
                            _poleMask = m;
                            _poleNumber = m.apiString;
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Ветка: магистраль или отпайка (как в Angular)
                      if (_showBranchChoice && !(widget.tapPoleId != null && widget.startNewTap)) ...[
                        Text('Ветка', style: TextStyle(fontSize: 12, color: PatrolColors.textSecondary)),
                        const SizedBox(height: 6),
                        Builder(
                          builder: (context) {
                            final seen = <String?>{};
                            final dropdownItems = <DropdownMenuItem<String?>>[
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Магистраль', style: TextStyle(color: PatrolColors.textPrimary)),
                              ),
                              ..._tapBranchesInLine.where((e) => seen.add(e.key)).map(
                                (e) => DropdownMenuItem<String?>(
                                  value: e.key,
                                  child: Text(e.value, style: TextStyle(color: PatrolColors.textPrimary)),
                                ),
                              ),
                            ];
                            final allowed = dropdownItems.map((e) => e.value).toSet();
                            final safeValue = allowed.contains(_branchSelection) ? _branchSelection : null;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: PatrolColors.surfaceCard,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  value: safeValue,
                                  isExpanded: true,
                                  hint: const Text('Магистраль'),
                                  items: dropdownItems,
                                  onChanged: (widget.tapPoleId != null && widget.tapBranchIndex != null)
                                      ? null
                                      : (v) => setState(() => _branchSelection = v),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                      ],

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
                        controller: _materialController,
                        decoration: InputDecoration(
                          labelText: 'Марка опоры',
                          hintText: 'CB-95-1',
                          prefixIcon: const Icon(Icons.search, size: 20, color: PatrolColors.textSecondary),
                          filled: true,
                          fillColor: PatrolColors.surfaceCard,
                        ),
                        style: const TextStyle(color: PatrolColors.textPrimary),
                        onChanged: (v) => _material = v.trim().isEmpty ? null : v.trim(),
                      ),
                      const SizedBox(height: 20),

                      // Оборудование на опоре: 0 из 6
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('ОБОРУДОВАНИЕ НА ОПОРЕ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PatrolColors.textSecondary)),
                          Text('$installedCount из ${_equipmentCategories.length}', style: TextStyle(fontSize: 12, color: PatrolColors.textSecondary)),
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
                                      final loadedForCategory = _loadedEquipment.where((e) {
                                        final t = e.equipmentType.trim().toLowerCase();
                                        final catType = EquipmentReferenceData.categoryToEquipmentType[cat.title]?.trim().toLowerCase();
                                        return catType != null && (t == catType || t.contains(catType) || catType.contains(t));
                                      }).toList();
                                      final existing = existingList.isNotEmpty
                                          ? existingList.first
                                          : (loadedForCategory.isNotEmpty
                                              ? EquipmentFormData(
                                                  equipmentType: loadedForCategory.first.equipmentType,
                                                  name: loadedForCategory.first.name,
                                                  quantity: 1,
                                                  categoryTitle: cat.title,
                                                )
                                              : null);

                                      if (installed && existing != null) {
                                        // Даём выбор: редактировать или удалить.
                                        final action = await showDialog<String>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: Text(cat.title),
                                            content: Text('Оборудование уже добавлено. Что сделать?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(ctx).pop('continue'),
                                                child: const Text('Продолжить'),
                                              ),
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
                                        if (action == 'continue') return;
                                        if (action == 'delete') {
                                          setState(() {
                                            _equipmentInstalled[i] = false;
                                            _pendingEquipment.removeWhere((e) => e.equipmentType == eqType);
                                          });
                                          if (widget.poleId != null) {
                                            final toRemove = _loadedEquipment.where((e) {
                                              final t = e.equipmentType.trim().toLowerCase();
                                              final catType = EquipmentReferenceData.categoryToEquipmentType[cat.title]?.trim().toLowerCase();
                                              return catType != null && (t == catType || t.contains(catType) || catType.contains(t));
                                            }).toList();
                                            final db = ref.read(databaseProvider);
                                            for (final eq in toRemove) {
                                              try {
                                                final apiService = ref.read(apiServiceProvider);
                                                await apiService.deletePoleEquipment(widget.poleId!, eq.id);
                                              } catch (_) {
                                                // Офлайн — удаление только локально
                                              }
                                              await db.deleteEquipment(eq.id);
                                            }
                                            if (mounted) setState(() {
                                              for (final eq in toRemove) _loadedEquipment.remove(eq);
                                            });
                                          }
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
                          if (_cardCommentAttachments.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () {
                                final raw = _encodeCardAttachmentsForDb();
                                if (raw != null) {
                                  showPoleAttachmentsTable(context, raw);
                                }
                              },
                              icon: const Icon(Icons.table_rows, size: 20),
                              label: const Text('Таблица'),
                              style: OutlinedButton.styleFrom(foregroundColor: PatrolColors.textPrimary),
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

              // Кнопка «Начать отпайку» — в режиме редактирования любой опоры (добавить первую опору отпайки от этой)
              if (widget.isEditMode && widget.poleId != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () {
                              final numStr = _poleMask.apiString;
                              final rootNum = numStr.contains('/')
                                  ? numStr.split('/').first.trim()
                                  : numStr;
                              Navigator.of(context).pop(<String, dynamic>{
                                'action': 'start_tap',
                                'tapPoleId': _editTapAnchorId ?? widget.poleId,
                                'lineId': widget.lineId,
                                'tapPoleNumber': rootNum.isEmpty ? null : rootNum,
                              });
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.teal,
                        side: const BorderSide(color: Colors.teal),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.call_split, size: 20),
                      label: const Text('Начать отпайку'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
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
        if (widget.isEditMode && _isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.9),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Загрузка...', style: TextStyle(color: PatrolColors.textPrimary)),
                  ],
                ),
              ),
            ),
          ),
      ],
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
