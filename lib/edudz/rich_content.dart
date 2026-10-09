import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as parser;
import 'package:html_unescape/html_unescape.dart';
import 'package:url_launcher/url_launcher.dart';
import 'attachments.dart';
import 'controller.dart';
import 'document_viewer.dart';

bool isSchoolResource(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.userInfo.isNotEmpty) return false;
  if (!uri.hasScheme && !uri.hasAuthority) {
    return value.startsWith('/cloud/') ||
        value.startsWith('/elearning/') ||
        value.startsWith('/foto/');
  }
  return uri.scheme == 'https' &&
      (uri.host == 'edupage.org' || uri.host.endsWith('.edupage.org')) &&
      (!uri.hasPort || uri.port == 443);
}

// Render a bounded, inert subset of teacher HTML. Local paths, active embeds,
// external trackers and author-controlled fonts/colors never enter the renderer.
String schoolHtml(String source) {
  if (!RegExp(r'<\s*/?\s*[a-z][^>]*>', caseSensitive: false).hasMatch(source)) {
    return const HtmlEscape()
        .convert(HtmlUnescape().convert(source))
        .replaceAll('\n', '<br>');
  }
  final root = parser.parseFragment(source);
  const allowed = {
    'a',
    'p',
    'div',
    'span',
    'br',
    'hr',
    'strong',
    'b',
    'em',
    'i',
    'u',
    's',
    'del',
    'blockquote',
    'pre',
    'code',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'ul',
    'ol',
    'li',
    'table',
    'thead',
    'tbody',
    'tfoot',
    'tr',
    'td',
    'th',
    'img',
    'sub',
    'sup'
  };
  const drop = {
    'script',
    'style',
    'iframe',
    'object',
    'embed',
    'form',
    'input',
    'button',
    'link',
    'meta',
    'video',
    'audio',
    'svg',
    'math'
  };
  for (final element in root.querySelectorAll('*').toList().reversed) {
    final tag = element.localName;
    if (drop.contains(tag)) {
      element.remove();
      continue;
    }
    if (!allowed.contains(tag)) {
      element.replaceWith(
          dom.Element.tag('span')..nodes.addAll(element.nodes.toList()));
      continue;
    }
    final attributes = Map<String, String>.from(element.attributes);
    element.attributes.clear();
    if (tag == 'a') {
      final href = attributes['href'] ?? '';
      final uri = Uri.tryParse(href);
      if (isSchoolResource(href) ||
          (uri != null &&
              ['https', 'http', 'mailto', 'tel'].contains(uri.scheme))) {
        element.attributes['href'] = href;
      }
    }
    if (tag == 'img') {
      final src = attributes['src'] ?? '';
      if (!isSchoolResource(src)) {
        element.replaceWith(
            dom.Element.tag('span')..text = attributes['alt'] ?? '');
        continue;
      }
      element.attributes['src'] = src;
      element.attributes['alt'] = attributes['alt'] ?? '';
    }
    for (final name in ['colspan', 'rowspan', 'start']) {
      final number = int.tryParse(attributes[name] ?? '');
      if (number != null && number > 0 && number <= 100) {
        element.attributes[name] = '$number';
      }
    }
    final style = attributes['style'] ?? '';
    final safe = <String>[];
    for (final declaration in style.split(';')) {
      final parts = declaration.split(':');
      if (parts.length != 2) continue;
      final property = parts[0].trim().toLowerCase(),
          value = parts[1].trim().toLowerCase();
      if (property == 'text-align' &&
              ['left', 'right', 'center', 'justify'].contains(value) ||
          property == 'font-weight' &&
              ['bold', 'normal', '600', '700'].contains(value) ||
          property == 'font-style' && ['italic', 'normal'].contains(value) ||
          property == 'text-decoration' &&
              ['underline', 'line-through', 'none'].contains(value)) {
        safe.add('$property:$value');
      }
    }
    if (safe.isNotEmpty) element.attributes['style'] = safe.join(';');
  }
  return root.outerHtml;
}

class SchoolRichText extends StatelessWidget {
  const SchoolRichText(
      {super.key,
      required this.controller,
      required this.content,
      this.files = const []});
  final SchoolController controller;
  final String content;
  final List<SchoolFile> files;
  @override
  Widget build(BuildContext context) => SelectionArea(
      child: HtmlWidget(schoolHtml(content),
          textStyle:
              Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55),
          customStylesBuilder: (element) => switch (element.localName) {
                'table' => {'border-collapse': 'collapse', 'width': '100%'},
                'td' || 'th' => {
                    'padding': '10px',
                    'border': '1px solid #a8b4ab'
                  },
                'blockquote' => {
                    'padding': '12px',
                    'border-left': '3px solid #8fa87e'
                  },
                'h1' => {'font-size': '24px'},
                'h2' => {'font-size': '21px'},
                'h3' => {'font-size': '18px'},
                _ => null,
              },
          customWidgetBuilder: (element) {
            if (element.localName != 'img') return null;
            final src = element.attributes['src'] ?? '';
            if (!isSchoolResource(src)) return const SizedBox.shrink();
            return _SchoolImage(
                controller: controller,
                file: files.where((f) => f.src == src).firstOrNull ??
                    SchoolFile(
                        src: src,
                        name: Uri.parse(src).pathSegments.lastOrNull ??
                            'image.jpg'));
          },
          onTapUrl: (value) async {
            final match = files.where((f) => f.src == value).firstOrNull;
            if (match != null ||
                isSchoolResource(value) &&
                    (value.contains('/cloud/') ||
                        value.contains('/elearning/'))) {
              final file = match ??
                  SchoolFile(
                      src: value,
                      name: Uri.parse(value).pathSegments.lastOrNull ??
                          'attachment');
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AttachmentViewer(
                          controller: controller, file: file)));
              return true;
            }
            final uri = Uri.tryParse(value);
            if (uri == null ||
                !['https', 'http', 'mailto', 'tel'].contains(uri.scheme)) {
              return true;
            }
            try {
              if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                return true;
              }
            } catch (_) {}
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(controller.tr(
                      'Не вдалося відкрити посилання.',
                      'Could not open link.',
                      'Link konnte nicht geöffnet werden.'))));
            }
            return true;
          }));
}

class _SchoolImage extends StatefulWidget {
  const _SchoolImage({required this.controller, required this.file});
  final SchoolController controller;
  final SchoolFile file;
  @override
  State<_SchoolImage> createState() => _SchoolImageState();
}

class _SchoolImageState extends State<_SchoolImage> {
  final cancel = CancelToken();
  late Future<File> image =
      FileService(widget.controller).fetch(widget.file, cancelToken: cancel);
  @override
  void dispose() {
    cancel.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: FutureBuilder<File>(
          future: image,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return SchoolFileTile(
                  controller: widget.controller, file: widget.file);
            }
            if (!snapshot.hasData) {
              return const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()));
            }
            return ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => AttachmentViewer(
                                controller: widget.controller,
                                file: widget.file))),
                    child: Image.file(snapshot.data!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => SchoolFileTile(
                            controller: widget.controller,
                            file: widget.file))));
          }));
}
