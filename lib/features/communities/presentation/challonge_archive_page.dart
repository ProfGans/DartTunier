import 'package:flutter/material.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../../tournaments/domain/tournament_models.dart';

class ChallongeArchivePage extends StatelessWidget {
  const ChallongeArchivePage({super.key, required this.tournament});
  final CreatedTournament tournament;
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
            'Challonge-Archiv · ${switch (archive.mode) {
              'single elimination' => 'Einfach-K.-o.',
              'double elimination' => 'Doppel-K.-o.',
              'round robin' => 'Jeder gegen jeden',
              'swiss' => 'Schweizer System',
              _ => archive.mode,
            }}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text('Originalergebnisse und Platzierungen aus Challonge.'),
          if (archive.url.isNotEmpty) SelectableText(archive.url),
          const SizedBox(height: 16),
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
            ),
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
