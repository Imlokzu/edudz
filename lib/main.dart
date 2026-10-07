import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:edudz/l10n/app_localizations.dart';
import 'package:toastification/toastification.dart';
import 'edudz/controller.dart';
import 'edudz/shell.dart';
import 'edudz/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

abstract class BaseState<T extends StatefulWidget> extends State<T> {
  @override
  void setState(VoidCallback fn) {
    if (mounted) super.setState(fn);
  }
}

final navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.controller});
  final SchoolController? controller;
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final SchoolController controller =
      widget.controller ?? SchoolController();
  @override
  void initState() {
    super.initState();
    if (widget.controller == null) controller.start();
  }

  @override
  void dispose() {
    if (widget.controller == null) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ToastificationWrapper(
          child: MaterialApp(
            title: 'edudz',
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            theme: edudzTheme(Brightness.light),
            darkTheme: edudzTheme(Brightness.dark),
            themeMode: controller.dark ? ThemeMode.dark : ThemeMode.light,
            locale: Locale(controller.language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
              value: controller.dark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark,
              child: child!,
            ),
            home: EdudzShell(controller: controller),
          ),
        ),
      );
}
