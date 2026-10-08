import 'package:flutter/material.dart';
import '../../../../communities/data/supabase_community_repository.dart';
import '../../../../communities/domain/community.dart';
import '../../../domain/tournament_access.dart';

class TournamentAccessEditor extends StatefulWidget {
  const TournamentAccessEditor({
    super.key,
    required this.communityId,
    required this.value,
    required this.onChanged,
    this.loadMembers,
  });
  final String communityId;
  final TournamentAccessSettings value;
  final ValueChanged<TournamentAccessSettings> onChanged;
  final Future<List<CommunityMember>> Function()? loadMembers;
  @override
  State<TournamentAccessEditor> createState() => _TournamentAccessEditorState();
}

class _TournamentAccessEditorState extends State<TournamentAccessEditor> {
  late Future<List<CommunityMember>> _members = _load();
  Future<List<CommunityMember>> _load() =>
      widget.loadMembers?.call() ??
      SupabaseCommunityRepository().loadMembers(widget.communityId);
  void _update({
    List<String>? directors,
    List<String>? reporters,
    ResultEntryMode? mode,
  }) => widget.onChanged(
    TournamentAccessSettings(
      creatorUserId: widget.value.creatorUserId,
      directorUserIds: directors ?? widget.value.directorUserIds,
      resultEntryMode: mode ?? widget.value.resultEntryMode,
      resultUserIds: reporters ?? widget.value.resultUserIds,
    ),
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Turnierrechte', style: Theme.of(context).textTheme.titleLarge),
      const Text(
        'Ersteller und Mitglieder mit dem Community-Recht „Turniere leiten“ gehören immer zur Turnierleitung. Weitere Mitglieder gelten nur für dieses Turnier.',
      ),
      const SizedBox(height: 12),
      const Text('Wer darf Ergebnisse eintragen?'),
      RadioGroup<ResultEntryMode>(
        groupValue: widget.value.resultEntryMode,
        onChanged: (value) { if (value != null) _update(mode: value); },
        child: const Column(children: [
          RadioListTile(value: ResultEntryMode.directors, title: Text('Nur die Turnierleitung')),
          RadioListTile(value: ResultEntryMode.selected, title: Text('Turnierleitung und ausgewählte Mitglieder')),
          RadioListTile(value: ResultEntryMode.members, title: Text('Alle Community-Mitglieder')),
        ]),
      ),
      const SizedBox(height: 8),
      const Text(
        'Zusätzliche Ergebnisschreiber dürfen offene Spiele online abschließen. Korrekturen und Annullierungen bleiben der Turnierleitung vorbehalten.',
      ),
      FutureBuilder<List<CommunityMember>>(
        future: _members,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Column(
              children: [
                const Text(
                  'Mitglieder konnten nicht geladen werden. Bestehende Auswahl bleibt erhalten.',
                ),
                TextButton(
                  onPressed: () => setState(() => _members = _load()),
                  child: const Text('Mitglieder erneut laden'),
                ),
              ],
            );
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            );
          }
          final members = snapshot.data!
              .where(
                (m) =>
                    m.userId != null && m.userId != widget.value.creatorUserId,
              )
              .toList();
          Widget selection(
            String title,
            List<String> ids,
            ValueChanged<List<String>> change,
          ) => ExpansionTile(
            title: Text(title),
            subtitle: Text('${ids.length} ausgewählt'),
            children: [
              for (final member in members)
                CheckboxListTile(
                  title: Text(member.displayName),
                  value: ids.contains(member.userId),
                  onChanged: (checked) {
                    final next = ids.toSet();
                    if (checked == true) {
                      next.add(member.userId!);
                    } else {
                      next.remove(member.userId);
                    }
                    change(next.toList());
                  },
                ),
              if (members.isEmpty)
                const Text('Keine weiteren Mitglieder mit Account vorhanden.'),
            ],
          );
          return Column(
            children: [
              selection(
                'Zusätzliche Turnierleitung',
                widget.value.directorUserIds,
                (ids) => _update(directors: ids),
              ),
              if (widget.value.resultEntryMode == ResultEntryMode.selected)
                selection(
                  'Zusätzliche Ergebnisschreiber',
                  widget.value.resultUserIds,
                  (ids) => _update(reporters: ids),
                ),
            ],
          );
        },
      ),
    ],
  );
}
