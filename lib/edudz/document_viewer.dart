import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'attachments.dart';
import 'controller.dart';
import 'local_document.dart';

class AttachmentViewer extends StatefulWidget {
  const AttachmentViewer(
      {super.key, required this.controller, required this.file});
  final SchoolController controller;
  final SchoolFile file;
  @override
  State<AttachmentViewer> createState() => _AttachmentViewerState();
}

class _AttachmentViewerState extends State<AttachmentViewer> {
  CancelToken? request;
  File? original, display;
  String? text, error;
  bool loading = true, saving = false, rendering = true;
  double? progress;
  int page = 0, pages = 0, revision = 0;
  PDFViewController? pdf;
  SchoolController get c => widget.controller;
  String t(String uk, String en, String de) => c.tr(uk, en, de);
  bool get isPDF => widget.file.extension == 'pdf';
  @override
  void initState() {
    super.initState();
    _load();
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
      progress = null;
      rendering = true;
      pages = 0;
      page = 0;
      revision++;
    });
    try {
      final source = await FileService(c).fetch(widget.file, cancelToken: token,
          onProgress: (count, total) {
        if (mounted && !token.isCancelled) {
          setState(() => progress = total > 0 ? count / total : null);
        }
      });
      if (!mounted || token.isCancelled) return;
      setState(() {
        original = source;
      });
      final rendered = source;
      String? content;
      if (['txt', 'md', 'json'].contains(widget.file.extension)) {
        if (await source.length() > 4 * 1024 * 1024) {
          throw const FormatException('Text too large');
        }
        content = utf8.decode(await source.readAsBytes(), allowMalformed: true);
      }
      if (mounted && !token.isCancelled) {
        setState(() {
          display = rendered;
          text = content;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted && !token.isCancelled) {
        setState(() {
          loading = false;
          error = widget.file.isOffice
              ? t(
                  'Не вдалося підготувати перегляд. Спробуй ще раз або збережи оригінал.',
                  'Could not prepare the preview. Retry or save the original.',
                  'Vorschau konnte nicht erstellt werden. Erneut versuchen oder Original speichern.')
              : t(
                  'Не вдалося відкрити файл. Спробуй ще раз.',
                  'Could not open this file. Please retry.',
                  'Datei konnte nicht geöffnet werden. Bitte erneut versuchen.');
        });
      }
    }
  }

  Future<void> _save() async {
    final file = original;
    if (file == null || saving) return;
    setState(() => saving = true);
    try {
      final result = await FileService(c).save(file, widget.file);
      if (mounted && result != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(t(
                'Збережено в Завантаження / edudz',
                'Saved to Downloads / edudz',
                'In Downloads / edudz gespeichert'))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(t('Не вдалося зберегти файл.', 'Could not save file.',
                'Datei konnte nicht gespeichert werden.'))));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _pdfError() {
    if (mounted) {
      setState(() => error = t(
          'Не вдалося показати документ. Оригінал можна завантажити.',
          'Could not display this document. You can save the original.',
          'Dokument kann nicht angezeigt werden. Das Original kann gespeichert werden.'));
    }
  }

  Future<void> _jump() async {
    final field = TextEditingController(text: '${page + 1}');
    final target = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(t(
                    'Перейти на сторінку', 'Go to page', 'Zu Seite springen')),
                content: TextField(
                    controller: field,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: '1 — $pages'),
                    onSubmitted: (value) =>
                        Navigator.pop(context, int.tryParse(value))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(t('Скасувати', 'Cancel', 'Abbrechen'))),
                  FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, int.tryParse(field.text)),
                      child: Text(t('Перейти', 'Go', 'Öffnen')))
                ]));
    // The dialog owns its text field until its closing animation is finished.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    field.dispose();
    if (target != null && target > 0 && target <= pages && mounted) {
      await pdf?.setPage(target - 1);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium),
            Text(
                widget.file.isOffice
                    ? t('Перегляд документа', 'Document preview',
                        'Dokumentvorschau')
                    : widget.file.extension.toUpperCase(),
                style: Theme.of(context).textTheme.bodySmall)
          ]),
          actions: [
            if (localDocumentFormats.contains(widget.file.extension))
              IconButton(
                  onPressed: loading ? null : _load,
                  tooltip: t('Оновити перегляд', 'Reload preview',
                      'Vorschau neu laden'),
                  icon: const Icon(Icons.refresh)),
            IconButton(
                onPressed: original == null || saving ? null : () => _save(),
                tooltip: t('Завантажити оригінал', 'Download original',
                    'Original herunterladen'),
                icon: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_outlined)),
          ]),
      body: SafeArea(
          child: Column(children: [
        Expanded(child: _body()),
        if (!loading && error == null && isPDF && pages > 0)
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                  border: Border(
                      top: BorderSide(color: Theme.of(context).dividerColor))),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(
                    onPressed: page > 0 ? () => pdf?.setPage(page - 1) : null,
                    tooltip: t('Попередня сторінка', 'Previous page',
                        'Vorherige Seite'),
                    icon: const Icon(Icons.chevron_left)),
                TextButton(
                    onPressed: _jump,
                    child: Text(
                        '${t('Сторінка', 'Page', 'Seite')} ${page + 1} / $pages')),
                IconButton(
                    onPressed:
                        page + 1 < pages ? () => pdf?.setPage(page + 1) : null,
                    tooltip:
                        t('Наступна сторінка', 'Next page', 'Nächste Seite'),
                    icon: const Icon(Icons.chevron_right)),
              ]))
      ])));
  Widget _body() {
    if (error != null) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.description_outlined, size: 52),
                    const SizedBox(height: 18),
                    Text(error!, textAlign: TextAlign.center),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label:
                            Text(t('Повторити', 'Retry', 'Erneut versuchen'))),
                    if (original != null)
                      TextButton.icon(
                          onPressed: saving ? null : () => _save(),
                          icon: const Icon(Icons.download_outlined),
                          label: Text(t('Зберегти оригінал', 'Save original',
                              'Original speichern')))
                  ]))));
    }
    if (loading) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(value: progress),
        const SizedBox(height: 20),
        Text(t('Завантажуємо файл…', 'Loading attachment…',
            'Anhang wird geladen…')),
      ]));
    }
    if (localDocumentFormats.contains(widget.file.extension)) {
      return LocalDocument(
          key: ValueKey('${display!.path}:$revision'),
          controller: c,
          file: display!,
          extension: widget.file.extension);
    }
    if (isPDF) {
      return Stack(children: [
        PDFView(
            key: ValueKey('${display!.path}:$revision'),
            filePath: display!.path,
            backgroundColor: const Color(0xFFE8E8E5),
            enableSwipe: true,
            autoSpacing: true,
            pageSnap: false,
            pageFling: false,
            fitPolicy: FitPolicy.WIDTH,
            preventLinkNavigation: true,
            onLinkHandler: (_) {},
            onViewCreated: (controller) => pdf = controller,
            onRender: (count) {
              if (mounted) {
                setState(() {
                  pages = count ?? 0;
                  rendering = false;
                });
              }
            },
            onPageChanged: (current, total) {
              if (mounted) {
                setState(() {
                  page = current ?? 0;
                  pages = total ?? pages;
                });
              }
            },
            onError: (_) => _pdfError(),
            onPageError: (_, __) => _pdfError()),
        if (rendering) const Center(child: CircularProgressIndicator())
      ]);
    }
    if (widget.file.isImage) {
      return InteractiveViewer(
          minScale: .5,
          maxScale: 8,
          child: Center(
              child: Image.file(display!,
                  errorBuilder: (_, __, ___) => Text(t('Зображення недоступне',
                      'Image unavailable', 'Bild nicht verfügbar')))));
    }
    if (text != null) {
      return Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: SelectableText(
                      text!.isEmpty
                          ? t('Порожній файл', 'Empty file', 'Leere Datei')
                          : text!,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(height: 1.6)))));
    }
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.insert_drive_file_outlined, size: 52),
              const SizedBox(height: 18),
              Text(
                  t(
                      'Цей формат можна зберегти на пристрої.',
                      'Save this file to your device.',
                      'Diese Datei auf deinem Gerät speichern.'),
                  textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton.icon(
                  onPressed: saving ? null : () => _save(),
                  icon: const Icon(Icons.download_outlined),
                  label: Text(t('Завантажити', 'Download', 'Herunterladen')))
            ])));
  }
}

