import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TowersPage extends ConsumerWidget {
  const TowersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Опоры'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Добавить создание новой опоры
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Создание новой опоры')),
              );
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('Список опор будет здесь'),
      ),
    );
  }
}
