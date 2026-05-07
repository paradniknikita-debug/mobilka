import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PowerLinesPage extends ConsumerWidget {
  const PowerLinesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ЛЭП'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Добавить создание новой ЛЭП
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Создание новой ЛЭП')),
              );
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('Список ЛЭП будет здесь'),
      ),
    );
  }
}
