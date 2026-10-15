import 'package:flutter/material.dart';
import '../../../../shared/widgets/adaptive_content.dart';
import '../../../statistics/domain/best_performance.dart';
import '../../domain/tournament_models.dart';
import '../../data/tournament_storage.dart';
import '../widgets/run/best_performance_editor.dart';

class ChallongeArchivePage extends StatefulWidget {
  const ChallongeArchivePage({super.key, required this.tournament});
  final CreatedTournament tournament;

  @override
  State<ChallongeArchivePage> createState() => _ChallongeArchivePageState();
}

class _ChallongeArchivePageState extends State<ChallongeArchivePage> {
  late CreatedTournament tournament = widget.tournament;
  bool saving = false;

  Future<void> editBestPerformances(Map<String, dynamic> source) async {
    final archive = tournament.importedArchive!;
    final playerById = <String, TournamentPlayer>{};
    for (final participant in archive.participants) {
      final player = TournamentPlayer(
        profileId: participant['profileId'] as String?,
        name: '${participant['name'] ?? 'Spieler'}',
        isGenerated: false,
      );
      playerById['${participant['id']}'] = player;
      for (final alias in participant['groupPlayerIds'] as List? ?? const []) {
        playerById['$alias'] = player;
      }
    }
    final performances = (source['bestPerformances'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => BestPerformance.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final match = GroupMatch(
      homePlayer: playerById['${source['player1_id']}'],
      awayPlayer: playerById['${source['player2_id']}'],
      round: (source['round'] as int? ?? 1).abs(),
      bestPerformances: performances,
    );
    final result = await showDialog<List<BestPerformance>>(
      context: context,
      builder: (_) => _ArchivePerformanceDialog(match: match, initial: performances),
    );
    if (result == null || !mounted) return;
    final matches = [
      for (final item in archive.matches)
        if (identical(item, source) ||
            (source['id'] != null && item['id'] == source['id']))
          {...item, 'bestPerformances': result.map((entry) => entry.toJson()).toList()}
        else
          Map<String, dynamic>.from(item),
    ];
    final updatedJson = tournament.toJson();
    updatedJson['importedArchive'] = archive.copyWithMatches(matches).toJson();
    final updated = CreatedTournament.fromJson(updatedJson);
    setState(() => saving = true);
    try {
      await TournamentStorage().saveTournament(updated);
      if (mounted) setState(() => tournament = updated);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bestleistungen konnten nicht gespeichert werden: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final archive = tournament.importedArchive!;
    final players = {
      for (final p in archive.participants) '${p['id']}': '${p['name']}',
      for (final p in archive.participants)
        for (final alias in (p['groupPlayerIds'] as List? ?? const []))
          '$alias': '${p['name']}',
    };
    final ranks = [...archive.participants]
      ..sort(
        (a, b) => ((a['finalRank'] as int?) ?? 999999).compareTo(
          (b['finalRank'] as int?) ?? 999999,
        ),
      );
    return Scaffold(
      appBar: AppBar(title: Text(tournament.name)),
      body: AdaptiveContentList(
        children: [
          Text(
            '${archive.usesNativeLogic ? 'Challonge-Vergleich' : 'Challonge-Archiv'} · ${switch (archive.mode) {
              'single elimination' => 'Einfach-K.-o.',
              'double elimination' => 'Doppel-K.-o.',
              'round robin' => 'Jeder gegen jeden',
              'swiss' => 'Schweizer System',
              _ => archive.mode,
            }}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text('Originalergebnisse und Platzierungen aus Challonge.'),
          if (saving) const LinearProgressIndicator(),
          if (archive.url.isNotEmpty) SelectableText(archive.url),
          const SizedBox(height: 16),
          if (archive.nativeValidation != null) ...[
            Text(
              'Prüfung mit eigener Turnierlogik',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              archive.nativeValidation!['status'] == 'matched'
                  ? 'Die berechneten Platzierungen und das Weiterkommen stimmen mit den verfügbaren Challonge-Daten überein.'
                  : 'Abweichungen zu Challonge wurden festgestellt:',
            ),
            for (final issue
                in archive.nativeValidation!['issues'] as List? ?? const [])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('$issue'),
              ),
            const Text(
              'Historische Paarungen und K.-o.-Startplätze werden übernommen; die Auslosung wird damit nicht geprüft.',
            ),
            const SizedBox(height: 16),
          ],
          Text('Platzierungen', style: Theme.of(context).textTheme.titleLarge),
          for (final p in ranks)
            ListTile(
              title: Text('${p['finalRank'] ?? '–'}. ${p['name']}'),
              subtitle: Text(
                [
                  if (p['finalRank'] == null)
                    'Keine Gesamtplatzierung von Challonge geliefert',
                  for (final group in p['groupPlacements'] as List? ?? const [])
                    '${group['group']}: Platz ${group['rank']}',
                ].join('\n'),
              ),
            ),
          Text(
            'Spiele (${archive.matches.length})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (final m in archive.matches)
            ListTile(
              title: Text(
                '${players['${m['player1_id']}'] ?? 'Freilos / offen'} – ${players['${m['player2_id']}'] ?? 'Freilos / offen'}',
              ),
              subtitle: Text(
                '${m['group_id'] == null ? '' : '${m['group_id']} · '}Runde ${m['round'] ?? '–'} · ${m['scores_csv'] == null || m['scores_csv'] == '' ? 'Kein Spielstand' : m['scores_csv']}\nSieger: ${players['${m['winner_id']}'] ?? 'Keiner angegeben'}',
              ),
              trailing: IconButton(
                tooltip: 'Bestleistungen erfassen oder bearbeiten',
                onPressed: saving ? null : () => editBestPerformances(m),
                icon: const Icon(Icons.military_tech_outlined),
              ),
            ),
          if (!archive.usesNativeLogic)
            const ExpansionTile(
              title: Text('Hinweise zum Import'),
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Einzelne ganzzahlige Spielstände werden als Legs in die Statistik übernommen. Mehrteilige Ergebnisse und kampflose Siege bleiben im Archiv sichtbar. Der historische Turnierbaum wird nicht neu berechnet.',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ArchivePerformanceDialog extends StatefulWidget {
  const _ArchivePerformanceDialog({required this.match, required this.initial});
  final GroupMatch match;
  final List<BestPerformance> initial;
  @override
  State<_ArchivePerformanceDialog> createState() => _ArchivePerformanceDialogState();
}

class _ArchivePerformanceDialogState extends State<_ArchivePerformanceDialog> {
  late List<BestPerformance> items = [...widget.initial];
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Bestleistungen erfassen'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: BestPerformanceEditor(
          match: widget.match,
          initial: items,
          onChanged: (value) => items = value,
        ),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
      FilledButton(onPressed: () => Navigator.pop(context, items), child: const Text('Speichern')),
    ],
  );
}
