import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edudz/edudz/controller.dart';
import 'package:edudz/edudz/assistant.dart';
import 'package:edudz/edudz/attachments.dart';
import 'package:edudz/edudz/details.dart';
import 'package:edudz/main.dart';

class LoginSpy extends SchoolController {
  bool called = false;
  String? submittedSchool;
  @override
  Future<void> login(String username, String password, String school) async {
    called = true;
    submittedSchool = school;
  }
}

void main() {
  test('Detected school is restored from the server token', () {
    final payload = base64Url
        .encode(utf8.encode(jsonEncode({'server': 'my-school.edupage.org'})));
    expect(resolvedSchool('header.$payload.signature', ''), 'my-school');
    expect(resolvedSchool('old-token', 'fallback'), 'fallback');
  });
  test('Attachment dictionaries and e-test cards expose actual source files',
      () {
    expect(SchoolFile.parse({'/cloud/a.pdf': 'lesson.pdf'}).single.name,
        'lesson.pdf');
    expect(
        SchoolFile.parse([
          {'src': '/cloud/b.png', 'name': 'image.png'}
        ]).single.extension,
        'png');
    final blocks = studyBlocks({
      'materialData': {
        'cardsData': {
          '1': {
            'content': jsonEncode({
              'widgets': [
                {
                  'props': {
                    'htmlText': '<p>Read chapter 5</p>',
                    'files': [
                      {'src': '/cloud/chapter.pdf', 'name': 'chapter.pdf'}
                    ]
                  }
                }
              ]
            })
          }
        }
      }
    });
    expect(blocks.single.text, 'Read chapter 5');
    expect(blocks.single.files.single.src, '/cloud/chapter.pdf');
    expect(safeFilename('../../notes.pdf'), '_.._notes.pdf');
  });
  test('Streaming decodes split UTF-8 tokens and multiple SSE events',
      () async {
    final bytes = utf8.encode(
        'event: token\ndata: {"text":"Привіт"}\n\nevent: done\ndata: {"ok":true}\n\n');
    final stream = Stream<List<int>>.fromIterable(
        [bytes.sublist(0, 33), bytes.sublist(33, 36), bytes.sublist(36)]);
    final events = await decodeAssistantStream(stream).toList();
    expect(events.map((e) => e.type), ['token', 'done']);
    expect(events.first.data['text'], 'Привіт');
  });
  testWidgets('Username and password can be submitted without a school address',
      (tester) async {
    final c = LoginSpy()..initializing = false;
    await tester.pumpWidget(MyApp(controller: c));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), 'student');
    await tester.enterText(find.byType(TextFormField).at(2), 'password');
    await tester.ensureVisible(find.text('Увійти'));
    await tester.tap(find.text('Увійти'));
    await tester.pumpAndSettle();
    expect(c.called, true);
    expect(c.submittedSchool, '');
    expect(find.text('Перевірте адресу вашої школи'), findsNothing);
  });
  testWidgets(
      'Tablet uses a rail and opens lesson details alongside the timetable',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = SchoolController()..enterDemo();
    c.selectedDate = DateTime(2026, 10, 7);
    await tester.pumpWidget(MyApp(controller: c));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.text('Розклад'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Математика').first);
    await tester.pumpAndSettle();
    expect(find.byType(DetailPane), findsOneWidget);
    expect(find.text('Тема уроку'), findsOneWidget);
    expect(find.text('Кабінет'), findsOneWidget);
    expect(find.text('Прочитати наступний розділ'), findsNothing);
    expect(tester.takeException(), null);
    await tester.tap(find.text('Запитати асистента'));
    await tester.pumpAndSettle();
    expect(find.byType(AssistantScreen), findsOneWidget);
    expect(tester.takeException(), null);
  });
  testWidgets('Homework opens its materials inside edudz', (tester) async {
    tester.view.physicalSize = const Size(440, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = SchoolController()..enterDemo();
    await tester.pumpWidget(MyApp(controller: c));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(NavigationDestination).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Квадратні рівняння'));
    await tester.pumpAndSettle();
    expect(find.text('Вкладення'), findsOneWidget);
    expect(find.text('worksheet.pdf'), findsOneWidget);
    expect(find.text('worksheet.txt'), findsOneWidget);
    expect(find.text('Відкрити школу в EduPage'), findsNothing);
    expect(tester.takeException(), null);
  });
}
