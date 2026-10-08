import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../../accounts/presentation/widgets/account_menu_card.dart';
import '../../tournaments/domain/tournament_models.dart';
import '../data/tournament_invitation_repository.dart';
import '../domain/tournament_invitation.dart';

class TournamentInvitationsPage extends StatefulWidget {
  const TournamentInvitationsPage({
    super.key,
    required this.tournament,
    required this.onAssign,
    this.repository,
  });
  final CreatedTournament tournament;
  final TournamentInvitationRepository? repository;
  final Future<void> Function(
    Map<String, dynamic> request,
    TournamentPlayer? existing,
  )
  onAssign;
  @override
  State<TournamentInvitationsPage> createState() => _InvitationsState();
}

class _InvitationsState extends State<TournamentInvitationsPage> {
  late final repository = widget.repository ?? TournamentInvitationRepository();
  String? token, error;
  bool busy = false;
  List<Map<String, dynamic>> requests = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final value = token ?? await repository.create(widget.tournament);
      final rows = await repository.requests(value);
      if (mounted) {
        setState(() {
          token = value;
          requests = rows;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Einladungen konnten nicht geladen werden. Bitte anmelden und Verbindung sowie Turnierrechte prüfen.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> assign(Map<String, dynamic> row) async {
    TournamentPlayer? player;
    bool community = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('Anmeldung: ${row['display_name']}'),
          scrollable: true,
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<TournamentPlayer>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Bestehender Spieler (optional)',
                  ),
                  items: [
                    for (final p in widget.tournament.players)
                      DropdownMenuItem(value: p, child: Text(p.name)),
                  ],
                  onChanged: (p) => update(() => player = p),
                ),
                const Text(
                  'Ohne Auswahl wird ein neuer Spieler angelegt. Neue Spieler sind nur vor dem ersten Spiel möglich; danach bitte einem vorhandenen Teilnehmer zuordnen.',
                ),
                if (widget.tournament.communityId != null)
                  SwitchListTile(
                    title: const Text('Auch zur Community hinzufügen'),
                    value: community,
                    onChanged: (v) => update(() => community = v),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Zuordnen'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onAssign(row, player);
      await repository.resolve(
        row['id'] as String,
        accept: true,
        playerKey:
            row['user_id'] as String? ??
            player?.profileId ??
            row['id'] as String,
        community: community,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is StateError
              ? e.message.toString()
              : 'Zuordnung noch nicht vollständig abgeschlossen. Bitte erneut versuchen.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> reject(Map<String, dynamic> row) async {
    setState(() => busy = true);
    try {
      await repository.resolve(row['id'] as String, accept: false);
      await load();
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Anmeldung konnte nicht abgelehnt werden.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Turniereinladungen')),
    body: AdaptiveContentList(
      children: [
        const AccountMenuCard(),
        if (busy) const LinearProgressIndicator(),
        if (error != null) Text(error!),
        TextButton.icon(
          onPressed: busy ? null : load,
          icon: const Icon(Icons.refresh),
          label: const Text('Anmeldungen laden'),
        ),
        if (token != null) ...[
          Center(
            child: SizedBox(
              width: 220,
              child: QrImageView(
                data: TournamentInvitation.link(token!),
                backgroundColor: Colors.white,
              ),
            ),
          ),
          SelectableText(TournamentInvitation.link(token!)),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: TournamentInvitation.link(token!)),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Turnierlink kopiert.')),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Einladungslink kopieren'),
          ),
          const Text(
            'Link und QR-Code gelten 30 Tage. Ohne App ist eine Anmeldung im Browser möglich. Die Zuordnung übernimmt die Turnierleitung.',
          ),
          const SizedBox(height: 16),
          Text(
            'Offene Anmeldungen (${requests.length})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (final row in requests)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row['display_name'] as String),
                    Text(
                      row['user_id'] == null
                          ? 'Gastanmeldung'
                          : 'Anmeldung mit Account',
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(
                          onPressed: busy ? null : () => assign(row),
                          child: const Text('Spieler zuordnen'),
                        ),
                        TextButton(
                          onPressed: busy ? null : () => reject(row),
                          child: const Text('Ablehnen'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    ),
  );
}
