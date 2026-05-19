import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../../core/config/pole_reference_data.dart';
import '../../../../core/models/equipment_catalog.dart';
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
    this.uid,
    this.defect,
    this.criticality,
    this.categoryTitle,
    this.defectAttachment,
    this.ratedCurrent,
    this.iTh,
    this.ipMax,
    this.tTh,
    this.normalOpen,
    this.retained,
    this.identifiedObjectDescription,
    this.nameplate,
    this.psrSubtype,
    this.installationDisplayName,
    this.nominalVoltageKv,
    this.tmCode,
    this.objectSubtype,
    this.poleCount,
    this.parentObjectRef,
    this.parentMainEquipmentPoleRef,
    this.nominalBreakingCurrentKa,
    this.ownTripTimeSec,
    this.emergencyCurrentA,
    this.continuousCurrentA,
    this.arresterType,
  });
  final String equipmentType;
  /// Диспетчерское наименование (CIM name); для разъединителя — отдельное поле, иначе как раньше = марка.
  final String name;
  final int quantity;
  final String? uid;
  final String? defect;
  final String? criticality;
  /// Название категории для отображения в списке дефектов (Фундамент, Изоляторы и т.д.)
  final String? categoryTitle;
  /// Вложения к описанию иного дефекта: JSON [{"t":"voice"|"photo","p":"path"}]
  final String? defectAttachment;
  final double? ratedCurrent;
  final double? iTh;
  final double? ipMax;
  final double? tTh;
  final bool? normalOpen;
  final bool? retained;
  final String? identifiedObjectDescription;
  final String? nameplate;
  final String? psrSubtype;
  final String? installationDisplayName;
  final double? nominalVoltageKv;
  final String? tmCode;
  final String? objectSubtype;
  final int? poleCount;
  final String? parentObjectRef;
  final String? parentMainEquipmentPoleRef;
  final double? nominalBreakingCurrentKa;
  final double? ownTripTimeSec;
  final double? emergencyCurrentA;
  final double? continuousCurrentA;
  final String? arresterType;
}

/// Диалог добавления оборудования по макету: марка, количество, дефект, критичность.
/// Для категорий вроде «Фундамент» количество фиксировано 1.
class AddEquipmentDialog extends StatefulWidget {
  const AddEquipmentDialog({
    super.key,
    required this.categoryTitle,
    required this.equipmentType,
    this.singleInstance = false,
    this.initialBrand,
  this.initialQuantity = 1,
  this.initialDefect,
  this.initialCriticality,
  this.initialDefectAttachment,
  this.initialUid,
  this.initialRatedCurrent,
  this.initialITh,
  this.initialIpMax,
  this.initialTTh,
  this.initialNormalOpen,
  this.initialRetained,
  this.initialIdentifiedObjectDescription,
  this.initialInstallationDisplayName,
  this.initialPsrSubtype,
  this.initialNominalVoltageKv,
  this.initialTmCode,
  this.initialObjectSubtype,
  this.initialParentObjectRef,
  this.initialNominalBreakingCurrentKa,
  this.initialOwnTripTimeSec,
  this.initialEmergencyCurrentA,
  this.initialContinuousCurrentA,
  this.initialArresterType,
  /// Для разъединителя: диспетчерское наименование (отдельно от марки/таблички).
  this.initialDispatcherName,
  this.initialParentMainEquipmentPoleRef,
  this.directionNeighborOptions,
  /// Марки из серверного справочника (equipment-catalog), подмешиваются к локальному списку.
  this.catalogExtraBrands,
    this.catalogItems,
    this.expectedLineVoltageKv,
    this.allowManualBrandOutsideCatalog = true,
  });

  final String categoryTitle;
  final String equipmentType;
  final bool singleInstance;
  final String? initialBrand;
  final int initialQuantity;
  final String? initialDefect;
  final String? initialCriticality;
  final String? initialDefectAttachment;
  final String? initialUid;
  final double? initialRatedCurrent;
  final double? initialITh;
  final double? initialIpMax;
  final double? initialTTh;
  final bool? initialNormalOpen;
  final bool? initialRetained;
  final String? initialIdentifiedObjectDescription;
  final String? initialInstallationDisplayName;
  final String? initialPsrSubtype;
  final double? initialNominalVoltageKv;
  final String? initialTmCode;
  final String? initialObjectSubtype;
  final String? initialParentObjectRef;
  final double? initialNominalBreakingCurrentKa;
  final double? initialOwnTripTimeSec;
  final double? initialEmergencyCurrentA;
  final double? initialContinuousCurrentA;
  final String? initialArresterType;
  final String? initialDispatcherName;
  final String? initialParentMainEquipmentPoleRef;
  /// Соседние опоры для выбора направления (value/label).
  final List<Map<String, String>>? directionNeighborOptions;
  final List<String>? catalogExtraBrands;
  final List<EquipmentCatalogItem>? catalogItems;
  /// Номинал линии, кВ. Если задан — используем как подсказку для ввода.
  final double? expectedLineVoltageKv;
  /// false — марка только из справочника (инженер-обходчик).
  final bool allowManualBrandOutsideCatalog;

  @override
  State<AddEquipmentDialog> createState() => _AddEquipmentDialogState();
}

