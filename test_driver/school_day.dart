import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() =>
    integrationDriver(onScreenshot: (name, bytes, [args]) async {
      final prefix = Platform.environment['EDUDZ_SCREENSHOT_PREFIX'] ?? '';
      final filename = name.startsWith('tablet-') ? name : '$prefix$name';
      final file = File('docs/screenshots/$filename.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      return true;
    });