class SchoolFileTile extends StatefulWidget {
  const SchoolFileTile(
      {super.key, required this.controller, required this.file});
  final SchoolController controller;
  final SchoolFile file;
  @override
  State<SchoolFileTile> createState() => _SchoolFileTileState();
}

class _SchoolFileTileState extends State<SchoolFileTile> {
  bool saving = false;
  final cancel = CancelToken();
  @override
  void dispose() {
    cancel.cancel();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => saving = true);
    final c = widget.controller;
    try {
      final service = FileService(c);
      final local = await service.fetch(widget.file, cancelToken: cancel);
      if (!mounted) return;
      final uri = await service.save(local, widget.file);
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
  Widget build(BuildContext context) {
    final f = widget.file;
    final c = widget.controller;
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                leading: Icon(
                    f.isImage
                        ? Icons.image_outlined
                        : f.extension == 'pdf'
                            ? Icons.picture_as_pdf_outlined
                            : f.extension.contains('xls')
                                ? Icons.table_chart_outlined
                                : Icons.description_outlined,
                    color: Theme.of(context).colorScheme.primary),
                title:
                    Text(f.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                    '${f.extension.toUpperCase()} · ${c.tr('Переглянути', 'Preview', 'Vorschau')}'),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            AttachmentViewer(controller: c, file: f))),
                trailing: IconButton(
                    onPressed: saving ? null : _save,
                    tooltip: c.tr('Завантажити', 'Download', 'Herunterladen'),
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download_outlined)))));
  }
}
