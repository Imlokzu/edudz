import 'package:edudz/api.dart';

DateTime schoolCalendarDay(DateTime date, int offset) =>
    DateTime(date.year, date.month, date.day + offset);

int? clockMinutes(String value) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final hour = int.parse(match[1]!), minute = int.parse(match[2]!);
  if (hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}

String minuteClock(int value) =>
    '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
DateTime onSchoolDate(DateTime date, String value) {
  final minute = clockMinutes(value) ?? 0;
  return DateTime(date.year, date.month, date.day, minute ~/ 60, minute % 60);
}

TimeTableClass periodCopy(
    TimeTableClass lesson, String period, String start, String end) {
  final value = TimeTableClass(
    type: lesson.type,
    date: lesson.date,
    period: period,
    startTime: start,
    endTime: end,
    subject: lesson.subject,
    classes: lesson.classes,
    groupNames: lesson.groupNames,
    iGroupId: lesson.iGroupId,
    teachers: lesson.teachers,
    classrooms: lesson.classrooms,
    studentIds: lesson.studentIds,
    colors: lesson.colors,
    blockStart:
        lesson.blockStart.isEmpty ? lesson.startTime : lesson.blockStart,
    blockEnd: lesson.blockEnd.isEmpty ? lesson.endTime : lesson.blockEnd,
    originPeriod:
        lesson.originPeriod.isEmpty ? lesson.period : lesson.originPeriod,
  );
  final slot = TimeTablePeriod(period, start, end, period, period);
  value.startPeriod = slot;
  value.endPeriod = slot;
  return value;
}

TimeTableData normalizeTimetable(TimeTableData day) {
  final periods = [...day.periods]..sort((a, b) =>
      (clockMinutes(a.startTime) ?? 0)
          .compareTo(clockMinutes(b.startTime) ?? 0));
  final result = <TimeTableClass>[];
  for (final lesson in day.classes) {
    if (lesson.subject == null || lesson.subject!.name.trim().isEmpty) continue;
    final start = clockMinutes(lesson.startTime),
        end = clockMinutes(lesson.endTime);
    if (start == null || end == null || end <= start) continue;
    final slots = periods
        .where((p) =>
            (clockMinutes(p.startTime) ?? -1) >= start &&
            (clockMinutes(p.endTime) ?? 2000) <= end &&
            (clockMinutes(p.endTime) ?? 0) > (clockMinutes(p.startTime) ?? 0))
        .toList();
    if (slots.isNotEmpty &&
        slots.first.startTime == lesson.startTime &&
        slots.last.endTime == lesson.endTime) {
      for (final slot in slots) {
        final copy = periodCopy(lesson, slot.id, slot.startTime, slot.endTime);
        copy.startPeriod = slot;
        copy.endPeriod = slot;
        result.add(copy);
      }
    } else if (end - start > 45 && (end - start) % 45 == 0) {
      final number = int.tryParse(lesson.period);
      for (var at = start; at < end; at += 45) {
        result.add(periodCopy(
            lesson,
            number == null ? lesson.period : '${number + (at - start) ~/ 45}',
            minuteClock(at),
            minuteClock(at + 45)));
      }
    } else {
      result.add(
          periodCopy(lesson, lesson.period, lesson.startTime, lesson.endTime));
    }
  }
  result.sort((a, b) => (clockMinutes(a.startTime) ?? 0)
      .compareTo(clockMinutes(b.startTime) ?? 0));
  return TimeTableData(day.date, result, periods);
}

enum SchoolPhase { noSchool, beforeSchool, lesson, breakTime, afterSchool }

class SchoolDayState {
  const SchoolDayState(
      {required this.phase,
      required this.total,
      required this.remaining,
      this.current,
      this.next,
      this.endsAt,
      this.start,
      this.end});
  final SchoolPhase phase;
  final int total, remaining;
  final TimeTableClass? current, next;
  final DateTime? endsAt, start, end;
  Duration remainingTime(DateTime now) {
    final value = endsAt?.difference(now) ?? Duration.zero;
    return value.isNegative ? Duration.zero : value;
  }
}

SchoolDayState schoolDayState(TimeTableData day, DateTime now) {
  final lessons = normalizeTimetable(day).classes;
  if (lessons.isEmpty) {
    return const SchoolDayState(
        phase: SchoolPhase.noSchool, total: 0, remaining: 0);
  }
  final start = onSchoolDate(day.date, lessons.first.startTime),
      end = onSchoolDate(day.date, lessons.last.endTime);
  for (var i = 0; i < lessons.length; i++) {
    final from = onSchoolDate(day.date, lessons[i].startTime),
        to = onSchoolDate(day.date, lessons[i].endTime);
    if (!now.isBefore(to)) continue;
    if (now.isBefore(from)) {
      return SchoolDayState(
          phase: i == 0 ? SchoolPhase.beforeSchool : SchoolPhase.breakTime,
          total: lessons.length,
          remaining: lessons.length - i,
          next: lessons[i],
          endsAt: from,
          start: start,
          end: end);
    }
    return SchoolDayState(
        phase: SchoolPhase.lesson,
        total: lessons.length,
        remaining: lessons.length - i,
        current: lessons[i],
        next: i + 1 < lessons.length ? lessons[i + 1] : null,
        endsAt: to,
        start: start,
        end: end);
  }
  return SchoolDayState(
      phase: SchoolPhase.afterSchool,
      total: lessons.length,
      remaining: 0,
      start: start,
      end: end);
}

bool gapContainsPeriod(int start, int end, List<TimeTablePeriod> periods) =>
    periods.any((p) {
      final from = clockMinutes(p.startTime), to = clockMinutes(p.endTime);
      return from != null &&
          to != null &&
          from >= start &&
          to <= end &&
          to > from;
    });

bool isFreeSchoolGap(TimeTableData day, DateTime now) {
  final lessons = normalizeTimetable(day).classes;
  for (var i = 1; i < lessons.length; i++) {
    final start = onSchoolDate(day.date, lessons[i - 1].endTime);
    final end = onSchoolDate(day.date, lessons[i].startTime);
    if (!now.isBefore(start) && now.isBefore(end)) {
      return gapContainsPeriod(clockMinutes(lessons[i - 1].endTime)!,
          clockMinutes(lessons[i].startTime)!, day.periods);
    }
  }
  return false;
}

String countdownText(Duration duration) {
  final seconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final hours = seconds ~/ 3600,
      minutes = (seconds ~/ 60) % 60,
      rest = seconds % 60;
  return hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}'
      : '${seconds ~/ 60}:${rest.toString().padLeft(2, '0')}';
}
