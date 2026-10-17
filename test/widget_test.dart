// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:call_monitoring_app/telecaller_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('email/password sign-in flow is presented', (tester) async {
    await tester.pumpWidget(MaterialApp(home: AuthScreen(onSignedIn: (_) {})));
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    await tester.tap(find.text('Need an account? Create one'));
    await tester.pump();
    expect(find.text('Create telecaller account'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(3));
  });
}
