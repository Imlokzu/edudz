import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:intl/intl.dart';
import 'attachments.dart';
import 'controller.dart';
import 'shell.dart' show Surface;

typedef AskStudy = void Function(String prompt, TaskEntry? task);

class DetailScreen extends StatelessWidget {
  const DetailScreen(
      {super.key,
      required this.controller,
      this.task,
      this.lesson,
      required this.onAsk});
  final SchoolController controller;
  final TaskEntry? task;
  final LessonEntry? lesson;
  final AskStudy onAsk;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar:
          AppBar(title: Text(controller.tr('Деталі', 'Details', 'Details'))),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: DetailPane(
                  controller: controller,
                  task: task,
                  lesson: lesson,
                  onAsk: onAsk))));
}

class DetailPane extends StatefulWidget {
  const DetailPane(
      {super.key,
      required this.controller,
      this.task,
      this.lesson,
      this.onClose,
      required this.onAsk});
  final SchoolController controller;
  final TaskEntry? task;
  final LessonEntry? lesson;
  final VoidCallback? onClose;
  final AskStudy onAsk;
  @override
  State<DetailPane> createState() => _DetailPaneState();
}

class _DetailPaneState extends State<DetailPane> {
  List<StudyBlock> blocks = [];
  Map<String, dynamic>? plan;
  bool loading = true;
  bool saving = false;
  String? error;
  CancelToken? request;
  SchoolController get c => widget.controller;
  String t(String uk, String en, String de) => c.tr(uk, en, de);
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DetailPane old) {
    super.didUpdateWidget(old);
    if (old.task?.id != widget.task?.id || old.lesson != widget.lesson) _load();
  }

  @override
  void dispose() {
    request?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    request?.cancel();
    final token = CancelToken();
    request = token;
    setState(() {
      loading = true;
      error = null;
      blocks = [];
      plan = null;
    });
    try {
      if (c.demo) {
        if (widget.task != null) {
          blocks = [
            StudyBlock(
                text: t(
                    'Матеріали до завдання. Відкрий файл, розв’яжи вправи й перевір результат.',
                    'Read the worksheet, solve the exercises and check your answers.',
                    'Lies das Arbeitsblatt, löse die Aufgaben und überprüfe deine Ergebnisse.'),
                files: const [
                  SchoolFile(
                      src: 'assets/demo/worksheet.pdf', name: 'worksheet.pdf'),
                  SchoolFile(
                      src: 'assets/demo/worksheet.txt', name: 'worksheet.txt')
                ])
          ];
        }
        if (widget.lesson != null) {
          plan = {
            'flags': {
              'dp0': {
                'note_wd': t('Повторення та практичні вправи',
                    'Revision and practice', 'Wiederholung und Übungen')
              }
            }
          };
        }
      } else if (widget.task?.original != null) {
        await c.ensureSession();
        final original = widget.task!.original!;
        if (original.testId.isNotEmpty && original.eSuperId.isNotEmpty) {
          final r = await c.data.dio.get('${c.data.baseUrl}/api/etest',
              queryParameters: {
                'testid': original.testId,
                'superid': original.eSuperId
              },
              options: Options(
                  headers: {'Authorization': 'Bearer ${c.data.user.token}'}),
              cancelToken: token);
          final parsed = studyBlocks(Map<String, dynamic>.from(r.data));
          if (!token.isCancelled) blocks = parsed;
        }
      } else if (widget.lesson != null) {
        await c.ensureSession();
        final r = await c.data.dio.get('${c.data.baseUrl}/api/lesson-plan',
            queryParameters: {
              'date': DateFormat('yyyy-MM-dd').format(c.selectedDate)
            },
            options: Options(
                headers: {'Authorization': 'Bearer ${c.data.user.token}'}),
            cancelToken: token);
        final plans = r.data['plan'];
        if (plans is List) {
          final original = widget.lesson!.original;
          final matched = plans.whereType<Map>().where((p) =>
              p['starttime'] == widget.lesson!.start &&
              (original == null ||
                  p['subjectid']?.toString() == original.subject?.id));
          if (matched.isNotEmpty && !token.isCancelled) {
            plan = Map<String, dynamic>.from(matched.first);
          }
        }
      }
    } catch (_) {
      if (!token.isCancelled) {
        error = t(
            'Додаткові матеріали не завантажилися.',
            'Could not load additional materials.',
            'Zusätzliche Materialien konnten nicht geladen werden.');
      }
    } finally {
      if (mounted && !token.isCancelled) setState(() => loading = false);
    }
  }

  String get topic {
    final flags = plan?['flags'];
    if (flags is! Map) return '';
    final dp = flags['dp0'];
    final event = flags['event'];
    return plainText((dp is Map ? dp['note_wd'] : null)?.toString() ??
        (event is Map ? event['name']?.toString() : null) ??
        '');
  }

  List<SchoolFile> get files {
    final result = <String, SchoolFile>{};
    for (final f in [
      ...SchoolFile.parse(widget.task?.original?.attachments),
      ...blocks.expand((b) => b.files)
    ]) {
      result[f.src] = f;
    }
    return result.values.toList();
  }

  Future<void> _save(SchoolFile f) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final service = FileService(c);
      final local = await service.fetch(f);
      final uri = await service.save(local, f);
      if (mounted && uri != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(t(
                'Збережено в Завантаження / edudz',
                'Saved to Downloads / edudz',
                'In Downloads / edudz gespeichert'))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(t(
                'Не вдалося зберегти файл. Спробуй ще раз.',
                'Could not save file. Please try again.',
                'Datei konnte nicht gespeichert werden. Erneut versuchen.'))));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final lesson = widget.lesson;
    final related = lesson == null
        ? <TaskEntry>[]
        : c.tasks
            .where((task) =>
                (lesson.original?.subject?.id != null &&
                    task.original?.lessonId.toString() ==
                        lesson.original?.subject?.id) ||
                task.subject == lesson.subject)
            .toList();
    return ListenableBuilder(
        listenable: c,
        builder: (context, _) =>
            ListView(padding: const EdgeInsets.all(24), children: [
              Row(children: [
                Expanded(
                    child: Text(task?.subject ?? lesson?.subject ?? '',
                        style: Theme.of(context).textTheme.titleMedium)),
                if (widget.onClose != null)
                  IconButton(
                      onPressed: widget.onClose,
                      tooltip: t('Закрити', 'Close', 'Schließen'),
                      icon: const Icon(Icons.close))
              ]),
              const SizedBox(height: 16),
              Text(task?.title ?? lesson?.subject ?? '',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 18),
              if (task?.due != null)
                _info(Icons.event, t('Здати до', 'Due on', 'Abgabe bis'),
                    DateFormat('d MMMM', c.language).format(task!.due!)),
              if (lesson != null) ...[
                _info(Icons.schedule, t('Час', 'Time', 'Zeit'),
                    '${lesson.start} — ${lesson.end}'),
                _info(Icons.location_on_outlined, t('Кабінет', 'Room', 'Raum'),
                    lesson.room.isEmpty ? '—' : lesson.room),
                _info(
                    Icons.person_outline,
                    t('Викладач', 'Teacher', 'Lehrkraft'),
                    lesson.teacher.isEmpty ? '—' : lesson.teacher),
                if (lesson.original?.classes.isNotEmpty ?? false)
                  _info(
                      Icons.groups_outlined,
                      t('Клас / група', 'Class / group', 'Klasse / Gruppe'),
                      [
                        ...lesson.original!.classes.map((cl) => cl.name),
                        ...lesson.original!.groupNames
                      ].join(', ')),
                const SizedBox(height: 24),
                Text(t('Тема уроку', 'Lesson topic', 'Unterrichtsthema'),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                if (!loading)
                  SelectableText(topic.isEmpty
                      ? t(
                          'Школа ще не вказала тему цього уроку.',
                          'The school has not published this lesson’s topic.',
                          'Die Schule hat noch kein Thema für diese Stunde veröffentlicht.')
                      : topic),
              ],
              if (task != null && task.details.isNotEmpty) ...[
                const SizedBox(height: 12),
                SelectableText(task.details),
                const SizedBox(height: 16)
              ],
              if (loading)
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: LinearProgressIndicator()),
              if (error != null) ...[
                Text(error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
                Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label:
                            Text(t('Повторити', 'Retry', 'Erneut versuchen'))))
              ],
              ...blocks.where((b) => b.text.isNotEmpty).map((b) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: SelectableText(b.text))),
              if (files.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(t('Вкладення', 'Attachments', 'Anhänge'),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                ...files.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Surface(
                        child: ListTile(
                            leading: Icon(f.extension == 'pdf'
                                ? Icons.picture_as_pdf_outlined
                                : Icons.insert_drive_file_outlined),
                            title: Text(f.name),
                            subtitle: Text(t('Відкрити всередині edudz',
                                'Open inside edudz', 'In edudz öffnen')),
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => AttachmentViewer(
                                        controller: c, file: f))),
                            trailing: IconButton(onPressed: saving ? null : () => _save(f), tooltip: t('Завантажити', 'Download', 'Herunterladen'), icon: const Icon(Icons.download_outlined))))))
              ],
              if (related.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                    t('Завдання з предмета', 'Subject homework',
                        'Aufgaben im Fach'),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                ...related.map((r) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(r.title),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => DetailScreen(
                                controller: c, task: r, onAsk: widget.onAsk)))))
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                  onPressed: () => widget.onAsk(
                      task == null
                          ? '${t('Поясни тему уроку:', 'Explain this lesson topic:', 'Erkläre dieses Unterrichtsthema:')} ${topic.isEmpty ? lesson?.subject : topic}'
                          : t(
                              'Допоможи розібрати це завдання.',
                              'Help me understand this homework.',
                              'Hilf mir, diese Aufgabe zu verstehen.'),
                      task),
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(t('Запитати асистента', 'Ask assistant',
                      'Assistenten fragen'))),
              if (task != null) ...[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                    onPressed: () => c.toggleTask(task.id),
                    icon: Icon(c.completed.contains(task.id)
                        ? Icons.undo
                        : Icons.done),
                    label: Text(c.completed.contains(task.id)
                        ? t('Повернути до завдань', 'Mark as to do',
                            'Als offen markieren')
                        : t('Позначити готовим', 'Mark as done',
                            'Als erledigt markieren'))),
                const SizedBox(height: 8),
                Text(
                    t(
                        'Позначка виконання зберігається на цьому пристрої.',
                        'Completion is saved on this device.',
                        'Der Erledigt-Status wird auf diesem Gerät gespeichert.'),
                    style: Theme.of(context).textTheme.bodySmall)
              ],
            ]));
  }

  Widget _info(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: Theme.of(context).textTheme.titleMedium)
        ]))
      ]));
}

