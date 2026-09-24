import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/backups/data/backup_service.dart';
import 'package:dart_tournament_manager/features/backups/presentation/backup_file_dialogs.dart';
import 'package:dart_tournament_manager/features/backups/presentation/backup_panel.dart';
import 'package:dart_tournament_manager/features/tournaments/data/tournament_storage.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'package:dart_tournament_manager/shared/persistence/storage_access.dart';

class _Dialogs extends BackupFileDialogs {
  String? target;
  XFile? source;
  @override
  Future<String?> savePath() async => target;
  @override
  Future<XFile?> open() async => source;
}

void main() {
  testWidgets('export, cancelled import and confirmed import use real stores', (
    tester,
  ) async {
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('backup_widget_'),
    ))!;
    addTearDown(() async {
      StorageAccess.restartRequired.value = false;
      await root.delete(recursive: true);
    });
    final service = BackupService(
      files: {
        for (final name in BackupService.names)
          name: File('${root.path}/data/$name'),
      },
      backupDirectory: Directory('${root.path}/data/backups'),
    );
    final storage = TournamentStorage(file: service.files['tournaments.json']);
    final dialogs = _Dialogs()..target = '${root.path}/export.dartbackup';
    await tester.runAsync(
      () => storage.saveTournament(
        CreatedTournament(
          name: 'Original',
          players: [],
          stages: [],
          runStages: [],
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BackupPanel(service: service, dialogs: dialogs),
        ),
      ),
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Backup exportieren'));
      // Await filesystem work outside fake async time.
      for (var i = 0; i < 100 && !await File(dialogs.target!).exists(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Backup gespeichert:'), findsOneWidget);
    dialogs.source = XFile(dialogs.target!);
    await tester.runAsync(
      () => storage.saveTournament(
        CreatedTournament(
          name: 'Später',
          players: [],
          stages: [],
          runStages: [],
        ),
      ),
    );
    Future<void> openPreview() async {
      await tester.runAsync(() async {
        await tester.tap(find.text('Backup wiederherstellen'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump(const Duration(milliseconds: 300));
    }

    await openPreview();
    expect(find.text('Backup wiederherstellen?'), findsOneWidget);
    expect(find.textContaining('1 Turniere'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      await tester.runAsync(
        () async => (await storage.loadTournaments()).length,
      ),
      2,
    );
    await openPreview();
    await tester.runAsync(() async {
      await tester.tap(find.text('Wiederherstellen'));
      for (var i = 0; i < 100 && !StorageAccess.restartRequired.value; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(StorageAccess.restartRequired.value, isTrue);
    expect(find.textContaining('Bitte App neu starten.'), findsOneWidget);
  });
}
