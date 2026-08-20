import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/src/screens/profile_screen.dart';

void main() {
  testWidgets('renders settings hub with integrations entry', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('ACCOUNT'), findsNothing);
    expect(find.text('Switch Profile'), findsNothing);
    expect(find.text('Account'), findsNothing);
    expect(find.text('GENERAL'), findsOneWidget);
    expect(find.text('Integrations'), findsOneWidget);
    expect(find.text('Connected Services'), findsNothing);
    expect(find.byKey(const ValueKey<String>('torbox-api-key-field')),
        findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('Check for updates'), findsOneWidget);
  });
}
