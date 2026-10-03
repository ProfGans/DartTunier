import '../../statistics/domain/match_scorer_summary.dart';
import '../../scorer/domain/scorer_highlight_rules.dart';
import '../../statistics/domain/statistics_period.dart';
import '../../tournaments/application/tournament_timing.dart';
import '../../tournaments/domain/tournament_models.dart';

enum HighlightCategory {
  average('Turnier-Average'),
  checkout('Höchstes Checkout'),
  shortLeg('Short Legs (bis 18 Darts)'),
  maximums('Maxima im Turnier'),
  other('Sonstiges');

  const HighlightCategory(this.label);
  final String label;
}

class CommunityHighlight {
  const CommunityHighlight({
    required this.key,
    required this.category,
    required this.title,
    required this.value,
    required this.player,
    required this.tournament,
    required this.date,
    this.note = '',
    this.deleted = false,
    this.edited = false,
  });
  final String key, title, value, player, tournament, note;
  final HighlightCategory category;
  final DateTime date;
  final bool deleted, edited;
  bool get automatic => key.startsWith('auto:');
  factory CommunityHighlight.fromJson(Map<String, dynamic> row) =>
      CommunityHighlight(
        key: row['highlight_key'] as String,
        category: HighlightCategory.values.byName(row['category'] as String),
        title: row['title'] as String,
        value: row['value'] as String,
        player: row['player_name'] as String,
        tournament: row['tournament_name'] as String,
        date: DateTime.parse(row['occurred_at'] as String).toLocal(),
        note: row['note'] as String? ?? '',
        deleted: row['deleted'] as bool? ?? false,
        edited: true,
      );
  Map<String, dynamic> toJson() => {
    'highlight_key': key,
    'category': category.name,
    'title': title,
    'value': value,
    'player_name': player,
    'tournament_name': tournament,
    'occurred_at': date.toUtc().toIso8601String(),
    'note': note,
    'deleted': deleted,
  };
  CommunityHighlight removed() => CommunityHighlight(
    key: key,
    category: category,
    title: title,
    value: value,
    player: player,
    tournament: tournament,
    date: date,
    note: note,
    deleted: true,
    edited: true,
  );
}

class CommunityHighlights {
  const CommunityHighlights();
  List<CommunityHighlight> automatic(
    String communityId,
    Iterable<CreatedTournament> tournaments,
  ) {
    final result = <CommunityHighlight>[];
    final unique = {
      for (final t in tournaments)
        if (t.communityId == communityId) t.id: t,
    };
    for (final t in unique.values) {
      final rows = TournamentScorerHighlights(
        TournamentTiming.matches(t),
      ).players;
      for (final p in rows) {
        void add(HighlightCategory category, String value) => result.add(
          CommunityHighlight(
            key:
                'auto:${Uri.encodeComponent(t.id)}:${Uri.encodeComponent(p.id)}:${category.name}',
            category: category,
            title: category.label,
            value: value,
            player: p.name,
            tournament: t.name,
            date: t.finishedAt ?? t.createdAt,
            note:
                'Aus übertragenen Scorer-Daten. Datum: Turnierende, ersatzweise Turnierbeginn.',
          ),
        );
        if (p.average != null) {
          add(HighlightCategory.average, p.average!.toStringAsFixed(2));
        }
        if (p.highestFinish > 0) {
          add(HighlightCategory.checkout, '${p.highestFinish} Punkte');
        }
        if (p.shortLegs.isNotEmpty) {
          add(
            HighlightCategory.shortLeg,
            highlightCountLabel(p.shortLegs, unit: ' Darts'),
          );
        }
        if (p.maxima.isNotEmpty) {
          add(HighlightCategory.maximums, highlightCountLabel(p.maxima));
        }
      }
    }
    return result;
  }

  List<CommunityHighlight> merge(
    List<CommunityHighlight> automatic,
    List<CommunityHighlight> saved,
  ) {
    final entries = {for (final h in automatic) h.key: h};
    for (final h in saved) {
      // Do not resurrect an automatic record after its source result disappears.
      if (!h.automatic || entries.containsKey(h.key)) entries[h.key] = h;
    }
    return entries.values.where((h) => !h.deleted).toList()..sort((a, b) {
      final date = b.date.compareTo(a.date);
      return date == 0 ? a.key.compareTo(b.key) : date;
    });
  }

  List<CommunityHighlight> filter(
    List<CommunityHighlight> entries, {
    String query = '',
    HighlightCategory? category,
    String? player,
    String? tournament,
    StatisticsPeriod? period,
    bool? automatic,
  }) => entries
      .where(
        (h) =>
            (category == null || h.category == category) &&
            (player == null || h.player == player) &&
            (tournament == null || h.tournament == tournament) &&
            (period == null || period.contains(h.date)) &&
            (automatic == null || h.automatic == automatic) &&
            '${h.title} ${h.value} ${h.player} ${h.tournament} ${h.note}'
                .toLowerCase()
                .contains(query.trim().toLowerCase()),
      )
      .toList();
}
