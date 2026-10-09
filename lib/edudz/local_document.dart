import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'controller.dart';

const localDocumentFormats = {'docx', 'xlsx', 'xls', 'ods', 'pptx', 'csv'};

class LocalDocument extends StatefulWidget {
  const LocalDocument(
      {super.key,
      required this.controller,
      required this.file,
      required this.extension});
  final SchoolController controller;
  final File file;
  final String extension;
  @override
  State<LocalDocument> createState() => _LocalDocumentState();
}

class _LocalDocumentState extends State<LocalDocument> {
  late final WebViewController web;
  Timer? timeout;
  bool loading = true, started = false;
  String? error;
  int current = 1, count = 0;
  String kind = 'page';
  double zoom = 1;
  String t(String uk, String en, String de) => widget.controller.tr(uk, en, de);
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFE9EBE8))
      ..addJavaScriptChannel('EdudzPreview', onMessageReceived: (message) {
        if (!mounted) return;
        try {
          final event = jsonDecode(message.message) as Map<String, dynamic>;
          switch (event['type']) {
            case 'boot':
              _send();
              break;
            case 'ready':
              timeout?.cancel();
              setState(() {
                loading = false;
                count = (event['count'] as num?)?.toInt() ?? 0;
                kind = event['kind']?.toString() ?? 'page';
              });
              break;
            case 'page':
            case 'sheet':
              setState(() {
                current = (event['page'] as num?)?.toInt() ?? 1;
                count = (event['count'] as num?)?.toInt() ?? count;
              });
              break;
            case 'error':
              _fail(event['reason']?.toString());
              break;
          }
        } catch (_) {
          _fail(null);
        }
      })
      ..setNavigationDelegate(
          NavigationDelegate(onNavigationRequest: (request) {
        final uri = Uri.tryParse(request.url);
        // All document code is bundled. School URLs, file links and script URLs
        // inside a document never navigate this WebView.
        return uri?.scheme == 'file' &&
                uri!.path.endsWith('/assets/document-preview/index.html')
            ? NavigationDecision.navigate
            : NavigationDecision.prevent;
      }, onWebResourceError: (event) {
        if (event.isForMainFrame == true) _fail(null);
      }));
    timeout = Timer(const Duration(seconds: 40), () => _fail('timeout'));
    try {
      await web.loadFlutterAsset('assets/document-preview/index.html');
    } catch (_) {
      _fail(null);
    }
  }

  Future<void> _send() async {
    if (started) return;
    started = true;
    try {
      if (await widget.file.length() > 25 * 1024 * 1024) {
        _fail('large');
        return;
      }
      final data = base64Encode(await widget.file.readAsBytes());
      if (!mounted) return;
      await web.runJavaScript(
          'Edudz.begin(${jsonEncode(widget.extension)},${jsonEncode(widget.controller.language)})');
      for (var start = 0; start < data.length; start += 48000) {
        if (!mounted) return;
        final end = (start + 48000).clamp(0, data.length);
        await web.runJavaScript(
            'Edudz.append(${jsonEncode(data.substring(start, end))})');
      }
      if (mounted) await web.runJavaScript('Edudz.render()');
    } catch (_) {
      _fail(null);
    }
  }

  void _fail(String? reason) {
    timeout?.cancel();
    if (!mounted) return;
    setState(() {
      loading = false;
      error = reason == 'large'
          ? t(
              'Файл завеликий для перегляду на телефоні. Збережи оригінал.',
              'This file is too large for an on-device preview. Save the original.',
              'Die Datei ist für die lokale Vorschau zu groß. Speichere das Original.')
          : t(
              'Не вдалося показати документ. Він може бути захищений паролем або містити непідтримувані елементи. Оригінал можна завантажити.',
              'Could not display this document. It may be password-protected or use unsupported features. You can download the original.',
              'Das Dokument kann nicht angezeigt werden. Es ist möglicherweise passwortgeschützt oder enthält nicht unterstützte Inhalte. Das Original kann heruntergeladen werden.');
    });
  }

  @override
  void dispose() {
    timeout?.cancel();
    super.dispose();
  }

  Future<void> _zoom(double value) async {
    setState(() => zoom = value.clamp(.75, 3));
    await web.runJavaScript('Edudz.setZoom($zoom)');
  }

  Future<void> _go(int target) async {
    await web.runJavaScript('Edudz.go($target)');
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Expanded(
            child: Stack(children: [
          if (error == null) WebViewWidget(controller: web),
          if (loading)
            ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 18),
                  Text(t('Відкриваємо на пристрої…', 'Opening on your device…',
                      'Wird auf deinem Gerät geöffnet…'))
                ]))),
          if (error != null)
            Center(
                child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.description_outlined, size: 48),
                          const SizedBox(height: 18),
                          Text(error!, textAlign: TextAlign.center)
                        ])))),
        ])),
        if (!loading && error == null)
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  border: Border(
                      top: BorderSide(color: Theme.of(context).dividerColor))),
              child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    IconButton(
                        onPressed: current > 1 ? () => _go(current - 1) : null,
                        tooltip: t('Назад', 'Previous', 'Zurück'),
                        icon: const Icon(Icons.chevron_left)),
                    Text(
                        '${kind == 'sheet' ? t('Аркуш', 'Sheet', 'Blatt') : kind == 'slide' ? t('Слайд', 'Slide', 'Folie') : t('Сторінка', 'Page', 'Seite')} $current / $count',
                        key: const ValueKey('document-pages')),
                    IconButton(
                        onPressed:
                            current < count ? () => _go(current + 1) : null,
                        tooltip: t('Далі', 'Next', 'Weiter'),
                        icon: const Icon(Icons.chevron_right)),
                    IconButton(
                        onPressed: zoom > .75 ? () => _zoom(zoom - .25) : null,
                        tooltip: t('Зменшити', 'Zoom out', 'Verkleinern'),
                        icon: const Icon(Icons.zoom_out)),
                    TextButton(
                        onPressed: () => _zoom(1),
                        child: Text('${(zoom * 100).round()}%')),
                    IconButton(
                        onPressed: zoom < 3 ? () => _zoom(zoom + .25) : null,
                        tooltip: t('Збільшити', 'Zoom in', 'Vergrößern'),
                        icon: const Icon(Icons.zoom_in)),
                  ]))
      ]);
}
