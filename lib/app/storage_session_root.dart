import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../shared/persistence/storage_access.dart';
import 'dart_tournament_app.dart';

/// Replaces and disposes the entire live application after a restore.
class StorageSessionRoot extends StatelessWidget {
  const StorageSessionRoot({super.key, this.startupError});
  final String? startupError;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: StorageAccess.restartRequired,
    builder: (context, restart, _) {
      if (startupError == null && !restart) return const DartTournamentApp();
      return MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Dart Turnierverwaltung')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SelectableText(
                      startupError ?? StorageAccess.restartMessage,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () {
                        if (Platform.isWindows ||
                            Platform.isLinux ||
                            Platform.isMacOS) {
                          exit(0);
                        }
                        SystemNavigator.pop();
                      },
                      child: const Text('App schließen'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
