import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:edudz/message.dart';
import 'package:flutter_session_manager/flutter_session_manager.dart';
import 'controller.dart';
import 'theme.dart';
import 'details.dart';
import 'assistant.dart';
import 'school_day.dart';

class EdudzShell extends StatefulWidget {
  const EdudzShell({super.key, required this.controller});
  final SchoolController controller;
  @override
  State<EdudzShell> createState() => _EdudzShellState();
}

class _EdudzShellState extends State<EdudzShell> with WidgetsBindingObserver {
  Timer? _schoolClock;
  int tab = 0;
  bool showDone = false;
  TaskEntry? selectedTask;
  LessonEntry? selectedLesson;
  SchoolController get c => widget.controller;
  String t(String uk, String en, [String? de]) => c.tr(uk, en, de);
  String date(DateTime value, [String pattern = 'd MMM']) =>
      DateFormat(pattern, c.language).format(value);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startClock();
  }

  void _startClock() {
    _schoolClock?.cancel();
    _schoolClock = Timer.periodic(const Duration(seconds: 1), (_) {
      c.tickSchoolClock();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      c.tickSchoolClock();
      _startClock();
      c.refresh();
    } else {
      _schoolClock?.cancel();
    }
  }

  @override
  void dispose() {
    _schoolClock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void changeTab(int value) {
    if (value == 0) c.showHomeDay();
    setState(() {
      tab = value;
      selectedTask = null;
      selectedLesson = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (c.initializing) {
      return const Scaffold(body: Center(child: BrandMark(size: 72)));
    }
    if (!c.authenticated) return LoginScreen(controller: c);
    final titles = [
      t('Твій день', 'Your day', 'Dein Tag'),
      t('Розклад', 'Timetable', 'Stundenplan'),
      t('Завдання', 'Homework', 'Aufgaben'),
      t('Оцінки', 'Grades', 'Noten'),
      t('Вхідні', 'Inbox', 'Nachrichten')
    ];
    return LayoutBuilder(builder: (context, layout) {
      final tablet = layout.maxWidth >= 700;
      final content = SafeArea(
          bottom: false,
          child: Center(
              child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 20, 12),
                  child: Row(children: [
                    const BrandMark(size: 34),
                    const SizedBox(width: 10),
                    Expanded(
                        child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text('edudz',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                        fontSize: 26, letterSpacing: -1)))),
                    if (c.demo)
                      Tag(t('ДЕМО', 'DEMO', 'DEMO'),
                          color: const Color(0xFFECE6D8)),
                    IconButton(
                        onPressed: () => showSettings(context, c),
                        tooltip: t('Налаштування', 'Settings', 'Einstellungen'),
                        icon: CircleAvatar(
                            radius: 19,
                            backgroundColor:
                                c.dark ? const Color(0xFF344A39) : mint,
                            child: Text(
                                c.name.isEmpty
                                    ? '?'
                                    : c.name.characters.first.toUpperCase(),
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w800)))),
                  ])),
              if (c.loading) const LinearProgressIndicator(minHeight: 2),
              if (c.demo || c.offline || c.failedSections.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _notice()),
              Expanded(
                  child: RefreshIndicator(
                      onRefresh: c.refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                        children: [
                          if (tab == 0)
                            ..._home(context)
                          else ...[
                            Text(titles[tab],
                                style:
                                    Theme.of(context).textTheme.headlineLarge),
                            const SizedBox(height: 8),
                            Text(
                                [
                                  '',
                                  t(
                                      'Плануй день у своєму ритмі.',
                                      'Make room for a good day.',
                                      'Dein Tag in deinem Rhythmus.'),
                                  t(
                                      'Крок за кроком. Усе встигнеш.',
                                      'One thing at a time. You’ve got this.',
                                      'Schritt für Schritt. Du schaffst das.'),
                                  t(
                                      'Твій прогрес у кожному предметі.',
                                      'Your progress, subject by subject.',
                                      'Dein Fortschritt in jedem Fach.'),
                                  t(
                                      'Усі шкільні новини під рукою.',
                                      'Everything happening at school.',
                                      'Alle Schulnachrichten an einem Ort.')
                                ][tab],
                                style: Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(height: 26),
                            if (tab == 1) ...[
                              _week(),
                              const SizedBox(height: 24),
                              ..._lessonList(context)
                            ],
                            if (tab == 2) ...[
                              _taskFilters(),
                              const SizedBox(height: 20),
                              ..._taskList(context)
                            ],
                            if (tab == 3) ..._gradeList(context),
                            if (tab == 4) ..._messageList(context),
                          ],
                        ],
                      ))),
            ]),
          )));
      return Scaffold(
        body: tablet
            ? Row(children: [
                SafeArea(
                    child: NavigationRail(
                  extended: layout.maxWidth >= 1100,
                  selectedIndex: tab,
                  onDestinationSelected: changeTab,
                  leading: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: BrandMark(size: 42)),
                  trailing: Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: IconButton.filledTonal(
                          onPressed: () => _assistant(),
                          tooltip: t('Асистент', 'Assistant', 'Assistent'),
                          icon: const Icon(Icons.auto_awesome))),
                  destinations: [
                    NavigationRailDestination(
                        icon: const Icon(Icons.grid_view_rounded),
                        label: Text(t('Сьогодні', 'Today', 'Heute'))),
                    NavigationRailDestination(
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(t('Розклад', 'Schedule', 'Plan'))),
                    NavigationRailDestination(
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(t('Завдання', 'Tasks', 'Aufgaben'))),
                    NavigationRailDestination(
                        icon: const Icon(Icons.bar_chart_rounded),
                        label: Text(t('Оцінки', 'Grades', 'Noten'))),
                    NavigationRailDestination(
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: Text(t('Вхідні', 'Inbox', 'Postfach'))),
                  ],
                )),
                const VerticalDivider(width: 1),
                Expanded(child: content),
                if (layout.maxWidth >= 1000 &&
                    (selectedTask != null || selectedLesson != null)) ...[
                  const VerticalDivider(width: 1),
                  SizedBox(
                      width: layout.maxWidth >= 1300 ? 420 : 360,
                      child: SafeArea(
                          child: DetailPane(
                        controller: c,
                        task: selectedTask,
                        lesson: selectedLesson,
                        onClose: () => setState(() {
                          selectedTask = null;
                          selectedLesson = null;
                        }),
                        onAsk: (prompt, task) =>
                            _assistant(prompt: prompt, task: task),
                      ))),
                ],
              ])
            : content,
        bottomNavigationBar: tablet
            ? null
            : NavigationBar(
                selectedIndex: tab,
                onDestinationSelected: changeTab,
                destinations: [
                    NavigationDestination(
                        icon: const Icon(Icons.grid_view_rounded),
                        label: t('Сьогодні', 'Today', 'Heute')),
                    NavigationDestination(
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: t('Розклад', 'Schedule', 'Plan')),
                    NavigationDestination(
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: t('Завдання', 'Tasks', 'Aufgaben')),
                    NavigationDestination(
                        icon: const Icon(Icons.bar_chart_rounded),
                        label: t('Оцінки', 'Grades', 'Noten')),
                    NavigationDestination(
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                        label: t('Вхідні', 'Inbox', 'Postfach')),
                  ]),
        floatingActionButton: tablet
            ? null
            : FloatingActionButton.small(
                onPressed: () => _assistant(),
                tooltip: t('Асистент', 'Assistant', 'Assistent'),
                child: const Icon(Icons.auto_awesome)),
      );
    });
  }

  Widget _notice() {
    final text = c.demo
        ? t(
            'Демонстраційні дані. Для своїх даних увійдіть у EduPage.',
            'Sample data. Sign in to EduPage to see your school.',
            'Beispieldaten. Für deine Schule bei EduPage anmelden.')
        : c.offline
            ? t(
                'Немає з’єднання. Показуємо збережені дані.',
                'Offline. Showing your saved data.',
                'Offline. Gespeicherte Daten werden angezeigt.')
            : '${t('Не вдалося оновити', 'Could not refresh', 'Aktualisierung fehlgeschlagen')}: ${c.failedSections.join(', ')}';
    return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(c.demo ? Icons.info_outline : Icons.cloud_off_outlined,
              size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
          if (!c.demo)
            IconButton(
                onPressed: c.loading ? null : c.refresh,
                tooltip: t('Повторити', 'Retry', 'Erneut versuchen'),
                icon: const Icon(Icons.refresh, size: 20)),
        ]));
  }

  List<Widget> _home(BuildContext context) {
    final pending =
        c.tasks.where((task) => !c.completed.contains(task.id)).toList();
    final lessons = c.homeLessons;
    return [
      Text(date(c.today, 'EEEE, d MMMM'),
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text(
          '${t('Привіт', 'Hey', 'Hallo')}, ${c.name.split(' ').first} ${String.fromCharCode(0x2728)}',
          style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 6),
      Text(
          t(
              'Усе для спокійного шкільного дня.',
              'A little clarity for your school day.',
              'Alles für einen entspannten Schultag.'),
          style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 26),
      _schoolStatus(context),
      const SizedBox(height: 24),
      Row(children: [
        Expanded(
            child: _stat(
                context,
                Icons.menu_book_outlined,
                '${lessons.length}',
                c.showingNextDay
                    ? t('Наступного дня', 'Next school day',
                        'Nächster Schultag')
                    : t('Уроків сьогодні', 'Lessons today', 'Stunden heute'),
                () => changeTab(1))),
        const SizedBox(width: 12),
        Expanded(
            child: _stat(
                context,
                Icons.done_all_rounded,
                '${pending.length}',
                t('На виконання', 'To get done', 'Zu erledigen'),
                () => changeTab(2)))
      ]),
      const SizedBox(height: 28),
      _section(
          c.showingNextDay
              ? t('Наступний навчальний день', 'Next school day',
                  'Nächster Schultag')
              : t('Твій розклад', 'Your schedule', 'Dein Stundenplan'), () {
        c.showHomeDay();
        changeTab(1);
      }),
      if (c.showingNextDay)
        Text(date(c.homeDate, 'EEEE, d MMMM'),
            style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 10),
      ..._lessonList(context, items: lessons),
      const SizedBox(height: 22),
      _section(t('Що на завтра?', 'What’s next?', 'Was steht an?'),
          () => changeTab(2)),
      const SizedBox(height: 10),
      if (pending.isEmpty)
        _empty(
            Icons.done_all_rounded,
            t(
                'Завдань немає. Можна видихнути.',
                'All caught up. Take a breather.',
                'Alles erledigt. Zeit zum Durchatmen.'))
      else
        ...pending.take(2).map((task) => _taskRow(context, task)),
    ];
  }

  Widget _schoolStatus(BuildContext context) => ValueListenableBuilder<
          DateTime>(
      valueListenable: c.clock,
      builder: (context, _, child) {
        final now = c.schoolNow;
        final state = c.schoolState;
        final nextDay = c.showingNextDay;
        final displayed = schoolDayState(c.dayFor(c.homeDate), now);
        final current = state.current;
        final next = state.next;
        final title = switch (state.phase) {
          SchoolPhase.lesson => current?.subject?.name ?? '—',
          SchoolPhase.breakTime => isFreeSchoolGap(c.dayFor(c.today), now)
              ? t('Вільний час', 'Free period', 'Freistunde')
              : t('Перерва', 'Break', 'Pause'),
          SchoolPhase.beforeSchool =>
            '${t('Школа починається о', 'School starts at', 'Schule beginnt um')} ${state.next?.startTime}',
          SchoolPhase.afterSchool => t('Школу на сьогодні завершено',
              'School is finished for today', 'Schule für heute beendet'),
          SchoolPhase.noSchool => t('Сьогодні уроків немає', 'No school today',
              'Heute kein Unterricht'),
        };
        final phaseLabel = switch (state.phase) {
          SchoolPhase.lesson =>
            '${t('УРОК', 'LESSON', 'STUNDE')} ${current?.period ?? ''}',
          SchoolPhase.breakTime => isFreeSchoolGap(c.dayFor(c.today), now)
              ? t('ВІЛЬНИЙ ЧАС', 'FREE PERIOD', 'FREISTUNDE')
              : t('ПЕРЕРВА', 'BREAK', 'PAUSE'),
          SchoolPhase.beforeSchool =>
            t('ДО ПОЧАТКУ ШКОЛИ', 'BEFORE SCHOOL', 'VOR SCHULBEGINN'),
          SchoolPhase.afterSchool =>
            t('НА СЬОГОДНІ ВСЕ', 'ALL DONE TODAY', 'FÜR HEUTE GESCHAFFT'),
          SchoolPhase.noSchool =>
            t('ВІЛЬНИЙ ДЕНЬ', 'DAY OFF', 'UNTERRICHTSFREI'),
        };
        final countdown = nextDay ? displayed : state;
        final countdownLabel = nextDay ||
                state.phase == SchoolPhase.beforeSchool
            ? t('До початку школи', 'Until school starts', 'Bis Schulbeginn')
            : state.phase == SchoolPhase.breakTime
                ? t('До наступного уроку', 'Until the next lesson',
                    'Bis zur nächsten Stunde')
                : t('До кінця уроку', 'Until the lesson ends',
                    'Bis Stundenende');
        return Container(
            key: const ValueKey('school-status'),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: forest, borderRadius: BorderRadius.circular(28)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(phaseLabel,
                  style: const TextStyle(
                      color: mint,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5)),
              const SizedBox(height: 14),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 29,
                      letterSpacing: -.9,
                      fontWeight: FontWeight.w700)),
              if (state.phase == SchoolPhase.lesson) ...[
                const SizedBox(height: 12),
                _heroLabel(Icons.schedule,
                    '${current!.startTime} — ${current.endTime}'),
                if (current.classrooms.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _heroLabel(Icons.location_on_outlined,
                      '${t('Каб.', 'Room', 'Raum')} ${current.classrooms.map((r) => r.name).join(', ')}'),
                ],
              ],
              if (state.phase == SchoolPhase.breakTime && next != null) ...[
                const SizedBox(height: 12),
                Text(
                    '${t('Далі', 'Next', 'Danach')}: ${next.period}. ${next.subject?.name ?? ''} · ${next.startTime}',
                    style: const TextStyle(color: mint, fontSize: 14)),
              ],
              if (nextDay) ...[
                const SizedBox(height: 14),
                Text(
                    '${t('Наступний навчальний день', 'Next school day', 'Nächster Schultag')}: ${date(c.homeDate, 'EEEE, d MMMM')} · ${displayed.next?.startTime ?? ''} — ${displayed.end == null ? '' : DateFormat('HH:mm').format(displayed.end!)}',
                    style: const TextStyle(color: mint, fontSize: 14)),
              ],
              if (countdown.endsAt != null) ...[
                const SizedBox(height: 20),
                Text(countdownLabel,
                    style: const TextStyle(color: mint, fontSize: 12)),
                const SizedBox(height: 4),
                Text(countdownText(countdown.remainingTime(now)),
                    key: const ValueKey('school-countdown'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()])),
              ],
              const SizedBox(height: 18),
              Container(height: 1, color: Colors.white.withValues(alpha: .18)),
              const SizedBox(height: 14),
              Text(
                  '${t('Залишилось уроків', 'Lessons remaining', 'Verbleibende Stunden')}: ${state.remaining} / ${state.total}',
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
              if (state.start != null && state.end != null) ...[
                const SizedBox(height: 8),
                Text(
                    '${t('Сьогодні', 'Today', 'Heute')}: ${DateFormat('HH:mm').format(state.start!)} — ${DateFormat('HH:mm').format(state.end!)}',
                    style: const TextStyle(color: mint, fontSize: 13)),
              ],
            ]));
      });

  Widget _heroLabel(IconData icon, String text) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: mint, size: 17),
        const SizedBox(width: 7),
        Flexible(
            child: Text(text,
                style: const TextStyle(color: Colors.white, fontSize: 13)))
      ]);
  Widget _stat(BuildContext context, IconData icon, String number, String label,
          VoidCallback tap) =>
      Surface(
          onTap: tap,
          child: Padding(
              padding: const EdgeInsets.all(17),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(icon,
                          size: 21,
                          color: Theme.of(context).colorScheme.primary),
                      const Spacer(),
                      Text(number,
                          style: Theme.of(context).textTheme.headlineMedium)
                    ]),
                    const SizedBox(height: 8),
                    Text(label, style: Theme.of(context).textTheme.bodySmall),
                  ])));
  Widget _section(String title, VoidCallback tap) => Row(children: [
        Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
        TextButton(
            onPressed: tap, child: Text(t('Усе →', 'See all →', 'Alle →')))
      ]);
  Widget _week() {
    final monday =
        schoolCalendarDay(c.selectedDate, 1 - c.selectedDate.weekday);
    return Column(children: [
      Row(children: [
        IconButton(
            onPressed: c.loading
                ? null
                : () => c.selectDay(schoolCalendarDay(c.selectedDate, -7)),
            tooltip:
                t('Попередній тиждень', 'Previous week', 'Vorherige Woche'),
            icon: const Icon(Icons.chevron_left)),
        Expanded(
            child: Center(
                child: Text(
                    '${date(monday)} — ${date(schoolCalendarDay(monday, 6))}',
                    style: Theme.of(context).textTheme.titleMedium))),
        IconButton(
            onPressed: c.loading
                ? null
                : () => c.selectDay(schoolCalendarDay(c.selectedDate, 7)),
            tooltip: t('Наступний тиждень', 'Next week', 'Nächste Woche'),
            icon: const Icon(Icons.chevron_right))
      ]),
      const SizedBox(height: 12),
      Row(
          children: List.generate(7, (i) {
        final day = schoolCalendarDay(monday, i);
        final selected = DateUtils.isSameDay(day, c.selectedDate);
        return Expanded(
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Semantics(
                    selected: selected,
                    button: true,
                    label: date(day, 'EEEE d MMMM'),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: c.loading ? null : () => c.selectDay(day),
                      child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                              color: selected ? forest : Colors.transparent,
                              borderRadius: BorderRadius.circular(18)),
                          child: Column(children: [
                            Text(date(day, 'EE'),
                                style: TextStyle(
                                    color: selected
                                        ? mint
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                    fontSize: 11)),
                            const SizedBox(height: 8),
                            Text('${day.day}',
                                style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 5),
                            Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                    color: DateUtils.isSameDay(day, c.today)
                                        ? (selected ? mint : forest)
                                        : Colors.transparent,
                                    shape: BoxShape.circle)),
                          ])),
                    ))));
      })),
      TextButton(
          onPressed: c.loading ? null : () => c.selectDay(c.today),
          child: Text(t('До сьогодні', 'Back to today', 'Zurück zu heute'))),
    ]);
  }

  List<Widget> _lessonList(BuildContext context, {List<LessonEntry>? items}) {
    final lessons = items ?? c.lessons;
    if (lessons.isEmpty) {
      return [
        _empty(
            Icons.wb_sunny_outlined,
            t('На цей день уроків немає.', 'No lessons on this day.',
                'An diesem Tag kein Unterricht.'))
      ];
    }
    final rows = <Widget>[];
    for (var i = 0; i < lessons.length; i++) {
      final l = lessons[i];
      if (i > 0) {
        final end = clockMinutes(lessons[i - 1].end)!;
        final start = clockMinutes(l.start)!;
        if (start > end) {
          final lessonDate =
              DateTime.tryParse(l.original?.date ?? '') ?? c.selectedDate;
          final free =
              gapContainsPeriod(end, start, c.dayFor(lessonDate).periods);
          rows.add(Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(children: [
                Icon(free ? Icons.hourglass_empty : Icons.coffee_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(
                        '${free ? t('Вільний час', 'Free period', 'Freistunde') : t('Перерва', 'Break', 'Pause')} · ${start - end} ${t('хв', 'min', 'Min.')} · ${lessons[i - 1].end} — ${l.start}',
                        style: Theme.of(context).textTheme.bodySmall)),
              ])));
        }
      }
      rows.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Surface(
              onTap: () => _lessonDetail(l),
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                            width: 48,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${l.original?.period ?? i + 1}.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge),
                                  const SizedBox(height: 6),
                                  Text(l.start,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700)),
                                  Text(l.end,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                ])),
                        const SizedBox(width: 12),
                        Container(
                            width: 3,
                            height: 48,
                            decoration: BoxDecoration(
                                color: [
                                  const Color(0xFF92AC7B),
                                  const Color(0xFFE4B980),
                                  const Color(0xFF96B8CA)
                                ][i % 3],
                                borderRadius: BorderRadius.circular(5))),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(l.subject,
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 4),
                              Text(l.teacher,
                                  style: Theme.of(context).textTheme.bodySmall),
                              if (l.room.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text('${t('Каб.', 'Room', 'Raum')} ${l.room}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                              ],
                            ])),
                      ])))));
    }
    return rows;
  }

  Widget _taskFilters() => Row(children: [
        ChoiceChip(
            label: Text(t('На виконання', 'To do', 'Offen')),
            selected: !showDone,
            onSelected: (_) => setState(() => showDone = false)),
        const SizedBox(width: 10),
        ChoiceChip(
            label: Text(t('Готово', 'Done', 'Erledigt')),
            selected: showDone,
            onSelected: (_) => setState(() => showDone = true)),
      ]);
  List<Widget> _taskList(BuildContext context) {
    final list = c.tasks
        .where((task) => c.completed.contains(task.id) == showDone)
        .toList();
    if (list.isEmpty) {
      return [
        _empty(
            Icons.check_circle_outline,
            t(
                'Тут усе спокійно. Завдань немає.',
                'Nothing here. You’re all caught up.',
                'Alles ruhig. Keine Aufgaben.'))
      ];
    }
    return list.map((task) => _taskRow(context, task)).toList();
  }

  Widget _taskRow(BuildContext context, TaskEntry task) {
    final done = c.completed.contains(task.id);
    final overdue = task.due != null &&
        DateUtils.dateOnly(task.due!)
            .isBefore(DateUtils.dateOnly(DateTime.now()));
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Surface(
            onTap: () => _taskDetail(task),
            child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                          value: done,
                          onChanged: (_) => c.toggleTask(task.id),
                          semanticLabel: t(
                              'Позначити виконаним на цьому пристрої',
                              'Mark done on this device',
                              'Auf diesem Gerät als erledigt markieren'),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6))),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(task.subject,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        fontWeight: FontWeight.w700)),
                            const SizedBox(height: 7),
                            Text(task.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                        decoration: done
                                            ? TextDecoration.lineThrough
                                            : null)),
                            const SizedBox(height: 10),
                            Wrap(spacing: 8, runSpacing: 5, children: [
                              if (task.due != null)
                                Tag('${overdue ? t('Минуло', 'Past due', 'Überfällig') : t('До', 'Due', 'Bis')} ${date(task.due!)}',
                                    color: overdue
                                        ? const Color(0xFFF5E1D8)
                                        : null),
                              if (done) Tag(t('Готово', 'Done', 'Erledigt')),
                            ]),
                          ])),
                      const SizedBox(width: 6),
                      Icon(Icons.north_east,
                          size: 16,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ]))));
  }

  void _assistant({String? prompt, TaskEntry? task}) => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => AssistantScreen(
              controller: c, initialPrompt: prompt, task: task)));

  void _taskDetail(TaskEntry task) {
    if (MediaQuery.sizeOf(context).width >= 1000) {
      setState(() {
        selectedTask = task;
        selectedLesson = null;
      });
    } else {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => DetailScreen(
                  controller: c,
                  task: task,
                  onAsk: (prompt, task) =>
                      _assistant(prompt: prompt, task: task))));
    }
  }

  void _lessonDetail(LessonEntry lesson) {
    if (MediaQuery.sizeOf(context).width >= 1000) {
      setState(() {
        selectedLesson = lesson;
        selectedTask = null;
      });
    } else {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => DetailScreen(
                  controller: c,
                  lesson: lesson,
                  onAsk: (prompt, task) =>
                      _assistant(prompt: prompt, task: task))));
    }
  }

  List<Widget> _gradeList(BuildContext context) {
    if (c.grades.isEmpty) {
      return [
        _empty(Icons.bar_chart,
            t('Оцінок поки немає.', 'No grades yet.', 'Noch keine Noten.'))
      ];
    }
    return [
      Text(
          t(
              'Оцінки показані у шкалі твоєї школи.',
              'Grades use your school’s grading scale.',
              'Die Noten entsprechen der Skala deiner Schule.'),
          style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 16),
      ...c.grades.map((g) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Surface(
              child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(children: [
                    Container(
                        width: 54,
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: c.dark ? const Color(0xFF364B36) : mint,
                            borderRadius: BorderRadius.circular(17)),
                        child: FittedBox(
                            child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(g.value.isEmpty ? '—' : g.value,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium)))),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(g.subject,
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(g.title,
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 4),
                          Text(g.date,
                              style: Theme.of(context).textTheme.bodySmall)
                        ])),
                  ]))))),
    ];
  }

  List<Widget> _messageList(BuildContext context) {
    if (c.messages.isEmpty) {
      return [
        _empty(
            Icons.mark_chat_read_outlined,
            t('Нових повідомлень немає.', 'No messages yet.',
                'Noch keine Nachrichten.'))
      ];
    }
    return c.messages
        .map((m) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Surface(
                onTap: () {
                  final id = int.tryParse(m.original?.id ?? '');
                  if (id != null) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => MessagePage(
                                sessionManager: SessionManager(),
                                id: id,
                                date: m.date)));
                  } else {
                    showModalBottomSheet(
                        context: context,
                        showDragHandle: true,
                        isScrollControlled: true,
                        builder: (context) => SafeArea(
                            child: SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(m.sender,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge),
                                      const SizedBox(height: 18),
                                      SelectableText(m.title)
                                    ]))));
                  }
                },
                child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                              backgroundColor: c.dark
                                  ? const Color(0xFF364B36)
                                  : const Color(0xFFEEEAE1),
                              child: Text(
                                  m.sender.isEmpty
                                      ? '?'
                                      : m.sender.characters.first.toUpperCase(),
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface))),
                          const SizedBox(width: 14),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Row(children: [
                                  Expanded(
                                      child: Text(m.sender,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium)),
                                  Text(date(m.date),
                                      style:
                                          Theme.of(context).textTheme.bodySmall)
                                ]),
                                const SizedBox(height: 6),
                                Text(m.title,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium)
                              ])),
                        ])))))
        .toList();
  }

  Widget _empty(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(children: [
        Icon(icon, size: 38, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium)
      ]));
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});
  final SchoolController controller;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  final school = TextEditingController(),
      username = TextEditingController(),
      password = TextEditingController();
  bool visible = false;
  SchoolController get c => widget.controller;
  String t(String uk, String en, [String? de]) => c.tr(uk, en, de);
  @override
  void dispose() {
    school.dispose();
    username.dispose();
    password.dispose();
    super.dispose();
  }

  void submit() {
    if (form.currentState!.validate()) {
      c.login(username.text, password.text, school.text);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: AutofillGroup(
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.all(28),
                        child: Form(
                            key: form,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    const BrandMark(size: 42),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text('edudz',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headlineMedium))),
                                    DropdownButton<String>(
                                        value: c.language,
                                        underline: const SizedBox(),
                                        onChanged: c.loading
                                            ? null
                                            : (v) => c.setLanguage(v!),
                                        items: const [
                                          DropdownMenuItem(
                                              value: 'uk', child: Text('УКР')),
                                          DropdownMenuItem(
                                              value: 'en', child: Text('EN')),
                                          DropdownMenuItem(
                                              value: 'de', child: Text('DE'))
                                        ])
                                  ]),
                                  const SizedBox(height: 44),
                                  Text(
                                      t(
                                          'Шкільний день.\nЗ легкістю.',
                                          'School days.\nMade lighter.',
                                          'Dein Schultag.\nEinfach leichter.'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineLarge
                                          ?.copyWith(
                                              fontSize: 42, height: 1.13)),
                                  const SizedBox(height: 16),
                                  Text(
                                      t(
                                          'Розклад, завдання та оцінки.\nУсе своє — в одному місці.',
                                          'Your schedule, homework and grades.\nA little more order. A lot less noise.',
                                          'Stundenplan, Aufgaben und Noten.\nAlles Wichtige an einem Ort.'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge),
                                  const SizedBox(height: 32),
                                  Row(children: [
                                    const Icon(Icons.school_outlined, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Text(
                                            t(
                                                'Увійти через EduPage',
                                                'Sign in with EduPage',
                                                'Mit EduPage anmelden'),
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium))
                                  ]),
                                  const SizedBox(height: 20),
                                  TextFormField(
                                      controller: school,
                                      enabled: !c.loading,
                                      textInputAction: TextInputAction.next,
                                      keyboardType: TextInputType.url,
                                      autocorrect: false,
                                      decoration: InputDecoration(
                                          labelText: t(
                                              'Школа (необов’язково)',
                                              'School (optional)',
                                              'Schule (optional)'),
                                          hintText: 'school.edupage.org',
                                          prefixIcon: const Icon(
                                              Icons.school_outlined)),
                                      validator: (v) => (v ?? '')
                                                  .trim()
                                                  .isNotEmpty &&
                                              schoolSubdomain(v ?? '').isEmpty
                                          ? t(
                                              'Перевірте адресу вашої школи',
                                              'Enter your school’s EduPage address',
                                              'EduPage-Adresse deiner Schule eingeben')
                                          : null),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                      controller: username,
                                      enabled: !c.loading,
                                      autofillHints: const [
                                        AutofillHints.username
                                      ],
                                      textInputAction: TextInputAction.next,
                                      autocorrect: false,
                                      decoration: InputDecoration(
                                          labelText: t(
                                              'Логін EduPage',
                                              'EduPage username',
                                              'EduPage-Benutzername'),
                                          prefixIcon:
                                              const Icon(Icons.person_outline)),
                                      validator: (v) =>
                                          v == null || v.trim().isEmpty
                                              ? t(
                                                  'Введіть логін',
                                                  'Enter your username',
                                                  'Benutzername eingeben')
                                              : null),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                      controller: password,
                                      enabled: !c.loading,
                                      autofillHints: const [
                                        AutofillHints.password
                                      ],
                                      obscureText: !visible,
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => submit(),
                                      decoration: InputDecoration(
                                          labelText: t(
                                              'Пароль', 'Password', 'Passwort'),
                                          prefixIcon:
                                              const Icon(Icons.lock_outline),
                                          suffixIcon: IconButton(
                                              tooltip: visible
                                                  ? t(
                                                      'Приховати пароль',
                                                      'Hide password',
                                                      'Passwort verbergen')
                                                  : t(
                                                      'Показати пароль',
                                                      'Show password',
                                                      'Passwort anzeigen'),
                                              onPressed: () => setState(
                                                  () => visible = !visible),
                                              icon: Icon(visible
                                                  ? Icons
                                                      .visibility_off_outlined
                                                  : Icons.visibility_outlined))),
                                      validator: (v) => v == null || v.isEmpty ? t('Введіть пароль', 'Enter your password', 'Passwort eingeben') : null),
                                  if (c.error != null)
                                    Padding(
                                        padding: const EdgeInsets.only(top: 16),
                                        child: Text(c.error!,
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error))),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                      width: double.infinity,
                                      child: FilledButton(
                                          onPressed: c.loading ? null : submit,
                                          child: c.loading
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2))
                                              : Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                      Text(t(
                                                          'Увійти',
                                                          'Let’s go',
                                                          'Anmelden')),
                                                      const SizedBox(width: 10),
                                                      const Icon(
                                                          Icons
                                                              .arrow_forward_rounded,
                                                          size: 18)
                                                    ]))),
                                  const SizedBox(height: 12),
                                  Center(
                                      child: TextButton(
                                          onPressed:
                                              c.loading ? null : c.enterDemo,
                                          child: Text(t(
                                              'Спочатку подивитися демо',
                                              'Take a look around first',
                                              'Zuerst die Demo ansehen')))),
                                  const SizedBox(height: 24),
                                  Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.shield_outlined,
                                            size: 16,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant),
                                        const SizedBox(width: 8),
                                        Expanded(
                                            child: Text(
                                                t(
                                                    'Працює через наш власний сервер. Дані входу зберігаються захищено на пристрої.',
                                                    'Powered by our own server. Sign-in details are stored securely on your device.',
                                                    'Läuft über unseren eigenen Server. Zugangsdaten werden sicher auf deinem Gerät gespeichert.'),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall))
                                      ]),
                                ]))),
                  )))));
}

