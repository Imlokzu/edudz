import 'package:edudz/api.dart';
import 'package:edudz/edudz/controller.dart';
import 'package:edudz/edudz/details.dart';
import 'package:edudz/edudz/school_day.dart';
import 'package:edudz/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

class DemoChangesCalendar extends SchoolController {
  DemoChangesCalendar(this.day, {super.nowProvider});
  final TimeTableData day;
  @override
  TimeTableData dayFor(DateTime date) =>
      DateUtils.isSameDay(date, day.date) ? day : TimeTableData(date, [], []);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'Native substitution, room/class changes, Ausfall and lunch break',
      (tester) async {
    var now = DateTime(2026, 10, 8, 8, 20);
    final source = SchoolController(nowProvider: () => now)..enterDemo();
    final day = source.dayFor(DateTime(2026, 10, 8));
    source.dispose();
    TimeTableClass changed(TimeTableClass l, LessonChanges changes) =>
        TimeTableClass.fromJson(
            {...l.toJson(), 'lesson_changes': changes.toJson()});
    final third = changed(
        day.classes[2],
        const LessonChanges(
            changed: true, schoolClass: true, originalClass: '9A'));
    final classLesson = TimeTableClass.fromJson({
      ...third.toJson(),
      'classes': [
        Class(
                id: '9b',
                name: '9B',
                short: '9B',
                grade: '9',
                teacherId: 'demo',
                teacher2Id: '',
                classroomId: '112')
            .toJson()
      ]
    });
    final lessons = [
      changed(
          day.classes.first,
          const LessonChanges(
              changed: true,
              teacher: true,
              room: true,
              originalTeacher: 'Frau Berg',
              originalRoom: '101')),
      changed(day.classes[1], const LessonChanges(cancelled: true)),
      classLesson,
      ...day.classes.skip(3),
      periodCopy(day.classes.first, '8', '14:00', '14:45'),
      periodCopy(day.classes.first, '9', '14:45', '15:30')
    ];
    final periods = [
      ...day.periods,
      TimeTablePeriod('7', '13:00', '13:45', '7', '7'),
      TimeTablePeriod('8', '14:00', '14:45', '8', '8'),
      TimeTablePeriod('9', '14:45', '15:30', '9', '9')
    ];
    final c = DemoChangesCalendar(TimeTableData(day.date, lessons, periods),
        nowProvider: () => now)
      ..enterDemo();
    await tester.pumpWidget(MyApp(controller: c));
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    expect(find.text('Заміна'), findsOneWidget);
    expect(find.text('Інший кабінет'), findsOneWidget);
    await binding.takeScreenshot('changes-today');
    final tablet = find.byType(NavigationRail).evaluate().isNotEmpty;
    if (tablet) {
      await tester.tap(find.byIcon(Icons.calendar_today_outlined).first);
    } else {
      await tester.tap(find.byType(NavigationDestination).at(1));
    }
    await tester.pumpAndSettle();
    final scroll = find
        .descendant(
            of: find.byType(RefreshIndicator),
            matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.text('Ausfall · скасовано'), 150,
        scrollable: scroll);
    expect(find.text('Ausfall · скасовано'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Інший клас'), 150,
        scrollable: scroll);
    expect(find.text('Інший клас'), findsOneWidget);
    await binding.takeScreenshot('changes-schedule');
    await tester.scrollUntilVisible(find.text('Було: каб. 101'), -150,
        scrollable: scroll);
    await Scrollable.ensureVisible(tester.element(find.text('Було: каб. 101')),
        alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Було: каб. 101'));
    await tester.pumpAndSettle();
    final detailScroll = find
        .descendant(
            of: find.byType(DetailPane), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.text('101 → 204'), 150,
        scrollable: detailScroll);
    expect(find.text('101 → 204'), findsOneWidget);
    await binding.takeScreenshot('changes-lesson');
    if (tablet) {
      await tester.tap(find.byTooltip('Закрити'));
    } else {
      await tester.binding.handlePopRoute();
    }
    await tester.pumpAndSettle();
    if (tablet) {
      await tester.tap(find.byIcon(Icons.grid_view_rounded).first);
    } else {
      await tester.tap(find.byType(NavigationDestination).first);
    }
    now = DateTime(2026, 10, 8, 13, 20);
    c.tickSchoolClock();
    await tester.pumpAndSettle();
    expect(find.text('ПЕРЕРВА'), findsOneWidget);
    expect(find.text('40:00'), findsOneWidget);
    expect(find.text('Залишилось уроків: 2 / 7'), findsOneWidget);
    await binding.takeScreenshot('changes-lunch');
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
  });
}
