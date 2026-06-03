import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/api_service.dart';
import '../../../../core/services/attachment_reader.dart';
import '../../../../core/services/equipment_catalog_cache.dart';
import '../../../../core/database/database.dart' hide Equipment, Pole;
import '../../../../core/models/equipment_catalog.dart';
import '../../../../core/models/power_line.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/utils/mrid.dart';
import '../../../../core/utils/normalize_pole_number.dart';
import '../../../../core/utils/local_pole_sequence.dart';
import '../../../../core/config/pole_reference_data.dart';
import '../../../../core/utils/pole_number_mask.dart';
import '../../../../core/theme/app_theme.dart';
import 'pole_number_mask_field.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/utils/pole_card_attachment_codec.dart';
import '../../../../core/utils/pole_card_comment_codec.dart';
import 'add_equipment_dialog.dart';
import 'filterable_mark_field.dart';
import 'pole_attachments_table_sheet.dart';

/// Категории оборудования на опоре (по макету карточки опоры).
class _EquipmentCategory {
  const _EquipmentCategory(this.title, this.icon);
  final String title;
  final IconData icon;
}

/// Явный выбор «новая ветка от якоря» при «Начать отпайку»; совпадает с Angular `create-object-dialog`.
const String _kBranchNewTapSentinel = '__new_tap__';

/// Пункт списка «Ветка»: подпись + tooltip (цепочка опор), как в веб `buildTapBranchOption`.
class _TapBranchOption {
  const _TapBranchOption({
    required this.value,
    required this.label,
    required this.tooltip,
  });
  final String value;
  final String label;
  final String tooltip;
}

