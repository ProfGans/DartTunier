import 'package:flutter/material.dart';
import 'package:dart_tournament_manager/app/app_theme.dart';
import 'package:dart_tournament_manager/features/autoscoring/presentation/autoscoring_page.dart';

/// Standalone hardware check; tournament storage and account bootstrap stay closed.
void main() {
  runApp(
    MaterialApp(
      title: 'Autoscorer Hardwaretest',
      theme: buildDartTournamentTheme(),
      home: const AutoscoringPage(),
    ),
  );
}
