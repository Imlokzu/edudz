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
    changes: lesson.changes,
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
    if (!lesson.changes.cancelled &&
        (lesson.subject == null || lesson.subject!.name.trim().isEmpty)) {
      continue;
    }
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
  return TimeTableData(day.date, result, periods, breaks: day.breaks);
}

enum SchoolPhase { noSchool, beforeSchool, lesson, breakTime, afterSchool }

class SchoolDayState {
  const SchoolDayState(
      {required this.phase,
      required this.total,
      required this.remaining,
      this.cancelled = 0,
      this.breakKind = '',
      this.current,
      this.next,
      this.endsAt,
      this.start,
      this.end});
  final SchoolPhase phase;
  final int total, remaining;
  final int cancelled;
  final String breakKind;
  final TimeTableClass? current, next;
  final DateTime? endsAt, start, end;
  Duration remainingTime(DateTime now) {
    final value = endsAt?.difference(now) ?? Duration.zero;
    return value.isNegative ? Duration.zero : value;
  }
}

SchoolDayState schoolDayState(TimeTableData day, DateTime now) {
  final all = normalizeTimetable(day).classes;
  final lessons = all.where((l) => !l.changes.cancelled).toList();
  final cancelled = all.length - lessons.length;
  if (lessons.isEmpty) {
    return SchoolDayState(
        phase: SchoolPhase.noSchool,
        total: 0,
        remaining: 0,
        cancelled: cancelled);
  }
  final start = onSchoolDate(day.date, lessons.first.startTime),
      end = onSchoolDate(day.date, lessons.last.endTime);
  for (var i = 0; i < lessons.length; i++) {
    final from = onSchoolDate(day.date, lessons[i].startTime),
        to = onSchoolDate(day.date, lessons[i].endTime);
    if (!now.isBefore(to)) continue;
    if (now.isBefore(from)) {
      final gap = i == 0 ? null : schoolGapAt(day, now);
      return SchoolDayState(
          phase: i == 0 ? SchoolPhase.beforeSchool : SchoolPhase.breakTime,
          total: lessons.length,
          remaining: lessons.length - i,
          cancelled: cancelled,
          breakKind: gap?.kind ?? '',
          next: lessons[i],
          endsAt: gap == null ? from : onSchoolDate(day.date, gap.end),
          start: start,
          end: end);
    }
    return SchoolDayState(
        phase: SchoolPhase.lesson,
        total: lessons.length,
        remaining: lessons.length - i,
        cancelled: cancelled,
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
      cancelled: cancelled,
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

List<SchoolBreak> schoolGapSegments(TimeTableData day, int start, int end) {
  if (end <= start) return [];
  final cuts = <int>{start, end};
  for (final pause in day.breaks) {
    final from = clockMinutes(pause.start), to = clockMinutes(pause.end);
    if (from != null && from > start && from < end) cuts.add(from);
    if (to != null && to > start && to < end) cuts.add(to);
  }
  final sorted = cuts.toList()..sort();
  return [
    for (var i = 1; i < sorted.length; i++)
      SchoolBreak(minuteClock(sorted[i - 1]), minuteClock(sorted[i]),
          kind: day.breaks.any((p) =>
                  (clockMinutes(p.start) ?? 2000) <= sorted[i - 1] &&
                  (clockMinutes(p.end) ?? -1) >= sorted[i])
              ? 'break'
              : gapContainsPeriod(sorted[i - 1], sorted[i], day.periods)
                  ? 'free_period'
                  : 'break')
  ];
}

List<SchoolBreak> schoolGaps(TimeTableData day) {
  final lessons = normalizeTimetable(day)
      .classes
      .where((l) => !l.changes.cancelled)
      .toList();
  final result = <SchoolBreak>[];
  if (lessons.isEmpty) return result;
  var end = clockMinutes(lessons.first.endTime)!;
  for (final lesson in lessons.skip(1)) {
    result.addAll(schoolGapSegments(day, end, clockMinutes(lesson.startTime)!));
    final nextEnd = clockMinutes(lesson.endTime)!;
    if (nextEnd > end) end = nextEnd;
  }
  return result;
}

SchoolBreak? schoolGapAt(TimeTableData day, DateTime now) {
  for (final gap in schoolGaps(day)) {
    if (!now.isBefore(onSchoolDate(day.date, gap.start)) &&
        now.isBefore(onSchoolDate(day.date, gap.end))) {
      return gap;
    }
  }
  return null;
}

bool isFreeSchoolGap(TimeTableData day, DateTime now) =>
    schoolGapAt(day, now)?.kind == 'free_period';

String countdownText(Duration duration) {
  final seconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final hours = seconds ~/ 3600,
      minutes = (seconds ~/ 60) % 60,
      rest = seconds % 60;
  return hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}'
      : '${seconds ~/ 60}:${rest.toString().padLeft(2, '0')}';
}
