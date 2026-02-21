import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;

import '../../../../core/config/app_config.dart';
import '../../../../core/database/database.dart' as drift_db;
import '../../../../core/models/power_line.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/pending_sync_provider.dart';
import '../../../../core/theme/app_theme.dart';

class CreateSessionPage extends ConsumerStatefulWidget {
  const CreateSessionPage({super.key});

  @override
  ConsumerState<CreateSessionPage> createState() => _CreateSessionPageState();
}

class _CreateSessionPageState extends ConsumerState<CreateSessionPage> {
  List<drift_db.PowerLine> _powerLines = [];
  bool _loadingLines = true;
  drift_db.PowerLine? _selectedLine;
  final _noteController = TextEditingController();

  double? _latitude;
  double? _longitude;
  double? _accuracyMeters;
  bool _gpsLoading = true;
  bool _gpsWarning = false;
  Timer? _gpsWarningTimer;

  @override
  void initState() {
    super.initState();
    _loadPowerLines();
    _captureGps();
    _gpsWarningTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _gpsLoading && (_latitude == null && _longitude == null)) {
        setState(() {
          _gpsWarning = true;
          _gpsLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _gpsWarningTimer?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadPowerLines() async {
    final db = ref.read(drift_db.databaseProvider);
    final list = await db.getAllPowerLines();
    if (mounted) {
      setState(() {
        _powerLines = list;
        _loadingLines = false;
      });
    }
  }

  Future<void> _captureGps() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() { _gpsLoading = false; });
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (mounted) setState(() { _gpsLoading = false; });
          return;
        }
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
          _accuracyMeters = pos.accuracy;
          _gpsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _gpsLoading = false; });
    }
  }

  String _accuracyLabel() {
    if (_accuracyMeters == null) return '—';
    if (_accuracyMeters! <= 10) return '±5 м';
    if (_accuracyMeters! <= 30) return '±20 м';
    if (_accuracyMeters! <= 150) return '±100 м';
    return '±${_accuracyMeters!.round()} м';
  }

  /// Показать диалог создания ЛЭП. После успешного создания обновляет список и выбирает новую линию.
  Future<void> _showCreatePowerLineDialog() async {
    final nameController = TextEditingController();
    final voltageController = TextEditingController(text: '110');
    final lengthController = TextEditingController();
    final descriptionController = TextEditingController();

    final newId = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Создать новую линию'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Название *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: voltageController,
                decoration: const InputDecoration(
                  labelText: 'Напряжение (кВ)',
                  hintText: '0.4, 6, 10, 35, 110, 220, 330, 500, 750',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: lengthController,
                decoration: const InputDecoration(
                  labelText: 'Длина (км)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Описание',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Название обязательно для заполнения'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              final name = nameController.text.trim();
              final code = name;
              final voltageLevel = double.tryParse(voltageController.text) ?? 0.0;
              final length = double.tryParse(lengthController.text);
              final branchId = 1;
              final status = 'active';
              final description = descriptionController.text.trim().isEmpty
                  ? null
                  : descriptionController.text.trim();
              final powerLineData = PowerLineCreate(
                name: name,
                code: code,
                voltageLevel: voltageLevel,
                length: length,
                branchId: branchId,
                status: status,
                description: description,
              );
              try {
                final apiService = ref.read(apiServiceProvider);
                final db = ref.read(drift_db.databaseProvider);
                final created = await apiService.createPowerLine(powerLineData);
                final lineCode = created.code.trim().isEmpty
                    ? 'LEP-${created.id.toRadixString(16).toUpperCase().padLeft(8, '0')}'
                    : created.code;
                await db.insertPowerLineOrReplace(drift_db.PowerLinesCompanion.insert(
                  id: drift.Value(created.id),
                  name: created.name,
                  code: lineCode,
                  voltageLevel: created.voltageLevel ?? 0.0,
                  length: drift.Value(created.length),
                  branchId: created.branchId ?? 1,
                  createdBy: created.createdBy,
                  status: created.status,
                  description: drift.Value(created.description),
                  createdAt: created.createdAt,
                  updatedAt: drift.Value(created.updatedAt),
                  isLocal: const drift.Value(false),
                  needsSync: const drift.Value(false),
                ));
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop(created.id);
              } on DioException catch (e) {
                final isOffline = e.type == DioExceptionType.connectionError ||
                    e.type == DioExceptionType.connectionTimeout ||
                    e.type == DioExceptionType.unknown;
                if (!isOffline) {
                  String message;
                  final data = e.response?.data;
                  if (data is Map && data['detail'] != null) {
                    final d = data['detail'];
                    message = d is String ? d : d.toString();
                  } else if (e.response?.statusCode == 400) {
                    message = 'Проверьте введённые данные: название, напряжение (кВ), длина (км).';
                  } else {
                    message = 'Ошибка создания линии: ${e.message}';
                  }
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(message), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
                    );
                  }
                  return;
                }
                final prefs = ref.read(prefsProvider);
                final db = ref.read(drift_db.databaseProvider);
                int localId = prefs.getInt(AppConfig.lastLocalPowerLineIdKey) ?? -1;
                localId--;
                await prefs.setInt(AppConfig.lastLocalPowerLineIdKey, localId);
                final userId = prefs.getInt(AppConfig.userIdKey) ?? 0;
                final now = DateTime.now();
                await db.insertPowerLine(drift_db.PowerLinesCompanion.insert(
                  id: drift.Value(localId),
                  name: name,
                  code: code,
                  voltageLevel: voltageLevel,
                  length: length != null ? drift.Value(length) : const drift.Value.absent(),
                  branchId: branchId,
                  createdBy: userId,
                  status: status,
                  description: drift.Value(description),
                  createdAt: now,
                  updatedAt: drift.Value(now),
                  isLocal: const drift.Value(true),
                  needsSync: const drift.Value(true),
                ));
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop(localId);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('Ошибка создания линии: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );

    if (newId != null && mounted) {
      await _loadPowerLines();
      if (mounted) {
        drift_db.PowerLine? newLine;
        for (final pl in _powerLines) {
          if (pl.id == newId) {
            newLine = pl;
            break;
          }
        }
        if (newLine != null) {
          setState(() => _selectedLine = newLine);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newLine != null
                ? 'Линия «${newLine.name}» создана и выбрана для обхода'
                : 'Линия создана'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (_selectedLine == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите линию из справочника'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final startedAt = DateTime.now();
    final prefs = ref.read(prefsProvider);
    final db = ref.read(drift_db.databaseProvider);
    final authState = ref.read(authStateProvider);
    final userId = authState is AuthStateAuthenticated ? authState.user.id : null;

    // Всегда сохраняем в локальную БД со статусом «Ожидает синхронизации»
    final note = _noteController.text.trim();
    final localId = await db.insertPatrolSession(
      drift_db.PatrolSessionsCompanion.insert(
        powerLineId: _selectedLine!.id,
        note: drift.Value(note.isEmpty ? null : note),
        startedAt: startedAt,
        syncStatus: const drift.Value('pending'),
        userId: drift.Value(userId),
      ),
    );

    await prefs.setInt(AppConfig.activeSessionPowerLineIdKey, _selectedLine!.id);
    await prefs.setString(AppConfig.activeSessionStartTimeKey, startedAt.toIso8601String());
    await prefs.setString(AppConfig.activeSessionNoteKey, note);
    await prefs.setInt(AppConfig.activeSessionLocalIdKey, localId);
    if (_latitude != null) {
      await prefs.setDouble(AppConfig.activeSessionLatKey, _latitude!);
    } else {
      await prefs.remove(AppConfig.activeSessionLatKey);
    }
    if (_longitude != null) {
      await prefs.setDouble(AppConfig.activeSessionLonKey, _longitude!);
    } else {
      await prefs.remove(AppConfig.activeSessionLonKey);
    }

    ref.invalidate(pendingPatrolSessionsCountProvider);
    ref.invalidate(hasPendingSyncProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Сохранено локально. Ожидает синхронизации.'),
        backgroundColor: Colors.orange,
      ),
    );
    context.go('/map');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PatrolColors.background,
      appBar: AppBar(
        backgroundColor: PatrolColors.background,
        elevation: 0,
        title: const Text(
          'Новый обход',
          style: TextStyle(color: PatrolColors.textPrimary, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: PatrolColors.textPrimary),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: PatrolColors.textPrimary),
            onPressed: () => context.go('/'),
          ),
        ],
      ),
      body: _loadingLines
          ? const Center(
              child: CircularProgressIndicator(color: PatrolColors.accent),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _GpsBlock(
                    latitude: _latitude,
                    longitude: _longitude,
                    accuracyLabel: _accuracyLabel(),
                    loading: _gpsLoading,
                    warning: _gpsWarning,
                    onRetry: _captureGps,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'ЛИНИЯ ИЛИ ВЛ',
                    style: TextStyle(
                      fontSize: 12,
                      color: PatrolColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _powerLines.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: PatrolColors.surfaceCard,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Нет линий в справочнике. Создайте новую линию или загрузите данные с сервера.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: PatrolColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: _showCreatePowerLineDialog,
                                icon: const Icon(Icons.add_road, size: 20, color: PatrolColors.accent),
                                label: const Text(
                                  'Создать новую линию',
                                  style: TextStyle(color: PatrolColors.accent),
                                ),
                              ),
                            ],
                          ),
                        )
                      : _LineSelector(
                          powerLines: _powerLines,
                          selected: _selectedLine,
                          onSelected: (pl) =>
                              setState(() => _selectedLine = pl),
                        ),
                  if (_powerLines.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _showCreatePowerLineDialog,
                      icon: const Icon(Icons.add_road, size: 18, color: PatrolColors.accent),
                      label: const Text(
                        'Создать новую линию',
                        style: TextStyle(color: PatrolColors.accent),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    'ПРИМЕЧАНИЕ',
                    style: TextStyle(
                      fontSize: 12,
                      color: PatrolColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteController,
                    style: const TextStyle(color: PatrolColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Особенности обхода, погодные условия...',
                      hintStyle: const TextStyle(color: PatrolColors.textSecondary),
                      filled: true,
                      fillColor: PatrolColors.surfaceCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _powerLines.isEmpty || _selectedLine == null
                          ? null
                          : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PatrolColors.accentBlue,
                        foregroundColor: PatrolColors.textPrimary,
                        disabledBackgroundColor: PatrolColors.surfaceCard,
                        disabledForegroundColor: PatrolColors.textSecondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Создать сессию'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _LineSelector extends StatelessWidget {
  const _LineSelector({
    required this.powerLines,
    required this.selected,
    required this.onSelected,
  });

  final List<drift_db.PowerLine> powerLines;
  final drift_db.PowerLine? selected;
  final ValueChanged<drift_db.PowerLine> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PatrolColors.surfaceCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _openPicker(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.search, size: 20, color: PatrolColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  selected != null
                      ? '${selected!.name} (${selected!.code})'
                      : 'Введите название или номер...',
                  style: TextStyle(
                    fontSize: 15,
                    color: selected != null
                        ? PatrolColors.textPrimary
                        : PatrolColors.textSecondary,
                  ),
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: PatrolColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  void _openPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PatrolColors.background,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => _LinePickerSheet(
          powerLines: powerLines,
          selected: selected,
          onSelected: (pl) {
            onSelected(pl);
            Navigator.of(ctx).pop();
          },
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class _LinePickerSheet extends StatefulWidget {
  const _LinePickerSheet({
    required this.powerLines,
    required this.selected,
    required this.onSelected,
    required this.scrollController,
  });

  final List<drift_db.PowerLine> powerLines;
  final drift_db.PowerLine? selected;
  final ValueChanged<drift_db.PowerLine> onSelected;
  final ScrollController scrollController;

  @override
  State<_LinePickerSheet> createState() => _LinePickerSheetState();
}

class _LinePickerSheetState extends State<_LinePickerSheet> {
  late List<drift_db.PowerLine> _filtered;
  final _queryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.powerLines);
    _queryController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _queryController.removeListener(_applyFilter);
    _queryController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final q = _queryController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = List.from(widget.powerLines);
      } else {
        _filtered = widget.powerLines
            .where((pl) =>
                pl.name.toLowerCase().contains(q) ||
                pl.code.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _queryController,
            style: const TextStyle(color: PatrolColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Поиск по названию или коду',
              labelStyle: const TextStyle(color: PatrolColors.textSecondary),
              prefixIcon: const Icon(Icons.search, color: PatrolColors.textSecondary),
              filled: true,
              fillColor: PatrolColors.surfaceCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            autofocus: true,
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            itemCount: _filtered.length,
            itemBuilder: (context, index) {
              final pl = _filtered[index];
              final isSelected = widget.selected?.id == pl.id;
              return ListTile(
                leading: Icon(
                  Icons.electrical_services,
                  color: isSelected ? PatrolColors.accent : PatrolColors.textSecondary,
                ),
                title: Text(
                  pl.name,
                  style: const TextStyle(
                    color: PatrolColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'ID: ${pl.code.trim().isEmpty ? pl.name : pl.code} • ${pl.voltageLevel > 0 ? '${pl.voltageLevel == pl.voltageLevel.roundToDouble() ? pl.voltageLevel.toInt() : pl.voltageLevel} кВ' : 'н/д'}',
                  style: const TextStyle(color: PatrolColors.textSecondary, fontSize: 12),
                ),
                selected: isSelected,
                selectedTileColor: PatrolColors.surfaceCard,
                onTap: () => widget.onSelected(pl),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GpsBlock extends StatelessWidget {
  const _GpsBlock({
    required this.latitude,
    required this.longitude,
    required this.accuracyLabel,
    required this.loading,
    required this.warning,
    required this.onRetry,
  });

  final double? latitude;
  final double? longitude;
  final String accuracyLabel;
  final bool loading;
  final bool warning;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PatrolColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PatrolColors.accentBlue.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading)
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: PatrolColors.accent),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Определение координат...',
                  style: TextStyle(color: PatrolColors.textSecondary, fontSize: 14),
                ),
              ],
            )
          else ...[
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: PatrolColors.accentBlue,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    latitude != null ? Icons.send : Icons.location_off,
                    color: PatrolColors.textPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latitude != null
                            ? 'ГЕОПОЗИЦИЯ ЗАФИКСИРОВАНА'
                            : 'Позиция не получена',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: PatrolColors.textPrimary,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        latitude != null
                            ? '${longitude!.toStringAsFixed(4)}, ${latitude!.toStringAsFixed(4)} ($accuracyLabel)'
                            : 'Включите GPS или нажмите «Повторить»',
                        style: const TextStyle(
                          fontSize: 13,
                          color: PatrolColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (warning) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: PatrolColors.statusPending.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: PatrolColors.statusPending, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'GPS не получен за 15 с. Можно продолжить и указать точку на карте позже.',
                        style: TextStyle(
                          fontSize: 12,
                          color: PatrolColors.statusPending,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18, color: PatrolColors.accent),
                label: const Text(
                  'Повторить',
                  style: TextStyle(color: PatrolColors.accent),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
