// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/main.dart';

void main() {
  testWidgets('Legally auth screen smoke test', (WidgetTester tester) async {
    // Build our auth screen widget directly.
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthScreen(),
      ),
    );

    // Verify that the title Legally Portal is present.
    expect(find.text('Legally Portal'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
  });
}

