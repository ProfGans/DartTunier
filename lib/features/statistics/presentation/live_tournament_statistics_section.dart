import 'package:flutter/material.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../../../shared/widgets/sport_metric_grid.dart';
import '../../../shared/widgets/sport_settings_section.dart';
import '../../tournaments/domain/tournament_models.dart';
import '../../tournaments/application/tournament_timing.dart';
import '../domain/tournament_player_statistics.dart';
import '../domain/match_scorer_summary.dart';
import 'tournament_highlights_page.dart';
import 'widgets/tournament_player_summary_card.dart';

/// Rebuilt from current results so edits and removed results are reflected.
class LiveTournamentStatisticsSection extends StatefulWidget {
  const LiveTournamentStatisticsSection({super.key, required this.tournament});
  final CreatedTournament tournament;
  @override
  State<LiveTournamentStatisticsSection> createState() =>
      _LiveTournamentStatisticsSectionState();
}

class _LiveTournamentStatisticsSectionState
    extends State<LiveTournamentStatisticsSection>
    with AutomaticKeepAliveClientMixin {
  int _section = 0, _sort = 0;
  String _query = '';
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final rows = const TournamentStatisticsCalculator().calculate([
      widget.tournament,
    ]);
    final highlights = TournamentScorerHighlights(
      TournamentTiming.matches(widget.tournament),
    );
    final visible =
        rows.where((r) => r.name.toLowerCase().contains(_query)).toList()
          ..sort((a, b) {
            final order = switch (_sort) {
              1 => (b.average ?? -1).compareTo(a.average ?? -1),
              2 => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              _ => b.wins.compareTo(a.wins),
            };
            return order != 0 ? order : a.name.compareTo(b.name);
          });
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Turnierstatistik',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Text('Aktueller Stand über alle Etappen'),
            const SizedBox(height: 16),
            SportMetricGrid(
              metrics: [
                SportMetric(
                  'Ergebnisse',
                  '${highlights.completed}',
                  Icons.check_circle_outline,
                ),
                SportMetric('Spieler', '${rows.length}', Icons.groups_outlined),
                SportMetric(
                  'Scorer-Spiele',
                  '${highlights.recorded}',
                  Icons.analytics_outlined,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Spielerstatistiken'),
                  selected: _section == 0,
                  padding: const EdgeInsets.all(12),
                  onSelected: (_) => setState(() => _section = 0),
                ),
                ChoiceChip(
                  label: const Text('Highlights'),
                  selected: _section == 1,
                  padding: const EdgeInsets.all(12),
                  onSelected: (_) => setState(() => _section = 1),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_section == 1)
              TournamentHighlightsSection(
                tournament: widget.tournament,
                showPlayers: false,
              )
            else ...[
              if (rows.isEmpty)
                const Text(
                  'Noch keine abgeschlossenen Spiele mit menschlichen Teilnehmern.',
                )
              else ...[
                AdaptiveTileLayout(
                  minTileWidth: 360,
                  children: [
                    TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        labelText: 'Spieler suchen',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()),
                    ),
                    DropdownButtonFormField<int>(
                      key: ValueKey(_sort),
                      initialValue: _sort,
                      isExpanded: true,
                      itemHeight: null,
                      decoration: const InputDecoration(
                        labelText: 'Sortierung',
                      ),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Siege')),
                        DropdownMenuItem(value: 1, child: Text('Average')),
                        DropdownMenuItem(value: 2, child: Text('Name')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _sort = value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (visible.isEmpty) const Text('Keine passenden Spieler.'),
                AdaptiveTileLayout(
                  minTileWidth: 360,
                  children: [
                    for (final row in visible)
                      TournamentPlayerSummaryCard(row: row),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 16),
            const SportSettingsSection(
              title: 'Datenbasis',
              summary: 'Welche Ergebnisse und Aufnahmen zählen?',
              icon: Icons.info_outline,
              children: [
                Text(
                  'Abgeschlossene Spiele und Ergebniskorrekturen werden berücksichtigt. Average, 180er und Checkoutquote benötigen übertragene Scorer-Aufnahmen. Bots erhalten keine Spielerstatistiken.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
