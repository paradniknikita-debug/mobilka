import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/api_service.dart';
import '../widgets/create_pole_dialog.dart';

class TowersPage extends ConsumerStatefulWidget {
  const TowersPage({super.key});

  @override
  ConsumerState<TowersPage> createState() => _TowersPageState();
}

class _TowersPageState extends ConsumerState<TowersPage> {
  List<int> _powerLineIds = [];
  bool _isLoading = false;
  int? _selectedPowerLineId;

  @override
  void initState() {
    super.initState();
    _loadPowerLines();
  }

  Future<void> _loadPowerLines() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final powerLines = await apiService.getPowerLines();

      setState(() {
        _powerLineIds = powerLines.map((pl) => pl.id).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки ЛЭП: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showCreatePoleDialog() async {
    // Если ЛЭП не выбрана, показываем диалог выбора
    if (_selectedPowerLineId == null && _powerLineIds.isNotEmpty) {
      _selectedPowerLineId = _powerLineIds.first;
    }

    if (_selectedPowerLineId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Сначала нужно создать или выбрать ЛЭП'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final result = await showDialog<dynamic>(
      context: context,
      builder: (context) => CreatePoleDialog(
        powerLineId: _selectedPowerLineId!,
      ),
    );

    final success = result == true || (result is Map && result['success'] == true);
    if (success && mounted) {
      // Опора создана, можно обновить список или показать уведомление
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Опора успешно создана'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Опоры'),
        actions: [
          if (_powerLineIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButton<int>(
                value: _selectedPowerLineId,
                hint: const Text('ЛЭП'),
                items: _powerLineIds.map((id) {
                  return DropdownMenuItem(
                    value: id,
                    child: Text('ЛЭП $id'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPowerLineId = value;
                  });
                },
              ),
            ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _isLoading ? null : _showCreatePoleDialog,
            tooltip: 'Создать опору',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _powerLineIds.isEmpty
              ? const Center(
                  child: Text('Нет доступных ЛЭП. Создайте ЛЭП сначала.'),
                )
              : const Center(
                  child: Text('Список опор будет здесь'),
                ),
    );
  }
}
