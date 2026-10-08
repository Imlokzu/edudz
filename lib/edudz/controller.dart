import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edudz/api.dart';
import 'package:edudz/server_config.dart';
import 'school_day.dart';

typedef LessonEntry = ({
  String subject,
  String start,
  String end,
  String room,
  String teacher,
  TimeTableClass? original
});
typedef TaskEntry = ({
  String id,
  String subject,
  String title,
  String details,
  DateTime? due,
  Homework? original
});
typedef GradeEntry = ({
  String subject,
  String value,
  String title,
  String date
});
typedef MessageEntry = ({
  String title,
  String sender,
  DateTime date,
  TimelineItem? original
});
String plainText(String value) => HtmlUnescape().convert(value
    .replaceAll(RegExp(r'<br\s*/?>|</p>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .trim());
String schoolSubdomain(String input) {
  var value = input
      .trim()
      .toLowerCase()
      .replaceFirst(RegExp(r'^https?://'), '')
      .split('/')
      .first;
  value = value.replaceFirst(RegExp(r'\.edupage\.org$'), '');
  return RegExp(r'^[a-z0-9][a-z0-9-]*$').hasMatch(value) ? value : '';
}

String resolvedSchool(String token, String fallback) {
  try {
    final part = token.split('.')[1];
    final payload =
        jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(part))));
    final school = schoolSubdomain(payload['server']?.toString() ?? '');
    if (school.isNotEmpty) return school;
  } catch (_) {
    /* The fallback supports older backends without a server claim. */
  }
  return schoolSubdomain(fallback);
}

DateTime? schoolDate(String value) => DateTime.tryParse(value.split(' ').first);

class SchoolController extends ChangeNotifier {
  SchoolController({DateTime Function()? nowProvider})
      : _deviceNow = nowProvider ?? DateTime.now;
  final DateTime Function() _deviceNow;
  final ValueNotifier<DateTime> clock = ValueNotifier(DateTime.now());
  DateTime? _serverWallTime, _receivedAt;
  String _clockPhaseKey = '';
  bool _manualDate = false;
  bool _updatingDay = false;
  DateTime? _lastDayCheck;
  DateTime? _lastDayAttempt;
  DateTime? _lastSnapshotAt;
  bool _disposed = false;

  DateTime get schoolNow => _serverWallTime == null
      ? _deviceNow()
      : _serverWallTime!.add(_deviceNow().difference(_receivedAt!));
  DateTime get today => DateUtils.dateOnly(schoolNow);

  TimeTableData dayFor(DateTime date) {
    final key = DateUtils.dateOnly(date);
    if (demo) return _demoDay(key);
    if (!authenticated) return TimeTableData(key, [], []);
    return data.timetable.timetables[key] ??
        TimeTableData(key, [], data.timetable.periods ?? []);
  }

  SchoolDayState get schoolState => schoolDayState(dayFor(today), schoolNow);
  DateTime get homeDate {
    final state = schoolState;
    if (state.phase != SchoolPhase.afterSchool &&
        state.phase != SchoolPhase.noSchool) {
      return today;
    }
    for (var offset = 1; offset <= 60; offset++) {
      final date = schoolCalendarDay(today, offset);
      if (dayFor(date).classes.any((l) => !l.changes.cancelled)) return date;
    }
    return today;
  }

  bool get showingNextDay => !DateUtils.isSameDay(homeDate, today);
  List<LessonEntry> get homeLessons => _entries(dayFor(homeDate));

  void tickSchoolClock() {
    if (!authenticated || _disposed) return;
    clock.value = schoolNow;
    final state = schoolState;
    final key =
        '${today.toIso8601String()}:${state.phase}:${state.breakKind}:${state.endsAt}:${state.current?.period}:${homeDate.toIso8601String()}';
    if (key != _clockPhaseKey) {
      _clockPhaseKey = key;
      if (!_manualDate) selectedDate = homeDate;
      notifyListeners();
    }
    if (!demo &&
        !_updatingDay &&
        !loading &&
        (_lastDayAttempt == null ||
            _deviceNow().difference(_lastDayAttempt!).inSeconds >= 60) &&
        (_lastSnapshotAt == null ||
            _deviceNow().difference(_lastSnapshotAt!).inSeconds >= 60 ||
            !DateUtils.isSameDay(_lastDayCheck, today))) {
      _updatingDay = true;
      _lastDayAttempt = _deviceNow();
      _updateSchoolSnapshot().catchError((Object _) {
        if (_disposed || !authenticated) return;
        final section = tr('розклад', 'timetable', 'Stundenplan');
        if (!failedSections.contains(section)) {
          failedSections.add(section);
          notifyListeners();
        }
      }).whenComplete(() {
        _updatingDay = false;
      });
    }
  }

