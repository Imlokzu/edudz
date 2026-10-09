import 'package:edudz/edudz/attachments.dart';
import 'package:edudz/edudz/controller.dart';
import 'package:edudz/edudz/message_detail.dart';
import 'package:edudz/edudz/rich_content.dart';
import 'package:edudz/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fallback = (
    title: 'Saved message',
    sender: 'Teacher',
    date: DateTime(2026, 10, 9),
    original: null
  );
  test(
      'Message keeps full formatted content, private attachment paths and replies',
      () {
    final message = SchoolMessage.fromJson({
      'vlastnik_meno': 'Frau Müller',
      'user_meno': '9A',
      'text': 'Short preview',
      'data': {
        'Value': {
          'messageContent': '<h2>Trip</h2><p><strong>Bring water</strong></p>',
          'attachements': {'/cloud/a.docx': 'Instructions.docx'},
          'votingParams': {
            'answers': [
              {'text': 'Yes'}
            ]
          }
        }
      },
      'replies': [
        {
          'vlastnik_meno': 'Teacher',
          'text': 'Second',
          'cas_pridania': '2026-10-09T10:00:00',
          'pomocny_zaznam': ''
        },
        {'text': 'Hidden', 'removed': 1},
        {
          'vlastnik_meno': 'Teacher',
          'text': 'First',
          'cas_pridania': '2026-10-09T09:00:00',
          'data': {
            'Value': {
              'attachements': {'/cloud/b.pdf': 'Map.pdf'}
            }
          }
        },
        {'text': 'System entry', 'pomocny_zaznam': '1'}
      ]
    }, fallback: fallback);
    expect(message.sender, 'Frau Müller');
    expect(message.important, true);
    expect(message.body, contains('<strong>Bring water</strong>'));
    expect(message.files.single.name, 'Instructions.docx');
    expect(message.replies.map((r) => r.body), ['First', 'Second']);
    expect(message.replies.first.files.single.name, 'Map.pdf');
    expect(message.poll, ['Yes']);
  });
  test('Missing message fields and encoded JSON do not crash', () {
    final message = SchoolMessage.fromJson(
        {'data': '{"attachments":{"/cloud/a.xlsx":"Budget.xlsx"}}'},
        fallback: fallback);
    expect(message.body, 'Saved message');
    expect(message.files.single.extension, 'xlsx');
  });
  test(
      'Rich content preserves tables and formatting while excluding active content',
      () {
    final html = schoolHtml(
        '<h2>Trip</h2><table><tr><td colspan="2"><b>Bring water</b></td></tr></table><script>steal()</script><iframe src="https://evil.test"></iframe><img src="file:///private/key"><img src="https://evil.test/tracker"><img src="/cloud/photo.png" onerror="steal()"><a href="javascript:steal()">Bad</a><p style="position:fixed;color:red;text-align:center">End</p>');
    expect(html, contains('<table>'));
    expect(html, contains('<b>Bring water</b>'));
    expect(html, contains('colspan="2"'));
    expect(html, contains('/cloud/photo.png'));
    for (final bad in [
      'script',
      'iframe',
      'steal',
      'file:',
      'evil.test',
      'position',
      'color:red',
      'onerror'
    ]) {
      expect(html, isNot(contains(bad)));
    }
    expect(html, contains('text-align:center'));
  });
  test('Plain text retains line breaks and comparison symbols', () {
    expect(schoolHtml('2 < 3\nA & B'), contains('2 &lt; 3<br>A &amp; B'));
    expect(isSchoolResource('https://school.edupage.org/cloud/a.pdf'), true);
    expect(isSchoolResource('https://edupage.org.evil.test/a.pdf'), false);
    expect(isSchoolResource('file:///private/data'), false);
  });
  test('Document types resolve MIME values and case-insensitive extensions',
      () {
    expect(
        const SchoolFile(src: '/file', name: 'BUDGET.XLSX').extension, 'xlsx');
    expect(
        const SchoolFile(
                src: '/file', name: 'download', mime: 'application/pdf')
            .extension,
        'pdf');
    expect(
        const SchoolFile(
                src: '/file',
                name: 'download',
                mime:
                    'application/vnd.openxmlformats-officedocument.wordprocessingml.document')
            .isOffice,
        true);
  });
  for (final size in [const Size(360, 900), const Size(1280, 900)]) {
    testWidgets(
        'Teacher message renders formatted body and attachments on $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final c = SchoolController()..enterDemo();
      await tester.pumpWidget(MyApp(controller: c));
      await tester.pumpAndSettle();
      if (size.width >= 700) {
        await tester.tap(find.byIcon(Icons.chat_bubble_outline).first);
      } else {
        await tester.tap(find.byType(NavigationDestination).at(4));
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('Екскурсія наступної п’ятниці'));
      await tester.pumpAndSettle();
      expect(find.byType(MessagePane), findsOneWidget);
      expect(find.byType(MessageScreen),
          size.width >= 1000 ? findsNothing : findsOneWidget);
      expect(find.byType(SchoolRichText), findsWidgets);
      final scroll = find
          .descendant(
              of: find.byType(MessagePane), matching: find.byType(Scrollable))
          .first;
      await tester.scrollUntilVisible(find.text('class-trip.docx'), 180,
          scrollable: scroll);
      expect(find.text('class-trip.docx'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Відповіді · 1'), 180,
          scrollable: scroll);
      expect(find.text('Відповіді · 1'), findsOneWidget);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
    });
  }
}