void showSettings(BuildContext context, SchoolController c) =>
    showModalBottomSheet(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => ListenableBuilder(
            listenable: c,
            builder: (context, _) => SafeArea(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 26),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              c.tr(
                                  'Твій простір', 'Your space', 'Dein Bereich'),
                              style:
                                  Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 6),
                          Text('${c.name} · ${c.school}',
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 24),
                          SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(c.tr(
                                  'Темна тема', 'Dark mode', 'Dunkles Design')),
                              secondary: const Icon(Icons.dark_mode_outlined),
                              value: c.dark,
                              onChanged: c.setDark),
                          const Divider(),
                          Row(children: [
                            const Icon(Icons.translate),
                            const SizedBox(width: 16),
                            Expanded(
                                child:
                                    Text(c.tr('Мова', 'Language', 'Sprache'))),
                            DropdownButton<String>(
                                value: c.language,
                                onChanged: (v) => c.setLanguage(v!),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'uk', child: Text('Українська')),
                                  DropdownMenuItem(
                                      value: 'en', child: Text('English')),
                                  DropdownMenuItem(
                                      value: 'de', child: Text('Deutsch'))
                                ])
                          ]),
                          const Divider(),
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.sync_rounded),
                              title: Text(c.tr(
                                  'Оновити дані',
                                  'Refresh school data',
                                  'Schuldaten aktualisieren')),
                              subtitle: Text(c.demo
                                  ? c.tr('Демонстраційні дані', 'Sample data',
                                      'Beispieldaten')
                                  : c.lastSync == null
                                      ? c.tr(
                                          'Ще не оновлювалися',
                                          'Not synced yet',
                                          'Noch nicht synchronisiert')
                                      : '${c.tr('Оновлено', 'Updated', 'Aktualisiert')} ${DateFormat('d MMM, HH:mm', c.language).format(c.lastSync!)}'),
                              trailing: c.loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.chevron_right),
                              onTap: c.loading || c.demo ? null : c.refresh),
                          const Divider(),
                          Text('edudz 2.0 · EduPage2 fork',
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 8),
                          Text(
                              c.tr(
                                  'Власний сервер · без реклами й аналітики',
                                  'Own server · no ads or analytics',
                                  'Eigener Server · keine Werbung oder Analytik'),
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 18),
                          SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                  onPressed: c.loading
                                      ? null
                                      : () async {
                                          await c.logout();
                                          if (context.mounted) {
                                            Navigator.pop(context);
                                          }
                                        },
                                  icon: const Icon(Icons.logout, size: 18),
                                  label: Text(c.demo
                                      ? c.tr(
                                          'Вийти з демо та увійти',
                                          'Leave demo and sign in',
                                          'Demo verlassen und anmelden')
                                      : c.tr('Вийти з акаунта', 'Sign out',
                                          'Abmelden')))),
                        ])))));

class Surface extends StatelessWidget {
  const Surface({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF223229)
          : Colors.white,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: child));
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF394839)
              : color ?? const Color(0xFFF0F2E9),
          borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface)));
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 42});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: forest, borderRadius: BorderRadius.circular(size * .29)),
      child: CustomPaint(painter: _MarkPainter()));
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = mint
      ..strokeWidth = size.width * .085
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * .29, size.height * .32),
        Offset(size.width * .7, size.height * .32), p);
    canvas.drawLine(Offset(size.width * .29, size.height * .5),
        Offset(size.width * .57, size.height * .5), p);
    canvas.drawLine(Offset(size.width * .29, size.height * .68),
        Offset(size.width * .7, size.height * .68), p);
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => false;
}
