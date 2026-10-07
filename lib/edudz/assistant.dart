import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'attachments.dart';
import 'controller.dart';
import 'details.dart';
import 'theme.dart';

class AssistantEvent {
  const AssistantEvent(this.type, this.data);
  final String type;
  final Map<String, dynamic> data;
}

Stream<AssistantEvent> decodeAssistantStream(Stream<List<int>> stream) async* {
  var event = 'message';
  final data = <String>[];
  await for (final line in stream
      .cast<List<int>>()
      .transform(utf8.decoder)
      .transform(const LineSplitter())) {
    if (line.startsWith('event:')) {
      event = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      data.add(line.substring(5).trimLeft());
    } else if (line.isEmpty && data.isNotEmpty) {
      final decoded = jsonDecode(data.join('\n'));
      if (decoded is Map) {
        yield AssistantEvent(event, Map<String, dynamic>.from(decoded));
      }
      event = 'message';
      data.clear();
    }
  }
  if (data.isNotEmpty) {
    final decoded = jsonDecode(data.join('\n'));
    if (decoded is Map) {
      yield AssistantEvent(event, Map<String, dynamic>.from(decoded));
    }
  }
}

class ChatEntry {
  ChatEntry(this.role, this.text, {this.failed = false});
  final String role;
  String text;
  bool failed;
}

