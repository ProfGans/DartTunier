import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../application/supabase_workspace_sync_service.dart';
import '../../accounts/data/supabase_account_config.dart';
import '../data/backup_service.dart';
import '../data/supabase_backup_repository.dart';

class CloudBackupPanel extends StatefulWidget {
  const CloudBackupPanel({super.key});

  @override
  State<CloudBackupPanel> createState() => _CloudBackupPanelState();
}

class _CloudBackupPanelState extends State<CloudBackupPanel> {
  bool _busy = false;
  String? _status;
  bool _error = false;

  Future<void> _signIn() async {
    final credentials = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _OperatorSignInDialog(),
    );
    if (credentials == null) return;
    await _run(() async {
      await Supabase.instance.client.auth.signInWithPassword(
        email: credentials.$1,
        password: credentials.$2,
      );
      _status = 'Betreiberkonto verbunden.';
    });
  }

  Future<void> _upload() => _run(() async {
    await SupabaseWorkspaceSyncService.instance.uploadLocalVersion();
    _status = SupabaseWorkspaceSyncService.status.value;
  });

  Future<void> _restore() => _run(() async {
    final backups = await BackupService.create();
    final repository = SupabaseBackupRepository();
    final preview = await repository.download(backups);
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cloud-Backup wiederherstellen?'),
        content: Text(
          'Backup vom ${preview.createdAt.toLocal()} mit ${preview.tournaments} Turnieren laden? '
          'Der aktuelle lokale Stand wird ersetzt; vorher legt die App eine Sicherung an.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Wiederherstellen')),
        ],
      ),
    );
    if (confirmed != true) return;
    await SupabaseWorkspaceSyncService.instance.downloadRemoteVersion();
    _status = 'Cloud-Datenstand übernommen. Die Oberfläche lädt neu.';
  });

  Future<void> _run(Future<void> Function() action) async {
    setState(() { _busy = true; _status = null; _error = false; });
    try {
      await action();
    } catch (error) {
      _error = true;
      _status = switch (error) {
        AuthException() => 'Anmeldung fehlgeschlagen. Zugangsdaten und E-Mail-Bestätigung prüfen.',
        StorageException() => 'Cloud-Backup fehlgeschlagen. Prüfe die Supabase-Storage-Regeln und Internetverbindung.',
        StateError() => '$error',
        _ => 'Cloud-Vorgang fehlgeschlagen: $error',
      };
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = SupabaseAccountConfig.isConfigured && SupabaseAccountBootstrap.isInitialized;
    final user = configured ? Supabase.instance.client.auth.currentUser : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Supabase-Backup & Synchronisierung', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(configured
              ? user == null
                  ? 'Mit demselben Supabase-Konto kannst du deinen Datenstand zwischen Laptop und Handy übertragen. Jedes Konto hat einen eigenen Cloud-Speicher.'
                  : 'Angemeldet als ${user.email ?? 'Betreiber'}. Der Cloud-Datenstand enthält Spieler, Turniere, Bestleistungen und Ranglisten.'
              : 'Für Cloud-Sicherung SUPABASE_PUBLISHABLE_KEY beim App-Build setzen.'),
          const SizedBox(height: 8),
          if (configured && user == null)
            Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(
              onPressed: _busy ? null : _signIn,
              icon: const Icon(Icons.login),
              label: const Text('Als Betreiber anmelden'),
            )),
          if (configured && user != null)
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(onPressed: _busy ? null : _upload, icon: const Icon(Icons.cloud_upload_outlined), label: const Text('Lokalen Stand hochladen')),
              OutlinedButton.icon(onPressed: _busy ? null : _restore, icon: const Icon(Icons.cloud_download_outlined), label: const Text('Cloud-Datenstand laden')),
              TextButton(onPressed: _busy ? null : () => _run(() async { await Supabase.instance.client.auth.signOut(); _status = 'Abgemeldet.'; }), child: const Text('Abmelden')),
            ]),
          if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
          ValueListenableBuilder<String>(valueListenable: SupabaseWorkspaceSyncService.status, builder: (context, status, _) => Padding(padding: const EdgeInsets.only(top: 8), child: Text(status))),
          if (_status != null) Padding(padding: const EdgeInsets.only(top: 8), child: SelectableText(_status!, style: TextStyle(color: _error ? Theme.of(context).colorScheme.error : null))),
        ]),
      ),
    );
  }
}

class _OperatorSignInDialog extends StatefulWidget {
  const _OperatorSignInDialog();
  @override
  State<_OperatorSignInDialog> createState() => _OperatorSignInDialogState();
}

class _OperatorSignInDialogState extends State<_OperatorSignInDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  @override
  void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Betreiberkonto'),
    content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: _email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.username], decoration: const InputDecoration(labelText: 'E-Mail')),
      TextField(controller: _password, obscureText: true, autofillHints: const [AutofillHints.password], decoration: const InputDecoration(labelText: 'Passwort')),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
      FilledButton(onPressed: () => Navigator.pop(context, (_email.text.trim(), _password.text)), child: const Text('Anmelden')),
    ],
  );
}
