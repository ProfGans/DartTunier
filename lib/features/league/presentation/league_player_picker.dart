import 'package:flutter/material.dart';
import '../../tournaments/data/app_database.dart';
import '../../tournaments/domain/tournament_models.dart';
import '../data/league_invitation_repository.dart';

/// A selected community account is only a candidate, not yet a roster member.
class LeaguePlayerChoice {
  const LeaguePlayerChoice(this.player, {this.inviteUserId});
  final TournamentPlayer player;
  final String? inviteUserId;
}

class LeaguePlayerPicker extends StatefulWidget {
  const LeaguePlayerPicker({
    super.key,
    required this.repository,
    this.database,
    this.initialCommunity = false,
  });
  final LeagueInvitationRepository repository;
  final LocalAppDatabase? database;
  final bool initialCommunity;
  @override
  State<LeaguePlayerPicker> createState() => _LeaguePlayerPickerState();
}

class _LeaguePlayerPickerState extends State<LeaguePlayerPicker> {
  late final database = widget.database ?? LocalAppDatabase();
  final name = TextEditingController();
  String query = '';
  final groups = <String, String>{};
  bool community = false, loading = false;
  String? error;
  List<LeaguePlayerChoice> choices = [];
  @override
  void initState() {
    super.initState();
    community = widget.initialCommunity;
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final candidates = community
          ? await widget.repository.candidates()
          : null;
      if (candidates != null) {
        groups.clear();
        groups.addEntries(candidates.map((p) => MapEntry(p.id, p.groups)));
      }
      final result = community
          ? [
              for (final p in candidates!)
                LeaguePlayerChoice(
                  TournamentPlayer(
                    name: p.name,
                    profileId: p.id,
                    isGenerated: false,
                  ),
                  inviteUserId: p.id,
                ),
            ]
          : [
              for (final p in await database.loadPlayerProfiles())
                if (p.userId == null)
                  LeaguePlayerChoice(
                    TournamentPlayer(
                      name: p.displayName,
                      profileId: p.id,
                      isGenerated: false,
                    ),
                  ),
            ];
      if (mounted) setState(() => choices = result);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = community
              ? 'Community-Mitglieder konnten nicht geladen werden. Online anmelden und Verbindung prüfen.'
              : 'Lokale Spieler konnten nicht geladen werden.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> create() async {
    if (name.text.trim().isEmpty) return;
    setState(() => loading = true);
    try {
      final player = await database.createPlayerProfile(
        displayName: name.text.trim(),
      );
      if (mounted) {
        Navigator.pop(
          context,
          LeaguePlayerChoice(
            TournamentPlayer(
              name: player.displayName,
              profileId: player.id,
              isGenerated: false,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Spieler konnte nicht gespeichert werden.';
        });
      }
    }
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Spieler hinzufügen'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Lokale Spieler'),
                  selected: !community,
                  onSelected: loading
                      ? null
                      : (_) {
                          community = false;
                          load();
                        },
                ),
                ChoiceChip(
                  label: const Text('Community einladen'),
                  selected: community,
                  onSelected: loading
                      ? null
                      : (_) {
                          community = true;
                          load();
                        },
                ),
              ],
            ),
            if (loading) const CircularProgressIndicator(),
            if (error != null) Text(error!),
            if (error != null)
              TextButton(
                onPressed: loading ? null : load,
                child: const Text('Erneut versuchen'),
              ),
            if (!loading && error == null) ...[
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Spieler oder Community suchen',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) =>
                    setState(() => query = value.trim().toLowerCase()),
              ),
              if (community)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Mitglieder aus deinen gemeinsamen Communitys erhalten eine Einladung. Sie gehören erst nach Annahme zur Mannschaft.',
                  ),
                ),
              if (choices.isEmpty) const Text('Keine Spieler verfügbar.'),
              for (final choice in choices.where(
                (p) => '${p.player.name} ${groups[p.inviteUserId] ?? ''}'
                    .toLowerCase()
                    .contains(query),
              ))
                ListTile(
                  title: Text(choice.player.name),
                  subtitle: community
                      ? Text(groups[choice.inviteUserId] ?? '')
                      : const Text('Lokaler Spieler'),
                  trailing: Icon(community ? Icons.mail_outline : Icons.add),
                  onTap: () => Navigator.pop(context, choice),
                ),
              if (!community) ...[
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Neuen lokalen Spieler erstellen',
                  ),
                ),
                TextButton.icon(
                  onPressed: create,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Erstellen und hinzufügen'),
                ),
              ],
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: loading ? null : () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
    ],
  );
}
