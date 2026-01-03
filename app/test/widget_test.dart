import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('Task app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TaskApp());

    // Verify that the app shows the empty state message.
    expect(find.textContaining('No tasks yet'), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);

    // Verify that the add button exists
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
