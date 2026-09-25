import 'dart:io';
import 'package:flutter/material.dart';
import '../data/backup_service.dart';
import 'android_backup_export.dart';
import 'backup_file_dialogs.dart';

class BackupPanel extends StatefulWidget {
  const BackupPanel({
    super.key,
    this.service,
    this.dialogs = const BackupFileDialogs(),
  });
  final BackupService? service;
  final BackupFileDialogs dialogs;
  @override
  State<BackupPanel> createState() => _BackupPanelState();
}

class _BackupPanelState extends State<BackupPanel> {
  static const _areaNames = {
    'tournaments.json': 'Turniere und Ergebnisse',
    'app_database.sqlite': 'Lokale Konten und Spielerprofile',
    'planning_settings.json': 'Turnierplanung',
    'devices.json': 'Geräteeinstellungen und Kopplungen',
  };
  bool _busy = false;
  String? _message;
  bool _failed = false;
  Future<BackupService> _service() async =>
      widget.service ?? await BackupService.create();

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
      _failed = false;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() {
          _failed = true;
          _message = error is FormatException
              ? error.message
              : 'Vorgang fehlgeschlagen. Die Datei konnte nicht verarbeitet werden. '
                    'Bitte Speicherort, freien Speicher und App-Version prüfen.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() => _run(() async {
    if (Platform.isAndroid) {
      final saved = await exportAndroidBackup(service: await _service());
      if (mounted && saved) {
        setState(
          () => _message = 'Backup am gewählten Speicherort gespeichert.',
        );
      }
      return;
    }
    final target = await widget.dialogs.savePath();
    if (target == null) return;
    await (await _service()).exportTo(File(target));
    if (mounted) setState(() => _message = 'Backup gespeichert:\n$target');
  });

  Future<void> _import() => _run(() async {
    final selected = await widget.dialogs.open();
    if (selected == null) return;
    if (await selected.length() > BackupService.maximumBytes) {
      throw const FormatException('Backup ist größer als 128 MB.');
    }
    final service = await _service();
    final preview = await service.inspect(await selected.readAsBytes());
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup wiederherstellen?'),
        content: SingleChildScrollView(
          child: Text(
            'Erstellt: ${preview.createdAt.toLocal()}\n'
            '${preview.tournaments} Turniere · ${preview.files.length} gespeicherte Datenbereiche\n\n'
            'Enthalten: ${preview.files.map((name) => _areaNames[name] ?? name).join(', ')}\n\n'
            'Der lokale Datenbestand wird vollständig ersetzt. Im Backup fehlende Bereiche '
            'werden zurückgesetzt. Vorher wird dein jetziger Stand automatisch gesichert. '
            'Nach der Wiederherstellung musst du die App neu starten.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Wiederherstellen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final safety = await service.restore(preview);
    if (mounted) {
      setState(
        () => _message =
            'Wiederhergestellt. Sicherung des vorherigen Stands:\n${safety.path}\nBitte App neu starten.',
      );
    }
  });

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Datensicherung',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        const Text(
          'Sichere Turniere mit Ergebnissen, lokale Spielerprofile, '
          'Planungs- und Geräteeinstellungen in einer Datei. Online-Konten und '
          'Cloud-Daten werden nicht zurückgesetzt; die Cloud-Anmeldung ist nicht Bestandteil des Backups.',
        ),
        const SizedBox(height: 12),
        const Text(
          'Die Datei ist nicht verschlüsselt und enthält persönliche Daten und '
          'Gerätekopplungen. Bewahre sie an einem geschützten Ort auf, möglichst auf einem zweiten Datenträger.',
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : _export,
              icon: const Icon(Icons.save_alt),
              label: const Text('Backup exportieren'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _import,
              icon: const Icon(Icons.restore),
              label: const Text('Backup wiederherstellen'),
            ),
          ],
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: LinearProgressIndicator(),
          ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: SelectableText(
              _message!,
              style: TextStyle(
                color: _failed ? Theme.of(context).colorScheme.error : null,
              ),
            ),
          ),
      ],
    ),
  );
}
