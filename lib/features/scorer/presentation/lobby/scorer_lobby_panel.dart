import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../application/scorer_lobby_controller.dart';
import '../../domain/scorer_lobby.dart';

class ScorerLobbyPanel extends StatelessWidget {
  const ScorerLobbyPanel({super.key, required this.controller});
  final ScorerLobbyController controller;

  Future<void> _invite(BuildContext context) async {
    try {
      final candidates = await controller.repository.candidates();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) =>
            _InviteDialog(controller: controller, candidates: candidates),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gruppenmitglieder konnten nicht geladen werden.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final lobby = controller.lobby;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mit Konto teilnehmen',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Text(
                'Gäste scannen den QR-Code unter Scorer → Spiel beitreten. Einladungen aus gemeinsamen Gruppen erscheinen als Pop-up in der geöffneten App.',
              ),
              if (!controller.repository.signedIn)
                const Text(
                  'Für Einladungen bitte zuerst im Hauptmenü mit einem Online-Konto anmelden. Gastnamen funktionieren auch offline.',
                )
              else if (lobby == null || !lobby.open)
                FilledButton.icon(
                  onPressed: controller.busy ? null : controller.create,
                  icon: const Icon(Icons.qr_code),
                  label: Text(
                    controller.busy
                        ? 'Wird geöffnet …'
                        : 'QR-Code & Einladungen öffnen',
                  ),
                )
              else ...[
                const SizedBox(height: 12),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: QrImageView(
                        data: ScorerJoinCode.link(lobby.code),
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
                SelectableText('Beitrittscode: ${lobby.code}'),
                Text(
                  'Gültig bis ${TimeOfDay.fromDateTime(lobby.expiresAt.toLocal()).format(context)} oder bis zum Spielstart.',
                ),
                Wrap(
                  spacing: 12,
                  children: [
                    TextButton.icon(
                      onPressed: () => Clipboard.setData(
                        ClipboardData(text: ScorerJoinCode.link(lobby.code)),
                      ),
                      icon: const Icon(Icons.copy),
                      label: const Text('Link kopieren'),
                    ),
                    OutlinedButton.icon(
                      onPressed: controller.busy
                          ? null
                          : () => _invite(context),
                      icon: const Icon(Icons.group_add_outlined),
                      label: const Text('Aus Gruppen einladen'),
                    ),
                    TextButton(
                      onPressed: controller.refresh,
                      child: const Text('Aktualisieren'),
                    ),
                  ],
                ),
                Text('${lobby.members.length} Konten beigetreten'),
              ],
              if (controller.error != null)
                Text(
                  controller.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _InviteDialog extends StatefulWidget {
  const _InviteDialog({required this.controller, required this.candidates});
  final ScorerLobbyController controller;
  final List<ScorerInviteCandidate> candidates;
  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final sent = <String>{};
  String? busy, error;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Aus gemeinsamen Gruppen einladen'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.candidates.isEmpty)
              const Text('Keine weiteren Konten in deinen Gruppen gefunden.'),
            if (error != null) Text(error!),
            for (final p in widget.candidates)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(p.groups),
                    OutlinedButton(
                      onPressed:
                          busy != null ||
                              sent.contains(p.id) ||
                              widget.controller.lobby!.members.any(
                                (m) => m.id == p.id,
                              )
                          ? null
                          : () async {
                              setState(() {
                                busy = p.id;
                                error = null;
                              });
                              try {
                                await widget.controller.repository.invite(
                                  widget.controller.lobby!.id,
                                  p.id,
                                );
                                if (mounted) setState(() => sent.add(p.id));
                              } catch (_) {
                                if (mounted) {
                                  setState(
                                    () => error =
                                        'Einladung konnte nicht gesendet werden.',
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => busy = null);
                              }
                            },
                      child: Text(
                        sent.contains(p.id)
                            ? 'Einladung angefragt'
                            : 'Einladen',
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Schließen'),
      ),
    ],
  );
}