class AssistantScreen extends StatefulWidget {
  const AssistantScreen(
      {super.key, required this.controller, this.initialPrompt, this.task});
  final SchoolController controller;
  final String? initialPrompt;
  final TaskEntry? task;
  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final input = TextEditingController(), scroll = ScrollController();
  final history = <ChatEntry>[];
  final sources = <SchoolFile>[];
  CancelToken? cancel;
  Timer? demoTimer;
  VoidCallback? finishDemo;
  bool streaming = false;
  String? status;
  String? error;
  SchoolController get c => widget.controller;
  String t(String uk, String en, String de) => c.tr(uk, en, de);
  @override
  void initState() {
    super.initState();
    if (widget.initialPrompt != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _send(widget.initialPrompt!));
    }
  }

  @override
  void dispose() {
    _stop();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _stop() {
    cancel?.cancel();
    finishDemo?.call();
  }

  void _bottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send(String prompt) async {
    if (streaming || prompt.trim().isEmpty) return;
    input.clear();
    final token = CancelToken();
    cancel = token;
    final previous =
        history.where((m) => !m.failed && m.text.isNotEmpty).toList();
    final answer = ChatEntry('assistant', '');
    setState(() {
      history.add(ChatEntry('user', prompt.trim()));
      history.add(answer);
      streaming = true;
      error = null;
      sources.clear();
      status = t('Переглядаю твої шкільні дані…', 'Reading your school data…',
          'Deine Schuldaten werden gelesen…');
    });
    _bottom();
    try {
      if (c.demo) {
        final response = t(
            'Це **демонстрація** асистента. У твоєму розкладі ${c.lessons.length} уроків, а у списку завдань — ${c.tasks.length}.\n\nДля квадратного рівняння спочатку визнач коефіцієнти, обчисли дискримінант **D = b² − 4ac**, а потім перевір знайдені корені.\n\nПісля входу я зможу читати твій розклад, домашні завдання, оцінки, повідомлення та матеріали вкладень.',
            'This is an **assistant demo**. Your sample schedule has ${c.lessons.length} lessons and ${c.tasks.length} tasks.\n\nFor a quadratic equation, identify the coefficients, calculate **D = b² − 4ac**, and check the roots.\n\nAfter sign-in I can read your timetable, homework, grades, messages and attached materials.',
            'Dies ist eine **Assistenten-Demo**. Dein Beispielplan enthält ${c.lessons.length} Stunden und ${c.tasks.length} Aufgaben.\n\nBei einer quadratischen Gleichung bestimmst du zuerst die Koeffizienten, berechnest **D = b² − 4ac** und prüfst die Lösungen.\n\nNach der Anmeldung kann ich Stundenplan, Aufgaben, Noten, Nachrichten und Anhänge lesen.');
        final words = response.split(' ');
        var index = 0;
        final done = Completer<void>();
        finishDemo = () {
          demoTimer?.cancel();
          if (!done.isCompleted) done.complete();
        };
        demoTimer = Timer.periodic(const Duration(milliseconds: 28), (_) {
          if (!mounted || token.isCancelled || index == words.length) {
            finishDemo?.call();
            return;
          }
          setState(() {
            status = null;
            answer.text += '${answer.text.isEmpty ? '' : ' '}${words[index++]}';
          });
          _bottom();
        });
        await done.future;
        finishDemo = null;
      } else {
        await c.ensureSession();
        final response = await c.data.dio.post<ResponseBody>(
            '${c.data.baseUrl}/api/assistant',
            data: {
              'message': prompt.trim(),
              'language': c.language,
              'date': c.selectedDate.toIso8601String().split('T').first,
              'homework_id': widget.task?.id,
              'history': previous
                  .take(16)
                  .map((m) => {'role': m.role, 'content': m.text})
                  .toList()
            },
            options: Options(
                responseType: ResponseType.stream,
                receiveTimeout: const Duration(minutes: 3),
                headers: {'Authorization': 'Bearer ${c.data.user.token}'}),
            cancelToken: token);
        var done = false;
        await for (final event
            in decodeAssistantStream(response.data!.stream)) {
          if (!mounted || token.isCancelled) break;
          setState(() {
            if (event.type == 'token') {
              status = null;
              answer.text += event.data['text']?.toString() ?? '';
            }
            if (event.type == 'status') status = event.data['text']?.toString();
            if (event.type == 'sources') {
              for (final file in SchoolFile.parse(event.data['files'])) {
                if (!sources.any((existing) => existing.src == file.src)) {
                  sources.add(file);
                }
              }
            }
            if (event.type == 'error') {
              throw StateError(
                  event.data['message']?.toString() ?? 'Assistant unavailable');
            }
            if (event.type == 'done') done = true;
          });
          _bottom();
        }
        if (!done && !token.isCancelled) {
          throw StateError('Connection interrupted');
        }
      }
    } catch (e) {
      if (!token.isCancelled && mounted) {
        setState(() {
          answer.failed = true;
          if (answer.text.isEmpty) {
            answer.text = t('Відповідь не отримана.', 'No reply received.',
                'Keine Antwort erhalten.');
          }
          error = t(
              'Асистент не завершив відповідь. Спробуй ще раз.',
              'The assistant could not finish its reply. Please try again.',
              'Der Assistent konnte die Antwort nicht abschließen. Erneut versuchen.');
        });
      }
    } finally {
      if (mounted) {
        if (token.isCancelled && answer.text.isEmpty) {
          answer.text = t(
              'Відповідь зупинено.', 'Response stopped.', 'Antwort gestoppt.');
        }
        setState(() {
          streaming = false;
          status = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Row(children: [
            Icon(Icons.auto_awesome,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Text(t('Асистент edudz', 'edudz assistant', 'edudz Assistent'))
          ]),
          actions: [
            IconButton(
                onPressed:
                    streaming ? null : () => setState(() => history.clear()),
                tooltip: t('Новий чат', 'New chat', 'Neuer Chat'),
                icon: const Icon(Icons.add_comment_outlined))
          ]),
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(children: [
                    Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                        child: Text(
                            c.demo
                                ? t(
                                    'Деморежим: відповідь на прикладі навчальних даних.',
                                    'Demo: example response using sample data.',
                                    'Demo: Beispielantwort mit Beispieldaten.')
                                : t(
                                    'Можу читати твій розклад, завдання, оцінки, повідомлення та вкладення.',
                                    'I can read your timetable, homework, grades, messages and attachments.',
                                    'Ich kann Stundenplan, Aufgaben, Noten, Nachrichten und Anhänge lesen.'),
                            style: Theme.of(context).textTheme.bodySmall)),
                    if (widget.task != null)
                      Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 8),
                          child: Row(children: [
                            const Icon(Icons.menu_book_outlined, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(widget.task!.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.bodySmall))
                          ])),
                    Expanded(
                        child: history.isEmpty
                            ? _welcome()
                            : ListView.builder(
                                controller: scroll,
                                padding: const EdgeInsets.all(24),
                                itemCount: history.length,
                                itemBuilder: (context, i) {
                                  final m = history[i];
                                  return Align(
                                      alignment: m.role == 'user'
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: Container(
                                          constraints: const BoxConstraints(
                                              maxWidth: 740),
                                          margin:
                                              const EdgeInsets.only(bottom: 18),
                                          padding: const EdgeInsets.all(18),
                                          decoration: BoxDecoration(
                                              color: m.role == 'user'
                                                  ? (c.dark
                                                      ? const Color(0xFF314A39)
                                                      : mint)
                                                  : (c.dark
                                                      ? const Color(0xFF23322A)
                                                      : Colors.white),
                                              borderRadius:
                                                  BorderRadius.circular(22)),
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                    m.role == 'user'
                                                        ? t('Ти', 'You', 'Du')
                                                        : 'edudz',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700)),
                                                const SizedBox(height: 8),
                                                if (m.text.isNotEmpty)
                                                  MarkdownBody(
                                                      data: m.text,
                                                      selectable: true,
                                                      imageBuilder: (_, __,
                                                              ___) =>
                                                          const SizedBox
                                                              .shrink(),
                                                      onTapLink: (_, __,
                                                          ___) {},
                                                      styleSheet:
                                                          MarkdownStyleSheet
                                                              .fromTheme(
                                                                  Theme.of(
                                                                      context)))
                                                else
                                                  Text(status ??
                                                      t('Пишу…', 'Writing…',
                                                          'Schreibe…')),
                                                if (m.failed) ...[
                                                  const SizedBox(height: 12),
                                                  Text(error ?? '',
                                                      style: TextStyle(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .error)),
                                                  TextButton.icon(
                                                      onPressed: () => _send(
                                                          history[i - 1].text),
                                                      icon: const Icon(
                                                          Icons.refresh),
                                                      label: Text(t(
                                                          'Повторити',
                                                          'Retry',
                                                          'Erneut versuchen')))
                                                ]
                                              ])));
                                })),
                    if (sources.isNotEmpty)
                      SizedBox(
                          height: 56,
                          child: ListView(
                              scrollDirection: Axis.horizontal,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              children: sources
                                  .map((f) => Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ActionChip(
                                          avatar: const Icon(Icons.attach_file,
                                              size: 16),
                                          label: Text(f.name),
                                          onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      AttachmentViewer(
                                                          controller: c,
                                                          file: f))))))
                                  .toList())),
                    if (streaming && status != null)
                      Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 8),
                          child: Row(children: [
                            const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(status!,
                                    style:
                                        Theme.of(context).textTheme.bodySmall))
                          ])),
                    Padding(
                        padding: EdgeInsets.fromLTRB(
                            18,
                            8,
                            18,
                            MediaQuery.viewInsetsOf(context).bottom > 0
                                ? 8
                                : 18),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                  child: TextField(
                                      controller: input,
                                      minLines: 1,
                                      maxLines: 5,
                                      enabled: !streaming,
                                      textInputAction: TextInputAction.send,
                                      onSubmitted: _send,
                                      decoration: InputDecoration(
                                          hintText: t(
                                              'Запитай про навчання…',
                                              'Ask about your schoolwork…',
                                              'Frage zu deiner Schule…')))),
                              const SizedBox(width: 10),
                              IconButton.filled(
                                  onPressed: streaming
                                      ? _stop
                                      : () => _send(input.text),
                                  tooltip: streaming
                                      ? t('Зупинити', 'Stop', 'Stoppen')
                                      : t('Надіслати', 'Send', 'Senden'),
                                  icon: Icon(streaming
                                      ? Icons.stop_rounded
                                      : Icons.arrow_upward))
                            ])),
                  ])))));
  Widget _welcome() => SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 24),
        const Icon(Icons.auto_awesome, size: 44, color: forest),
        const SizedBox(height: 24),
        Text(
            t('Розберемося разом.', 'Let’s figure it out.',
                'Finden wir es gemeinsam heraus.'),
            style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 16),
        Text(t(
            'Попроси пояснити тему, знайти завдання або прочитати прикріплений матеріал.',
            'Ask for a topic explanation, find homework or read attached materials.',
            'Lass dir ein Thema erklären, finde Aufgaben oder lies angehängte Materialien.')),
        const SizedBox(height: 24),
        ...[
          t('Що мені задано на завтра?', 'What homework is due tomorrow?',
              'Welche Aufgaben sind für morgen fällig?'),
          t(
              'Які уроки й кабінети в мене сьогодні?',
              'What are my lessons and rooms today?',
              'Welche Stunden und Räume habe ich heute?'),
          t(
              'Поясни моє останнє завдання та прочитай вкладення.',
              'Explain my latest homework and read its attachments.',
              'Erkläre meine neueste Aufgabe und lies ihre Anhänge.'),
        ].map((q) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton(
                onPressed: () => _send(q),
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(q))))))
      ]));
}
