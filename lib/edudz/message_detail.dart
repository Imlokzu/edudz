import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'attachments.dart';
import 'controller.dart';
import 'document_viewer.dart';
import 'rich_content.dart';

Map<String, dynamic> _map(dynamic value) {
  if (value is String) {
    try {
      value = jsonDecode(value);
    } catch (_) {
      return {};
    }
  }
  return value is Map ? Map<String, dynamic>.from(value) : {};
}

String _string(dynamic value) => value is String ? value : '';

class SchoolMessage {
  const SchoolMessage(
      {required this.sender,
      required this.body,
      required this.date,
      this.recipient = '',
      this.important = false,
      this.files = const [],
      this.replies = const [],
      this.poll = const []});
  final String sender, recipient, body;
  final DateTime date;
  final bool important;
  final List<SchoolFile> files;
  final List<SchoolMessage> replies;
  final List<String> poll;
  factory SchoolMessage.fromJson(Map<String, dynamic> json,
      {required MessageEntry fallback}) {
    final raw = _map(json['data']);
    final data = raw.containsKey('Value') ? _map(raw['Value']) : raw;
    final content = _string(data['messageContent']);
    final files = <String, SchoolFile>{};
    for (final source in [
      data['attachements'],
      data['attachments'],
      json['attachements'],
      json['attachments']
    ]) {
      for (final file in SchoolFile.parse(source)) {
        files[file.src] = file;
      }
    }
    final replies = <SchoolMessage>[];
    for (final item in json['replies'] is List ? json['replies'] : const []) {
      final value = _map(item);
      if (_string(value['pomocny_zaznam']).isNotEmpty ||
          value['removed'] == 1 ||
          value['removed'] == '1' ||
          value['removed'] == true) {
        continue;
      }
      replies.add(SchoolMessage.fromJson({...value, 'replies': []},
          fallback: fallback));
    }
    replies.sort((a, b) => a.date.compareTo(b.date));
    final poll = _map(data['votingParams'])['answers'];
    final owner = plainText(_string(json['vlastnik_meno']));
    return SchoolMessage(
        sender: owner.isEmpty ? fallback.sender : owner,
        recipient: plainText(_string(json['user_meno'])),
        body: content.isNotEmpty
            ? content
            : _string(json['text']).isNotEmpty
                ? json['text']
                : fallback.title,
        date: (DateTime.tryParse(_string(json['cas_pridania'])) ??
                DateTime.tryParse(_string(json['timestamp'])) ??
                fallback.date)
            .toLocal(),
        important: content.isNotEmpty ||
            data['important'] == true ||
            data['important'] == 1,
        files: files.values.toList(),
        replies: replies,
        poll: poll is List
            ? poll
                .map((item) => plainText(_string(_map(item)['text'])))
                .where((s) => s.isNotEmpty)
                .toList()
            : []);
  }
}

class MessageScreen extends StatelessWidget {
  const MessageScreen(
      {super.key, required this.controller, required this.message});
  final SchoolController controller;
  final MessageEntry message;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(controller.tr('Повідомлення', 'Message', 'Nachricht'))),
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 850),
                  child:
                      MessagePane(controller: controller, message: message)))));
}

class MessagePane extends StatefulWidget {
  const MessagePane(
      {super.key,
      required this.controller,
      required this.message,
      this.onClose});
  final SchoolController controller;
  final MessageEntry message;
  final VoidCallback? onClose;
  @override
  State<MessagePane> createState() => _MessagePaneState();
}

