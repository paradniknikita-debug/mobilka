import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/database/database.dart' as drift_db;
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/pending_sync_provider.dart';

/// Страница «Продолжить обход»: выбор линии из созданных, сохранение активной сессии и переход на карту.
class ContinueSessionPage extends ConsumerStatefulWidget {
  const ContinueSessionPage({super.key});

  @override
  ConsumerState<ContinueSessionPage> createState() => _ContinueSessionPageState();
}

class _ContinueSessionPageState extends ConsumerState<ContinueSessionPage> {
  List<drift_db.PowerLine> _powerLines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPowerLines();
  }

  Future<void> _loadPowerLines() async {
    final db = ref.read(drift_db.databaseProvider);
    final list = await db.getAllPowerLines();
    if (mounted) {
      setState(() {
        _powerLines = list;
        _loading = false;
      });
    }
  }

  Future<void> _selectLineAndGoToMap(drift_db.PowerLine line) async {
    final startedAt = DateTime.now();
    final prefs = ref.read(prefsProvider);
    final db = ref.read(drift_db.databaseProvider);
    final authState = ref.read(authStateProvider);
    final userId = authState is AuthStateAuthenticated ? authState.user.id : null;

    final localId = await db.insertPatrolSession(
      drift_db.PatrolSessionsCompanion.insert(
        powerLineId: line.id,
        note: const drift.Value(null),
        startedAt: startedAt,
        syncStatus: const drift.Value('pending'),
        userId: drift.Value(userId),
      ),
    );

    await prefs.setInt(AppConfig.activeSessionPowerLineIdKey, line.id);
    await prefs.setString(AppConfig.activeSessionStartTimeKey, startedAt.toIso8601String());
    await prefs.setString(AppConfig.activeSessionNoteKey, '');
    await prefs.setInt(AppConfig.activeSessionLocalIdKey, localId);

    ref.invalidate(pendingPatrolSessionsCountProvider);
    ref.invalidate(hasPendingSyncProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Обход по линии «${line.name}». Ожидает синхронизации.'),
        backgroundColor: Colors.orange,
      ),
    );
    context.go('/map');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Продолжить обход'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _powerLines.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.electrical_services_outlined,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'Нет созданных линий',
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Создайте линию через «Начать новый обход» или на карте в меню.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: () => context.go('/'),
                          icon: const Icon(Icons.home),
                          label: const Text('На главную'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Выберите линию для продолжения обхода',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _powerLines.length,
                        itemBuilder: (context, index) {
                          final pl = _powerLines[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.electrical_services),
                              title: Text(pl.name),
                              subtitle: Text(
                                  '${pl.name} • ${pl.voltageLevel > 0 ? '${pl.voltageLevel == pl.voltageLevel.roundToDouble() ? pl.voltageLevel.toInt() : pl.voltageLevel} кВ' : 'н/д'}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _selectLineAndGoToMap(pl),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
