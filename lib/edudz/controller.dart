import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edudz/api.dart';
import 'package:edudz/server_config.dart';

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
      authenticated = true;
      demo = false;
      offline = false;
      selectedDate = DateUtils.dateOnly(DateTime.now());
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
            await data.timetable.loadTt(selectedDate);
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
    initializing = false;
    authenticated = true;
    demo = true;
    error = null;
    completed = {};
    notifyListeners();
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
    selectedDate = DateUtils.dateOnly(value);
    notifyListeners();
    if (!demo && authenticated) await refresh();
  }

  List<LessonEntry> get lessons {
    if (demo) {
      if (selectedDate.weekday > 5) return [];
      return [
        (
          subject: tr('Математика', 'Mathematics', 'Mathematik'),
          start: '08:00',
          end: '08:45',
          room: '204',
          teacher: 'Frau Müller',
          original: null
        ),
        (
          subject: tr('Німецька мова', 'German', 'Deutsch'),
          start: '08:55',
          end: '09:40',
          room: '112',
          teacher: 'Herr Schmidt',
          original: null
        ),
        (
          subject: tr('Біологія', 'Biology', 'Biologie'),
          start: '10:00',
          end: '10:45',
          room: '308',
          teacher: 'Frau Weber',
          original: null
        ),
        (
          subject: tr('Англійська мова', 'English', 'Englisch'),
          start: '10:55',
          end: '11:40',
          room: '112',
          teacher: 'Mrs. Taylor',
          original: null
        ),
        (
          subject: tr('Історія', 'History', 'Geschichte'),
          start: '12:00',
          end: '12:45',
          room: '206',
          teacher: 'Herr Fischer',
          original: null
        ),
      ];
    }
    final list = data.timetable.timetables[selectedDate]?.classes ?? [];
    return list
        .map((l) => (
              subject: l.subject?.name ?? '—',
              start: l.startTime,
              end: l.endTime,
              room: l.classrooms.map((r) => r.name).join(', '),
              teacher: l.teachers
                  .map((t) => '${t.firstName} ${t.lastName}'.trim())
                  .join(', '),
              original: l
            ))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
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
