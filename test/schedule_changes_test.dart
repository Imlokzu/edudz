import 'package:edudz/api.dart';
import 'package:edudz/edudz/controller.dart';
import 'package:edudz/edudz/school_day.dart';
import 'package:edudz/edudz/details.dart';
import 'package:edudz/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TimeTableData ordinaryDay() {
  final c = SchoolController(nowProvider: () => DateTime(2026, 10, 8, 8))
    ..enterDemo();
  final day = c.dayFor(DateTime(2026, 10, 8));
  c.dispose();
  return day;
}

TimeTableClass withChanges(TimeTableClass lesson, LessonChanges changes) =>
    TimeTableClass.fromJson(
        {...lesson.toJson(), 'lesson_changes': changes.toJson()});

class ChangedCalendar extends SchoolController {
  ChangedCalendar(this.day, {super.nowProvider, this.extra = const {}});
  TimeTableData day;
  final Map<DateTime, TimeTableData> extra;
  @override
  TimeTableData dayFor(DateTime date) => DateUtils.isSameDay(date, day.date)
      ? day
      : extra[DateUtils.dateOnly(date)] ?? TimeTableData(date, [], []);
}

void main() {
  test('13:00–14:00 is a real break despite the generic period 7', () {
    final day = ordinaryDay();
    final afternoon = TimeTableData(day.date, [
      ...day.classes,
      periodCopy(day.classes.first, '8', '14:00', '14:45'),
      periodCopy(day.classes.first, '9', '14:45', '15:30')
    ], [
      ...day.periods,
      TimeTablePeriod('7', '13:00', '13:45', '7', '7'),
      TimeTablePeriod('8', '14:00', '14:45', '8', '8'),
      TimeTablePeriod('9', '14:45', '15:30', '9', '9')
    ]);
    final now = DateTime(2026, 10, 8, 13, 20);
    final state = schoolDayState(afternoon, now);
    expect(state.phase, SchoolPhase.breakTime);
    expect(state.breakKind, 'break');
    expect(state.remainingTime(now), const Duration(minutes: 40));
    expect(state.next!.period, '8');
    expect(state.total, 8);
    expect(isFreeSchoolGap(afternoon, now), false);
    final gap = schoolGaps(afternoon).last;
    expect([gap.start, gap.end], ['13:00', '14:00']);
  });

  test('Free time is split around the two morning school breaks', () {
    final day = ordinaryDay();
    final sparse = TimeTableData(
        day.date, [day.classes.first, day.classes[4]], day.periods);
    final gap = schoolGapAt(sparse, DateTime(2026, 10, 8, 9, 35));
    expect(gap!.kind, 'break');
    expect(gap.end, '09:45');
    final state = schoolDayState(sparse, DateTime(2026, 10, 8, 9, 35));
    expect(state.remainingTime(DateTime(2026, 10, 8, 9, 35)),
        const Duration(minutes: 10));
    expect(
        schoolGapAt(sparse, DateTime(2026, 10, 8, 9, 45))!.kind, 'free_period');
    expect(schoolGapAt(sparse, DateTime(2026, 10, 8, 11, 20))!.kind, 'break');
  });

  test('Cancelled lessons remain in cache but no longer extend school', () {
    final day = ordinaryDay();
    final altered = TimeTableData(
        day.date,
        [
          ...day.classes.take(4),
          ...day.classes
              .skip(4)
              .map((l) => withChanges(l, const LessonChanges(cancelled: true)))
        ],
        day.periods);
    final cached = TimeTableData.fromJson(altered.toJson());
    expect(cached.classes.length, 6);
    expect(cached.classes.last.changes.cancelled, true);
    final state = schoolDayState(cached, DateTime(2026, 10, 8, 11, 15));
    expect(state.phase, SchoolPhase.afterSchool);
    expect(state.total, 4);
    expect(state.cancelled, 2);
    expect(state.remaining, 0);
    expect(state.end, DateTime(2026, 10, 8, 11, 15));
  });

  test('Unknown-subject cancelled periods remain visible', () {
    final day = ordinaryDay();
    final cancelled = TimeTableClass(
        period: '1',
        startTime: '08:00',
        endTime: '09:30',
        changes: const LessonChanges(cancelled: true));
    final normalized =
        normalizeTimetable(TimeTableData(day.date, [cancelled], day.periods));
    expect(normalized.classes.length, 2);
    expect(schoolDayState(normalized, DateTime(2026, 10, 8, 8)).phase,
        SchoolPhase.noSchool);
  });

  test('Change labels and originals survive split lessons and offline cache',
      () {
    final day = ordinaryDay();
    const changes = LessonChanges(
        changed: true,
        teacher: true,
        room: true,
        originalTeacher: 'Usual teacher',
        originalRoom: '101');
    final double = withChanges(
        periodCopy(day.classes.first, '1', '08:00', '09:30'), changes);
    final normalized = TimeTableData.fromJson(
        TimeTableData(day.date, [double], day.periods).toJson());
    expect(normalized.classes.length, 2);
    expect(normalized.classes.last.changes.room, true);
    expect(normalized.classes.last.changes.originalTeacher, 'Usual teacher');
    expect(normalized.classes.last.changes.originalRoom, '101');
    expect(normalized.breaks.last.end, '14:00');
  });

  test('Home skips an all-cancelled next day', () {
    final day = ordinaryDay();
    final cancelled = TimeTableData(
        day.date,
        day.classes
            .map((l) => withChanges(l, const LessonChanges(cancelled: true)))
            .toList(),
        day.periods);
    final c = ChangedCalendar(cancelled,
        nowProvider: () => DateTime(2026, 10, 7, 15),
        extra: {
          DateTime(2026, 10, 9):
              TimeTableData(DateTime(2026, 10, 9), day.classes, day.periods)
        })
      ..authenticated = true
      ..demo = true;
    expect(c.homeDate, DateTime(2026, 10, 9));
    c.dispose();
  });

  for (final width in [360.0, 1280.0]) {
    testWidgets('Substitution, room change and Ausfall at width $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final day = ordinaryDay();
      final lessons = [
        withChanges(
            day.classes[0],
            const LessonChanges(
                changed: true,
                teacher: true,
                room: true,
                originalTeacher: 'Usual teacher',
                originalRoom: '101')),
        withChanges(day.classes[1], const LessonChanges(cancelled: true)),
        ...day.classes.skip(2)
      ];
      final c = ChangedCalendar(TimeTableData(day.date, lessons, day.periods),
          nowProvider: () => DateTime(2026, 10, 8, 8, 20))
        ..enterDemo();
      await tester.pumpWidget(MyApp(controller: c));
      await tester.pumpAndSettle();
      if (width >= 700) {
        await tester.tap(find.byIcon(Icons.calendar_today_outlined).first);
      } else {
        await tester.tap(find.byType(NavigationDestination).at(1));
      }
      await tester.pumpAndSettle();
      expect(find.text('Заміна'), findsOneWidget);
      expect(find.text('Інший кабінет'), findsOneWidget);
      final timetableScroll = find
          .descendant(
              of: find.byType(RefreshIndicator),
              matching: find.byType(Scrollable))
          .first;
      await tester.scrollUntilVisible(find.text('Ausfall · скасовано'), 150,
          scrollable: timetableScroll);
      expect(find.text('Ausfall · скасовано'), findsOneWidget);
      expect(tester.takeException(), null);
      await tester.scrollUntilVisible(find.text('Було: каб. 101'), -150,
          scrollable: timetableScroll);
      await Scrollable.ensureVisible(
          tester.element(find.text('Було: каб. 101')),
          alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Було: каб. 101'));
      await tester.pumpAndSettle();
      expect(find.byType(DetailPane), findsOneWidget);
      await tester.scrollUntilVisible(find.text('101 → 204'), 150,
          scrollable: find
              .descendant(
                  of: find.byType(DetailPane),
                  matching: find.byType(Scrollable))
              .first);
      expect(find.text('101 → 204'), findsOneWidget);
      final fresh = TimeTableClass.fromJson({
        ...lessons.first.toJson(),
        'classrooms': [Classroom(id: '212', name: '212', short: '212').toJson()]
      });
      c.day = TimeTableData(day.date, [fresh, ...lessons.skip(1)], day.periods);
      await c.selectDay(day.date);
      await tester.pumpAndSettle();
      expect(find.text('101 → 212'), findsOneWidget);
      expect(find.text('101 → 204'), findsNothing);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
    });
  }
}
