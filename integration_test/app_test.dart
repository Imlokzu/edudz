import 'package:edudz/edudz/controller.dart';
import 'package:edudz/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android demo navigation and settings', (tester) async {
    final c = SchoolController()..enterDemo();
    await tester.pumpWidget(MyApp(controller: c));
    await tester.pumpAndSettle();
    expect(find.text('edudz'), findsOneWidget);
    for (var i = 1; i < 5; i++) {
      await tester.tap(find.byType(NavigationDestination).at(i));
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
    }
    await tester.tap(find.byTooltip('Налаштування'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(c.dark, true);
  });
}