class _MessagePaneState extends State<MessagePane> {
  late SchoolMessage message;
  CancelToken? request;
  bool loading = false;
  String? error;
  SchoolController get c => widget.controller;
  String t(String uk, String en, String de) => c.tr(uk, en, de);
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MessagePane old) {
    super.didUpdateWidget(old);
    if (old.message != widget.message) _load();
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
    message = SchoolMessage.fromJson(widget.message.original?.toJson() ?? {},
        fallback: widget.message);
    setState(() {
      error = null;
      loading = widget.message.original != null && !c.demo;
    });
    if (c.demo) {
      if (widget.message.sender == 'Sekretariat') {
        message = SchoolMessage(
            sender: widget.message.sender,
            date: widget.message.date,
            body: t(
                '<h2>Зміна кабінету</h2><p>Наступний урок англійської відбудеться в <strong>кабінеті 204</strong>. Перевір актуальний розклад перед уроком.</p>',
                '<h2>Room change</h2><p>The next English lesson will be in <strong>room 204</strong>. Check the current timetable before class.</p>',
                '<h2>Raumänderung</h2><p>Die nächste Englischstunde findet in <strong>Raum 204</strong> statt. Prüfe vor dem Unterricht den aktuellen Stundenplan.</p>'));
        return;
      }
      message = SchoolMessage(
          sender: widget.message.sender,
          date: widget.message.date,
          recipient: '9A',
          important: true,
          body:
              '<h2>${t('Поїздка класу до музею', 'Our class museum trip', 'Unser Klassenausflug ins Museum')}</h2><p>${t('Зустрічаємося <strong>о 08:00 біля школи</strong>. Будь ласка, візьміть:', 'Meet <strong>at 08:00 outside school</strong>. Please bring:', 'Wir treffen uns <strong>um 08:00 vor der Schule</strong>. Bitte mitbringen:')}</p><ul><li>${t('Воду та перекус', 'Water and a snack', 'Wasser und einen Snack')}</li><li>${t('Підписаний дозвіл', 'Signed permission form', 'Unterschriebene Einverständniserklärung')}</li></ul><table><tr><th>${t('Час', 'Time', 'Zeit')}</th><th>${t('План', 'Plan', 'Plan')}</th></tr><tr><td>08:15</td><td>${t('Виїзд', 'Departure', 'Abfahrt')}</td></tr><tr><td>13:00</td><td>${t('Повернення', 'Return', 'Rückkehr')}</td></tr></table><p>${t('Документи для підготовки додаю нижче.', 'Preparation documents are attached below.', 'Die Unterlagen zur Vorbereitung findet ihr unten.')}</p>',
          files: const [
            SchoolFile(
                src: 'assets/demo/class-trip.docx', name: 'class-trip.docx'),
            SchoolFile(
                src: 'assets/demo/trip-budget.xlsx', name: 'trip-budget.xlsx'),
            SchoolFile(
                src: 'assets/demo/museum-slides.pptx',
                name: 'museum-slides.pptx'),
            SchoolFile(src: 'assets/demo/worksheet.pdf', name: 'worksheet.pdf'),
            SchoolFile(src: 'assets/demo/worksheet.txt', name: 'worksheet.txt')
          ],
          replies: [
            SchoolMessage(
                sender: 'Frau Müller',
                date: widget.message.date.add(const Duration(minutes: 20)),
                body: t(
                    '<p>Уточнення: <strong>повертаємося до школи</strong>, де закінчиться поїздка.</p>',
                    '<p>Update: we will <strong>return to school</strong> at the end of the trip.</p>',
                    '<p>Ergänzung: Zum Abschluss kommen wir <strong>zur Schule zurück</strong>.</p>'))
          ]);
      return;
    }
    final id = widget.message.original?.id;
    if (id == null || id.isEmpty) return;
    try {
      await c.ensureSession();
      final response = await c.data.dio.get(
          '${c.data.baseUrl}/api/timelineitem/${Uri.encodeComponent(id)}',
          queryParameters: {
            'date': widget.message.date
                .subtract(const Duration(days: 1))
                .toUtc()
                .toIso8601String()
          },
          options: Options(
              headers: {'Authorization': 'Bearer ${c.data.user.token}'}),
          cancelToken: token);
      if (!mounted || token.isCancelled) return;
      final parsed =
          SchoolMessage.fromJson(_map(response.data), fallback: widget.message);
      setState(() {
        message = parsed;
        loading = false;
      });
    } catch (_) {
      if (mounted && !token.isCancelled) {
        setState(() {
          loading = false;
          error = t(
              'Не вдалося оновити повідомлення. Показано збережений текст.',
              'Could not refresh this message. Showing saved text.',
              'Nachricht konnte nicht aktualisiert werden. Gespeicherter Text wird angezeigt.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
      onRefresh: _load,
      child: ListView(
          key: ValueKey(widget.message.original?.id ?? widget.message.title),
          padding: const EdgeInsets.all(24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(
                  radius: 23,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                      message.sender.isEmpty
                          ? '?'
                          : message.sender.characters.first.toUpperCase(),
                      style: Theme.of(context).textTheme.titleLarge)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(message.sender,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                        DateFormat('d MMMM, HH:mm', c.language)
                            .format(message.date),
                        style: Theme.of(context).textTheme.bodySmall),
                    if (message.recipient.isNotEmpty &&
                        message.recipient != message.sender)
                      Text('${t('Кому', 'To', 'An')}: ${message.recipient}',
                          style: Theme.of(context).textTheme.bodySmall)
                  ])),
              if (widget.onClose != null)
                IconButton(
                    onPressed: widget.onClose,
                    tooltip: t('Закрити', 'Close', 'Schließen'),
                    icon: const Icon(Icons.close))
            ]),
            if (message.important)
              Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Row(children: [
                    Icon(Icons.push_pin_outlined,
                        size: 17, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 7),
                    Expanded(
                        child: Text(
                            t('Важливе повідомлення', 'Important message',
                                'Wichtige Nachricht'),
                            style: Theme.of(context).textTheme.labelLarge))
                  ])),
            const SizedBox(height: 22),
            if (loading)
              const Padding(
                  padding: EdgeInsets.only(bottom: 18),
                  child: LinearProgressIndicator(minHeight: 2)),
            if (error != null)
              Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                        TextButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: Text(
                                t('Повторити', 'Retry', 'Erneut versuchen')))
                      ])),
            SchoolRichText(
                controller: c, content: message.body, files: message.files),
            if (message.files.isNotEmpty) ...[
              const SizedBox(height: 26),
              Text(
                  '${t('Вкладення', 'Attachments', 'Anhänge')} · ${message.files.length}',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              ...message.files
                  .map((f) => SchoolFileTile(controller: c, file: f))
            ],
            if (message.poll.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                  t('Варіанти опитування', 'Poll options',
                      'Antwortmöglichkeiten'),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...message.poll.map((text) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text('• $text')))
            ],
            if (message.replies.isNotEmpty) ...[
              const SizedBox(height: 26),
              const Divider(),
              const SizedBox(height: 14),
              Text(
                  '${t('Відповіді', 'Replies', 'Antworten')} · ${message.replies.length}',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 18),
              ...message.replies.map((reply) => Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 4, 0, 4),
                      decoration: BoxDecoration(
                          border: Border(
                              left: BorderSide(
                                  width: 2,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant))),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(reply.sender,
                                style: Theme.of(context).textTheme.titleSmall),
                            Text(
                                DateFormat('d MMM, HH:mm', c.language)
                                    .format(reply.date),
                                style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 12),
                            SchoolRichText(
                                controller: c,
                                content: reply.body,
                                files: reply.files),
                            const SizedBox(height: 10),
                            ...reply.files.map(
                                (f) => SchoolFileTile(controller: c, file: f))
                          ]))))
            ],
          ]));
}
