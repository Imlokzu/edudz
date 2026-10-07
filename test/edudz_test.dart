import 'package:edudz/edudz/controller.dart';
import 'package:edudz/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edudz/api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('School addresses are normalized without accepting arbitrary hosts', () {
    expect(schoolSubdomain('https://my-school.edupage.org/login'), 'my-school');
    expect(schoolSubdomain(' my-school '), 'my-school');
    expect(schoolSubdomain('https://evil.example'), '');
    expect(schoolSubdomain('a@school.edupage.org'), '');
  });
  test('HTML content is readable and dates remain optional', () {
    expect(plainText('<p>A &amp; B<br>Homework</p>'), 'A & B\nHomework');
    expect(schoolDate(''), null);
    expect(schoolDate('2026-10-08 14:00'), DateTime(2026, 10, 8));
  });
  test('Credentials use secure storage and are removed from preferences',
      () async {
    SharedPreferences.setMockInitialValues(
        {'user': 'old plaintext', 'password': 'old password'});
    final secured = <String, String>{};
    const channel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = Map<String, dynamic>.from(call.arguments);
      if (call.method == 'write') secured[args['key']] = args['value'];
      if (call.method == 'read') return secured[args['key']];
      if (call.method == 'delete') secured.remove(args['key']);
      return null;
    });
    final user =
        User(username: 'test', password: 'test-secret', server: 'test-school')
          ..token = 'session';
    await user.saveToCache();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('password'), null);
    expect(prefs.getString('user'), null);
    expect((await User.loadFromCache())!.token, 'session');
    await user.clearCache();
    expect(await User.loadFromCache(), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  testWidgets('Login validates required credentials before connecting',
      (tester) async {
    final c = SchoolController()..initializing = false;
    await tester.pumpWidget(MyApp(controller: c));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Увійти'));
    await tester.tap(find.text('Увійти'));
    await tester.pumpAndSettle();
    expect(find.text('Перевірте адресу вашої школи'), findsNothing);
    expect(find.text('Введіть логін'), findsOneWidget);
    expect(find.text('Введіть пароль'), findsOneWidget);
    expect(c.loading, false);
  });
  testWidgets(
      'Demo navigates all tabs, completes homework, changes theme and exits',
      (tester) async {
    tester.view.physicalSize = const Size(440, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = SchoolController()..enterDemo();
    c.selectedDate = DateTime(2026, 10, 7);
    await tester.pumpWidget(MyApp(controller: c));
    await tester.pumpAndSettle();
    expect(find.text('edudz'), findsOneWidget);
    expect(find.textContaining('Демонстраційні дані'), findsOneWidget);
    for (final i in [1, 3, 4, 2]) {
      await tester.tap(find.byType(NavigationDestination).at(i));
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
    }
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(c.completed.contains('demo1'), true);
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    expect(find.text('Квадратні рівняння'), findsOneWidget);
    await tester.tap(find.byTooltip('Налаштування'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(c.dark, true);
    await tester.tap(find.text('Вийти з демо та увійти'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(3));
  });
  testWidgets('Small screens with large text keep the login usable',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = SchoolController()..initializing = false;
    await tester.pumpWidget(MyApp(controller: c));
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
    await tester.ensureVisible(find.text('Спочатку подивитися демо'));
    await tester.tap(find.text('Спочатку подивитися демо'));
    await tester.pumpAndSettle();
    expect(c.demo, true);
    expect(tester.takeException(), null);
  });
}
