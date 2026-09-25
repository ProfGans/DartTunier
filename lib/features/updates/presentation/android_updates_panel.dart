import 'dart:io';
import 'package:flutter/material.dart';
import '../../backups/presentation/android_backup_export.dart';
import '../data/android_update_service.dart';
import '../domain/android_release.dart';

class AndroidUpdatesPanel extends StatefulWidget {
  const AndroidUpdatesPanel({super.key});
  @override
  State<AndroidUpdatesPanel> createState() => _AndroidUpdatesPanelState();
}

class _AndroidUpdatesPanelState extends State<AndroidUpdatesPanel> {
  final _service = AndroidUpdateService();
  bool _busy = false;
  bool _downloaded = false;
  double? _progress;
  String _status = 'Updates für Android aus ProfGans/DartTunier.';
  String? _installed;
  AndroidRelease? _release;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _status = 'Update fehlgeschlagen: $error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _check() => _run(() async {
    final installed = await _service.installed();
    final release = await _service.check(installed.build);
    if (!mounted) return;
    setState(() {
      _installed = '${installed.version} (${installed.build})';
      _release = release;
      _downloaded = false;
      _status = release == null
          ? 'Kein neueres Android-Update veröffentlicht.'
          : 'Verfügbar: ${release.version} (${release.build})';
    });
  });

  Future<void> _install() => _run(() async {
    if (!_downloaded) {
      await _service.download(_release!, (value) {
        if (mounted) setState(() => _progress = value);
      });
      _downloaded = true;
    }
    if (!mounted) return;
    final backup = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup vor dem Update?'),
        content: const SingleChildScrollView(
          child: Text(
            'Möchtest du deine Turniere, Ergebnisse und Einstellungen zusätzlich '
            'als Backup-Datei speichern? Du wählst den Speicherort selbst.\n\n'
            'Eine interne Sicherung wird vor der Installation automatisch erstellt. '
            'Die exportierte Datei ist nicht verschlüsselt; bewahre sie sicher auf.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ohne Export fortfahren'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Backup speichern und installieren'),
          ),
        ],
      ),
    );
    if (backup == null || !mounted) return;
    if (backup && !await exportAndroidBackup()) {
      if (mounted) {
        setState(
          () => _status = 'Backup abgebrochen. Update noch nicht installiert.',
        );
      }
      return;
    }
    if (!mounted) return;
    final started = await _service.install();
    if (mounted) {
      setState(
        () => _status = started
            ? 'Android-Installation geöffnet.'
            : 'Bitte die Installation aus dieser Quelle erlauben, zurückkehren und erneut auf Installieren tippen.',
      );
    }
  });

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Updates', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        if (!Platform.isAndroid)
          const Text('App-Updates sind zunächst für Android verfügbar.')
        else ...[
          if (_installed != null) Text('Installiert: $_installed'),
          Text(_status),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _check,
            child: const Text('Nach Updates suchen'),
          ),
          if (_release != null) ...[
            const SizedBox(height: 16),
            Text(
              _release!.notes.isEmpty
                  ? 'Keine Versionshinweise.'
                  : _release!.notes,
            ),
            const SizedBox(height: 12),
            const Text(
              'Vor der Installation wird dein lokaler Datenbestand gesichert. '
              'Android fragt nach deiner Bestätigung. Bitte die bestehende App nicht deinstallieren.',
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : _install,
              child: Text(
                _downloaded
                    ? 'Installieren'
                    : 'Update herunterladen und installieren',
              ),
            ),
          ],
          if (_busy)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(value: _progress),
            ),
        ],
      ],
    ),
  );
}