class _AddEquipmentDialogState extends State<AddEquipmentDialog> {
  static const String _noBrandLabel = 'Нет';
  static final _decimalInputFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]'));

  final _brandController = TextEditingController();
  final _dispatcherNameController = TextEditingController();
  final _unitNumberController = TextEditingController();
  final _installationNameController = TextEditingController();
  final _nominalVoltageController = TextEditingController();
  final _tmCodeController = TextEditingController();
  final _subtypeController = TextEditingController();
  final _parentObjectController = TextEditingController();
  final _parentMainPoleController = TextEditingController();
  String? _selectedDirectionPoleRef;
  List<Map<String, String>> _directionNeighborOptions = const [];
  final _nominalBreakingCurrentController = TextEditingController();
  final _ownTripTimeController = TextEditingController();
  final _emergencyCurrentController = TextEditingController();
  final _continuousCurrentController = TextEditingController();
  String _arresterType = 'opn';
  final _otherDefectController = TextEditingController();
  late int _quantity;
  String? _selectedDefect;
  String? _selectedCriticality;
  bool _isOtherDefect = false;
  final _ratedCurrentController = TextEditingController();
  final _iThController = TextEditingController();
  final _ipMaxController = TextEditingController();
  final _tThController = TextEditingController();
  bool? _normalOpen;
  bool? _retained;
  String _psrSubtype = 'retractable';
  final List<Map<String, String>> _defectAttachments = [];
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _lastAppliedCatalogLabel;
  bool _electricalExpanded = false;

  String get _equipmentTypeKey =>
      widget.equipmentType.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  bool get _isDisconnector =>
      _equipmentTypeKey == 'disconnector' || _equipmentTypeKey == 'разъединитель';
  bool get _isGroundingSwitch =>
      _equipmentTypeKey == 'grounding_switch' ||
      _equipmentTypeKey == 'зн' ||
      _equipmentTypeKey == 'zn';
  bool get _isBreaker =>
      _equipmentTypeKey == 'breaker' || _equipmentTypeKey == 'выключатель';
  bool get _isRecloser =>
      _equipmentTypeKey == 'recloser' || _equipmentTypeKey == 'реклоузер';
  bool get _isSurgeArrester =>
      _equipmentTypeKey == 'surge_arrester' ||
      _equipmentTypeKey == 'arrester' ||
      _equipmentTypeKey == 'разрядник';
  bool get _isSwitchLike => _isDisconnector || _isGroundingSwitch;
  bool get _isSwitchLikeForm =>
      _isSwitchLike || _isBreaker || _isRecloser;
  bool get _usesDispatcherNameField =>
      _isDisconnector || _isGroundingSwitch || _isBreaker || _isRecloser;
  bool get _isNoBrandSelected {
    final v = _brandController.text.trim().toLowerCase();
    return v == _noBrandLabel.toLowerCase() || v == 'другое';
  }
  bool get _isManualBrandInputMode {
    final brand = _brandController.text.trim().toLowerCase();
    if (brand.isEmpty) return false;
    if (brand == _noBrandLabel.toLowerCase() || brand == 'другое') return false;
    return !_brandSuggestions.any((s) => s.trim().toLowerCase() == brand);
  }
  bool get _canEditElectricalCharacteristics =>
      _isElectricalEquipment && (_isManualBrandInputMode && !_isNoBrandSelected);
  bool get _isElectricalEquipment =>
      _isSwitchLike || _isBreaker || _isRecloser || _isSurgeArrester;

  /// Номинал линии задан — номинальное напряжение оборудования только с линии, без ручного ввода.
  bool get _lineVoltageLocksNominal =>
      widget.expectedLineVoltageKv != null && _isElectricalEquipment;

  String _formatKvForDisplay(double kv) => kv == kv.truncateToDouble()
      ? kv.truncate().toString()
      : kv.toStringAsFixed(1);

  void _applyLineVoltageToNominalControllerIfLocked() {
    if (!_lineVoltageLocksNominal) return;
    _nominalVoltageController.text =
        _formatKvForDisplay(widget.expectedLineVoltageKv!);
  }

  bool get _isNonElectricalStructure {
    const nonElectricalKeys = {
      'фундамент',
      'изолятор',
      'траверса',
      'грозоотвод',
      'foundation',
      'insulator',
      'cross_arm',
      'traverse',
      'lightning_rod',
      'lightning_protection',
      'ground_wire',
    };
    final normalizedCategory = widget.categoryTitle.trim().toLowerCase();
    const nonElectricalCategories = {
      'фундамент',
      'изоляторы',
      'траверсы',
      'грозоотвод',
    };
    return nonElectricalKeys.contains(_equipmentTypeKey) ||
        nonElectricalCategories.contains(normalizedCategory);
  }

  String _sanitizeBrandSuggestion(String raw) {
    var s = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (s.toLowerCase() == 'другое') return _noBrandLabel;
    // Убираем дубли вида "Бренд Модель" + "Модель" для всех типов оборудования.
    final parts = s.split(' ');
    if (parts.length >= 2) {
      final head = parts.first.trim();
      final tail = parts.sublist(1).join(' ').trim();
      final headNorm = _normalizeSwitchBrandKey(head);
      final tailNorm = _normalizeSwitchBrandKey(tail);
      final repeatedHeadInTail =
          headNorm.isNotEmpty &&
          tailNorm.isNotEmpty &&
          tailNorm.startsWith(headNorm) &&
          tailNorm.length > headNorm.length;
      if (repeatedHeadInTail) {
        s = tail;
      }
    }
    if (!_isGroundingSwitch) return s;
    final lower = s.toLowerCase();
    if (lower.startsWith('зн ')) {
      s = s.substring(3).trim();
    }
    if (RegExp(r'^зн-\d+([/.-]\d+)?$', caseSensitive: false).hasMatch(s)) {
      return '';
    }
    return s;
  }

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
    _ratedCurrentController.text =
        _isElectricalEquipment ? (widget.initialRatedCurrent?.toString() ?? '') : '';
    _iThController.text =
        _isElectricalEquipment ? (widget.initialITh?.toString() ?? '') : '';
    _ipMaxController.text =
        _isElectricalEquipment ? (widget.initialIpMax?.toString() ?? '') : '';
    _tThController.text =
        _isElectricalEquipment ? (widget.initialTTh?.toString() ?? '') : '';
    _normalOpen = _isElectricalEquipment ? (widget.initialNormalOpen ?? true) : null;
    _retained = _isElectricalEquipment ? (widget.initialRetained ?? true) : null;
    _unitNumberController.text =
        _isElectricalEquipment ? (widget.initialIdentifiedObjectDescription ?? '') : '';
    _installationNameController.text =
        _isSwitchLikeForm ? (widget.initialInstallationDisplayName ?? '') : '';
    if (_lineVoltageLocksNominal) {
      _nominalVoltageController.text =
          _formatKvForDisplay(widget.expectedLineVoltageKv!);
    } else {
      _nominalVoltageController.text =
          widget.initialNominalVoltageKv?.toString() ??
              (widget.expectedLineVoltageKv != null
                  ? _formatKvForDisplay(widget.expectedLineVoltageKv!)
                  : '');
    }
    _tmCodeController.text = (_isBreaker || _isRecloser || _isSurgeArrester)
        ? (widget.initialTmCode ?? '')
        : '';
    _subtypeController.text =
        (_isBreaker || _isRecloser) ? (widget.initialObjectSubtype ?? '') : '';
    _parentObjectController.text = (_isBreaker || _isRecloser || _isSurgeArrester)
        ? (widget.initialParentObjectRef ?? '')
        : '';
    _parentMainPoleController.text =
        _isElectricalEquipment ? (widget.initialParentMainEquipmentPoleRef ?? '') : '';
    _selectedDirectionPoleRef = !_isSwitchLikeForm ||
            widget.initialParentMainEquipmentPoleRef?.trim().isEmpty == true
        ? null
        : widget.initialParentMainEquipmentPoleRef?.trim();
    _directionNeighborOptions = List<Map<String, String>>.from(
      widget.directionNeighborOptions ?? const <Map<String, String>>[],
    );
    final initialDirection = _selectedDirectionPoleRef;
    if (initialDirection != null && initialDirection.isNotEmpty) {
      final hasInitial = _directionNeighborOptions.any(
        (e) => (e['value'] ?? '').trim() == initialDirection,
      );
      if (!hasInitial) {
        _directionNeighborOptions = [
          ..._directionNeighborOptions,
          <String, String>{
            'value': initialDirection,
            'label': '$initialDirection (вне соседних)',
          },
        ];
      }
    }
    _nominalBreakingCurrentController.text =
        widget.initialNominalBreakingCurrentKa?.toString() ?? '';
    _ownTripTimeController.text = widget.initialOwnTripTimeSec?.toString() ?? '';
    _emergencyCurrentController.text =
        widget.initialEmergencyCurrentA?.toString() ?? '';
    _continuousCurrentController.text =
        widget.initialContinuousCurrentA?.toString() ?? '';
    _psrSubtype = widget.initialPsrSubtype ?? 'retractable';
    _arresterType = widget.initialArresterType ?? 'opn';
    if (_usesDispatcherNameField) {
      _dispatcherNameController.text = (widget.initialDispatcherName ?? '').trim();
      _brandController.text = (widget.initialBrand ?? '').trim();
    }

    final hasInitialElectricalValues =
        widget.initialRatedCurrent != null ||
        widget.initialITh != null ||
        widget.initialIpMax != null ||
        widget.initialTTh != null ||
        widget.initialNormalOpen != null ||
        widget.initialRetained != null ||
        widget.initialNominalVoltageKv != null ||
        widget.initialNominalBreakingCurrentKa != null ||
        widget.initialOwnTripTimeSec != null ||
        widget.initialEmergencyCurrentA != null ||
        widget.initialContinuousCurrentA != null ||
        (widget.initialTmCode?.trim().isNotEmpty == true) ||
        (widget.initialObjectSubtype?.trim().isNotEmpty == true) ||
        (widget.initialPsrSubtype?.trim().isNotEmpty == true) ||
        (widget.initialArresterType?.trim().isNotEmpty == true);

    final initialBrand = _brandController.text.trim();
    if (_isElectricalEquipment &&
        !hasInitialElectricalValues &&
        initialBrand.isNotEmpty &&
        !_isNoBrandSelected) {
      _tryApplyCatalogPresetByInput(initialBrand);
    }
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _brandController.dispose();
    _dispatcherNameController.dispose();
    _unitNumberController.dispose();
    _installationNameController.dispose();
    _nominalVoltageController.dispose();
    _tmCodeController.dispose();
    _subtypeController.dispose();
    _parentObjectController.dispose();
    _parentMainPoleController.dispose();
    _nominalBreakingCurrentController.dispose();
    _ownTripTimeController.dispose();
    _emergencyCurrentController.dispose();
    _continuousCurrentController.dispose();
    _otherDefectController.dispose();
    _ratedCurrentController.dispose();
    _iThController.dispose();
    _ipMaxController.dispose();
    _tThController.dispose();
    super.dispose();
  }

  List<String> get _filteredBrandSuggestions {
    final q = _brandController.text.trim().toLowerCase();
    final all = _brandSuggestions;
    if (q.isEmpty) return all;
    return all.where((s) => s.toLowerCase().contains(q)).toList();
  }

  List<String> get _brandSuggestions {
    final extra = widget.catalogExtraBrands ?? const <String>[];
    final seen = <String>{};
    final out = <String>[];
    for (final x in extra) {
      final k = _sanitizeBrandSuggestion(x);
      if (k.isEmpty || seen.contains(k)) continue;
      if (!_isBrandAllowedForLine(k)) continue;
      seen.add(k);
      out.add(k);
    }
    if (!seen.contains(_noBrandLabel) && _isBrandAllowedForLine(_noBrandLabel)) {
      out.add(_noBrandLabel);
    }
    return out;
  }

  String _catalogLabel(EquipmentCatalogItem item) {
    final full = item.fullName?.trim();
    if (full != null && full.isNotEmpty) return full;
    return '${item.brand} ${item.model}'.trim();
  }

  dynamic _parseAttrsJsonValue(String? attrsJson, List<String> keys) {
    if (attrsJson == null || attrsJson.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(attrsJson);
      if (decoded is! Map) return null;
      for (final key in keys) {
        if (decoded.containsKey(key) && decoded[key] != null) return decoded[key];
      }
    } catch (_) {}
    return null;
  }

  void _tryApplyCatalogPresetByInput(String raw) {
    if (_isNonElectricalStructure) return;
    final input = raw.trim();
    if (input.isEmpty) return;
    final labels = <String>[];
    for (final item in widget.catalogItems ?? const <EquipmentCatalogItem>[]) {
      final full = _catalogLabel(item);
      if (full.trim().isNotEmpty) labels.add(full);
      final brand = item.brand.trim();
      if (brand.isNotEmpty) labels.add(brand);
      final model = item.model.trim();
      if (model.isNotEmpty) labels.add(model);
      final combo = '${item.brand} ${item.model}'.trim();
      if (combo.isNotEmpty) labels.add(combo);
    }
    String? matched;
    for (final l in labels) {
      if (l.trim().toLowerCase() == input.toLowerCase()) {
        matched = l;
        break;
      }
    }
    if (matched == null) {
      _applyKnownSwitchBrandPresetByInput(input);
      return;
    }
    if (_lastAppliedCatalogLabel == matched) return;
    _applyCatalogPresetByLabel(matched);
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.'));
  }

  bool? _toBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    final v = value.toString().trim().toLowerCase();
    if (v == 'true' || v == '1') return true;
    if (v == 'false' || v == '0') return false;
    return null;
  }

  String _normalizeSwitchBrandKey(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '').replaceAll(',', '.');

  bool _applyKnownSwitchBrandPresetByInput(String raw) {
    if (_isNonElectricalStructure) return false;
    final key = _normalizeSwitchBrandKey(raw);
    if (key.isEmpty) return false;

    final kz = RegExp(r'^(КЗ|KZ|K3)-?(\d+(?:\.\d+)?)\/(\d+)$', caseSensitive: false)
        .firstMatch(key);
    if (kz != null) {
      final kv = _toDouble(kz.group(2));
      final current = _toDouble(kz.group(3));
      setState(() {
        _lastAppliedCatalogLabel = key;
        if (kv != null) _nominalVoltageController.text = kv.toString();
        _ratedCurrentController.text = current?.toString() ?? '';
        if (_isGroundingSwitch) _psrSubtype = 'short_circuiter';
        _electricalExpanded = true;
      });
      _applyLineVoltageToNominalControllerIfLocked();
      return true;
    }

    final rgpGnp =
        RegExp(r'^(РГП|RGP|ГНП|GNP)-?(\d+(?:\.\d+)?)$', caseSensitive: false).firstMatch(key);
    if (rgpGnp != null) {
      final kv = _toDouble(rgpGnp.group(2));
      setState(() {
        _lastAppliedCatalogLabel = key;
        if (kv != null) _nominalVoltageController.text = kv.toString();
        if (_isGroundingSwitch) _psrSubtype = 'short_circuiter';
        _electricalExpanded = true;
      });
      _applyLineVoltageToNominalControllerIfLocked();
      return true;
    }

    if (_isSurgeArrester) {
      final opn = RegExp(r'^(ОПНП?|OPN)-?(\d+(?:\.\d+)?)$', caseSensitive: false)
          .firstMatch(key);
      if (opn != null) {
        final kv = _toDouble(opn.group(2));
        setState(() {
          _lastAppliedCatalogLabel = key;
          if (kv != null) _nominalVoltageController.text = kv.toString();
          // Для типовых ОПН берём базовый разрядный ток по умолчанию.
          _ratedCurrentController.text = '10000';
          _arresterType = 'opn';
          _electricalExpanded = true;
        });
        _applyLineVoltageToNominalControllerIfLocked();
        return true;
      }

      final rvoRvm = RegExp(r'^(РВО|RVO|РВМ|RVM)-?(\d+(?:\.\d+)?)$', caseSensitive: false)
          .firstMatch(key);
      if (rvoRvm != null) {
        final kv = _toDouble(rvoRvm.group(2));
        setState(() {
          _lastAppliedCatalogLabel = key;
          if (kv != null) _nominalVoltageController.text = kv.toString();
          _ratedCurrentController.text = '5000';
          _arresterType = 'valve';
          _electricalExpanded = true;
        });
        _applyLineVoltageToNominalControllerIfLocked();
        return true;
      }
    }

    return false;
  }

  bool _isBrandAllowedForLine(String brandRaw) {
    final expected = widget.expectedLineVoltageKv;
    if (expected == null) return true;
    final b = brandRaw.trim();
    if (b.isEmpty) return false;
    if (b.toLowerCase() == 'другое' || b.toLowerCase() == _noBrandLabel.toLowerCase()) return true;
    final voltage = _catalogVoltageByBrand(b) ?? _extractVoltageFromBrand(b);
    if (voltage == null) return false;
    return (voltage - expected).abs() <= 0.001;
  }

  double? _catalogVoltageByBrand(String brandRaw) {
    final brand = brandRaw.trim();
    if (brand.isEmpty) return null;
    if (brand.toLowerCase() == _noBrandLabel.toLowerCase() || brand.toLowerCase() == 'другое') {
      return null;
    }
    String norm(String v) =>
        v.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final key = norm(brand);
    for (final item in widget.catalogItems ?? const <EquipmentCatalogItem>[]) {
      final full = norm(_catalogLabel(item));
      final b = norm(item.brand);
      final model = norm(item.model);
      final combo = norm('${item.brand} ${item.model}');
      if (key == full || key == b || key == model || key == combo) {
        return item.voltageKv;
      }
    }
    return null;
  }

  double? _extractVoltageFromBrand(String brandRaw) {
    final raw = brandRaw.trim().toUpperCase();
    if (raw == _noBrandLabel.toUpperCase() || raw == 'ДРУГОЕ') return null;
    if (raw.isEmpty) return null;
    final withKv = RegExp(r'(\d+(?:[.,]\d+)?)\s*КВ').firstMatch(raw);
    if (withKv != null) {
      return _toDouble(withKv.group(1)?.replaceAll(',', '.'));
    }
    final prefixed = RegExp(
      r'^[A-ZА-Я0-9/._]+-(\d+(?:[.,]\d+)?)(?:/|$)',
    ).firstMatch(raw);
    if (prefixed != null) {
      return _toDouble(prefixed.group(1)?.replaceAll(',', '.'));
    }
    final compact = raw.replaceAll(RegExp(r'\s+'), '');
    final compactPrefixed = RegExp(
      r'^[A-ZА-Я0-9/._]+-(\d+(?:[.,]\d+)?)(?:/|$)',
    ).firstMatch(compact);
    if (compactPrefixed != null) {
      return _toDouble(compactPrefixed.group(1)?.replaceAll(',', '.'));
    }
    return null;
  }

  void _clearElectricalCharacteristics() {
    _lastAppliedCatalogLabel = null;
    _ratedCurrentController.clear();
    _iThController.clear();
    _ipMaxController.clear();
    _tThController.clear();
    _nominalBreakingCurrentController.clear();
    _ownTripTimeController.clear();
    _emergencyCurrentController.clear();
    _continuousCurrentController.clear();
    _normalOpen = null;
    _retained = null;
    _electricalExpanded = false;
  }

  bool _applyCatalogPresetByLabel(String label) {
    if (_isNonElectricalStructure) return false;
    final items = widget.catalogItems ?? const <EquipmentCatalogItem>[];
    String norm(String v) => v.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final key = norm(label);
    final selected = items.where((e) {
      final full = norm(_catalogLabel(e));
      final brand = norm(e.brand);
      final model = norm(e.model);
      final combo = norm('${e.brand} ${e.model}');
      return key == full || key == brand || key == model || key == combo;
    }).toList();
    if (selected.isEmpty) return false;
    final item = selected.first;

    final ratedCurrent = item.currentA ??
        _toDouble(_parseAttrsJsonValue(item.attrsJson, const ['rated_current', 'ratedCurrent']));
    final iTh = _toDouble(_parseAttrsJsonValue(item.attrsJson, const ['i_th', 'iTh']));
    final ipMax = _toDouble(_parseAttrsJsonValue(item.attrsJson, const ['ip_max', 'ipMax']));
    final tTh = _toDouble(_parseAttrsJsonValue(item.attrsJson, const ['t_th', 'tTh']));
    final normalOpen =
        _toBool(_parseAttrsJsonValue(item.attrsJson, const ['normal_open', 'normalOpen']));
    final retained = _toBool(_parseAttrsJsonValue(item.attrsJson, const ['retained']));
    final nominalVoltageKv = item.voltageKv ??
        _toDouble(_parseAttrsJsonValue(item.attrsJson, const ['nominal_voltage_kv', 'nominalVoltageKv', 'voltage_kv']));
    final nominalBreakingCurrentKa = _toDouble(
      _parseAttrsJsonValue(item.attrsJson, const ['nominal_breaking_current_ka', 'nominalBreakingCurrentKa']),
    );
    final ownTripTimeSec = _toDouble(
      _parseAttrsJsonValue(item.attrsJson, const ['own_trip_time_sec', 'ownTripTimeSec']),
    );
    final emergencyCurrentA = _toDouble(
      _parseAttrsJsonValue(item.attrsJson, const ['emergency_current_a', 'emergencyCurrentA']),
    );
    final continuousCurrentA = _toDouble(
      _parseAttrsJsonValue(item.attrsJson, const ['continuous_current_a', 'continuousCurrentA']),
    );
    final tmCodeRaw = _parseAttrsJsonValue(item.attrsJson, const ['tm_code', 'tmCode']);
    final tmCode = tmCodeRaw == null ? null : tmCodeRaw.toString().trim();
    final objectSubtypeRaw = _parseAttrsJsonValue(item.attrsJson, const ['object_subtype', 'objectSubtype']);
    final objectSubtype = objectSubtypeRaw == null ? null : objectSubtypeRaw.toString().trim();
    final psrSubtypeRaw = _parseAttrsJsonValue(item.attrsJson, const ['psr_subtype', 'psrSubtype']);
    final psrSubtype = psrSubtypeRaw == null ? null : psrSubtypeRaw.toString().trim();
    final arresterTypeRaw = _parseAttrsJsonValue(item.attrsJson, const ['arrester_type', 'arresterType']);
    final arresterType = arresterTypeRaw == null ? null : arresterTypeRaw.toString().trim();

    setState(() {
      _lastAppliedCatalogLabel = label;
      _ratedCurrentController.text = ratedCurrent?.toString() ?? '';
      _iThController.text = iTh?.toString() ?? '';
      _ipMaxController.text = ipMax?.toString() ?? '';
      _tThController.text = tTh?.toString() ?? '';
      _normalOpen = normalOpen;
      _retained = retained;
      if (_lineVoltageLocksNominal) {
        _nominalVoltageController.text =
            _formatKvForDisplay(widget.expectedLineVoltageKv!);
      } else if (nominalVoltageKv != null) {
        _nominalVoltageController.text = nominalVoltageKv.toString();
      }
      _nominalBreakingCurrentController.text = nominalBreakingCurrentKa?.toString() ?? '';
      _ownTripTimeController.text = ownTripTimeSec?.toString() ?? '';
      _emergencyCurrentController.text = emergencyCurrentA?.toString() ?? '';
      _continuousCurrentController.text = continuousCurrentA?.toString() ?? '';
      _tmCodeController.text = (tmCode != null && tmCode.isNotEmpty) ? tmCode : '';
      _subtypeController.text =
          (objectSubtype != null && objectSubtype.isNotEmpty) ? objectSubtype : '';
      if (_isDisconnector) {
        _psrSubtype =
            (psrSubtype != null && psrSubtype.isNotEmpty) ? psrSubtype : 'retractable';
      }
      if (_isSurgeArrester) {
        _arresterType = (arresterType != null && arresterType.isNotEmpty) ? arresterType : 'opn';
      }
      _electricalExpanded = true;
    });
    return true;
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

  void _save() {
    final brand = _brandController.text.trim();
    final noBrandSelected = _isNoBrandSelected;
    final isDisconnector = _isDisconnector;
    final isGroundingSwitch = _isGroundingSwitch;
    final isSwitchLikeForm = _isSwitchLikeForm;
    if (brand.isEmpty && !isSwitchLikeForm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Укажите марку оборудования'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (isSwitchLikeForm && brand.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isDisconnector
                ? 'Укажите марку (табличку) разъединителя'
                : 'Укажите марку (табличку) оборудования',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_usesDispatcherNameField && _dispatcherNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isDisconnector
                ? 'Укажите диспетчерское наименование разъединителя'
                : 'Укажите диспетчерское наименование',
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
    double? parseNullableDouble(String text) => double.tryParse(text.trim().replaceAll(',', '.'));
    final expectedLineVoltage = widget.expectedLineVoltageKv;
    final enteredNominalVoltage = _lineVoltageLocksNominal && expectedLineVoltage != null
        ? expectedLineVoltage
        : parseNullableDouble(_nominalVoltageController.text);
    final brandVoltage =
        _catalogVoltageByBrand(brand) ?? _extractVoltageFromBrand(brand);

    if (!widget.allowManualBrandOutsideCatalog &&
        _isElectricalEquipment &&
        !_isNoBrandSelected &&
        _isManualBrandInputMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Выберите марку из справочника. Добавление произвольных марок доступно паспортисту и администратору.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_isElectricalEquipment && expectedLineVoltage != null) {
      if (brandVoltage != null &&
          (brandVoltage - expectedLineVoltage).abs() > 0.001) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Марка оборудования (${brandVoltage.toStringAsFixed(brandVoltage.truncateToDouble() == brandVoltage ? 0 : 1)} кВ) не соответствует линии (${expectedLineVoltage.toStringAsFixed(expectedLineVoltage.truncateToDouble() == expectedLineVoltage ? 0 : 1)} кВ)',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (!_lineVoltageLocksNominal) {
        if (enteredNominalVoltage == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Укажите номинальное напряжение оборудования: ${expectedLineVoltage.toStringAsFixed(expectedLineVoltage.truncateToDouble() == expectedLineVoltage ? 0 : 1)} кВ',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        if ((enteredNominalVoltage - expectedLineVoltage).abs() > 0.001) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Номинал оборудования (${enteredNominalVoltage.toStringAsFixed(enteredNominalVoltage.truncateToDouble() == enteredNominalVoltage ? 0 : 1)} кВ) отличается от линии (${expectedLineVoltage.toStringAsFixed(expectedLineVoltage.truncateToDouble() == expectedLineVoltage ? 0 : 1)} кВ). Сохранение разрешено.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }

    final apiName = _usesDispatcherNameField
        ? _dispatcherNameController.text.trim()
        : brand;
    double? parseElectrical(String text) =>
        _isNonElectricalStructure ? null : parseNullableDouble(text);

    Navigator.of(context).pop(EquipmentFormData(
      equipmentType: widget.equipmentType,
      name: apiName,
      quantity: _quantity,
      uid: (widget.initialUid ?? '').trim().isNotEmpty ? widget.initialUid!.trim() : null,
      defect: defect?.isEmpty == true ? null : defect,
      criticality: criticality,
      categoryTitle: widget.categoryTitle,
      defectAttachment: encodeDefectAttachmentList(_defectAttachments),
      ratedCurrent: _isElectricalEquipment && !noBrandSelected
          ? parseElectrical(_ratedCurrentController.text)
          : null,
      iTh: _isElectricalEquipment && !noBrandSelected ? parseElectrical(_iThController.text) : null,
      ipMax: _isElectricalEquipment && !noBrandSelected ? parseElectrical(_ipMaxController.text) : null,
      tTh: _isElectricalEquipment && !noBrandSelected ? parseElectrical(_tThController.text) : null,
      normalOpen: _isElectricalEquipment && !noBrandSelected ? _normalOpen : null,
      retained: _isElectricalEquipment && !noBrandSelected ? _retained : null,
      identifiedObjectDescription:
          _isElectricalEquipment && _unitNumberController.text.trim().isNotEmpty
          ? _unitNumberController.text.trim()
          : null,
      nameplate: isSwitchLikeForm
          ? (noBrandSelected ? null : (brand.isEmpty ? null : brand))
          : null,
      psrSubtype: isDisconnector
          ? _psrSubtype
          : (isGroundingSwitch ? 'short_circuiter' : null),
      installationDisplayName: isSwitchLikeForm && _installationNameController.text.trim().isNotEmpty
          ? _installationNameController.text.trim()
          : null,
      nominalVoltageKv: _isElectricalEquipment && !noBrandSelected
          ? enteredNominalVoltage
          : null,
      tmCode: (_isBreaker || _isRecloser || _isSurgeArrester) &&
              _tmCodeController.text.trim().isNotEmpty
          ? _tmCodeController.text.trim()
          : null,
      objectSubtype: (_isBreaker || _isRecloser) && _subtypeController.text.trim().isNotEmpty
          ? _subtypeController.text.trim()
          : null,
      poleCount: _isSurgeArrester
          ? null
          : ((_isBreaker || _isRecloser) ? 2 : (_isElectricalEquipment ? 1 : null)),
      parentObjectRef:
          (_isBreaker || _isRecloser || _isSurgeArrester) &&
                  _parentObjectController.text.trim().isNotEmpty
              ? _parentObjectController.text.trim()
              : null,
      parentMainEquipmentPoleRef: _isSwitchLikeForm
          ? (_selectedDirectionPoleRef == null || _selectedDirectionPoleRef!.trim().isEmpty
              ? null
              : _selectedDirectionPoleRef!.trim())
          : (_isElectricalEquipment && _parentMainPoleController.text.trim().isNotEmpty
              ? _parentMainPoleController.text.trim()
              : null),
      nominalBreakingCurrentKa:
          (_isBreaker || _isRecloser) && !noBrandSelected
              ? parseElectrical(_nominalBreakingCurrentController.text)
              : null,
      ownTripTimeSec:
          (_isBreaker || _isRecloser) && !noBrandSelected
              ? parseElectrical(_ownTripTimeController.text)
              : null,
      emergencyCurrentA: _isBreaker && !noBrandSelected
          ? parseElectrical(_emergencyCurrentController.text)
          : null,
      continuousCurrentA: _isBreaker && !noBrandSelected
          ? parseElectrical(_continuousCurrentController.text)
          : null,
      arresterType: _isSurgeArrester ? _arresterType : null,
    ));
  }

  void _onBrandPicked(String value) {
    setState(() {
      if (value.trim().toLowerCase() == _noBrandLabel.toLowerCase() ||
          value.trim().toLowerCase() == 'другое') {
        _brandController.text = _noBrandLabel;
        _clearElectricalCharacteristics();
        return;
      }
      _brandController.text = value;
    });
    if (value.trim().toLowerCase() != _noBrandLabel.toLowerCase() &&
        value.trim().toLowerCase() != 'другое') {
      final applied = _applyCatalogPresetByLabel(value);
      if (!applied) {
        _applyKnownSwitchBrandPresetByInput(value);
      }
    }
  }

  /// Выпадающий список марок с фильтрацией по вводу (поиск по подстроке).
  Widget _buildBrandCatalogDropdown({
    required String labelText,
    required String hintText,
  }) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: _brandController.text),
      optionsBuilder: (textEditingValue) {
        final q = textEditingValue.text.trim().toLowerCase();
        if (q.isEmpty) return _brandSuggestions;
        return _brandSuggestions.where((s) => s.toLowerCase().contains(q));
      },
      displayStringForOption: (o) => o,
      onSelected: _onBrandPicked,
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        if (textEditingController.text != _brandController.text) {
          textEditingController.text = _brandController.text;
        }
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          onFieldSubmitted: (v) => onFieldSubmitted(),
          decoration: InputDecoration(
            labelText: labelText,
            hintText: hintText,
            helperText: 'Начните ввод — список отфильтруется',
            helperMaxLines: 2,
            filled: true,
            fillColor: PatrolColors.surfaceCard,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: const Icon(Icons.arrow_drop_down, color: PatrolColors.textSecondary),
          ),
          style: const TextStyle(color: PatrolColors.textPrimary),
          onChanged: (v) {
            _brandController.text = v;
            setState(() {
              if (v.trim().toLowerCase() == _noBrandLabel.toLowerCase() ||
                  v.trim().toLowerCase() == 'другое') {
                _clearElectricalCharacteristics();
              }
            });
            _tryApplyCatalogPresetByInput(v);
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            color: PatrolColors.surfaceCard,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, minWidth: 280),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(
                      option,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: PatrolColors.textPrimary),
                    ),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
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
              if ((widget.initialUid ?? '').trim().isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: PatrolColors.surfaceCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black26),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('UID', style: TextStyle(fontSize: 11, color: PatrolColors.textSecondary)),
                            const SizedBox(height: 4),
                            SelectableText(
                              widget.initialUid!.trim(),
                              style: const TextStyle(color: PatrolColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Скопировать UID',
                        icon: const Icon(Icons.copy),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: widget.initialUid!.trim()));
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('UID скопирован')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_usesDispatcherNameField) ...[
                TextField(
                  controller: _dispatcherNameController,
                  decoration: InputDecoration(
                    labelText: 'Диспетчерское наименование *',
                    hintText: _isGroundingSwitch
                        ? 'Например: ЗН-3-2с 10'
                        : 'Например: СР 3-2с 10',
                    filled: true,
                    fillColor: PatrolColors.surfaceCard,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  style: const TextStyle(color: PatrolColors.textPrimary),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                _buildBrandCatalogDropdown(
                  labelText: _isGroundingSwitch
                      ? 'Марка (табличка, nameplate)'
                      : 'Марка (табличка, nameplate) *',
                  hintText: _isGroundingSwitch ? 'Например: ЗН-10' : 'Например: GW4-12D(W)1250',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _unitNumberController,
                  decoration: InputDecoration(
                    labelText: 'Примечание',
                    hintText: 'Текст примечания (необязательно)',
                    filled: true,
                    fillColor: PatrolColors.surfaceCard,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  style: const TextStyle(color: PatrolColors.textPrimary),
                ),
                const SizedBox(height: 12),
                if (_isBreaker || _isRecloser || _isSurgeArrester) ...[
                  TextField(
                    controller: _tmCodeController,
                    decoration: InputDecoration(
                      labelText: 'Код ТМ в ИС ПЭС',
                      filled: true,
                      fillColor: PatrolColors.surfaceCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _parentObjectController,
                    decoration: InputDecoration(
                      labelText: 'Родительский объект в базовом дереве',
                      hintText: 'Опора/ЛЭП (как в схеме)',
                      filled: true,
                      fillColor: PatrolColors.surfaceCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _nominalVoltageController,
                  readOnly: _lineVoltageLocksNominal,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters:
                      _lineVoltageLocksNominal ? null : [_decimalInputFormatter],
                  decoration: InputDecoration(
                    labelText: 'Номинальное напряжение, кВ',
                    hintText: _lineVoltageLocksNominal ? null : 'Например: 10',
                    helperText: _lineVoltageLocksNominal
                        ? 'Как у линии (${_formatKvForDisplay(widget.expectedLineVoltageKv!)} кВ), редактирование отключено'
                        : null,
                    helperMaxLines: 2,
                    filled: true,
                    fillColor: PatrolColors.surfaceCard,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                if (_isSwitchLikeForm) ...[
                  DropdownButtonFormField<String>(
                    value: _selectedDirectionPoleRef,
                    decoration: InputDecoration(
                      labelText: 'Направление к соседней опоре',
                      hintText: 'Выберите соседнюю опору',
                      filled: true,
                      fillColor: PatrolColors.surfaceCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Авто (без явного направления)'),
                      ),
                      ..._directionNeighborOptions.map((o) {
                        final value = (o['value'] ?? '').trim();
                        final label = (o['label'] ?? value).trim();
                        return DropdownMenuItem<String>(
                          value: value.isEmpty ? null : value,
                          child: Text(label.isEmpty ? '—' : label),
                        );
                      }),
                    ],
                    onChanged: (v) => setState(() => _selectedDirectionPoleRef = v),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_isSurgeArrester) ...[
                  TextField(
                    controller: _parentMainPoleController,
                    decoration: InputDecoration(
                      labelText: 'Полюс основного оборудования',
                      hintText: 'Участок линии / разъединитель / выключатель',
                      filled: true,
                      fillColor: PatrolColors.surfaceCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_isSurgeArrester) ...[
                  DropdownButtonFormField<String>(
                    value: _arresterType,
                    decoration: InputDecoration(
                      labelText: 'Тип разрядника',
                      filled: true,
                      fillColor: PatrolColors.surfaceCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'valve', child: Text('Вентильный')),
                      DropdownMenuItem(value: 'tube', child: Text('Трубчатый')),
                      DropdownMenuItem(value: 'opn', child: Text('ОПН')),
                    ],
                    onChanged: (v) => setState(() => _arresterType = v ?? 'opn'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_isBreaker || _isRecloser) ...[
                  TextField(
                    controller: _subtypeController,
                    decoration: InputDecoration(
                      labelText: 'Подтип энергообъекта',
                      hintText: 'Выкатной / вакуумный и т.д.',
                      filled: true,
                      fillColor: PatrolColors.surfaceCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_isDisconnector) ...[
                  DropdownButtonFormField<String>(
                    value: _psrSubtype,
                    decoration: InputDecoration(
                      labelText: 'Подтип ПСР',
                      filled: true,
                      fillColor: PatrolColors.surfaceCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'retractable', child: Text('Выкатной разъединитель')),
                      DropdownMenuItem(value: 'sectionalizer', child: Text('Отделитель')),
                    ],
                    onChanged: (v) => setState(() => _psrSubtype = v ?? 'retractable'),
                  ),
                  const SizedBox(height: 12),
                ] else if (_isGroundingSwitch) ...[
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Подтип энергообъекта',
                      filled: true,
                      fillColor: PatrolColors.surfaceCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Короткозамыкатель'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Родительский объект задаётся автоматически по выбранной опоре.',
                    style: TextStyle(fontSize: 11, color: PatrolColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                ],
              ] else ...[
                _buildBrandCatalogDropdown(
                  labelText: 'Марка оборудования *',
                  hintText: 'Выберите марку из справочника',
                ),
              ],
              const SizedBox(height: 16),
              if (!_isNonElectricalStructure)
                ExpansionTile(
                  initiallyExpanded: _electricalExpanded,
                  onExpansionChanged: (v) => setState(() => _electricalExpanded = v),
                  tilePadding: EdgeInsets.zero,
                  collapsedIconColor: PatrolColors.textSecondary,
                  iconColor: PatrolColors.accentBlue,
                  title: const Text(
                    'Электрические характеристики',
                    style: TextStyle(color: PatrolColors.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Switch/ConductingEquipment поля'),
                  children: [
                  if (_lastAppliedCatalogLabel != null &&
                      _lastAppliedCatalogLabel!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Значения подставлены из каталога: $_lastAppliedCatalogLabel. Вы можете изменить их вручную.',
                        style: TextStyle(
                          fontSize: 12,
                          color: PatrolColors.textSecondary,
                        ),
                      ),
                    ),
                  TextField(
                    controller: _ratedCurrentController,
                    readOnly: !_canEditElectricalCharacteristics,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [_decimalInputFormatter],
                    decoration: const InputDecoration(
                      labelText: 'Номинальный ток, А',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _iThController,
                    readOnly: !_canEditElectricalCharacteristics,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [_decimalInputFormatter],
                    decoration: const InputDecoration(
                      labelText: 'Ток термической стойкости, А',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _ipMaxController,
                    readOnly: !_canEditElectricalCharacteristics,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [_decimalInputFormatter],
                    decoration: const InputDecoration(
                      labelText: 'Максимальный пиковый ток КЗ, А',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tThController,
                    readOnly: !_canEditElectricalCharacteristics,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [_decimalInputFormatter],
                    decoration: const InputDecoration(
                      labelText: 'Время воздействия тока термической стойкости, с',
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_isBreaker || _isRecloser) ...[
                    TextField(
                      controller: _nominalBreakingCurrentController,
                      readOnly: !_canEditElectricalCharacteristics,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [_decimalInputFormatter],
                      decoration: const InputDecoration(
                        labelText: 'Номинальный ток отключения, кА',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _ownTripTimeController,
                      readOnly: !_canEditElectricalCharacteristics,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [_decimalInputFormatter],
                      decoration: const InputDecoration(
                        labelText: 'Собственное время отключения, с',
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_isBreaker) ...[
                    TextField(
                      controller: _emergencyCurrentController,
                      readOnly: !_canEditElectricalCharacteristics,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [_decimalInputFormatter],
                      decoration: const InputDecoration(
                        labelText: 'Аварийно-допустимый ток, А',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _continuousCurrentController,
                      readOnly: !_canEditElectricalCharacteristics,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [_decimalInputFormatter],
                      decoration: const InputDecoration(
                        labelText: 'Длительно-допустимый ток, А',
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  ],
                ),
              const SizedBox(height: 8),
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