const List<_EquipmentCategory> _equipmentCategories = [
  _EquipmentCategory('Фундамент', Icons.anchor),
  _EquipmentCategory('Изоляторы', Icons.bolt),
  _EquipmentCategory('Траверсы', Icons.settings),
  _EquipmentCategory('Грозоотвод', Icons.flash_on),
  _EquipmentCategory('Разрядники', Icons.shield_outlined),
  _EquipmentCategory('Разъединители', Icons.power),
  // _EquipmentCategory('Выключатели', Icons.toggle_on), // временно отключено
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
  /// У паспортиста/админа можно вводить марки вне справочника; у инженера — только из каталога.
  final bool allowManualBrandOutsideCatalog;

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
    this.allowManualBrandOutsideCatalog = true,
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
  final _structuralDefectController = TextEditingController();
  String? _structuralCrit;
  String? _structuralDefectForApi() {
    final t = _structuralDefectController.text.trim();
    return t.isEmpty ? null : t;
  }

  String? _structuralCritForApi() {
    if (_structuralDefectForApi() == null) return null;
    final c = _structuralCrit?.trim().toLowerCase();
    if (c == null || c.isEmpty) return null;
    if (c == 'high' || c == 'medium' || c == 'low') return c;
    return null;
  }

  String? _conductorType = PoleReferenceData.defaultConductorType;
  String? _conductorMaterial = PoleReferenceData.defaultConductorMaterial;
  String? _conductorSection = PoleReferenceData.defaultConductorSection;
  final _conductorTypeController = TextEditingController();
  List<String> _conductorSuggestions = const [];
  List<String> get _poleBrandOptions {
    final list = List<String>.from(PoleReferenceData.poleBrandsCis);
    final cur = _materialController.text.trim();
    if (cur.isNotEmpty && !list.contains(cur)) {
      list.insert(0, cur);
    }
    return list;
  }

  List<String> get _conductorMarkOptions {
    final list = (_conductorSuggestions.isNotEmpty
            ? _conductorSuggestions
            : PoleReferenceData.conductorTypes)
        .toList();
    final cur = _conductorTypeController.text.trim();
    if (cur.isNotEmpty && !list.contains(cur)) {
      list.insert(0, cur);
    }
    return list;
  }

  /// Поле марки с выпадающим списком, отфильтрованным по вводу (как фильтр в Excel).
  Widget _buildFilterableMarkField({
    required TextEditingController controller,
    required List<String> options,
    required String labelText,
    required String hintText,
    required ValueChanged<String> onChanged,
    String? helperText,
    Widget? prefixIcon,
  }) {
    return FilterableMarkField(
      controller: controller,
      options: options,
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      prefixIcon: prefixIcon,
      onChanged: onChanged,
    );
  }

  void _releaseMarkFieldFocus() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  double? _expectedLineVoltageKv;
  bool _isTap = false;

  /// Показывать выбор «Магистраль» / «Отпайка от X — ветка N» (как в Angular).
  bool _showBranchChoice = false;
  /// Список веток для выбора: value = "tapPoleId:tapBranchIndex".
  List<_TapBranchOption> _tapBranchesInLine = [];
  /// Отпаечные опоры линии (id, pole_number) для подписей.
  List<MapEntry<int, String>> _tapPolesInLine = [];
  /// Выбранная ветка: null = магистраль; [_kBranchNewTapSentinel] = новая ветка от якоря; иначе "tapPoleId:tapBranchIndex".
  String? _branchSelection;
  bool _branchAutofilledApplied = false;

  String _normalizeEquipmentTypeKey(String raw) =>
      raw.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');

  String _canonicalEquipmentType(String rawType) {
    final t = _normalizeEquipmentTypeKey(rawType);
    if (t == 'разъединитель') return 'disconnector';
    if (t == 'зн' || t == 'zn') return 'grounding_switch';
    if (t == 'выключатель') return 'breaker';
    if (t == 'реклоузер') return 'recloser';
    if (t == 'разрядник' || t == 'surge_arrester' || t == 'arrester' || t == 'opn' || t == 'опн') return 'arrester';
    if (t == 'траверса') return 'cross_arm';
    return t;
  }

  bool _equipmentTypeMatches(String left, String right) {
    final a = _canonicalEquipmentType(left);
    final b = _canonicalEquipmentType(right);
    return a == b || a.contains(b) || b.contains(a);
  }

  String? _directionRefFromEquipmentNotes(String? notes) {
    final text = (notes ?? '').trim();
    if (text.isEmpty) return null;
    final m = RegExp(
      r'полюс основного оборудования:\s*([^;]+)',
      caseSensitive: false,
    ).firstMatch(text);
    final value = m?.group(1)?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  String? _nameplateFromEquipmentNotes(String? notes) {
    final text = notes ?? '';
    if (text.trim().isEmpty) return null;
    final m = RegExp(
      r'марка \(nameplate\):\s*([^;]+)',
      caseSensitive: false,
    ).firstMatch(text);
    final value = m?.group(1)?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  String? _stringFromEquipmentNotes(String? notes, String keyLabel) {
    final text = notes ?? '';
    if (text.trim().isEmpty) return null;
    final m = RegExp(
      '${RegExp.escape(keyLabel)}:\\s*([^;]+)',
      caseSensitive: false,
    ).firstMatch(text);
    final value = m?.group(1)?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  double? _doubleFromEquipmentNotes(String? notes, String keyLabel) {
    final raw = _stringFromEquipmentNotes(notes, keyLabel);
    if (raw == null) return null;
    return double.tryParse(raw.replaceAll(',', '.'));
  }

  bool? _boolFromEquipmentNotes(String? notes, String keyLabel) {
    final raw = _stringFromEquipmentNotes(notes, keyLabel)?.toLowerCase();
    if (raw == null) return null;
    if (raw == 'true' || raw == '1' || raw == 'да') return true;
    if (raw == 'false' || raw == '0' || raw == 'нет') return false;
    return null;
  }

  String? _defectFromEquipmentNotes(String? notes) {
    final text = notes ?? '';
    final m = RegExp(r'дефект:\s*([^;]+)', caseSensitive: false).firstMatch(text);
    return m?.group(1)?.trim();
  }

  String? _criticalityFromEquipmentNotes(String? notes) {
    final text = notes ?? '';
    final m = RegExp(r'критичность:\s*(\w+)', caseSensitive: false).firstMatch(text);
    return m?.group(1)?.trim();
  }

  String? _categoryTitleForEquipmentType(String equipmentType) {
    final t = equipmentType.trim().toLowerCase();
    for (final cat in _equipmentCategories) {
      final catType =
          EquipmentReferenceData.categoryToEquipmentType[cat.title]?.trim().toLowerCase();
      if (catType != null &&
          (t == catType || t.contains(catType) || catType.contains(t))) {
        return cat.title;
      }
    }
    return null;
  }

  EquipmentFormData _toFormDataFromLoadedEquipment(Equipment e) {
    final categoryTitle = _categoryTitleForEquipmentType(e.equipmentType);
    return EquipmentFormData(
      equipmentType: e.equipmentType,
      name: e.name,
      quantity: 1,
      uid: e.mrid,
      categoryTitle: categoryTitle,
      defect: e.defect?.trim().isNotEmpty == true
          ? e.defect!.trim()
          : _defectFromEquipmentNotes(e.notes),
      criticality: e.criticality?.trim().isNotEmpty == true
          ? e.criticality!.trim()
          : _criticalityFromEquipmentNotes(e.notes),
      defectAttachment: e.defectAttachment,
      ratedCurrent: e.ratedCurrent,
      iTh: e.iTh,
      ipMax: e.ipMax,
      tTh: e.tTh,
      normalOpen: e.normalOpen,
      retained: e.retained,
      identifiedObjectDescription: e.identifiedObjectDescription,
      nameplate: e.nameplate?.trim().isNotEmpty == true
          ? e.nameplate
          : _nameplateFromEquipmentNotes(e.notes),
      psrSubtype: e.psrSubtype,
      installationDisplayName: e.installationDisplayName,
      nominalVoltageKv: e.nominalVoltageKv,
      tmCode: e.tmCode,
      objectSubtype: e.objectSubtype,
      poleCount: e.poleCount,
      parentObjectRef: e.parentObjectRef,
      parentMainEquipmentPoleRef:
          e.parentMainEquipmentPoleRef ?? _directionRefFromEquipmentNotes(e.notes),
      nominalBreakingCurrentKa: e.nominalBreakingCurrentKa,
      ownTripTimeSec: e.ownTripTimeSec,
      emergencyCurrentA: e.emergencyCurrentA,
      continuousCurrentA: e.continuousCurrentA,
      arresterType: e.arresterType,
    );
  }

  List<EquipmentFormData> _effectiveEquipmentForEditSave() {
    final result = <EquipmentFormData>[..._pendingEquipment];
    for (final loaded in _loadedEquipment) {
      final exists = result.any((p) =>
          (p.uid != null &&
              p.uid!.trim().isNotEmpty &&
              loaded.mrid != null &&
              loaded.mrid!.trim().isNotEmpty &&
              p.uid!.trim() == loaded.mrid!.trim()) ||
          _equipmentTypeMatches(p.equipmentType, loaded.equipmentType));
      if (!exists) {
        result.add(_toFormDataFromLoadedEquipment(loaded));
      }
    }
    return result;
  }

  bool _isSwitchLikeEquipmentType(String rawType) {
    final t = _normalizeEquipmentTypeKey(rawType);
    return t == 'disconnector' ||
        t == 'grounding_switch' ||
        t == 'breaker' ||
        t == 'recloser' ||
        t == 'разъединитель' ||
        t == 'зн' ||
        t == 'выключатель' ||
        t == 'реклоузер';
  }

  bool _usesDispatcherNameForEquipmentType(String rawType) {
    final t = _normalizeEquipmentTypeKey(rawType);
    return t == 'disconnector' ||
        t == 'grounding_switch' ||
        t == 'breaker' ||
        t == 'recloser' ||
        t == 'разъединитель' ||
        t == 'зн' ||
        t == 'выключатель' ||
        t == 'реклоузер';
  }

  List<Map<String, dynamic>> _cardCommentMessages = [];
  final _newCardCommentController = TextEditingController();
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
      final decoded = jsonDecode(jsonStr);
      List<dynamic> list = const [];
      String? templateBranchSelection;
      int? templateLineId;
      if (decoded is List<dynamic>) {
        // Обратная совместимость со старым форматом (только список оборудования).
        list = decoded;
      } else if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        final items = map['equipment'];
        if (items is List<dynamic>) list = items;
        final bs = map['branchSelection'];
        if (bs is String && bs.trim().isNotEmpty) {
          templateBranchSelection = bs.trim();
        }
        final lid = map['lineId'];
        if (lid is num) templateLineId = lid.toInt();
      }
      if (list.isEmpty) return false;
      if (!mounted) return false;
      var added = 0;
      final canApplyBranchFromTemplate =
          widget.tapPoleId == null &&
          !widget.startNewTap &&
          templateBranchSelection != null &&
          templateLineId != null &&
          templateLineId == widget.lineId;
      setState(() {
        if (canApplyBranchFromTemplate) {
          _branchSelection = templateBranchSelection;
          _branchAutofilledApplied = true;
        }
        for (final e in list) {
          final map = e as Map<String, dynamic>;
          final eq = EquipmentFormData(
            equipmentType: map['equipmentType'] as String? ?? '',
            name: map['name'] as String? ?? '',
            quantity: (map['quantity'] as num?)?.toInt() ?? 1,
            uid: map['uid'] as String?,
            defect: null,
            criticality: null,
            categoryTitle: map['categoryTitle'] as String?,
            ratedCurrent: (map['ratedCurrent'] as num?)?.toDouble(),
            iTh: (map['iTh'] as num?)?.toDouble(),
            ipMax: (map['ipMax'] as num?)?.toDouble(),
            tTh: (map['tTh'] as num?)?.toDouble(),
            normalOpen: map['normalOpen'] as bool?,
            retained: map['retained'] as bool?,
            identifiedObjectDescription: map['identifiedObjectDescription'] as String?,
            nameplate: map['nameplate'] as String?,
            psrSubtype: map['psrSubtype'] as String?,
            installationDisplayName: map['installationDisplayName'] as String?,
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
    final equipment = _pendingEquipment
        .where((e) => e.categoryTitle != null && _autofillCategories.contains(e.categoryTitle))
        .map((e) => {
              'equipmentType': e.equipmentType,
              'name': e.name,
              'quantity': e.quantity,
              'uid': e.uid,
              'defect': e.defect,
              'criticality': e.criticality,
              'categoryTitle': e.categoryTitle,
              'ratedCurrent': e.ratedCurrent,
              'iTh': e.iTh,
              'ipMax': e.ipMax,
              'tTh': e.tTh,
              'normalOpen': e.normalOpen,
              'retained': e.retained,
              'identifiedObjectDescription': e.identifiedObjectDescription,
              'nameplate': e.nameplate,
              'psrSubtype': e.psrSubtype,
              'installationDisplayName': e.installationDisplayName,
            })
        .toList();
    final branchForTemplate = (_branchSelection != null &&
            _branchSelection != _kBranchNewTapSentinel &&
            _branchSelection!.trim().isNotEmpty)
        ? _branchSelection!.trim()
        : null;
    final payload = {
      'version': 2,
      'lineId': widget.lineId,
      'branchSelection': branchForTemplate,
      'equipment': equipment,
    };
    prefs.setString(AppConfig.autofillEquipmentTemplateKey, jsonEncode(payload));
  }

  bool _isCategoryInstalled(String categoryTitle) {
    final catType = EquipmentReferenceData.categoryToEquipmentType[categoryTitle]
        ?.trim()
        .toLowerCase();
    if (catType == null) return false;

    final hasPending = _pendingEquipment.any(
      (e) => e.categoryTitle == categoryTitle || _equipmentTypeMatches(e.equipmentType, catType),
    );
    if (hasPending) return true;

    return _loadedEquipment.any((e) {
      return _equipmentTypeMatches(e.equipmentType, catType);
    });
  }

  void _refreshEquipmentInstalledFlags() {
    for (var i = 0; i < _equipmentCategories.length; i++) {
      _equipmentInstalled[i] = _isCategoryInstalled(_equipmentCategories[i].title);
    }
  }

  void _clearAutofillEquipmentFromDraft() {
    _pendingEquipment.removeWhere(
      (e) => e.categoryTitle != null && _autofillCategories.contains(e.categoryTitle),
    );
    if (_branchAutofilledApplied && widget.tapPoleId == null && !widget.startNewTap) {
      _branchSelection = null;
      _branchAutofilledApplied = false;
    }
    _refreshEquipmentInstalledFlags();
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
      final fileBytes = await file.readAsBytes();
      if (fileBytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не удалось прочитать выбранное фото'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      final uid = ref.read(prefsProvider).getInt(AppConfig.userIdKey) ?? 0;
      final auth = ref.read(authServiceProvider);
      String? uname;
      if (auth is AuthStateAuthenticated) {
        uname = auth.user.fullName.isNotEmpty ? auth.user.fullName : auth.user.username;
      }
      final fileName = file.name.trim().isNotEmpty
          ? file.name.trim()
          : 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ext = fileName.contains('.') ? fileName.split('.').last : 'jpg';

      // Для существующей опоры сразу загружаем фото на сервер,
      // чтобы вложение не потерялось при повторном открытии карточки.
      final existingPoleId = widget.poleId;
      if (existingPoleId != null) {
        final api = ref.read(apiServiceProvider);
        final uploaded = await api.uploadPoleAttachment(
          existingPoleId,
          'photo',
          fileBytes,
          fileName,
        );
        final url = uploaded['url']?.toString();
        if (url != null && url.isNotEmpty) {
          setState(() => _cardCommentAttachments.add({
                'id': const Uuid().v4(),
                't': 'photo',
                'url': url,
                if (uploaded['filename'] != null) 'filename': uploaded['filename'],
                if (uploaded['original_filename'] != null)
                  'original_filename': uploaded['original_filename'],
                'added_by': uid,
                'added_at': DateTime.now().toUtc().toIso8601String(),
                if (uploaded['thumbnail_url'] != null)
                  'thumbnail_url': uploaded['thumbnail_url'],
                if (uname != null && uname.isNotEmpty) 'added_by_name': uname,
              }));
          return;
        }
      }

      setState(() => _cardCommentAttachments.add({
            ...PoleCardAttachmentCodec.newPhotoAttachment(
              file.path,
              userId: uid,
              userName: uname,
            ),
            'filename': fileName,
            // На web path из picker часто недоступен при последующей отправке.
            // Сохраняем bytes как fallback до _resolveCardCommentAttachments.
            'bytes_b64': base64Encode(fileBytes),
            'original_ext': ext,
          }));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_formatUploadError(e, fallback: 'Ошибка загрузки фото')),
            backgroundColor: Colors.red,
          ),
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
      final bytesB64 = m['bytes_b64'] as String?;
      final type = m['t'] as String? ?? 'file';
      try {
        List<int> bytes = const [];
        if (bytesB64 != null && bytesB64.isNotEmpty) {
          bytes = base64Decode(bytesB64);
        } else if (path != null && path.isNotEmpty) {
          bytes = await readAttachmentBytes(path);
        }
        if (bytes.isEmpty) continue;
        String ext = 'jpg';
        if (path != null && path.contains('.')) {
          ext = path.split('.').last;
        } else if ((m['original_ext'] as String?)?.isNotEmpty ?? false) {
          ext = (m['original_ext'] as String).trim();
        }
        final filename = (m['filename'] as String?)?.trim().isNotEmpty == true
            ? (m['filename'] as String).trim()
            : 'upload.$ext';
        final result = await api.uploadPoleAttachment(
          poleId,
          type,
          bytes,
          filename,
        );
        final url = result['url'] as String?;
        if (url != null) {
          final entry = <String, dynamic>{'t': type, 'url': url};
          if (result['thumbnail_url'] != null) entry['thumbnail_url'] = result['thumbnail_url'];
          if ((m['id'] as String?)?.isNotEmpty ?? false) entry['id'] = m['id'];
          if ((m['added_by'] as Object?) != null) entry['added_by'] = m['added_by'];
          if ((m['added_at'] as String?)?.isNotEmpty ?? false) entry['added_at'] = m['added_at'];
          if ((m['added_by_name'] as String?)?.isNotEmpty ?? false) {
            entry['added_by_name'] = m['added_by_name'];
          }
          if (result['filename'] != null) entry['filename'] = result['filename'];
          if (result['original_filename'] != null) {
            entry['original_filename'] = result['original_filename'];
          }
          resolved.add(entry);
        }
      } on DioException catch (e) {
        throw StateError(
          'Ошибка загрузки вложения "${m['filename'] ?? 'файл'}": ${_dioErrorMessage(e)}',
        );
      } catch (e) {
        throw StateError(
          'Ошибка загрузки вложения "${m['filename'] ?? 'файл'}": $e',
        );
      }
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
        final type = (m['t'] ?? 'file').toString();
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
          final bn = path.replaceAll('\\', '/').split('/').last;
          final uploadName = bn.trim().isEmpty ? 'defect.$ext' : bn;
          final uploaded = await api.uploadPoleAttachment(poleId, type, bytes, uploadName);
          final url = uploaded['url']?.toString();
          if (url == null || url.isEmpty) continue;
          final entry = <String, dynamic>{'t': type, 'url': url};
          final thumb = uploaded['thumbnail_url']?.toString();
          if (thumb != null && thumb.isNotEmpty) {
            entry['thumbnail_url'] = thumb;
          }
          if (uploaded['filename'] != null) entry['filename'] = uploaded['filename'];
          if (uploaded['original_filename'] != null) {
            entry['original_filename'] = uploaded['original_filename'];
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

  String _absoluteAttachmentUrl(String u) {
    final t = u.trim();
    if (t.isEmpty) return t;
    if (t.startsWith('http://') || t.startsWith('https://')) return t;
    if (t.startsWith('/')) return '${AppConfig.baseUrl}$t';
    return '${AppConfig.baseUrl}/$t';
  }

  /// Веб и общий выбор файла: загрузка сразу на сервер (нужен сохранённый id опоры).
  Future<void> _pickCardCommentFileAny() async {
    final pid = widget.poleId;
    if (pid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Сначала сохраните опору — затем можно добавлять файлы и аудио с диска.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    try {
      final r = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: const [
          'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'tif', 'tiff', 'heic',
          'm4a', 'mp3', 'wav', 'aac', 'ogg',
          'mp4', 'webm', 'mov',
          'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'rtf', 'odt', 'ods',
          'zip', 'rar', '7z',
          'dwg',
        ],
      );
      if (r == null || r.files.isEmpty || !mounted) return;
      final f = r.files.first;
      final bytes = f.bytes;
      final name = f.name;
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось прочитать файл')),
          );
        }
        return;
      }
      final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
      if (!_isAllowedAttachmentExt(ext)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Неподдерживаемый формат файла: .${ext.isEmpty ? 'unknown' : ext}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      var attType = 'file';
      if (const {'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'}.contains(ext)) {
        attType = 'photo';
      } else if (const {'m4a', 'mp3', 'wav', 'aac', 'ogg'}.contains(ext)) {
        attType = 'voice';
      } else if (const {'mp4', 'webm', 'mov'}.contains(ext)) {
        attType = 'video';
      } else if (ext == 'pdf' || ext == 'dwg') {
        attType = 'schema';
      }
      final api = ref.read(apiServiceProvider);
      final res = await api.uploadPoleAttachment(pid, attType, bytes, name);
      final url = res['url'] as String?;
      if (url == null || url.isEmpty) return;
      final uid = ref.read(prefsProvider).getInt(AppConfig.userIdKey) ?? 0;
      final auth = ref.read(authServiceProvider);
      String? uname;
      if (auth is AuthStateAuthenticated) {
        uname = auth.user.fullName.isNotEmpty
            ? auth.user.fullName
            : auth.user.username;
      }
      setState(() {
        _cardCommentAttachments.add({
          'id': const Uuid().v4(),
          't': attType,
          'url': url,
          'filename': name,
          'added_by': uid,
          'added_at': DateTime.now().toUtc().toIso8601String(),
          if (uname != null && uname.isNotEmpty) 'added_by_name': uname,
        });
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_formatUploadError(e, fallback: 'Ошибка загрузки файла')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Веб: выбор аудиофайла с диска как голосового вложения.
  Future<void> _pickCardCommentVoiceFileWeb() async {
    final pid = widget.poleId;
    if (pid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Сначала сохраните опору — затем можно добавить голосовой файл.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    try {
      final r = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['m4a', 'mp3', 'wav', 'aac', 'ogg', 'webm'],
      );
      if (r == null || r.files.isEmpty || !mounted) return;
      final f = r.files.first;
      final bytes = f.bytes;
      final name = f.name;
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось прочитать аудиофайл')),
          );
        }
        return;
      }
      final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
      if (!const {'m4a', 'mp3', 'wav', 'aac', 'ogg', 'webm'}.contains(ext)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Неподдерживаемый формат ГС: .${ext.isEmpty ? 'unknown' : ext}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      final api = ref.read(apiServiceProvider);
      final res = await api.uploadPoleAttachment(pid, 'voice', bytes, name);
      final url = res['url'] as String?;
      if (url == null || url.isEmpty) return;
      final uid = ref.read(prefsProvider).getInt(AppConfig.userIdKey) ?? 0;
      final auth = ref.read(authServiceProvider);
      String? uname;
      if (auth is AuthStateAuthenticated) {
        uname = auth.user.fullName.isNotEmpty
            ? auth.user.fullName
            : auth.user.username;
      }
      setState(() {
        _cardCommentAttachments.add({
          'id': const Uuid().v4(),
          't': 'voice',
          'url': url,
          'filename': name,
          'added_by': uid,
          'added_at': DateTime.now().toUtc().toIso8601String(),
          if (uname != null && uname.isNotEmpty) 'added_by_name': uname,
        });
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_formatUploadError(e, fallback: 'Ошибка загрузки голосового файла')),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  String _dioErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      final detail = data['detail'];
      return detail is String ? detail : detail.toString();
    }
    return e.message ?? e.toString();
  }

  bool _isAllowedAttachmentExt(String ext) {
    const allowed = {
      'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp',
      'm4a', 'mp3', 'wav', 'aac', 'ogg',
      'mp4', 'webm', 'mov',
      'pdf', 'dwg',
    };
    return allowed.contains(ext.toLowerCase());
  }

  String _formatUploadError(Object e, {required String fallback}) {
    if (e is DioException) {
      final detail = _dioErrorMessage(e).trim();
      if (detail.isNotEmpty) return detail;
    }
    final text = e.toString().trim();
    if (text.isNotEmpty) return text;
    return fallback;
  }

  Future<void> _openAttachmentsFieldSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: PatrolColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final hasItems = _cardCommentAttachments.isNotEmpty;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Вложения',
                    style: TextStyle(
                      color: PatrolColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: PatrolColors.textPrimary),
                  title: const Text('Добавить фото', style: TextStyle(color: PatrolColors.textPrimary)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickCommentImage();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.attach_file, color: PatrolColors.textPrimary),
                  title: const Text('Добавить файл', style: TextStyle(color: PatrolColors.textPrimary)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickCardCommentFileAny();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.table_rows, color: hasItems ? PatrolColors.textPrimary : Colors.white38),
                  title: Text(
                    'Открыть таблицу вложений',
                    style: TextStyle(color: hasItems ? PatrolColors.textPrimary : Colors.white38),
                  ),
                  subtitle: Text(
                    hasItems ? 'Вложений: ${_cardCommentAttachments.length}' : 'Нет вложений',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  onTap: hasItems
                      ? () {
                          final raw = _encodeCardAttachmentsForDb();
                          Navigator.of(ctx).pop();
                          if (raw != null) {
                            showPoleAttachmentsTable(context, raw);
                          }
                        }
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
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
          uid: eq.uid,
          defect: null,
          criticality: null,
          categoryTitle: eq.categoryTitle,
          defectAttachment: null,
          ratedCurrent: eq.ratedCurrent,
          iTh: eq.iTh,
          ipMax: eq.ipMax,
          tTh: eq.tTh,
          normalOpen: eq.normalOpen,
          retained: eq.retained,
          identifiedObjectDescription: eq.identifiedObjectDescription,
          nameplate: eq.nameplate,
          psrSubtype: eq.psrSubtype,
          installationDisplayName: eq.installationDisplayName,
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

  /// Три уровня критичности дефекта опоры с цветовой подсветкой (low / medium / high).
  Widget _buildStructuralCriticalityRow() {
    Widget chip(String level, String title) {
      final selected = _structuralCrit == level;
      final accent = _criticalityColor(level);
      return Expanded(
        child: Material(
          color: selected ? accent.withValues(alpha: 0.42) : accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => setState(
              () => _structuralCrit = _structuralCrit == level ? null : level,
            ),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? accent : Colors.transparent,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                  color: PatrolColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Критичность дефекта опоры',
          style: TextStyle(fontSize: 12, color: PatrolColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            chip('low', DefectReferenceData.criticalityLabels['low'] ?? 'Низкая'),
            const SizedBox(width: 8),
            chip('medium', DefectReferenceData.criticalityLabels['medium'] ?? 'Средняя'),
            const SizedBox(width: 8),
            chip('high', DefectReferenceData.criticalityLabels['high'] ?? 'Высокая'),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _structuralCrit = null),
            style: TextButton.styleFrom(
              foregroundColor: PatrolColors.textSecondary,
              padding: const EdgeInsets.only(top: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Не указана'),
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _materialController = TextEditingController();
    _conductorTypeController.text = _conductorType ?? '';
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
    if (!widget.isEditMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadTapBranchesForLine();
        _loadPoleNumberSuggestion();
      });
    }
    if (widget.startNewTap && widget.tapPoleId != null) {
      _branchSelection = _kBranchNewTapSentinel;
    } else if (widget.tapPoleId != null && widget.tapBranchIndex != null) {
      _branchSelection = '${widget.tapPoleId}:${widget.tapBranchIndex}';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadLineVoltageAndConductorCatalog();
    });
  }

  Future<void> _loadLineVoltageAndConductorCatalog() async {
    await _loadExpectedLineVoltageKv();
    await _loadConductorCatalog();
  }

  Future<void> _loadExpectedLineVoltageKv() async {
    double? v;
    try {
      final api = ref.read(apiServiceProvider);
      final line = await api.getPowerLine(widget.lineId);
      v = line.voltageLevel;
    } catch (_) {
      try {
        final db = ref.read(databaseProvider);
        final localLine = await db.getPowerLine(widget.lineId);
        v = localLine?.voltageLevel;
      } catch (_) {
        v = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _expectedLineVoltageKv = v;
    });
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
      _structuralDefectController.text = pole.structuralDefect ?? '';
      _structuralCrit = pole.structuralDefectCriticality;
      _conductorType = pole.conductorType;
      _conductorMaterial = pole.conductorMaterial;
      _conductorSection = pole.conductorSection;
      _conductorTypeController.text = pole.conductorType ?? '';
      _isTap = pole.isTapPole;
      if (pole.tapPoleId != null && pole.tapBranchIndex != null) {
        _branchSelection = '${pole.tapPoleId}:${pole.tapBranchIndex}';
      } else {
        _branchSelection = null;
      }
      _loadedEquipment = equipmentList;
      _cardCommentMessages
        ..clear()
        ..addAll(PoleCardCommentCodec.parse(pole.cardComment));
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

  /// Подпись отпайки в списке: якорь + номер ветки + цепочка опор (как веб `buildTapBranchOption`).
  _TapBranchOption _tapBranchOptionFromLine(
    String valueKey,
    int tapPoleId,
    int branchIndex,
    Map<int, String> tapPoleNames,
    List<Pole> allPoles,
  ) {
    final rawName = tapPoleNames[tapPoleId];
    final anchor = (rawName != null && rawName.trim().isNotEmpty)
        ? rawName.trim()
        : 'Опора $tapPoleId';
    final onBranch = allPoles
        .where((p) =>
            p.tapPoleId != null &&
            p.tapPoleId == tapPoleId &&
            (p.tapBranchIndex ?? 1) == branchIndex)
        .toList()
      ..sort((a, b) => (a.sequenceNumber ?? 0).compareTo(b.sequenceNumber ?? 0));
    final names = onBranch.map((p) {
      final pn = p.poleNumber.trim();
      return pn.isNotEmpty ? pn : 'оп.${p.id}';
    }).toList();
    final chain = names.join(' → ');
    final first = names.isNotEmpty ? names.first : '—';
    final last = names.isNotEmpty ? names.last : '—';
    final tooltip =
        'Якорь: $anchor (id $tapPoleId), индекс отпайки $branchIndex. '
        '${chain.isNotEmpty ? 'Все опоры отпайки: $chain.' : 'На отпайке пока нет учтённых опор.'}';
    if (names.isEmpty) {
      return _TapBranchOption(
        value: valueKey,
        label: '$anchor · отпайка $branchIndex — (пока без опор)',
        tooltip: tooltip,
      );
    }
    if (names.length == 1) {
      return _TapBranchOption(
        value: valueKey,
        label: '$anchor · отпайка $branchIndex — к $first',
        tooltip: tooltip,
      );
    }
    return _TapBranchOption(
      value: valueKey,
      label: '$anchor · отпайка $branchIndex: $first → $last (${names.length} оп.)',
      tooltip: tooltip,
    );
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
        final n = p.poleNumber.trim();
        tapPoleNames[p.id] = n.isNotEmpty ? n : 'Опора ${p.id}';
      }
      final branchSet = <String>{};
      for (final p in poles) {
        if (p.tapPoleId != null) {
          final bi = p.tapBranchIndex ?? 1;
          branchSet.add('${p.tapPoleId}:$bi');
        }
      }
      final branches = branchSet.map((s) {
        final parts = s.split(':');
        final pid = int.tryParse(parts[0]) ?? 0;
        final bi = int.tryParse(parts[1]) ?? 1;
        return _tapBranchOptionFromLine(s, pid, bi, tapPoleNames, poles);
      }).toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      final allowedValues = branches.map((e) => e.value).toSet();
      setState(() {
        _tapPolesInLine = tapPoles.map((p) => MapEntry(p.id, p.poleNumber)).toList();
        _tapBranchesInLine = branches;
        _showBranchChoice = _tapBranchesInLine.isNotEmpty || _tapPolesInLine.isNotEmpty;
        // Нет в списке веток — сброс (для «Начать отпайку» возвращаем sentinel, не магистраль).
        if (_branchSelection != null &&
            _branchSelection != _kBranchNewTapSentinel &&
            !allowedValues.contains(_branchSelection)) {
          _branchSelection =
              !widget.isEditMode && widget.startNewTap && widget.tapPoleId != null
                  ? _kBranchNewTapSentinel
                  : null;
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
          defect: eq.defect,
          criticality: eq.criticality,
          defectAttachment: eq.defectAttachment,
          mrid: eq.mrid,
          nameplate: eq.nameplate ?? _nameplateFromEquipmentNotes(eq.notes),
          ratedCurrent: _doubleFromEquipmentNotes(eq.notes, 'номинальный ток, А'),
          iTh: _doubleFromEquipmentNotes(eq.notes, 'термический ток (i_th), кА'),
          ipMax: _doubleFromEquipmentNotes(eq.notes, 'пиковый ток (ip_max), кА'),
          tTh: _doubleFromEquipmentNotes(eq.notes, 'время терм. стойкости (t_th), c'),
          normalOpen: _boolFromEquipmentNotes(eq.notes, 'normal_open'),
          retained: _boolFromEquipmentNotes(eq.notes, 'retained'),
          identifiedObjectDescription:
              _stringFromEquipmentNotes(eq.notes, 'номер единицы оборудования'),
          psrSubtype: _stringFromEquipmentNotes(eq.notes, 'подтип пср'),
          installationDisplayName:
              _stringFromEquipmentNotes(eq.notes, 'название электроустановки'),
          nominalVoltageKv:
              _doubleFromEquipmentNotes(eq.notes, 'номинальное напряжение, кВ'),
          tmCode: _stringFromEquipmentNotes(eq.notes, 'код ТМ'),
          objectSubtype:
              _stringFromEquipmentNotes(eq.notes, 'подтип энергообъекта'),
          parentObjectRef:
              _stringFromEquipmentNotes(eq.notes, 'родительский объект'),
          parentMainEquipmentPoleRef:
              _stringFromEquipmentNotes(eq.notes, 'полюс основного оборудования'),
          nominalBreakingCurrentKa: _doubleFromEquipmentNotes(
              eq.notes, 'номинальный ток отключения, кА'),
          ownTripTimeSec:
              _doubleFromEquipmentNotes(eq.notes, 'собственное время отключения, c'),
          emergencyCurrentA:
              _doubleFromEquipmentNotes(eq.notes, 'аварийно-допустимый ток, А'),
          continuousCurrentA:
              _doubleFromEquipmentNotes(eq.notes, 'длительно-допустимый ток, А'),
          arresterType: _stringFromEquipmentNotes(eq.notes, 'тип разрядника'),
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
          structuralDefect: driftPole.structuralDefect,
          structuralDefectCriticality: driftPole.structuralDefectCriticality,
          cardComment: driftPole.cardComment,
          cardCommentAttachment: driftPole.cardCommentAttachment,
          createdBy: driftPole.createdBy,
          createdAt: driftPole.createdAt,
          updatedAt: driftPole.updatedAt,
          // Локальная БД не хранит is_tap_pole; не выводим из номера — только с сервера при онлайн-загрузке.
          isTapPole: false,
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
      structuralDefect: drift.Value(_structuralDefectForApi()),
      structuralDefectCriticality: drift.Value(_structuralCritForApi()),
      cardComment: _cardCommentSerialized() == null
          ? const drift.Value.absent()
          : drift.Value(_cardCommentSerialized()!),
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
          (p.uid != null &&
              p.uid!.trim().isNotEmpty &&
              eq.mrid != null &&
              eq.mrid!.trim().isNotEmpty &&
              p.uid!.trim() == eq.mrid!.trim()) ||
          _equipmentTypeMatches(p.equipmentType, eq.equipmentType));
      if (!kept) {
        await db.deleteEquipment(eq.id);
      }
    }

    // Обновляем или добавляем оборудование
    for (final eq in _pendingEquipment) {
      final matching = _loadedEquipment.where((e) =>
          (eq.uid != null &&
              eq.uid!.trim().isNotEmpty &&
              e.mrid != null &&
              e.mrid!.trim().isNotEmpty &&
              eq.uid!.trim() == e.mrid!.trim()) ||
          _equipmentTypeMatches(e.equipmentType, eq.equipmentType)).toList();
      final existingEq = matching.isEmpty ? null : matching.first;
      final existingEqData = existingEq != null ? await db.getEquipment(existingEq.id) : null;
      final notesParts = <String>[];
      if (eq.quantity > 1) notesParts.add('количество: ${eq.quantity}');
      if (eq.nameplate != null && eq.nameplate!.trim().isNotEmpty) {
        notesParts.add('марка (nameplate): ${eq.nameplate!.trim()}');
      }
      if (eq.ratedCurrent != null) notesParts.add('номинальный ток, А: ${eq.ratedCurrent}');
      if (eq.iTh != null) notesParts.add('термический ток (i_th), кА: ${eq.iTh}');
      if (eq.ipMax != null) notesParts.add('пиковый ток (ip_max), кА: ${eq.ipMax}');
      if (eq.tTh != null) notesParts.add('время терм. стойкости (t_th), c: ${eq.tTh}');
      if (eq.normalOpen != null) notesParts.add('normal_open: ${eq.normalOpen}');
      if (eq.retained != null) notesParts.add('retained: ${eq.retained}');
      if (eq.identifiedObjectDescription != null &&
          eq.identifiedObjectDescription!.trim().isNotEmpty) {
        notesParts.add(
          'номер единицы оборудования: ${eq.identifiedObjectDescription!.trim()}',
        );
      }
      if (eq.psrSubtype != null && eq.psrSubtype!.trim().isNotEmpty) {
        notesParts.add('подтип пср: ${eq.psrSubtype!.trim()}');
      }
      if (eq.installationDisplayName != null &&
          eq.installationDisplayName!.trim().isNotEmpty) {
        notesParts.add(
          'название электроустановки: ${eq.installationDisplayName!.trim()}',
        );
      }
      if (eq.nominalVoltageKv != null) {
        notesParts.add('номинальное напряжение, кВ: ${eq.nominalVoltageKv}');
      }
      if (eq.tmCode != null && eq.tmCode!.trim().isNotEmpty) {
        notesParts.add('код ТМ: ${eq.tmCode!.trim()}');
      }
      if (eq.objectSubtype != null && eq.objectSubtype!.trim().isNotEmpty) {
        notesParts.add('подтип энергообъекта: ${eq.objectSubtype!.trim()}');
      }
      if (eq.parentObjectRef != null && eq.parentObjectRef!.trim().isNotEmpty) {
        notesParts.add('родительский объект: ${eq.parentObjectRef!.trim()}');
      }
      if (eq.parentMainEquipmentPoleRef != null &&
          eq.parentMainEquipmentPoleRef!.trim().isNotEmpty) {
        notesParts.add(
          'полюс основного оборудования: ${eq.parentMainEquipmentPoleRef!.trim()}',
        );
      }
      if (eq.nominalBreakingCurrentKa != null) {
        notesParts.add(
          'номинальный ток отключения, кА: ${eq.nominalBreakingCurrentKa}',
        );
      }
      if (eq.ownTripTimeSec != null) {
        notesParts.add('собственное время отключения, c: ${eq.ownTripTimeSec}');
      }
      if (eq.emergencyCurrentA != null) {
        notesParts.add('аварийно-допустимый ток, А: ${eq.emergencyCurrentA}');
      }
      if (eq.continuousCurrentA != null) {
        notesParts.add('длительно-допустимый ток, А: ${eq.continuousCurrentA}');
      }
      if (eq.arresterType != null && eq.arresterType!.trim().isNotEmpty) {
        notesParts.add('тип разрядника: ${eq.arresterType!.trim()}');
      }
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

  String? _cardCommentSerialized() =>
      PoleCardCommentCodec.serialize(_cardCommentMessages);

  Future<void> _sendCardCommentMessage() async {
    final text = _newCardCommentController.text;
    if (text.trim().isEmpty) return;
    try {
      final api = ref.read(apiServiceProvider);
      final user = await api.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _cardCommentMessages = PoleCardCommentCodec.append(
          List<Map<String, dynamic>>.from(_cardCommentMessages),
          text,
          userId: user.id,
          userName: user.fullName.trim().isNotEmpty ? user.fullName : user.username,
        );
        _newCardCommentController.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось добавить комментарий: $e')),
        );
      }
    }
  }

  String _headerBadgeText(int seq) {
    final raw = _poleNumber.trim();
    if (raw.isEmpty) return '$seq';
    final compact = raw.replaceAll(' ', '');
    final slashParts = compact.split('/');
    if (slashParts.length >= 2) {
      final p1 = slashParts[0];
      final p2 = slashParts[1];
      if (p1.isNotEmpty && p2.isNotEmpty) {
        final right = p2.length > 2 ? p2.substring(0, 2) : p2;
        final candidate = '$p1/$right';
        if (candidate.length <= 5) return candidate;
      }
    }
    if (compact.length <= 5) return compact;
    return '${compact.substring(0, 4)}…';
  }

  @override
  void dispose() {
    _materialController.dispose();
    _conductorTypeController.dispose();
    _structuralDefectController.dispose();
    _newCardCommentController.dispose();
    _cardCommentRecorder.dispose();
    super.dispose();
  }

  Future<void> _loadConductorCatalog() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final rows = await apiService.getLineConductorCatalogRaw(
        null,
        _expectedLineVoltageKv,
        true,
        0,
        1000,
      );
      if (!mounted) return;
      final seen = <String>{};
      final suggestions = <String>[];
      for (final row in rows) {
        final mark = (row['mark'] ?? '').toString().trim();
        if (mark.isEmpty) continue;
        final key = mark.toLowerCase();
        if (seen.add(key)) {
          suggestions.add(mark);
        }
      }
      setState(() {
        _conductorSuggestions = suggestions;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _conductorSuggestions = PoleReferenceData.conductorTypes;
      });
    }
  }

  String? _equipmentCatalogTypeCode(String categoryTitle) {
    switch (categoryTitle) {
      case 'Разрядники':
        return 'arrester';
      case 'Выключатели':
        return 'breaker';
      case 'ЗН':
        return 'zn';
      case 'Реклоузеры':
        return 'recloser';
      case 'Разъединители':
        return 'disconnector';
      case 'Траверсы':
        return 'cross_arm';
      default:
        return null;
    }
  }

  Future<List<EquipmentCatalogItem>> _fetchCatalogItems(String categoryTitle) async {
    final code = _equipmentCatalogTypeCode(categoryTitle);
    if (code == null) return const [];
    final prefs = ref.read(prefsProvider);
    List<EquipmentCatalogItem> fromCacheByAliases() {
      final aliases = <String>{
        code,
        if (code == 'zn') 'grounding_switch',
        if (code == 'grounding_switch') 'zn',
        if (code == 'arrester') 'surge_arrester',
        if (code == 'surge_arrester') 'arrester',
      };
      final seen = <int>{};
      final out = <EquipmentCatalogItem>[];
      for (final alias in aliases) {
        for (final item in EquipmentCatalogCache.loadByType(prefs, alias)) {
          if (seen.add(item.id)) out.add(item);
        }
      }
      return out;
    }
    try {
      final api = ref.read(apiServiceProvider);
      var live = await api.getEquipmentCatalog(typeCode: code, limit: 500);
      if (live.isEmpty && (code == 'zn' || code == 'grounding_switch')) {
        final alt = code == 'zn' ? 'grounding_switch' : 'zn';
        live = await api.getEquipmentCatalog(typeCode: alt, limit: 500);
      }
      if (live.isEmpty && (code == 'arrester' || code == 'surge_arrester')) {
        final alt = code == 'arrester' ? 'surge_arrester' : 'arrester';
        live = await api.getEquipmentCatalog(typeCode: alt, limit: 500);
      }
      if (live.isNotEmpty) {
        return live;
      }
      final cached = fromCacheByAliases();
      if (cached.isNotEmpty) return cached;
      return EquipmentCatalogCache.loadByType(prefs, code);
    } catch (_) {
      final cached = fromCacheByAliases();
      if (cached.isNotEmpty) return cached;
      return EquipmentCatalogCache.loadByType(prefs, code);
    }
  }

  Future<EquipmentFormData?> _openEquipmentEditor({
    required String categoryTitle,
    required String equipmentType,
    required bool singleInstance,
    String? initialBrand,
    int initialQuantity = 1,
    String? initialDefect,
    String? initialCriticality,
    String? initialDefectAttachment,
    String? initialUid,
    double? initialRatedCurrent,
    double? initialITh,
    double? initialIpMax,
    double? initialTTh,
    bool? initialNormalOpen,
    bool? initialRetained,
    String? initialIdentifiedObjectDescription,
    String? initialInstallationDisplayName,
    String? initialPsrSubtype,
    double? initialNominalVoltageKv,
    String? initialTmCode,
    String? initialObjectSubtype,
    String? initialParentObjectRef,
    double? initialNominalBreakingCurrentKa,
    double? initialOwnTripTimeSec,
    double? initialEmergencyCurrentA,
    double? initialContinuousCurrentA,
    String? initialArresterType,
    String? initialDispatcherName,
    String? initialParentMainEquipmentPoleRef,
  }) async {
    double? expectedLineVoltageKv;
    try {
      final api = ref.read(apiServiceProvider);
      final line = await api.getPowerLine(widget.lineId);
      expectedLineVoltageKv = line.voltageLevel;
    } catch (_) {
      try {
        final db = ref.read(databaseProvider);
        final localLine = await db.getPowerLine(widget.lineId);
        expectedLineVoltageKv = localLine?.voltageLevel;
      } catch (_) {
        expectedLineVoltageKv = null;
      }
    }

    final catalogItems = await _fetchCatalogItems(categoryTitle);
    final filteredCatalogItems = expectedLineVoltageKv == null
        ? catalogItems
        : catalogItems.where((e) {
            final kv = e.voltageKv;
            if (kv == null) return true;
            return (kv - expectedLineVoltageKv!).abs() <= 0.001;
          }).toList();
    final catalogForDialog =
        filteredCatalogItems.isNotEmpty ? filteredCatalogItems : catalogItems;
    final directionNeighborOptions = await _resolveDirectionNeighborOptions();
    final seen = <String>{};
    final extra = <String>[];
    for (final e in catalogForDialog) {
      final label = (e.fullName != null && e.fullName!.trim().isNotEmpty)
          ? e.fullName!.trim()
          : '${e.brand} ${e.model}'.trim();
      if (label.isEmpty || seen.contains(label)) continue;
      seen.add(label);
      extra.add(label);
    }
    if (!mounted) return null;
    return showDialog<EquipmentFormData>(
      context: context,
      builder: (ctx) => AddEquipmentDialog(
        categoryTitle: categoryTitle,
        equipmentType: equipmentType,
        singleInstance: singleInstance,
        initialBrand: initialBrand,
        initialQuantity: initialQuantity,
        initialDefect: initialDefect,
        initialCriticality: initialCriticality,
        initialDefectAttachment: initialDefectAttachment,
        initialUid: initialUid,
        initialRatedCurrent: initialRatedCurrent,
        initialITh: initialITh,
        initialIpMax: initialIpMax,
        initialTTh: initialTTh,
        initialNormalOpen: initialNormalOpen,
        initialRetained: initialRetained,
        initialIdentifiedObjectDescription: initialIdentifiedObjectDescription,
        initialInstallationDisplayName: initialInstallationDisplayName,
        initialPsrSubtype: initialPsrSubtype,
        initialNominalVoltageKv: initialNominalVoltageKv,
        initialTmCode: initialTmCode,
        initialObjectSubtype: initialObjectSubtype,
        initialParentObjectRef: initialParentObjectRef,
        initialNominalBreakingCurrentKa: initialNominalBreakingCurrentKa,
        initialOwnTripTimeSec: initialOwnTripTimeSec,
        initialEmergencyCurrentA: initialEmergencyCurrentA,
        initialContinuousCurrentA: initialContinuousCurrentA,
        initialArresterType: initialArresterType,
        initialDispatcherName: initialDispatcherName,
        initialParentMainEquipmentPoleRef: initialParentMainEquipmentPoleRef,
        directionNeighborOptions: directionNeighborOptions.isEmpty ? null : directionNeighborOptions,
        catalogExtraBrands: extra.isEmpty ? null : extra,
        catalogItems: catalogForDialog.isEmpty ? null : catalogForDialog,
        expectedLineVoltageKv: expectedLineVoltageKv,
        allowManualBrandOutsideCatalog: widget.allowManualBrandOutsideCatalog,
      ),
    );
  }

  int _poleOrderFromNumberForDirection(String poleNumber) {
    final t = poleNumber.trim();
    if (t.isEmpty) return 1 << 30;
    if (!t.contains('/')) return int.tryParse(t) ?? (1 << 30);
    final parts = t.split('/');
    if (parts.length < 2) return 1 << 30;
    return int.tryParse(parts[1].trim()) ?? (1 << 30);
  }

  List<Pole> _sortPolesForDirection(List<Pole> poles) {
    final out = [...poles];
    out.sort((a, b) {
      final sa = a.sequenceNumber;
      final sb = b.sequenceNumber;
      if (sa != null && sb != null && sa != sb) return sa.compareTo(sb);
      if (sa != null && sb == null) return -1;
      if (sa == null && sb != null) return 1;
      final oa = _poleOrderFromNumberForDirection(a.poleNumber);
      final ob = _poleOrderFromNumberForDirection(b.poleNumber);
      if (oa != ob) return oa.compareTo(ob);
      return a.poleNumber.compareTo(b.poleNumber);
    });
    return out;
  }

  Future<List<Map<String, String>>> _resolveDirectionNeighborOptions() async {
    if (widget.poleId == null) return const [];
    try {
      final api = ref.read(apiServiceProvider);
      final poles = await api.getPoles(widget.lineId);
      if (poles.isEmpty) return const [];
      final byId = {for (final p in poles) p.id: p};
      final current = byId[widget.poleId!];
      if (current == null) return const [];

      final neighbors = <Pole>[];
      void addNeighbor(Pole? p) {
        if (p == null) return;
        if (p.id == current.id) return;
        if (neighbors.any((x) => x.id == p.id)) return;
        neighbors.add(p);
      }

      if (current.tapPoleId == null) {
        final mainPoles = _sortPolesForDirection(
          poles.where((p) => p.tapPoleId == null).toList(),
        );
        final idx = mainPoles.indexWhere((p) => p.id == current.id);
        if (idx > 0) addNeighbor(mainPoles[idx - 1]);
        if (idx >= 0 && idx < mainPoles.length - 1) addNeighbor(mainPoles[idx + 1]);

        final branchGroups = <int, List<Pole>>{};
        for (final p in poles.where((p) => p.tapPoleId == current.id)) {
          final bi = p.tapBranchIndex ?? 1;
          branchGroups.putIfAbsent(bi, () => <Pole>[]).add(p);
        }
        for (final group in branchGroups.values) {
          final sorted = _sortPolesForDirection(group);
          if (sorted.isNotEmpty) addNeighbor(sorted.first);
        }
      } else {
        final anchor = byId[current.tapPoleId!];
        final branchIdx = current.tapBranchIndex ?? 1;
        final branchPoles = _sortPolesForDirection(
          poles.where((p) {
            if (p.tapPoleId != current.tapPoleId) return false;
            if (branchIdx == 1) return (p.tapBranchIndex ?? 1) == 1;
            return p.tapBranchIndex == branchIdx;
          }).toList(),
        );
        final idx = branchPoles.indexWhere((p) => p.id == current.id);
        if (idx > 0) {
          addNeighbor(branchPoles[idx - 1]);
        } else {
          addNeighbor(anchor);
        }
        if (idx >= 0 && idx < branchPoles.length - 1) addNeighbor(branchPoles[idx + 1]);
      }

      return neighbors
          .map((p) {
            final num = p.poleNumber.trim();
            final value = num.isNotEmpty ? num : p.id.toString();
            final label = num.isNotEmpty ? '$num (ID ${p.id})' : 'ID ${p.id}';
            return <String, String>{'value': value, 'label': label};
          })
          .toList();
    } catch (_) {
      return const [];
    }
  }

  List<Pole> _computeAdjacentPolesForEquipment(Pole currentPole, List<Pole> allPoles) {
    final neighbors = <Pole>[];
    void addUnique(Pole? p) {
      if (p == null) return;
      if (p.id == currentPole.id) return;
      if (neighbors.any((x) => x.id == p.id)) return;
      neighbors.add(p);
    }

    final curTapPoleId = currentPole.tapPoleId;
    final curTapBranchIndex = currentPole.tapBranchIndex ?? 1;
    if (curTapPoleId != null) {
      final branch = _sortPolesForDirection(
        allPoles
            .where((p) =>
                p.tapPoleId == curTapPoleId &&
                (p.tapBranchIndex ?? 1) == curTapBranchIndex)
            .toList(),
      );
      final idx = branch.indexWhere((p) => p.id == currentPole.id);
      if (idx > 0) {
        addUnique(branch[idx - 1]);
      } else {
        Pole? anchor;
        for (final p in allPoles) {
          if (p.id == curTapPoleId) {
            anchor = p;
            break;
          }
        }
        addUnique(anchor);
      }
      if (idx >= 0 && idx < branch.length - 1) addUnique(branch[idx + 1]);
    } else {
      final main = _sortPolesForDirection(
        allPoles.where((p) => p.tapPoleId == null).toList(),
      );
      final idx = main.indexWhere((p) => p.id == currentPole.id);
      if (idx > 0) addUnique(main[idx - 1]);
      if (idx >= 0 && idx < main.length - 1) addUnique(main[idx + 1]);

      final firstTapByBranch = <int, Pole>{};
      for (final p in allPoles.where((p) => p.tapPoleId == currentPole.id)) {
        final k = p.tapBranchIndex ?? 1;
        final existing = firstTapByBranch[k];
        final pSeq = p.sequenceNumber ?? 1 << 30;
        final eSeq = existing?.sequenceNumber ?? 1 << 30;
        if (existing == null || pSeq < eSeq) {
          firstTapByBranch[k] = p;
        }
      }
      for (final p in firstTapByBranch.values) {
        addUnique(p);
      }
    }
    return neighbors;
  }

  bool _matchesPoleRefForEquipment(String refRaw, Pole pole) {
    final ref = refRaw.trim().toLowerCase();
    if (ref.isEmpty) return false;
    return ref == pole.id.toString().toLowerCase() || ref == pole.poleNumber.trim().toLowerCase();
  }

  Future<EquipmentCreate> _buildEquipmentCreatePayload(
    ApiServiceWithExport apiService,
    int poleId,
    EquipmentFormData eq,
    String? notes,
    String? defectAttachment,
    int slotIndex,
  ) async {
    double? xPosition;
    double? yPosition;
    try {
      final pole = await apiService.getPole(poleId);
      final poles = pole.lineId > 0 ? await apiService.getPoles(pole.lineId) : <Pole>[];
      final lat0 = pole.yPosition;
      final lng0 = pole.xPosition;

      Pole? neighbor;
      final adjacent = _computeAdjacentPolesForEquipment(pole, poles);
      final ref = (eq.parentMainEquipmentPoleRef ?? '').trim();
      if (ref.isNotEmpty) {
        for (final p in adjacent) {
          if (_matchesPoleRefForEquipment(ref, p)) {
            neighbor = p;
            break;
          }
        }
      }
      neighbor ??= adjacent.isNotEmpty ? adjacent.first : null;

      // Ставим оборудование в нескольких метрах от опоры, а не в процентах пролёта:
      // это исключает "улёт" на длинных участках.
      final dxRaw = (neighbor?.xPosition ?? lng0) - lng0;
      final dyRaw = (neighbor?.yPosition ?? (lat0 + 0.0001)) - lat0;
      final len = math.sqrt(dxRaw * dxRaw + dyRaw * dyRaw);
      final ux = len > 1e-12 ? (dxRaw / len) : 1.0; // вдоль линии (lng)
      final uy = len > 1e-12 ? (dyRaw / len) : 0.0; // вдоль линии (lat)
      final nx = -uy; // поперёк линии (lng)
      final ny = ux; // поперёк линии (lat)

      const baseAlongMeters = 10.0;
      final ring = (slotIndex + 1) ~/ 2;
      final side = slotIndex.isEven ? 1.0 : -1.0;
      final crossMeters = slotIndex == 0 ? 0.0 : side * (8.0 * ring);

      final latRad = lat0 * math.pi / 180.0;
      const metersPerDegLat = 111320.0;
      final metersPerDegLng = math.max(111320.0 * math.cos(latRad).abs(), 1.0);

      final dLat = (baseAlongMeters * uy + crossMeters * ny) / metersPerDegLat;
      final dLng = (baseAlongMeters * ux + crossMeters * nx) / metersPerDegLng;
      yPosition = lat0 + dLat;
      xPosition = lng0 + dLng;
    } catch (_) {}

    return EquipmentCreate(
      equipmentType: eq.equipmentType,
      name: eq.name,
      condition: 'good',
      notes: notes,
      defect: eq.defect,
      criticality: eq.criticality,
      defectAttachment: defectAttachment,
      ratedCurrent: eq.ratedCurrent,
      iTh: eq.iTh,
      ipMax: eq.ipMax,
      tTh: eq.tTh,
      normalOpen: eq.normalOpen,
      retained: eq.retained,
      identifiedObjectDescription: eq.identifiedObjectDescription,
      nameplate: eq.nameplate,
      psrSubtype: eq.psrSubtype,
      installationDisplayName: eq.installationDisplayName,
      tmCode: eq.tmCode,
      objectSubtype: eq.objectSubtype,
      poleCount: eq.poleCount,
      parentObjectRef: eq.parentObjectRef,
      parentMainEquipmentPoleRef: eq.parentMainEquipmentPoleRef,
      nominalVoltageKv: eq.nominalVoltageKv,
      nominalBreakingCurrentKa: eq.nominalBreakingCurrentKa,
      ownTripTimeSec: eq.ownTripTimeSec,
      emergencyCurrentA: eq.emergencyCurrentA,
      continuousCurrentA: eq.continuousCurrentA,
      arresterType: eq.arresterType,
      xPosition: xPosition,
      yPosition: yPosition,
    );
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
      final poleMrid = generateMrid();
      _poleNumber = _poleMask.apiString;
      final normalizedNumber = normalizePoleNumber(_poleNumber);
      final branch = _resolveBranchFieldsForSubmit();
      final linePoles = await db.getPolesByLine(widget.lineId);
      final sequenceNumber = branch.branchType == 'tap'
          ? linePoles
                  .where((p) =>
                      p.tapPoleId == branch.tapPoleId &&
                      (p.tapBranchIndex ?? 1) == (branch.tapBranchIndex ?? 1))
                  .length +
              1
          : nextMainSequenceNumber(linePoles);
      await db.insertPole(PolesCompanion.insert(
        id: drift.Value(localId),
        lineId: widget.lineId,
        poleNumber: normalizedNumber,
        mrid: drift.Value(poleMrid),
        xPosition: drift.Value(_longitude!),  // CIM: x = долгота
        yPosition: drift.Value(_latitude!),   // CIM: y = широта
        poleType: drift.Value(_poleType),
        height: drift.Value(_height),
        foundationType: drift.Value(_foundationType),
        material: drift.Value(_material),
        yearInstalled: drift.Value(_yearInstalled),
        condition: drift.Value(_condition),
        notes: drift.Value(_notes),
        structuralDefect: drift.Value(_structuralDefectForApi()),
        structuralDefectCriticality: drift.Value(_structuralCritForApi()),
        cardComment: _cardCommentSerialized() == null
            ? const drift.Value.absent()
            : drift.Value(_cardCommentSerialized()!),
        cardCommentAttachment: newPoleCardAtt == null
            ? const drift.Value.absent()
            : drift.Value(newPoleCardAtt),
        sequenceNumber: drift.Value(sequenceNumber),
        branchType: drift.Value(branch.branchType),
        tapPoleId: branch.tapPoleId == null
            ? const drift.Value.absent()
            : drift.Value(branch.tapPoleId!),
        tapBranchIndex: branch.tapBranchIndex == null
            ? const drift.Value.absent()
            : drift.Value(branch.tapBranchIndex!),
        isTapPole: drift.Value(_isTap),
        conductorType: _conductorType == null || _conductorType!.isEmpty
            ? const drift.Value.absent()
            : drift.Value(_conductorType!),
        conductorMaterial: _conductorMaterial != null && _conductorMaterial!.isNotEmpty
            ? drift.Value(_conductorMaterial!)
            : const drift.Value.absent(),
        conductorSection: _conductorSection != null && _conductorSection!.isNotEmpty
            ? drift.Value(_conductorSection!)
            : const drift.Value.absent(),
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

  String _labelNewTapBranch() {
    final id = widget.tapPoleId;
    if (id == null) return 'Новая отпайка';
    for (final e in _tapPolesInLine) {
      if (e.key == id) return 'Новая отпайка от ${e.value}';
    }
    return 'Новая отпайка от опоры $id';
  }

  /// Поля ветки для JSON: выбор в списке → `branch_type` / `tap_pole_id` / `tap_branch_index` / `start_new_tap`.
  ({
    int? tapPoleId,
    int? tapBranchIndex,
    String branchType,
    bool startNewTap,
  }) _resolveBranchFieldsForSubmit() {
    int? tapPoleId;
    int? tapBranchIndex;
    var branchType = 'main';
    var startNewTap = false;

    if (widget.isEditMode) {
      final sel = _branchSelection;
      if (sel == null || sel.isEmpty || sel == _kBranchNewTapSentinel) {
        return (
          tapPoleId: null,
          tapBranchIndex: null,
          branchType: 'main',
          startNewTap: false,
        );
      }
      if (sel.contains(':')) {
        final parts = sel.split(':');
        tapPoleId = int.tryParse(parts[0]);
        tapBranchIndex = parts.length > 1 ? int.tryParse(parts[1]) : null;
        if (tapPoleId != null && tapBranchIndex != null) {
          return (
            tapPoleId: tapPoleId,
            tapBranchIndex: tapBranchIndex,
            branchType: 'tap',
            startNewTap: false,
          );
        }
      }
      return (
        tapPoleId: null,
        tapBranchIndex: null,
        branchType: 'main',
        startNewTap: false,
      );
    }

    final hasBranchUi =
        _showBranchChoice && (_tapBranchesInLine.isNotEmpty || _tapPolesInLine.isNotEmpty);

    if (hasBranchUi) {
      final sel = _branchSelection;
      if (sel == null || sel.isEmpty) {
        return (
          tapPoleId: null,
          tapBranchIndex: null,
          branchType: 'main',
          startNewTap: false,
        );
      }
      if (sel == _kBranchNewTapSentinel) {
        final anchor = widget.tapPoleId;
        if (anchor != null) {
          return (
            tapPoleId: anchor,
            tapBranchIndex: null,
            branchType: 'tap',
            startNewTap: true,
          );
        }
        return (
          tapPoleId: null,
          tapBranchIndex: null,
          branchType: 'main',
          startNewTap: false,
        );
      }
      if (sel.contains(':')) {
        final parts = sel.split(':');
        tapPoleId = int.tryParse(parts[0]);
        tapBranchIndex = parts.length > 1 ? int.tryParse(parts[1]) : 1;
        if (tapPoleId != null && tapBranchIndex != null) {
          return (
            tapPoleId: tapPoleId,
            tapBranchIndex: tapBranchIndex,
            branchType: 'tap',
            startNewTap: false,
          );
        }
      }
      return (
        tapPoleId: null,
        tapBranchIndex: null,
        branchType: 'main',
        startNewTap: false,
      );
    }

    if (widget.startNewTap && widget.tapPoleId != null) {
      return (
        tapPoleId: widget.tapPoleId,
        tapBranchIndex: null,
        branchType: 'tap',
        startNewTap: true,
      );
    }
    if (widget.tapPoleId != null && widget.tapBranchIndex != null) {
      return (
        tapPoleId: widget.tapPoleId,
        tapBranchIndex: widget.tapBranchIndex,
        branchType: 'tap',
        startNewTap: false,
      );
    }

    return (
      tapPoleId: null,
      tapBranchIndex: null,
      branchType: 'main',
      startNewTap: false,
    );
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
      _conductorType = _conductorTypeController.text.trim().isEmpty
          ? null
          : _conductorTypeController.text.trim();

      if (_conductorType != null &&
          _conductorType!.isNotEmpty &&
          _expectedLineVoltageKv != null) {
        final rows = await apiService.getLineConductorCatalogRaw(
          _conductorType,
          null,
          true,
          0,
          100,
        );
        final exactRows = rows.where((row) {
          final mark = (row['mark'] ?? '').toString().trim().toLowerCase();
          return mark == _conductorType!.trim().toLowerCase();
        }).toList();
        if (exactRows.isNotEmpty) {
          final hasNominalMatch = exactRows.any((row) {
            final raw = row['voltage_kv'];
            final kv = raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
            return kv != null && (kv - _expectedLineVoltageKv!).abs() <= 0.001;
          });
          if (!hasNominalMatch) {
            throw StateError(
              'Марка "$_conductorType" не соответствует номиналу линии ${_expectedLineVoltageKv!.toStringAsFixed(_expectedLineVoltageKv!.truncateToDouble() == _expectedLineVoltageKv ? 0 : 1)} кВ',
            );
          }
        }
      }
      final cardCommentJson = _cardCommentSerialized();

      final branch = _resolveBranchFieldsForSubmit();
      final tapPoleId = branch.tapPoleId;
      final tapBranchIndex = branch.tapBranchIndex;
      final branchType = branch.branchType;
      final startNewTap = branch.startNewTap;

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
        structuralDefect: _structuralDefectForApi(),
        structuralDefectCriticality: _structuralCritForApi(),
        isTap: _isTap,
        conductorType: _conductorType,
        conductorMaterial: _conductorMaterial,
        conductorSection: _conductorSection,
        cardComment: cardCommentJson,
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
          structuralDefect: poleData.structuralDefect,
          structuralDefectCriticality: poleData.structuralDefectCriticality,
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
            structuralDefect: drift.Value(updatedPole.structuralDefect),
            structuralDefectCriticality:
                drift.Value(updatedPole.structuralDefectCriticality),
            cardComment: cardCommentJson == null
                ? const drift.Value.absent()
                : drift.Value(cardCommentJson),
            cardCommentAttachment: attJsonResolved == null
                ? const drift.Value.absent()
                : drift.Value(attJsonResolved),
            createdBy: drift.Value(updatedPole.createdBy),
            createdAt: drift.Value(updatedPole.createdAt),
            updatedAt: drift.Value(updatedPole.updatedAt),
            isLocal: const drift.Value(false),
            needsSync: const drift.Value(false),
          ));
          // При редактировании обновляем существующие элементы (без смены UID),
          // создаём только новые и удаляем только реально снятые.
          final effectiveEquipment = _effectiveEquipmentForEditSave();
          final touchedExistingIds = <int>{};
          for (var i = 0; i < effectiveEquipment.length; i++) {
            final eq = effectiveEquipment[i];
            try {
              final notesParts = <String>[];
              if (eq.quantity > 1) notesParts.add('количество: ${eq.quantity}');
              if (eq.nameplate != null && eq.nameplate!.trim().isNotEmpty) {
                notesParts.add('марка (nameplate): ${eq.nameplate!.trim()}');
              }
              if (eq.nominalVoltageKv != null) {
                notesParts.add('номинальное напряжение, кВ: ${eq.nominalVoltageKv}');
              }
              if (eq.tmCode != null) notesParts.add('код ТМ: ${eq.tmCode}');
              if (eq.objectSubtype != null) notesParts.add('подтип энергообъекта: ${eq.objectSubtype}');
              if (eq.poleCount != null) notesParts.add('полюс оборудования: ${eq.poleCount}');
              if (eq.parentObjectRef != null) notesParts.add('родительский объект: ${eq.parentObjectRef}');
              if (eq.parentMainEquipmentPoleRef != null) {
                notesParts.add('полюс основного оборудования: ${eq.parentMainEquipmentPoleRef}');
              }
              if (eq.nominalBreakingCurrentKa != null) {
                notesParts.add('номинальный ток отключения, кА: ${eq.nominalBreakingCurrentKa}');
              }
              if (eq.ownTripTimeSec != null) {
                notesParts.add('собственное время отключения, c: ${eq.ownTripTimeSec}');
              }
              if (eq.emergencyCurrentA != null) {
                notesParts.add('аварийно-допустимый ток, А: ${eq.emergencyCurrentA}');
              }
              if (eq.continuousCurrentA != null) {
                notesParts.add('длительно-допустимый ток, А: ${eq.continuousCurrentA}');
              }
              if (eq.arresterType != null) notesParts.add('тип разрядника: ${eq.arresterType}');
              if (eq.defect != null && eq.defect!.isNotEmpty) {
                notesParts.add('дефект: ${eq.defect}');
                if (eq.criticality != null) {
                  notesParts.add('критичность: ${eq.criticality}');
                }
              }
              final resolvedDefectAttachment = await _resolveEquipmentDefectAttachmentJson(
                apiService,
                updatedPole.id,
                eq.defectAttachment,
              );
              final equipmentPayload = await _buildEquipmentCreatePayload(
                apiService,
                updatedPole.id,
                eq,
                notesParts.isEmpty ? null : notesParts.join('; '),
                resolvedDefectAttachment,
                i,
              );
              Equipment? matchedExisting;
              if (eq.uid != null && eq.uid!.trim().isNotEmpty) {
                for (final oldEq in _loadedEquipment) {
                  if (oldEq.mrid != null &&
                      oldEq.mrid!.trim().isNotEmpty &&
                      oldEq.mrid!.trim() == eq.uid!.trim()) {
                    matchedExisting = oldEq;
                    break;
                  }
                }
              }
              matchedExisting ??= _loadedEquipment.cast<Equipment?>().firstWhere(
                    (oldEq) =>
                        oldEq != null &&
                        _equipmentTypeMatches(oldEq.equipmentType, eq.equipmentType),
                    orElse: () => null,
                  );

              final savedEq = matchedExisting != null
                  ? await apiService.updateEquipment(
                      matchedExisting.id,
                      equipmentPayload,
                      poleId: updatedPole.id,
                    )
                  : await apiService.createEquipment(updatedPole.id, equipmentPayload);
              if (matchedExisting != null) touchedExistingIds.add(matchedExisting.id);
              final db2 = ref.read(databaseProvider);
              await db2.insertEquipmentOrReplace(EquipmentCompanion.insert(
                id: drift.Value(savedEq.id),
                poleId: savedEq.poleId,
                equipmentType: savedEq.equipmentType,
                name: savedEq.name,
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
                condition: savedEq.condition,
                notes: drift.Value(savedEq.notes),
                createdBy: savedEq.createdBy,
                createdAt: savedEq.createdAt,
                updatedAt: drift.Value(savedEq.updatedAt),
                isLocal: const drift.Value(false),
                needsSync: const drift.Value(false),
              ));
            } catch (e) {
              throw StateError('Не удалось сохранить оборудование "${eq.name}": $e');
            }
          }
          for (final oldEq in _loadedEquipment) {
            if (touchedExistingIds.contains(oldEq.id)) continue;
            final stillPresent = effectiveEquipment.any((eq) =>
                (eq.uid != null &&
                    eq.uid!.trim().isNotEmpty &&
                    oldEq.mrid != null &&
                    oldEq.mrid!.trim().isNotEmpty &&
                    eq.uid!.trim() == oldEq.mrid!.trim()) ||
                _equipmentTypeMatches(eq.equipmentType, oldEq.equipmentType));
            if (stillPresent) continue;
            try {
              await apiService.deletePoleEquipment(updatedPole.id, oldEq.id);
            } catch (_) {}
            try {
              await db.deleteEquipment(oldEq.id);
            } catch (_) {}
          }
        } catch (e) {
          throw StateError('Ошибка при обновлении оборудования опоры: $e');
        }
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

      // Query from_pole_id — только для опоры в отпайке (якорь из JSON).
      final createdPole = await apiService.createPole(
        widget.lineId,
        poleData,
        fromPoleId: branchType == 'tap' ? tapPoleId : null,
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
              structuralDefect: poleData.structuralDefect,
              structuralDefectCriticality: poleData.structuralDefectCriticality,
              isTap: poleData.isTap,
              conductorType: poleData.conductorType,
              conductorMaterial: poleData.conductorMaterial,
              conductorSection: poleData.conductorSection,
              cardComment: cardCommentJson,
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
          mrid: drift.Value(createdPole.mrid),
          xPosition: drift.Value(createdPole.xPosition),
          yPosition: drift.Value(createdPole.yPosition),
          poleType: drift.Value(createdPole.poleType),
          height: drift.Value(createdPole.height),
          foundationType: drift.Value(createdPole.foundationType),
          material: drift.Value(createdPole.material),
          yearInstalled: drift.Value(createdPole.yearInstalled),
          condition: drift.Value(createdPole.condition),
          notes: drift.Value(createdPole.notes),
          structuralDefect: drift.Value(createdPole.structuralDefect),
          structuralDefectCriticality:
              drift.Value(createdPole.structuralDefectCriticality),
          cardComment: cardCommentJson == null
              ? const drift.Value.absent()
              : drift.Value(cardCommentJson),
          cardCommentAttachment: attJsonCreate == null
              ? const drift.Value.absent()
              : drift.Value(attJsonCreate),
          createdBy: createdPole.createdBy,
          createdAt: createdPole.createdAt,
          updatedAt: drift.Value(createdPole.updatedAt),
          isLocal: const drift.Value(false),
          needsSync: const drift.Value(false),
        ));

        for (var i = 0; i < _pendingEquipment.length; i++) {
          final eq = _pendingEquipment[i];
          try {
            final notesParts = <String>[];
            if (eq.quantity > 1) notesParts.add('количество: ${eq.quantity}');
            if (eq.nameplate != null && eq.nameplate!.trim().isNotEmpty) {
              notesParts.add('марка (nameplate): ${eq.nameplate!.trim()}');
            }
            if (eq.defect != null && eq.defect!.isNotEmpty) {
              notesParts.add('дефект: ${eq.defect}');
              if (eq.criticality != null) notesParts.add('критичность: ${eq.criticality}');
            }
            final resolvedDefectAttachment = await _resolveEquipmentDefectAttachmentJson(
              apiService,
              createdPole.id,
              eq.defectAttachment,
            );
            final equipmentPayload = await _buildEquipmentCreatePayload(
              apiService,
              createdPole.id,
              eq,
              notesParts.isEmpty ? null : notesParts.join('; '),
              resolvedDefectAttachment,
              i,
            );
            final createdEq = await apiService.createEquipment(
              createdPole.id,
              equipmentPayload,
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
          } catch (e) {
            throw StateError('Не удалось создать оборудование "${eq.name}": $e');
          }
        }
      } catch (e) {
        throw StateError('Ошибка при сохранении оборудования опоры: $e');
      }
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
      final errMsg = _dioErrorMessage(e);
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
            SnackBar(content: Text('Ошибка: $errMsg'), backgroundColor: Colors.red),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $errMsg'), backgroundColor: Colors.red),
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
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _headerBadgeText(seq),
                                maxLines: 1,
                                softWrap: false,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
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
                child: GestureDetector(
                  onTap: _releaseMarkFieldFocus,
                  behavior: HitTestBehavior.translucent,
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
                      // `is_tap` / is_tap_pole: только с этой галочкой с карты можно «Начать отпайку» от опоры.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _isTap,
                            onChanged: (v) => setState(() => _isTap = v ?? false),
                          ),
                          Expanded(
                            child: Text(
                              'Отпаечная опора (от неё можно создавать отпайки на карте)',
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
                                        setState(() {
                                          _autofill = v;
                                          if (!v) {
                                            _clearAutofillEquipmentFromDraft();
                                          }
                                        });
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
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Автозаполненные виды оборудования очищены'),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
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

                      // Отпайка: новая от якоря / магистраль / существующие отпайки (JSON = выбор).
                      if (_showBranchChoice) ...[
                        Text('Отпайка', style: TextStyle(fontSize: 12, color: PatrolColors.textSecondary)),
                        const SizedBox(height: 6),
                        Builder(
                          builder: (context) {
                            final dropdownItems = <DropdownMenuItem<String?>>[];
                            if (!widget.isEditMode &&
                                widget.startNewTap &&
                                widget.tapPoleId != null) {
                              dropdownItems.add(
                                DropdownMenuItem<String?>(
                                  value: _kBranchNewTapSentinel,
                                  child: Text(
                                    _labelNewTapBranch(),
                                    style: TextStyle(color: PatrolColors.textPrimary),
                                  ),
                                ),
                              );
                            }
                            dropdownItems.add(
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Магистраль', style: TextStyle(color: PatrolColors.textPrimary)),
                              ),
                            );
                            final seen = <String>{};
                            for (final tb in _tapBranchesInLine) {
                              if (!seen.add(tb.value)) continue;
                              dropdownItems.add(
                                DropdownMenuItem<String?>(
                                  value: tb.value,
                                  child: Tooltip(
                                    message: tb.tooltip,
                                    waitDuration: const Duration(milliseconds: 400),
                                    child: Text(
                                      tb.label,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: PatrolColors.textPrimary),
                                    ),
                                  ),
                                ),
                              );
                            }
                            final allowed = dropdownItems.map((e) => e.value).toSet();
                            final safeValue =
                                allowed.contains(_branchSelection) ? _branchSelection : null;
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
                                  onChanged: (v) => setState(() => _branchSelection = v),
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

                      Text(
                        'Дефект опоры',
                        style: TextStyle(fontSize: 12, color: PatrolColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _structuralDefectController,
                        maxLines: 2,
                        onChanged: (v) {
                          setState(() {
                            if (v.trim().isEmpty && _structuralCrit != null) {
                              _structuralCrit = null;
                            }
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Описание дефекта конструкции',
                          hintText: 'Трещины, коррозия ствола, отклонение…',
                          filled: true,
                          fillColor: PatrolColors.surfaceCard,
                          suffixIcon: _structuralDefectController.text.trim().isNotEmpty
                              ? IconButton(
                                  tooltip: 'Очистить дефект',
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _structuralDefectController.clear();
                                      _structuralCrit = null;
                                    });
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        style: const TextStyle(color: PatrolColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      _buildStructuralCriticalityRow(),
                      const SizedBox(height: 8),

                      _buildFilterableMarkField(
                        controller: _materialController,
                        options: _poleBrandOptions,
                        labelText: 'Марка опоры',
                        hintText: 'Например: СВ95-2',
                        prefixIcon: const Icon(Icons.search, size: 20, color: PatrolColors.textSecondary),
                        onChanged: (v) {
                          setState(() {
                            _materialController.text = v;
                            _material = v.trim().isEmpty ? null : v.trim();
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      _buildFilterableMarkField(
                        controller: _conductorTypeController,
                        options: _conductorMarkOptions,
                        labelText: 'Марка провода ЛЭП',
                        hintText: 'Например: СИП-3 1х70',
                        helperText: _expectedLineVoltageKv == null
                            ? 'Справочник марок из БД'
                            : 'Показаны марки для ${_expectedLineVoltageKv!.toStringAsFixed(_expectedLineVoltageKv!.truncateToDouble() == _expectedLineVoltageKv ? 0 : 1)} кВ',
                        prefixIcon: const Icon(Icons.cable, size: 20, color: PatrolColors.textSecondary),
                        onChanged: (v) {
                          setState(() {
                            _conductorTypeController.text = v;
                            _conductorType = v.trim().isEmpty ? null : v.trim();
                          });
                        },
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
                                      final isSwitchLikeType = _isSwitchLikeEquipmentType(eqType);
                                      final isDispatcherNameType =
                                          _usesDispatcherNameForEquipmentType(eqType);
                                      final singleInstance = EquipmentReferenceData.isSingleInstance(cat.title);
                                      final existingList = _pendingEquipment
                                          .where((e) => _equipmentTypeMatches(e.equipmentType, eqType))
                                          .toList();
                                      final loadedForCategory = _loadedEquipment.where((e) {
                                        final catType = EquipmentReferenceData
                                            .categoryToEquipmentType[cat.title]
                                            ?.trim()
                                            .toLowerCase();
                                        return catType != null &&
                                            _equipmentTypeMatches(e.equipmentType, catType);
                                      }).toList();
                                      final loadedUid = loadedForCategory.isNotEmpty
                                          ? (loadedForCategory.first.mrid?.trim().isNotEmpty == true
                                              ? loadedForCategory.first.mrid!.trim()
                                              : null)
                                          : null;
                                      final loadedDirectionFromNotes = loadedForCategory.isNotEmpty
                                          ? _directionRefFromEquipmentNotes(loadedForCategory.first.notes)
                                          : null;
                                      Equipment? loadedMatch;
                                      if (loadedForCategory.isNotEmpty) {
                                        if (existingList.isNotEmpty &&
                                            existingList.first.uid != null &&
                                            existingList.first.uid!.trim().isNotEmpty) {
                                          for (final x in loadedForCategory) {
                                            if (x.mrid != null &&
                                                x.mrid!.trim().isNotEmpty &&
                                                x.mrid!.trim() ==
                                                    existingList.first.uid!.trim()) {
                                              loadedMatch = x;
                                              break;
                                            }
                                          }
                                        }
                                        loadedMatch ??= loadedForCategory.first;
                                      }
                                      final existing = existingList.isNotEmpty
                                          ? existingList.first
                                          : (loadedForCategory.isNotEmpty
                                              ? EquipmentFormData(
                                                  equipmentType: loadedForCategory.first.equipmentType,
                                                  name: loadedForCategory.first.name,
                                                  quantity: 1,
                                                  uid: loadedForCategory.first.mrid,
                                                  categoryTitle: cat.title,
                                                  defect: loadedForCategory.first.defect
                                                      ?.trim()
                                                      .isNotEmpty ==
                                                          true
                                                      ? loadedForCategory
                                                          .first
                                                          .defect!
                                                      : _defectFromEquipmentNotes(
                                                          loadedForCategory
                                                              .first
                                                              .notes),
                                                  criticality: loadedForCategory
                                                          .first
                                                          .criticality
                                                          ?.trim()
                                                          .isNotEmpty ==
                                                      true
                                                      ? loadedForCategory
                                                          .first
                                                          .criticality
                                                      : _criticalityFromEquipmentNotes(
                                                          loadedForCategory
                                                              .first
                                                              .notes),
                                                  defectAttachment:
                                                      loadedForCategory
                                                          .first
                                                          .defectAttachment,
                                                  ratedCurrent: loadedForCategory.first.ratedCurrent,
                                                  iTh: loadedForCategory.first.iTh,
                                                  ipMax: loadedForCategory.first.ipMax,
                                                  tTh: loadedForCategory.first.tTh,
                                                  normalOpen: loadedForCategory.first.normalOpen,
                                                  retained: loadedForCategory.first.retained,
                                                  identifiedObjectDescription:
                                                      loadedForCategory.first.identifiedObjectDescription,
                                                  nameplate: loadedForCategory.first.nameplate,
                                                  psrSubtype: loadedForCategory.first.psrSubtype,
                                                  nominalVoltageKv:
                                                      loadedForCategory.first.nominalVoltageKv,
                                                  tmCode: loadedForCategory.first.tmCode,
                                                  objectSubtype:
                                                      loadedForCategory.first.objectSubtype,
                                                  parentObjectRef:
                                                      loadedForCategory.first.parentObjectRef,
                                                  parentMainEquipmentPoleRef:
                                                      loadedForCategory
                                                          .first
                                                          .parentMainEquipmentPoleRef,
                                                  nominalBreakingCurrentKa:
                                                      loadedForCategory
                                                          .first
                                                          .nominalBreakingCurrentKa,
                                                  ownTripTimeSec:
                                                      loadedForCategory.first.ownTripTimeSec,
                                                  emergencyCurrentA:
                                                      loadedForCategory.first.emergencyCurrentA,
                                                  continuousCurrentA:
                                                      loadedForCategory
                                                          .first
                                                          .continuousCurrentA,
                                                  arresterType:
                                                      loadedForCategory.first.arresterType,
                                                  installationDisplayName:
                                                      loadedForCategory.first.installationDisplayName,
                                                )
                                              : null);
                                      final sourceEq = loadedMatch != null
                                          ? _toFormDataFromLoadedEquipment(loadedMatch)
                                          : existing;

                                      if (installed && existing != null) {
                                        final src = sourceEq ?? existing;
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
                                            _pendingEquipment.removeWhere(
                                              (e) => _equipmentTypeMatches(e.equipmentType, eqType),
                                            );
                                          });
                                          if (widget.poleId != null) {
                                            final toRemove = _loadedEquipment.where((e) {
                                              final catType = EquipmentReferenceData
                                                  .categoryToEquipmentType[cat.title]
                                                  ?.trim()
                                                  .toLowerCase();
                                              return catType != null &&
                                                  _equipmentTypeMatches(e.equipmentType, catType);
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
                                          final result = await _openEquipmentEditor(
                                            categoryTitle: cat.title,
                                            equipmentType: eqType,
                                            singleInstance: singleInstance,
                                            initialBrand: isSwitchLikeType
                                                ? ((loadedMatch != null &&
                                                            loadedMatch.nameplate?.trim().isNotEmpty == true)
                                                        ? loadedMatch.nameplate!
                                                        : ((src.nameplate?.trim().isNotEmpty == true)
                                                            ? src.nameplate!
                                                            : ''))
                                                : src.name,
                                            initialQuantity: src.quantity,
                                            initialDefect: src.defect,
                                            initialCriticality: src.criticality,
                                            initialDefectAttachment: src.defectAttachment,
                                            initialRatedCurrent: src.ratedCurrent,
                                            initialITh: src.iTh,
                                            initialIpMax: src.ipMax,
                                            initialTTh: src.tTh,
                                            initialNormalOpen: src.normalOpen,
                                            initialRetained: src.retained,
                                            initialUid: src.uid ?? loadedUid,
                                            initialIdentifiedObjectDescription:
                                                src.identifiedObjectDescription,
                                            initialInstallationDisplayName:
                                                src.installationDisplayName,
                                            initialPsrSubtype: src.psrSubtype,
                                            initialNominalVoltageKv:
                                                src.nominalVoltageKv,
                                            initialTmCode: src.tmCode,
                                            initialObjectSubtype:
                                                src.objectSubtype,
                                            initialParentObjectRef:
                                                src.parentObjectRef,
                                            initialParentMainEquipmentPoleRef:
                                                src.parentMainEquipmentPoleRef ??
                                                    loadedDirectionFromNotes,
                                            initialNominalBreakingCurrentKa:
                                                src.nominalBreakingCurrentKa,
                                            initialOwnTripTimeSec:
                                                src.ownTripTimeSec,
                                            initialEmergencyCurrentA:
                                                src.emergencyCurrentA,
                                            initialContinuousCurrentA:
                                                src.continuousCurrentA,
                                            initialArresterType:
                                                src.arresterType,
                                            initialDispatcherName: isSwitchLikeType
                                                ? (isDispatcherNameType ? src.name : null)
                                                : null,
                                          );
                                          if (result != null && mounted) {
                                            _releaseMarkFieldFocus();
                                            setState(() {
                                              _pendingEquipment.removeWhere(
                                                (e) => _equipmentTypeMatches(e.equipmentType, eqType),
                                              );
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
                                          _pendingEquipment.removeWhere(
                                            (e) => _equipmentTypeMatches(e.equipmentType, eqType),
                                          );
                                        });
                                        return;
                                      }

                                      final result = await _openEquipmentEditor(
                                        categoryTitle: cat.title,
                                        equipmentType: eqType,
                                        singleInstance: singleInstance,
                                        initialQuantity: singleInstance ? 1 : 1,
                                      );
                                      if (result != null && mounted) {
                                        _releaseMarkFieldFocus();
                                        setState(() {
                                          _pendingEquipment.removeWhere(
                                            (e) => _equipmentTypeMatches(e.equipmentType, eqType),
                                          );
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
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black26),
                        ),
                        child: _cardCommentMessages.isEmpty &&
                                _cardCommentAttachments.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text(
                                    'Нет сообщений и вложений',
                                    style: TextStyle(
                                      color: PatrolColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              )
                            : ListView(
                                padding: const EdgeInsets.all(8),
                                children: [
                                  ..._cardCommentMessages.map((m) {
                                    final whoRaw = (m['user_name'] as String?)?.trim();
                                    final who = whoRaw != null && whoRaw.isNotEmpty
                                        ? whoRaw
                                        : (m['user_id'] != null
                                            ? 'id ${m['user_id']}'
                                            : '—');
                                    final when = PoleCardCommentCodec.formatDateTime(
                                      m['at'] as String?,
                                    );
                                    final voiceUrl =
                                        (m['voice_url'] as String?)?.trim() ?? '';
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: PatrolColors.surfaceCard,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: Colors.black.withValues(
                                              alpha: 0.08,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    who,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  when,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            if ((m['text'] as String?)
                                                    ?.trim()
                                                    .isNotEmpty ??
                                                false)
                                              Text(
                                                '${m['text']}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  height: 1.35,
                                                ),
                                              ),
                                            if (voiceUrl.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.mic,
                                                    size: 18,
                                                    color:
                                                        PatrolColors.accentBlue,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  TextButton(
                                                    onPressed: () async {
                                                      final uri = Uri.parse(
                                                        _absoluteAttachmentUrl(
                                                          voiceUrl,
                                                        ),
                                                      );
                                                      if (await canLaunchUrl(
                                                        uri,
                                                      )) {
                                                        await launchUrl(
                                                          uri,
                                                          mode: LaunchMode
                                                              .externalApplication,
                                                        );
                                                      }
                                                    },
                                                    child: const Text(
                                                      'Прослушать голос',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                  if (_cardCommentAttachments.isNotEmpty)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: PatrolColors.surfaceCard,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.black.withValues(
                                            alpha: 0.08,
                                          ),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Вложения (${_cardCommentAttachments.length})',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 6,
                                            children:
                                                _cardCommentAttachments
                                                    .asMap()
                                                    .entries
                                                    .map((e) {
                                                      final type =
                                                          (e.value['t']
                                                                  as String?)
                                                              ?.toLowerCase() ??
                                                          '';
                                                      final isVoice =
                                                          type == 'voice';
                                                      final isFile =
                                                          type == 'file' ||
                                                          type == 'schema' ||
                                                          type == 'video';
                                                      final label =
                                                          isVoice
                                                              ? 'Голос'
                                                              : (isFile
                                                                  ? 'Файл'
                                                                  : 'Фото');
                                                      final icon =
                                                          isVoice
                                                              ? Icons.mic
                                                              : (isFile
                                                                  ? Icons
                                                                      .attach_file
                                                                  : Icons.photo);
                                                      return Chip(
                                                        label: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              icon,
                                                              size: 16,
                                                              color:
                                                                  PatrolColors
                                                                      .textPrimary,
                                                            ),
                                                            const SizedBox(
                                                              width: 4,
                                                            ),
                                                            Text(
                                                              label,
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                        deleteIcon: const Icon(
                                                          Icons.close,
                                                          size: 18,
                                                        ),
                                                        onDeleted:
                                                            () => setState(
                                                              () =>
                                                                  _cardCommentAttachments
                                                                      .removeAt(
                                                                        e.key,
                                                                      ),
                                                            ),
                                                      );
                                                    })
                                                    .toList(),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _newCardCommentController,
                              decoration: InputDecoration(
                                labelText: 'Сообщение',
                                hintText: 'Введите текст…',
                                filled: true,
                                fillColor: PatrolColors.surfaceCard,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              style: const TextStyle(color: PatrolColors.textPrimary),
                              minLines: 1,
                              maxLines: 3,
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            onPressed: _isLoading ? null : _sendCardCommentMessage,
                            icon: const Icon(Icons.send),
                            tooltip: 'Отправить',
                            style: IconButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _openAttachmentsFieldSheet,
                              icon: const Icon(Icons.attach_file, size: 20),
                              label: Text(
                                _cardCommentAttachments.isEmpty
                                    ? 'Вложения'
                                    : 'Вложения (${_cardCommentAttachments.length})',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: PatrolColors.textPrimary,
                              ),
                            ),
                          ),
                          if (kIsWeb) ...[
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _isLoading ? null : _pickCardCommentVoiceFileWeb,
                              icon: const Icon(Icons.mic, size: 20),
                              label: const Text('Голос'),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: PatrolColors.textPrimary),
                            ),
                          ],
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
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                ),
              ),

              // Кнопка «Начать отпайку»
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
