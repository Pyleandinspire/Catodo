import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:catodo/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: CatodoApp()));
    // Allow async initialization to settle
    await tester.pump(const Duration(seconds: 1));
    // Verify the app renders without crashing
    expect(find.byType(CatodoApp), findsOneWidget);
  });
}
