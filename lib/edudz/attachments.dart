import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'controller.dart';

class SchoolFile {
  const SchoolFile({required this.src, required this.name, this.mime = ''});
  final String src, name, mime;
  bool get isOffice => const [
        'docx',
        'doc',
        'xlsx',
        'xls',
        'pptx',
        'ppt',
        'odt',
        'ods',
        'odp',
        'rtf'
      ].contains(extension);
  bool get isImage =>
      const ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'].contains(extension);
  String get extension {
    final parts = name.split('?').first.split('.');
    if (parts.length > 1) return parts.last.toLowerCase();
    final type = mime.toLowerCase().split(';').first;
    const types = {
      'application/pdf': 'pdf',
      'image/jpeg': 'jpg',
      'image/png': 'png',
      'image/webp': 'webp',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
          'docx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
          'xlsx',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation':
          'pptx',
      'application/msword': 'doc',
      'application/vnd.ms-excel': 'xls',
      'application/vnd.ms-powerpoint': 'ppt'
    };
    if (types.containsKey(type)) return types[type]!;
    if ([
      'pdf',
      'png',
      'jpg',
      'jpeg',
      'gif',
      'webp',
      'docx',
      'xlsx',
      'pptx',
      'txt'
    ].contains(type)) {
      return type;
    }
    return Uri.tryParse(src)?.path.split('.').last.toLowerCase() ?? '';
  }

  static List<SchoolFile> parse(dynamic value) {
    final result = <SchoolFile>[];
    void add(dynamic src, dynamic name, [dynamic mime]) {
      if (src is! String || src.trim().isEmpty) return;
      result.add(SchoolFile(
          src: src,
          name: name is String && name.isNotEmpty
              ? name
              : Uri.tryParse(src)?.pathSegments.lastOrNull ?? 'attachment',
          mime: mime?.toString() ?? ''));
    }

    if (value is Map) {
      if (value.containsKey('src') || value.containsKey('url')) {
        add(value['src'] ?? value['url'], value['name'] ?? value['filename'],
            value['type'] ?? value['mime'] ?? value['contentType']);
      } else {
        for (final e in value.entries) {
          add(e.key, e.value);
        }
      }
    } else if (value is List) {
      for (final v in value) {
        result.addAll(parse(v));
      }
    }
    return result;
  }
}

class StudyBlock {
  const StudyBlock({required this.text, this.files = const [], this.html});
  final String text;
  final String? html;
  final List<SchoolFile> files;
}

List<StudyBlock> studyBlocks(Map<String, dynamic> value) {
  final material = value['materialData'];
  if (material is! Map) return [];
  final rawCards = material['cardsData'];
  final cards = rawCards is Map
      ? rawCards.values
      : rawCards is List
          ? rawCards
          : const [];
  final result = <StudyBlock>[];
  for (final card in cards) {
    if (card is! Map) continue;
    dynamic content = card['content'];
    if (content is String) {
      try {
        content = jsonDecode(content);
      } catch (_) {
        continue;
      }
    }
    if (content is! Map) continue;
    for (final widget
        in (content['widgets'] is List ? content['widgets'] : const [])) {
      if (widget is! Map) continue;
      final props = widget['props'];
      if (props is! Map) continue;
      final text = plainText((props['_parsedHtmlText'] ??
              props['htmlText'] ??
              props['text'] ??
              props['question'] ??
              '')
          .toString());
      final files = SchoolFile.parse(props['files']);
      if (text.isNotEmpty || files.isNotEmpty) {
        result.add(StudyBlock(
            text: text,
            files: files,
            html: (props['_parsedHtmlText'] ?? props['htmlText'])?.toString()));
      }
    }
  }
  return result;
}

String safeFilename(String name) {
  final cleaned = name
      .replaceAll(RegExp(r'[/\\\x00-\x1f]'), '_')
      .replaceAll(RegExp(r'^\.+'), '')
      .trim();
  return cleaned.isEmpty
      ? 'attachment'
      : cleaned.length > 180
          ? cleaned.substring(cleaned.length - 180)
          : cleaned;
}

class FileService {
  FileService(this.controller);
  final SchoolController controller;
  static const channel = MethodChannel('edudz/files');
  Future<File> fetch(SchoolFile file,
      {void Function(int, int)? onProgress, CancelToken? cancelToken}) async {
    final directory = await getTemporaryDirectory();
    final account = controller.demo
        ? 'demo'
        : '${controller.data.user.username}@${controller.data.user.server}';
    final key = sha256.convert(utf8.encode('$account:${file.src}')).toString();
    final folder = Directory('${directory.path}/edudz/$key');
    await folder.create(recursive: true);
    final local = File('${folder.path}/${safeFilename(file.name)}');
    if (await local.exists()) return local;
    if (controller.demo && file.src.startsWith('assets/demo/')) {
      await local
          .writeAsBytes((await rootBundle.load(file.src)).buffer.asUint8List());
      return local;
    }
    final part = File('${local.path}.part');
    try {
      await controller.ensureSession();
      await controller.data.dio.download(
          '${controller.data.baseUrl}/api/file', part.path,
          queryParameters: {'src': file.src},
          options: Options(headers: {
            'Authorization': 'Bearer ${controller.data.user.token}'
          }),
          cancelToken: cancelToken,
          onReceiveProgress: onProgress);
      await part.rename(local.path);
      return local;
    } catch (_) {
      if (await part.exists()) await part.delete();
      rethrow;
    }
  }

  Future<String?> save(File local, SchoolFile file) =>
      channel.invokeMethod<String>('save', {
        'path': local.path,
        'name': safeFilename(file.name),
        'mime': file.mime.contains('/') ? file.mime : mimeFor(file.extension)
      });
  static String mimeFor(String ext) => switch (ext) {
        'pdf' => 'application/pdf',
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        'docx' =>
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'xlsx' =>
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'pptx' =>
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        'doc' => 'application/msword',
        'xls' => 'application/vnd.ms-excel',
        'ppt' => 'application/vnd.ms-powerpoint',
        'odt' => 'application/vnd.oasis.opendocument.text',
        'ods' => 'application/vnd.oasis.opendocument.spreadsheet',
        'odp' => 'application/vnd.oasis.opendocument.presentation',
        'rtf' => 'application/rtf',
        'txt' || 'csv' => 'text/plain',
        _ => 'application/octet-stream',
      };
}
