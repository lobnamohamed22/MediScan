import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mediscan/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
  });

  testWidgets('MediScan app builds', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MediScanApp(),
    );

    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
