import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lepm_mobile/main.dart';

void main() {
  testWidgets('Приложение LepmApp рендерится без ошибок', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: LepmApp(),
      ),
    );

    expect(find.byType(LepmApp), findsOneWidget);
  });
}

