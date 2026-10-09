import 'package:edudz/edudz/controller.dart';
import 'package:edudz/edudz/message_detail.dart';
import 'package:edudz/edudz/document_viewer.dart';
import 'package:edudz/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Teacher messages and local office documents work on Android',
      (tester) async {
    final c = SchoolController()..enterDemo();
    await tester.pumpWidget(MyApp(controller: c));
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    final tablet = find.byType(NavigationRail).evaluate().isNotEmpty;
    if (tablet) {
      await tester.tap(find.byIcon(Icons.chat_bubble_outline).first);
    } else {
      await tester.tap(find.byType(NavigationDestination).at(4));
    }
    await tester.pumpAndSettle();
    await tester.tap(find.text('Екскурсія наступної п’ятниці'));
    await tester.pumpAndSettle();
    expect(find.byType(MessagePane), findsOneWidget);
    await binding.takeScreenshot('teacher-message');
    final scroll = find
        .descendant(
            of: find.byType(MessagePane), matching: find.byType(Scrollable))
        .first;
    for (final item in [
      ('class-trip.docx', 'word', 2),
      ('trip-budget.xlsx', 'excel', 2),
      ('museum-slides.pptx', 'powerpoint', 3)
    ]) {
      await tester.scrollUntilVisible(find.text(item.$1), 150,
          scrollable: scroll);
      await Scrollable.ensureVisible(tester.element(find.text(item.$1)),
          alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(find.text(item.$1));
      await tester.pumpAndSettle();
      expect(find.byType(AttachmentViewer), findsOneWidget);
      final counter = find.byKey(const ValueKey('document-pages'));
      for (var i = 0; i < 120 && counter.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(counter, findsOneWidget,
          reason: '${item.$1} did not render locally');
      expect(tester.widget<Text>(counter).data, contains('1 / ${item.$3}'));
      await tester.pump(const Duration(milliseconds: 500));
      await binding.takeScreenshot('document-${item.$2}');
      await tester.tap(find.byTooltip('Далі'));
      for (var i = 0;
          i < 30 && !(tester.widget<Text>(counter).data ?? '').contains('2 /');
          i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(tester.widget<Text>(counter).data, contains('2 / ${item.$3}'));
      await tester.tap(find.byTooltip('Збільшити'));
      await tester.pumpAndSettle();
      expect(find.text('125%'), findsOneWidget);
      if (item.$2 == 'word') {
        await tester.tap(find.byTooltip('Завантажити оригінал'));
        await tester.pumpAndSettle();
        for (var i = 0;
            i < 20 &&
                find
                    .text('Збережено в Завантаження / edudz')
                    .evaluate()
                    .isEmpty;
            i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(find.text('Збережено в Завантаження / edudz'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      }
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(find.text('worksheet.pdf'), 150,
        scrollable: scroll);
    await Scrollable.ensureVisible(tester.element(find.text('worksheet.pdf')),
        alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(find.text('worksheet.pdf'));
    await tester.pumpAndSettle();
    for (var i = 0;
        i < 80 && find.text('Сторінка 1 / 1').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.text('Сторінка 1 / 1'), findsOneWidget);
    await binding.takeScreenshot('document-pdf');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Відповіді · 1'), 160,
        scrollable: scroll);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('teacher-replies');
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
  });
}