  Future<void> _updateSchoolSnapshot() async {
    await ensureSession();
    await loadSchoolSnapshot();
  }

  void showHomeDay() {
    _manualDate = false;
    selectedDate = homeDate;
    notifyListeners();
  }

  Future<void> loadSchoolSnapshot({DateTime? date}) async {
    final token = data.user.token;
    final response = await data.dio.get('${data.baseUrl}/api/school-day',
        queryParameters: date == null
            ? null
            : {'date': date.toIso8601String().split('T').first},
        options: Options(headers: {'Authorization': 'Bearer $token'}));
    if (_disposed || !authenticated || demo || data.user.token != token) return;
    final value = Map<String, dynamic>.from(response.data);
    final serverTime = value['server_time'] as String;
    _serverWallTime = DateTime.parse(serverTime.substring(0, 19));
    _receivedAt = _deviceNow();
    final periods = (value['periods'] as Map)
        .values
        .map((p) => TimeTablePeriod.fromJson(Map<String, dynamic>.from(p)))
        .toList();
    data.timetable.periods = periods;
    final breaks = value['scheduled_breaks'] == null
        ? defaultSchoolBreaks
        : (value['scheduled_breaks'] as List)
            .map((p) => SchoolBreak.fromJson(Map<String, dynamic>.from(p)))
            .toList();
    for (final entry in (value['days'] as Map).entries) {
      final date = DateTime.parse(entry.key as String);
      final items = (entry.value as List)
          .map((item) =>
              TimeTableClass.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      data.timetable.timetables[DateUtils.dateOnly(date)] = normalizeTimetable(
          TimeTableData(date, items, periods, breaks: breaks));
    }
    await data.timetable.saveToCache();
    if (_disposed || !authenticated || demo || data.user.token != token) return;
    _lastDayCheck = today;
    _lastSnapshotAt = _deviceNow();
    failedSections.remove(tr('розклад', 'timetable', 'Stundenplan'));
    if (!_manualDate) selectedDate = homeDate;
    clock.value = schoolNow;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    clock.dispose();
    super.dispose();
  }

  final EP2Data data = EP2Data.getInstance();
  bool initializing = true,
      authenticated = false,
      demo = false,
      loading = false,
      dark = false,
      offline = false;
  String language = 'uk';
  String? error;
  List<String> failedSections = [];
  DateTime selectedDate = DateUtils.dateOnly(DateTime.now());
  DateTime? lastSync;
  Set<String> completed = {};
  SharedPreferences? _prefs;
  String tr(String uk, String en, [String? de]) => language == 'uk'
      ? uk
      : language == 'de'
          ? de ?? en
          : en;
  String get name => !authenticated
      ? ''
      : demo
          ? 'Alex'
          : data.user.name.isEmpty
              ? data.user.username
              : data.user.name;
  String get school => !authenticated
      ? ''
      : demo
          ? 'Demo school'
          : data.user.server;

  Future<void> start() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      data.sharedPreferences = _prefs!;
      data.baseUrl = ep2ServerUrl;
      dark = _prefs!.getBool('edudz_dark') ?? false;
      language = _prefs!.getString('edudz_language') ?? 'uk';
      completed = (_prefs!.getStringList('edudz_completed') ?? []).toSet();
      lastSync = DateTime.tryParse(_prefs!.getString('edudz_sync') ?? '');
      final account = await User.loadFromCache();
      if (account != null) {
        data.user = account;
        data.timeline = await Timeline.loadFromCache() ??
            Timeline(homeworks: {}, items: {});
        data.timetable = await TimeTable.loadFromCache() ?? TimeTable();
        data.grades =
            await Grades.loadFromCache() ?? Grades(events: {}, notes: {});
        data.dbi = await DBI.loadFromCache() ?? DBI(subjects: {});
        authenticated = true;
      }
    } catch (_) {
      error = tr(
          'Не вдалося відновити сесію. Увійдіть ще раз.',
          'Could not restore your session. Please sign in again.',
          'Sitzung konnte nicht geladen werden. Bitte erneut anmelden.');
    } finally {
      initializing = false;
      notifyListeners();
    }
    if (authenticated) await refresh();
  }

  Future<void> login(String username, String password, String school) async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      _prefs ??= await SharedPreferences.getInstance();
      data.sharedPreferences = _prefs!;
      data.baseUrl = ep2ServerUrl;
      final response = await data.dio.post('$ep2ServerUrl/login',
          data: {
            'username': username.trim(),
            'password': password,
            'server': schoolSubdomain(school)
          },
          options: Options(contentType: Headers.formUrlEncodedContentType));
      final account = User(
          username: username.trim(),
          password: password,
          server: resolvedSchool(response.data['token'], school))
        ..token = response.data['token']
        ..name = response.data['name'] ?? '';
      // Remove the previous account's school data before saving a new identity.
      for (final key in ['timeline', 'timetable', 'grades', 'dbi']) {
        await _prefs!.remove(key);
      }
      await account.saveToCache();
      data.user = account;
      data.timeline = Timeline(homeworks: {}, items: {});
      data.timetable = TimeTable();
      data.grades = Grades(events: {}, notes: {});
      data.dbi = DBI(subjects: {});
      await _prefs!.setBool('onboardingCompleted', true);
      await _prefs!.setBool('demo', false);
      await _prefs!.remove('edudz_completed');
      await _prefs!.remove('edudz_sync');
      completed = {};
      lastSync = null;
      _resetClock();
      authenticated = true;
      demo = false;
      offline = false;
      selectedDate = today;
    } on DioException catch (e) {
      error = e.response?.statusCode == 401 || e.response?.statusCode == 403
          ? tr(
              'Перевірте школу, логін і пароль EduPage.',
              'Check your school, EduPage username and password.',
              'Bitte Schule, Benutzername und Passwort prüfen.')
          : tr(
              'Сервер недоступний. Перевірте інтернет і спробуйте ще раз.',
              'Server unavailable. Check your connection and try again.',
              'Server nicht erreichbar. Verbindung prüfen und erneut versuchen.');
    } catch (_) {
      error = tr(
          'Не вдалося зберегти сесію. Спробуйте ще раз.',
          'Could not save your session. Please try again.',
          'Sitzung konnte nicht gespeichert werden. Erneut versuchen.');
    } finally {
      loading = false;
      notifyListeners();
    }
    if (authenticated) await refresh();
  }

  Future<void> ensureSession() async {
    if (demo) return;
    if (!authenticated) throw StateError('Sign-in required');
    if (await data.user.validate()) return;
    if (!await data.user.login()) {
      throw StateError('Could not restore school session');
    }
  }

  Future<void> refresh() async {
    if (loading || demo || !authenticated) return;
    loading = true;
    error = null;
    failedSections = [];
    notifyListeners();
    try {
      if (!await isConnected()) {
        offline = true;
        return;
      }
      if (!await data.user.validate() && !await data.user.login()) {
        final status = data.user.lastLoginFailure?.response?.statusCode;
        if (status == 401 || status == 403) {
          error = tr(
              'Сесію завершено. Увійдіть знову.',
              'Session expired. Please sign in again.',
              'Sitzung abgelaufen. Bitte erneut anmelden.');
          authenticated = false;
        } else {
          offline = true;
        }
        return;
      }
      offline = false;
      final oldDay = data.timetable.timetables.remove(selectedDate);
      final jobs = <(String, Future<void> Function())>[
        (
          tr('завдання і повідомлення', 'tasks and messages',
              'Aufgaben und Nachrichten'),
          data.timeline.loadMessages
        ),
        (
          tr('розклад', 'timetable', 'Stundenplan'),
          () async {
            await loadSchoolSnapshot();
            if (!data.timetable.timetables.containsKey(selectedDate)) {
              await loadSchoolSnapshot(date: selectedDate);
            }
          }
        ),
        (tr('оцінки', 'grades', 'Noten'), data.grades.loadGrades),
      ];
      for (var i = 0; i < jobs.length; i++) {
        try {
          await jobs[i].$2();
        } catch (_) {
          failedSections.add(jobs[i].$1);
          if (i == 1 && oldDay != null) {
            data.timetable.timetables[selectedDate] = oldDay;
          }
        }
      }
      for (final id
          in data.grades.events.values.map((e) => e.subjectID).toSet()) {
        await data.dbi.getSubject(id);
      }
      if (failedSections.isEmpty) {
        lastSync = DateTime.now();
        await _prefs?.setString('edudz_sync', lastSync!.toIso8601String());
      }
    } catch (_) {
      offline = true;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void enterDemo() {
    _resetClock();
    initializing = false;
    authenticated = true;
    demo = true;
    error = null;
    completed = {};
    selectedDate = homeDate;
    notifyListeners();
  }

  void _resetClock() {
    _serverWallTime = null;
    _receivedAt = null;
    _lastDayCheck = null;
    _lastDayAttempt = null;
    _lastSnapshotAt = null;
    _clockPhaseKey = '';
    _manualDate = false;
    clock.value = schoolNow;
  }

  Future<void> logout() async {
    if (loading) return;
    if (!demo) {
      await data.clearCache();
      for (final key in [
        'dbi',
        'edudz_completed',
        'edudz_sync',
        'onboardingCompleted'
      ]) {
        await _prefs?.remove(key);
      }
    }
    authenticated = false;
    demo = false;
    _resetClock();
    completed = {};
    lastSync = null;
    error = null;
    failedSections = [];
    notifyListeners();
  }

  Future<void> setLanguage(String value) async {
    language = value;
    await _prefs?.setString('edudz_language', value);
    notifyListeners();
  }

  Future<void> setDark(bool value) async {
    dark = value;
    await _prefs?.setBool('edudz_dark', value);
    notifyListeners();
  }

  Future<void> toggleTask(String id) async {
    completed.contains(id) ? completed.remove(id) : completed.add(id);
    if (!demo) {
      await _prefs?.setStringList('edudz_completed', completed.toList());
    }
    notifyListeners();
  }

  Future<void> selectDay(DateTime value) async {
    if (loading) return;
    _manualDate = true;
    selectedDate = DateUtils.dateOnly(value);
    notifyListeners();
    if (!demo && authenticated) await refresh();
  }

  List<LessonEntry> get lessons => _entries(dayFor(selectedDate));

  LessonEntry? resolveLesson(LessonEntry? entry) {
    final original = entry?.original;
    final date = DateTime.tryParse(original?.date ?? '');
    if (entry == null || original == null || date == null) return entry;
    final matches = _entries(dayFor(date))
        .where((l) =>
            l.start == entry.start &&
            l.original?.period == original.period &&
            (l.original?.type == 'event') == (original.type == 'event'))
        .toList();
    if (matches.length == 1) return matches.single;
    final active = matches
        .where((l) =>
            l.original?.changes.cancelled != true &&
            (l.original?.subject?.id == original.subject?.id ||
                l.original?.changes.originalSubject == entry.subject))
        .toList();
    return active.length == 1 ? active.single : entry;
  }

  List<LessonEntry> _entries(TimeTableData day) => normalizeTimetable(day)
      .classes
      .map((l) => (
            subject: l.subject?.name.isNotEmpty == true
                ? l.subject!.name
                : tr('Урок', 'Lesson', 'Stunde'),
            start: l.startTime,
            end: l.endTime,
            room: l.classrooms.map((r) => r.name).join(', '),
            teacher: l.teachers
                .map((t) => '${t.firstName} ${t.lastName}'.trim())
                .join(', '),
            original: l,
          ))
      .toList();

  TimeTableData _demoDay(DateTime date) {
    if (date.weekday > 5) return TimeTableData(date, [], []);
    final periods = <TimeTablePeriod>[
      TimeTablePeriod('1', '08:00', '08:45', '1.', '1'),
      TimeTablePeriod('2', '08:45', '09:30', '2.', '2'),
      TimeTablePeriod('3', '09:45', '10:30', '3.', '3'),
      TimeTablePeriod('4', '10:30', '11:15', '4.', '4'),
      TimeTablePeriod('5', '11:30', '12:15', '5.', '5'),
      TimeTablePeriod('6', '12:15', '13:00', '6.', '6'),
    ];
    TimeTableClass lesson(String id, String name, String period, String start,
            String end, String room, String teacher) =>
        TimeTableClass(
          period: period,
          startTime: start,
          endTime: end,
          date: date.toIso8601String().split('T').first,
          subject: Subject(id: id, name: name, short: name, cbHidden: false),
          classrooms: [Classroom(id: room, name: room, short: room)],
          teachers: [
            Teacher(
                id: teacher,
                firstName: teacher,
                lastName: '',
                short: teacher,
                gender: '',
                classroomId: room,
                dateFrom: '',
                dateTo: '',
                isOut: false)
          ],
          studentIds: ['demo'],
        );
    final classes = [
      lesson('math', tr('Математика', 'Mathematics', 'Mathematik'), '1',
          '08:00', '09:30', '204', 'Frau Müller'),
      lesson('german', tr('Німецька мова', 'German', 'Deutsch'), '3', '09:45',
          '10:30', '112', 'Herr Schmidt'),
      lesson('biology', tr('Біологія', 'Biology', 'Biologie'), '4', '10:30',
          '11:15', '308', 'Frau Weber'),
      lesson('english', tr('Англійська мова', 'English', 'Englisch'), '5',
          '11:30', '13:00', '112', 'Mrs. Taylor'),
    ];
    return normalizeTimetable(TimeTableData(date, classes, periods));
  }

  List<TaskEntry> get tasks {
    if (demo) {
      return [
        (
          id: 'demo1',
          subject: tr('Математика', 'Mathematics', 'Mathematik'),
          title: tr('Квадратні рівняння', 'Quadratic equations',
              'Quadratische Gleichungen'),
          details: tr(
              'Сторінка 42, вправи 3–7. Запишіть усі кроки розв’язання.',
              'Page 42, exercises 3–7. Show all your working.',
              'Seite 42, Aufgaben 3–7. Alle Rechenschritte aufschreiben.'),
          due: DateTime.now().add(const Duration(days: 1)),
          original: null
        ),
        (
          id: 'demo2',
          subject: tr('Англійська мова', 'English', 'Englisch'),
          title: tr('Прочитати наступний розділ', 'Read the next chapter',
              'Das nächste Kapitel lesen'),
          details: tr(
              'Підготуйте короткий переказ розділу 5.',
              'Prepare a short summary of chapter 5.',
              'Eine kurze Zusammenfassung von Kapitel 5 vorbereiten.'),
          due: DateTime.now().add(const Duration(days: 2)),
          original: null
        ),
        (
          id: 'demo3',
          subject: tr('Біологія', 'Biology', 'Biologie'),
          title: tr('Будова клітини', 'The structure of a cell',
              'Aufbau einer Zelle'),
          details: tr(
              'Намалюйте клітину та підпишіть її частини.',
              'Draw a cell and label its parts.',
              'Eine Zelle zeichnen und die Bestandteile beschriften.'),
          due: DateTime.now().add(const Duration(days: 3)),
          original: null
        ),
      ];
    }
    return data.timeline.homeworks.values
        .where((t) => t.name.trim().isNotEmpty)
        .map((t) => (
              id: t.id,
              subject: plainText(t.lessonName),
              title: plainText(t.name),
              details: plainText(t.details),
              due: schoolDate(t.dateTo),
              original: t,
            ))
        .toList()
      ..sort((a, b) =>
          (a.due ?? DateTime(2100)).compareTo(b.due ?? DateTime(2100)));
  }

  List<GradeEntry> get grades {
    if (demo) {
      return [
        (
          subject: tr('Математика', 'Mathematics', 'Mathematik'),
          value: '2',
          title: tr('Самостійна робота', 'Class test', 'Klassenarbeit'),
          date: '2026-10-05'
        ),
        (
          subject: tr('Англійська мова', 'English', 'Englisch'),
          value: '1',
          title: tr('Усна відповідь', 'Oral assessment', 'Mündliche Leistung'),
          date: '2026-10-02'
        ),
        (
          subject: tr('Біологія', 'Biology', 'Biologie'),
          value: '2+',
          title: tr('Проєкт', 'Project', 'Projekt'),
          date: '2026-09-30'
        ),
      ];
    }
    return data.grades.events.values
        .map((g) => (
              subject: data.dbi.subjects[g.subjectID]?.name ?? g.subjectID,
              value: g.data,
              title: plainText(g.eventName),
              date: g.date
            ))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<MessageEntry> get messages {
    if (demo) {
      return [
        (
          title: tr('Екскурсія наступної п’ятниці', 'School trip next Friday',
              'Schulausflug am nächsten Freitag'),
          sender: 'Frau Müller',
          date: DateTime.now().subtract(const Duration(hours: 2)),
          original: null
        ),
        (
          title: tr('Зміна кабінету: англійська', 'Room change: English',
              'Raumänderung: Englisch'),
          sender: 'Sekretariat',
          date: DateTime.now().subtract(const Duration(days: 1)),
          original: null
        ),
      ];
    }
    return data.timeline.items.values
        .where((m) =>
            m.removed == 0 && m.text.trim().isNotEmpty && m.reactionTo.isEmpty)
        .map((m) => (
              title: plainText(m.text),
              sender: m.userName.isNotEmpty ? m.userName : m.ownerName,
              date: m.timestamp,
              original: m
            ))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }
}
