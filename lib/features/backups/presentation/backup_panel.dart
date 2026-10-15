import '../../../shared/widgets/sport_menu.dart';
import 'package:dart_tournament_manager/shared/widgets/adaptive_content.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import '../data/backup_service.dart';
import 'android_backup_export.dart';
import 'backup_file_dialogs.dart';
import 'cloud_backup_panel.dart';

class BackupPanel extends StatefulWidget {
  const BackupPanel({
    super.key,
    this.service,
    this.dialogs = const BackupFileDialogs(),
    this.trailing,
  });
  final BackupService? service;
  final BackupFileDialogs dialogs;
  final Widget? trailing;
  @override
  State<BackupPanel> createState() => _BackupPanelState();
}

class _BackupPanelState extends State<BackupPanel> {
  static const _areaNames = {
    'tournaments.json': 'Turniere und Ergebnisse',
    'app_database.sqlite': 'Spielerprofile und Ranglisten',
    'planning_settings.json': 'Turnierplanung',
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
    child: AdaptiveContentList(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Datensicherung',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        const CloudBackupPanel(),
        const SizedBox(height: 12),
        const Text(
          'Sichere Turniere mit Ergebnissen, lokale Spielerprofile, '
          'Ranglisten und Einstellungen in einer Datei. Das Supabase-Backup '
          'wird separat mit dem Betreiberkonto gespeichert und wiederhergestellt.',
        ),
        const SizedBox(height: 12),
        const Text(
          'Die Datei ist nicht verschlüsselt und enthält Spieler-, Turnier- und '
          'Geräteeinstellungen. Bewahre lokale Exportdateien geschützt auf.',
        ),
        const SizedBox(height: 24),
        SportMenuGroup(
          title: 'Sicherung verwalten',
          actions: [
            SportMenuAction(
              label: 'Backup exportieren',
              description: 'Aktuellen Stand als Datei sichern.',
              icon: Icons.save_alt,
              onTap: _busy ? null : _export,
            ),
            SportMenuAction(
              label: 'Backup wiederherstellen',
              description: 'Gesicherte Datei prüfen und einlesen.',
              icon: Icons.restore,
              onTap: _busy ? null : _import,
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
        if (widget.trailing != null) ...[
          const SizedBox(height: 16),
          widget.trailing!,
        ],
      ],
    ),
  );
}
