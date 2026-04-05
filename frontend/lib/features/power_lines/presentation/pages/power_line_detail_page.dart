import 'package:flutter/material.dart';

class PowerLineDetailPage extends StatelessWidget {
  final int powerLineId;

  const PowerLineDetailPage({
    super.key,
    required this.powerLineId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ЛЭП #$powerLineId'),
      ),
      body: Center(
        child: Text('Детали ЛЭП #$powerLineId'),
      ),
    );
  }
}
