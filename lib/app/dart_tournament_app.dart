import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../tournament_workspace.dart';
import 'app_theme.dart';

class DartTournamentApp extends StatelessWidget {
  const DartTournamentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dart Turnierverwaltung',
      scrollBehavior: const DartTournamentScrollBehavior(),
      theme: buildDartTournamentTheme(),
      home: const HomePage(),
    );
  }
}

class DartTournamentScrollBehavior extends MaterialScrollBehavior {
  const DartTournamentScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
