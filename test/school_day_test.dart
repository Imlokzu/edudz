import 'package:edudz/api.dart';
import 'package:edudz/edudz/controller.dart';
import 'package:edudz/edudz/details.dart';
import 'package:edudz/edudz/school_day.dart';
import 'package:edudz/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final schoolDateFixture = DateTime(2026, 10, 7);
TimeTableData fixture() {
  final c = SchoolController(nowProvider: () => DateTime(2026, 10, 7, 8))
    ..enterDemo();
  final day = c.dayFor(schoolDateFixture);
  c.dispose();
  return day;
}

class CalendarController extends SchoolController {
  CalendarController({super.nowProvider, required this.days});
  final Map<DateTime, TimeTableData> days;
  @override
  TimeTableData dayFor(DateTime date) =>
      days[DateUtils.dateOnly(date)] ?? TimeTableData(date, [], []);
}

void main() {
  test('Double lessons are separate, retain details and survive cache reload',
      () {
    final day = fixture();
    expect(day.classes.length, 6);
    expect(day.classes.map((l) => l.period), ['1', '2', '3', '4', '5', '6']);
    for (final l in day.classes) {
      expect(clockMinutes(l.endTime)! - clockMinutes(l.startTime)!, 45);
      expect(l.teachers, isNotEmpty);
      expect(l.classrooms, isNotEmpty);
    }
    final second = TimeTableClass.fromJson(day.classes[1].toJson());
    expect(second.blockStart, '08:00');
    expect(second.blockEnd, '09:30');
    expect(second.originPeriod, '1');
    expect(normalizeTimetable(day).classes.length, 6);
    final fallback = normalizeTimetable(TimeTableData(schoolDateFixture,
        [periodCopy(day.classes.first, '1', '08:00', '09:30')], []));
    expect(fallback.classes.map((l) => l.period), ['1', '2']);
  });

  test('School clock respects each lesson and real break boundary', () {
    final day = fixture();
    final cases = <(int, int, int, SchoolPhase, String?, int, int)>[
      (7, 59, 59, SchoolPhase.beforeSchool, null, 6, 1),
      (8, 0, 0, SchoolPhase.lesson, '1', 6, 2700),
      (8, 44, 59, SchoolPhase.lesson, '1', 6, 1),
      (8, 45, 0, SchoolPhase.lesson, '2', 5, 2700),
      (9, 30, 0, SchoolPhase.breakTime, null, 4, 900),
      (9, 45, 0, SchoolPhase.lesson, '3', 4, 2700),
      (11, 15, 0, SchoolPhase.breakTime, null, 2, 900),
      (12, 15, 0, SchoolPhase.lesson, '6', 1, 2700),
      (13, 0, 0, SchoolPhase.afterSchool, null, 0, 0),
    ];
    for (final tc in cases) {
      final now = DateTime(2026, 10, 7, tc.$1, tc.$2, tc.$3);
      final state = schoolDayState(day, now);
      expect(state.phase, tc.$4, reason: '$now');
      expect(state.current?.period, tc.$5);
      expect(state.remaining, tc.$6);
      expect(state.remainingTime(now).inSeconds, tc.$7);
      expect(state.start, DateTime(2026, 10, 7, 8));
      expect(state.end, DateTime(2026, 10, 7, 13));
    }
    expect(countdownText(const Duration(seconds: 900)), '15:00');
    expect(countdownText(const Duration(seconds: 1)), '0:01');
  });

  test('Free periods never add lessons', () {
    final day = fixture();
    final sparse = TimeTableData(
        day.date, [day.classes.first, day.classes[4]], day.periods);
    final now = DateTime(2026, 10, 7, 10);
    expect(schoolDayState(sparse, now).remaining, 1);
    expect(schoolDayState(sparse, now).total, 2);
    expect(isFreeSchoolGap(sparse, now), true);
    expect(isFreeSchoolGap(day, DateTime(2026, 10, 7, 9, 35)), false);
  });

  test(
      'Home changes after school, while a manually selected day stays selected',
      () async {
    var now = DateTime(2026, 10, 7, 12, 59, 59);
    final c = SchoolController(nowProvider: () => now)..enterDemo();
    c.tickSchoolClock();
    expect(c.homeDate, DateTime(2026, 10, 7));
    await c.selectDay(DateTime(2026, 10, 5));
    now = DateTime(2026, 10, 7, 13);
    c.tickSchoolClock();
    expect(c.homeDate, DateTime(2026, 10, 8));
    expect(c.selectedDate, DateTime(2026, 10, 5));
    expect(c.homeLessons.length, 6);
    c.showHomeDay();
    expect(c.selectedDate, DateTime(2026, 10, 8));
    now = DateTime(2026, 10, 8, 0);
    c.tickSchoolClock();
    expect(c.homeDate, DateTime(2026, 10, 8));
    expect(c.schoolState.phase, SchoolPhase.beforeSchool);
    c.dispose();
  });

  test('Next school day skips weekends and empty holiday dates', () {
    final c = SchoolController(nowProvider: () => DateTime(2026, 10, 9, 13))
      ..enterDemo();
    expect(c.homeDate, DateTime(2026, 10, 12));
    c.dispose();
    final afterHoliday = DateTime(2026, 11, 23);
    final calendar = CalendarController(
        nowProvider: () => DateTime(2026, 10, 9, 13),
        days: {
          afterHoliday:
              TimeTableData(afterHoliday, fixture().classes, fixture().periods)
        })
      ..initializing = false
      ..authenticated = true
      ..demo = true;
    expect(calendar.homeDate, afterHoliday);
    calendar.dispose();
  });

  test('Second half of a double lesson opens the original block topic', () {
    final c = SchoolController(nowProvider: () => DateTime(2026, 10, 7, 8))
      ..enterDemo();
    final second = c.homeLessons[1];
    final plans = [
      {'subjectid': 'other', 'starttime': '08:00', 'topic': 'wrong subject'},
      {
        'subjectid': second.original!.subject!.id,
        'starttime': '08:00',
        'topic': 'block topic'
      }
    ];
    expect(lessonPlanFor(plans, second)?['topic'], 'block topic');
    plans.add({
      'subjectid': second.original!.subject!.id,
      'starttime': '08:45',
      'topic': 'specific topic'
    });
    expect(lessonPlanFor(plans, second)?['topic'], 'specific topic');
    c.dispose();
  });

  for (final width in [360.0, 1280.0]) {
    testWidgets('Live countdown and next-day transition at width $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      var now = DateTime(2026, 10, 7, 8, 44, 59);
      final c = SchoolController(nowProvider: () => now)..enterDemo();
      await tester.pumpWidget(MyApp(controller: c));
      await tester.pumpAndSettle();
      expect(find.text('УРОК 1'), findsOneWidget);
      expect(find.text('0:01'), findsOneWidget);
      now = DateTime(2026, 10, 7, 8, 45);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('УРОК 2'), findsOneWidget);
      expect(find.text('45:00'), findsOneWidget);
      now = DateTime(2026, 10, 7, 9, 30);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('ПЕРЕРВА'), findsOneWidget);
      expect(find.text('15:00'), findsOneWidget);
      now = DateTime(2026, 10, 7, 13);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Школу на сьогодні завершено'), findsOneWidget);
      expect(find.text('Залишилось уроків: 0 / 6'), findsOneWidget);
      expect(c.homeDate, DateTime(2026, 10, 8));
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
    });
  }
}