class AttachmentViewer extends StatefulWidget {
  const AttachmentViewer(
      {super.key, required this.controller, required this.file});
  final SchoolController controller;
  final SchoolFile file;
  @override
  State<AttachmentViewer> createState() => _AttachmentViewerState();
}

class _AttachmentViewerState extends State<AttachmentViewer> {
  final cancel = CancelToken();
  File? local;
  String? text;
  String? error;
  double? progress;
  bool saving = false;
  SchoolController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    cancel.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => error = null);
    try {
      final f = await FileService(c).fetch(widget.file, cancelToken: cancel,
          onProgress: (count, total) {
        if (mounted) {
          setState(() => progress = total > 0 ? count / total : null);
        }
      });
      if (!mounted) return;
      final ext = widget.file.extension;
      if (['docx', 'xlsx', 'pptx'].contains(ext)) {
        text = officeText(await f.readAsBytes(), ext);
      }
      if (['txt', 'csv', 'md'].contains(ext)) {
        text = utf8.decode(await f.readAsBytes(), allowMalformed: true);
      }
      setState(() => local = f);
    } catch (_) {
      if (mounted) {
        setState(() => error = c.tr('Не вдалося відкрити файл.',
            'Could not open file.', 'Datei konnte nicht geöffnet werden.'));
      }
    }
  }

  Future<void> _save() async {
    if (local == null || saving) return;
    setState(() => saving = true);
    try {
      final uri = await FileService(c).save(local!, widget.file);
      if (mounted && uri != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(c.tr(
                'Збережено в Завантаження / edudz',
                'Saved to Downloads / edudz',
                'In Downloads / edudz gespeichert'))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(c.tr(
                'Не вдалося зберегти файл.',
                'Could not save file.',
                'Datei konnte nicht gespeichert werden.'))));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(widget.file.name), actions: [
        IconButton(
            onPressed: local == null || saving ? null : _save,
            tooltip: c.tr('Завантажити', 'Download', 'Herunterladen'),
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download_outlined))
      ]),
      body: _body());
  Widget _body() {
    if (error != null) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(error!),
        TextButton(
            onPressed: _load,
            child: Text(c.tr('Повторити', 'Retry', 'Erneut versuchen')))
      ]));
    }
    if (local == null) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(value: progress),
        const SizedBox(height: 16),
        Text(c.tr('Завантажуємо файл…', 'Loading attachment…',
            'Anhang wird geladen…'))
      ]));
    }
    if (widget.file.extension == 'pdf') {
      return PDFView(
          filePath: local!.path,
          enableSwipe: true,
          autoSpacing: true,
          onError: (_) {
            if (mounted) {
              setState(() => error = c.tr(
                  'PDF пошкоджений або недоступний.',
                  'PDF is damaged or unavailable.',
                  'PDF ist beschädigt oder nicht verfügbar.'));
            }
          });
    }
    if (['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp']
        .contains(widget.file.extension)) {
      return InteractiveViewer(
          minScale: .2,
          maxScale: 8,
          child: Center(
              child: Image.file(local!,
                  errorBuilder: (_, __, ___) => Text(c.tr(
                      'Не вдалося показати зображення.',
                      'Could not display image.',
                      'Bild konnte nicht angezeigt werden.')))));
    }
    if (text != null) {
      return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SelectableText(text!.isEmpty
              ? c.tr(
                  'Текстового вмісту немає. Оригінал можна завантажити.',
                  'No text content. You can download the original.',
                  'Kein Textinhalt. Das Original kann heruntergeladen werden.')
              : text!));
    }
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.insert_drive_file_outlined, size: 54),
              const SizedBox(height: 18),
              Text(
                  c.tr(
                      'Цей формат можна зберегти на пристрої.',
                      'Save this file to your device.',
                      'Diese Datei auf deinem Gerät speichern.'),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.download),
                  label: Text(c.tr('Завантажити', 'Download', 'Herunterladen')))
            ])));
  }
}
