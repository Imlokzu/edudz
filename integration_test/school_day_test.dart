import 'package:edudz/edudz/controller.dart';
import 'package:edudz/edudz/details.dart';
import 'package:edudz/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Native lesson clock, break, next-day schedule and details',
      (tester) async {
    var now = DateTime(2026, 10, 7, 8, 20);
    final c = SchoolController(nowProvider: () => now)..enterDemo();
    await tester.pumpWidget(MyApp(controller: c));
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    expect(find.text('УРОК 1'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    await binding.takeScreenshot('today');

    now = DateTime(2026, 10, 7, 9, 35);
    c.tickSchoolClock();
    await tester.pumpAndSettle();
    expect(find.text('ПЕРЕРВА'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    await binding.takeScreenshot('school-break');

    now = DateTime(2026, 10, 7, 13);
    c.tickSchoolClock();
    await tester.pumpAndSettle();
    expect(c.homeDate, DateTime(2026, 10, 8));
    expect(find.text('Школу на сьогодні завершено'), findsOneWidget);
    await binding.takeScreenshot('school-finished');

    final tablet = find.byType(NavigationRail).evaluate().isNotEmpty;
    if (tablet) {
      await tester.tap(find.byIcon(Icons.calendar_today_outlined).first);
    } else {
      await tester.tap(find.byType(NavigationDestination).at(1));
    }
    await tester.pumpAndSettle();
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);
    await binding.takeScreenshot('schedule');
    await tester.tap(find.text('Математика').at(1));
    await tester.pumpAndSettle();
    expect(find.byType(DetailPane), findsOneWidget);
    expect(find.text('Номер уроку'), findsOneWidget);
    expect(find.text('Повторення та практичні вправи'), findsOneWidget);
    await binding.takeScreenshot(tablet ? 'tablet-lesson' : 'lesson-detail');
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
  });
}
