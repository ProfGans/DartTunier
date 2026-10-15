import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../application/ranking_year_review_image_generator.dart';
import 'package:flutter/services.dart';

import '../../../shared/widgets/adaptive_content.dart';
import '../domain/local_elo_calculator.dart';
import '../../tournaments/data/app_database.dart';
import '../../tournaments/data/tournament_storage.dart';
import '../../tournaments/domain/tournament_models.dart';
import '../application/local_ranking_elo_service.dart';
import '../application/local_ranking_series_service.dart';
import '../application/ranking_year_review_service.dart';
import '../domain/local_ranking.dart';

import '../../statistics/domain/best_performance.dart';
import '../../statistics/domain/local_statistics.dart';
import '../../statistics/presentation/local_player_statistics_page.dart';

class RankingsPage extends StatefulWidget {
  const RankingsPage({super.key, LocalAppDatabase? database})
    : _database = database;

  final LocalAppDatabase? _database;

  @override
  State<RankingsPage> createState() => _RankingsPageState();
}

enum _YearReviewMode { ranking, player }

class RankingYearReviewPage extends StatefulWidget {
  const RankingYearReviewPage({super.key});
  @override
  State<RankingYearReviewPage> createState() => _RankingYearReviewPageState();
}

class _RankingYearReviewPageState extends State<RankingYearReviewPage> {
  final _database = LocalAppDatabase();
  late final Future<List<LocalRanking>> _rankings = _database.loadLocalRankings();
  late final Future<List<PlayerProfile>> _players = _database.loadPlayerProfiles();
  _YearReviewMode _mode = _YearReviewMode.ranking;
  LocalRanking? _selectedRanking;
  PlayerProfile? _selectedPlayer;
  int _year = DateTime.now().year;
  Future<RankingYearReview>? _rankingReview;
  Future<LocalPlayerStatistics>? _playerReview;
  bool _exporting = false;

  void _selectRanking(LocalRanking? ranking) {
    setState(() {
      _selectedRanking = ranking;
      _rankingReview = ranking == null ? null : const RankingYearReviewService().calculate(ranking, _year);
    });
  }

  void _selectPlayer(PlayerProfile? player) {
    setState(() {
      _selectedPlayer = player;
      _playerReview = player == null ? null : const LocalStatisticsService().forPlayers({player.id}, year: _year);
    });
  }

  void _setYear(int year) {
    setState(() {
      _year = year;
      if (_selectedRanking != null) {
        _rankingReview = const RankingYearReviewService().calculate(_selectedRanking!, year);
      }
      if (_selectedPlayer != null) {
        _playerReview = const LocalStatisticsService().forPlayers({_selectedPlayer!.id}, year: year);
      }
    });
  }

  Future<void> _exportReview(LocalRanking ranking, RankingYearReview review) async {
    setState(() => _exporting = true);
    try {
      const generator = RankingYearReviewImageGenerator();
      final pngBytes = await generator.generatePng(ranking: ranking, review: review);
      final cleanName = ranking.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final fileName = 'ranglisten-rueckblick-$cleanName-${review.year}.png';

      if (kIsWeb) {
        final uri = Uri.dataFromBytes(pngBytes, mimeType: 'image/png');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      } else if (Platform.isAndroid) {
        try {
          final saved = await const MethodChannel(
            'dartturnier/backups',
          ).invokeMethod<bool>('export', {
            'bytes': pngBytes,
            'fileName': fileName,
            'mimeType': 'image/png',
          });
          if (saved == false) return;
        } catch (_) {
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/$fileName');
          await file.writeAsBytes(pngBytes, flush: true);
          final uri = Uri.file(file.path);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        }
      } else {
        final location = await getSaveLocation(
          suggestedName: fileName,
          acceptedTypeGroups: [
            const XTypeGroup(label: 'PNG-Grafik', extensions: ['png']),
          ],
        );
        if (location == null) return;
        await File(location.path).writeAsBytes(pngBytes, flush: true);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Jahresrückblick erfolgreich als Grafik exportiert.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Grafikexport fehlgeschlagen: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = List<int>.generate(currentYear - 1999, (index) => currentYear - index);

    return Scaffold(
      appBar: AppBar(title: const Text('Jahresrückblick')),
      body: FutureBuilder<(List<LocalRanking>, List<PlayerProfile>)>(
        future: Future.wait([_rankings, _players]).then(
          (res) => (res[0] as List<LocalRanking>, res[1] as List<PlayerProfile>),
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final (rankings, players) = snapshot.data!;

          return AdaptiveContentList(
            children: [
              Center(
                child: SegmentedButton<_YearReviewMode>(
                  segments: const [
                    ButtonSegment(
                      value: _YearReviewMode.ranking,
                      label: Text('Nach Rangliste'),
                      icon: Icon(Icons.leaderboard_outlined),
                    ),
                    ButtonSegment(
                      value: _YearReviewMode.player,
                      label: Text('Nach Spieler'),
                      icon: Icon(Icons.person_outline),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (set) {
                    setState(() => _mode = set.first);
                  },
                ),
              ),
              const SizedBox(height: 24),
              if (_mode == _YearReviewMode.ranking) ...[
                Text('Rückblick nach Rangliste', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 14),
                DropdownButtonFormField<LocalRanking>(
                  initialValue: _selectedRanking,
                  decoration: const InputDecoration(
                    labelText: 'Rangliste auswählen',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.emoji_events_outlined),
                  ),
                  items: [
                    for (final ranking in rankings)
                      DropdownMenuItem(value: ranking, child: Text(ranking.name)),
                  ],
                  onChanged: _selectRanking,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _year,
                  menuMaxHeight: 320,
                  decoration: const InputDecoration(
                    labelText: 'Jahr',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  items: [for (final year in years) DropdownMenuItem(value: year, child: Text('$year'))],
                  onChanged: (value) { if (value != null) _setYear(value); },
                ),
                if (rankings.isEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Lege zuerst eine Rangliste an und weise Spieler zu.'),
                ],
                if (_rankingReview != null && _selectedRanking != null) ...[
                  const SizedBox(height: 16),
                  FutureBuilder<RankingYearReview>(
                    future: _rankingReview,
                    builder: (context, data) {
                      if (!data.hasData) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
                      final review = data.data!;
                      final rows = review.players.entries.toList();
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const SizedBox(height: 8),
                        Text(
                          '${review.tournaments} Turniere · ${review.totalLegs} Legs · ${review.totalBestPerformances} Bestleistungen · ${review.total180} × 180+ · ${review.total170} × 170+ · ${review.totalShortLegs} Shortlegs · ${review.totalHighFinishes} High Finishes',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: _exporting ? null : () => _exportReview(_selectedRanking!, review),
                            icon: _exporting
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.image_outlined),
                            label: Text(_exporting ? 'Grafik wird exportiert…' : 'Rückblick als Grafik exportieren'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('Turniere pro Monat', style: Theme.of(context).textTheme.titleLarge),
                        for (var i = 0; i < 12; i++)
                          _MonthBar(
                            month: i + 1,
                            count: review.monthlyTournaments[i],
                            max: review.monthlyTournaments.fold<int>(0, (a, b) => a > b ? a : b),
                          ),
                        const SizedBox(height: 16),
                        _ReviewLeaders(title: 'Meiste Teilnahmen', rows: rows, metric: (s) => s.participations),
                        _ReviewLeaders(title: 'Meiste Turniersiege', rows: rows, metric: (s) => s.tournamentWins),
                        _ReviewLeaders(title: 'Meiste gewonnene Legs', rows: rows, metric: (s) => s.legsWon),
                        _ReviewLeaders(title: 'Meiste verlorene Legs', rows: rows, metric: (s) => s.legsLost),
                        _ReviewLeaders(title: 'Meiste Bestleistungen', rows: rows, metric: (s) => s.bestPerformances),
                        _ReviewLeaders(title: 'Meiste 180+', rows: rows, metric: (s) => s.scores180),
                        _ReviewLeaders(title: 'Meiste 170+', rows: rows, metric: (s) => s.scores170),
                        _ReviewLeaders(title: 'Meiste Shortlegs', rows: rows, metric: (s) => s.shortLegs),
                        _ReviewLeaders(title: 'Meiste High Finishes', rows: rows, metric: (s) => s.highFinishes),
                      ]);
                    },
                  ),
                ],
              ] else ...[
                Text('Rückblick nach Spieler', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 14),
                DropdownButtonFormField<PlayerProfile>(
                  initialValue: _selectedPlayer,
                  decoration: const InputDecoration(
                    labelText: 'Spieler auswählen',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_search_outlined),
                  ),
                  items: [
                    for (final player in players)
                      DropdownMenuItem(value: player, child: Text(player.displayName)),
                  ],
                  onChanged: _selectPlayer,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _year,
                  menuMaxHeight: 320,
                  decoration: const InputDecoration(
                    labelText: 'Jahr',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  items: [for (final year in years) DropdownMenuItem(value: year, child: Text('$year'))],
                  onChanged: (value) { if (value != null) _setYear(value); },
                ),
                if (players.isEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Noch keine Spielerprofile vorhanden.'),
                ],
                if (_playerReview != null && _selectedPlayer != null) ...[
                  const SizedBox(height: 20),
                  FutureBuilder<LocalPlayerStatistics>(
                    future: _playerReview,
                    builder: (context, data) {
                      if (!data.hasData) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
                      final stats = data.data!;
                      final p = _selectedPlayer!;
                      final performanceCounts = {
                        for (final type in BestPerformanceType.values)
                          type: stats.bestPerformances.where((item) => item.type == type).length,
                      };
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${p.displayName} · $_year', style: Theme.of(context).textTheme.titleLarge),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.open_in_new),
                                label: const Text('Profil öffnen'),
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => LocalPlayerStatisticsPage(
                                      name: p.displayName,
                                      profileIds: {p.id},
                                      year: _year,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _StatMiniCard(label: 'Turniere in $_year', value: '${stats.tournaments}'),
                              _StatMiniCard(label: 'Spiele', value: '${stats.matches}'),
                              _StatMiniCard(label: 'Siege / Niederlagen', value: '${stats.wins} / ${stats.losses}'),
                              _StatMiniCard(label: 'Siegquote', value: '${stats.matchWinRate.toStringAsFixed(1)} %'),
                              _StatMiniCard(label: 'Legs (gew./verl.)', value: '${stats.legsWon} / ${stats.legsLost}'),
                              _StatMiniCard(label: 'Leg-Siegquote', value: '${stats.legWinRate.toStringAsFixed(1)} %'),
                              _StatMiniCard(label: '180+ Aufnahmen', value: '${performanceCounts[BestPerformanceType.score180]}'),
                              _StatMiniCard(label: 'High Finishes (100+)', value: '${performanceCounts[BestPerformanceType.highFinish]}'),
                              _StatMiniCard(label: 'Shortlegs (≤18)', value: '${performanceCounts[BestPerformanceType.shortLeg]}'),
                            ],
                          ),
                          if (stats.bestPerformances.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Text('Bestleistungen in $_year (${stats.bestPerformances.length})', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            for (final item in stats.bestPerformances)
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.star_outline, size: 20),
                                title: Text('${item.label}${item.value == null ? '' : ' (${item.value})'}'),
                              ),
                          ],
                          if (stats.tournaments == 0 && stats.matches == 0) ...[
                            const SizedBox(height: 16),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text('Keine Turnierspiele oder Bestleistungen für ${p.displayName} im Jahr $_year erfasst.'),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StatMiniCard extends StatelessWidget {
  const _StatMiniCard({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 180,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}

class _ReviewLeaders extends StatelessWidget {
  const _ReviewLeaders({required this.title, required this.rows, required this.metric});
  final String title;
  final List<MapEntry<String, RankingYearPlayerStats>> rows;
  final int Function(RankingYearPlayerStats) metric;
  @override
  Widget build(BuildContext context) {
    final ranked = rows.where((r) => metric(r.value) > 0).toList()..sort((a, b) => metric(b.value).compareTo(metric(a.value)));
    return ExpansionTile(title: Text(title), subtitle: Text(ranked.isEmpty ? 'Keine Daten' : '${ranked.first.key} · ${metric(ranked.first.value)}'), children: [
      for (final row in ranked.take(5)) ListTile(title: Text(row.key), trailing: Text('${metric(row.value)}')),
    ]);
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({required this.month, required this.count, required this.max});
  final int month, count, max;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [SizedBox(width: 38, child: Text('$month.')), Expanded(child: LinearProgressIndicator(value: max == 0 ? 0 : count / max, minHeight: 12)), const SizedBox(width: 12), SizedBox(width: 28, child: Text('$count'))]),
  );
}

class _RankingsPageState extends State<RankingsPage> {
  late final LocalAppDatabase _database = widget._database ?? LocalAppDatabase();
  late Future<List<LocalRanking>> _rankings = _database.loadLocalRankings();
  bool _saving = false;

  Future<void> _create() async {
    final ranking = await showDialog<LocalRanking>(
      context: context,
      builder: (_) => const _RankingEditorDialog(),
    );
    if (ranking == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await _database.saveLocalRanking(ranking);
      if (mounted) setState(() => _rankings = _database.loadLocalRankings());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rangliste konnte nicht gespeichert werden: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit(LocalRanking ranking) async {
    final updated = await showDialog<LocalRanking>(context: context, builder: (_) => _RankingEditorDialog(initial: ranking));
    if (updated == null) return;
    await _database.saveLocalRanking(updated);
    if (mounted) setState(() => _rankings = _database.loadLocalRankings());
  }

  Future<void> _assignTournaments(LocalRanking ranking) async {
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => _RankingTournamentsPage(ranking: ranking)));
  }

  Future<void> _assignPlayers(LocalRanking ranking) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _RankingPlayersPage(
          database: _database,
          ranking: ranking,
        ),
      ),
    );
    if (saved == true && mounted) {
      setState(() => _rankings = _database.loadLocalRankings());
    }
  }

  Future<void> _openRanking(LocalRanking ranking) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ranking.type == RankingType.elo
            ? LocalRankingStandingsPage(database: _database, ranking: ranking)
            : LocalRankingSeriesStandingsPage(database: _database, ranking: ranking),
      ),
    );
  }

  Future<void> _delete(LocalRanking ranking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rangliste löschen?'),
        content: Text('„${ranking.name}“ und ihre Spielerzuweisungen werden gelöscht.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _database.deleteLocalRanking(ranking.id);
    if (mounted) setState(() => _rankings = _database.loadLocalRankings());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ranglisten')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _saving ? null : _create,
      icon: const Icon(Icons.add),
      label: const Text('Rangliste erstellen'),
    ),
    body: SafeArea(
      child: FutureBuilder<List<LocalRanking>>(
        future: _rankings,
        builder: (context, snapshot) => AdaptiveContentList(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
          children: [
            Text('Ranglisten verwalten', style: Theme.of(context).textTheme.headlineSmall),
            const Text('Ranglisten werden lokal geführt und im konto-bezogenen Supabase-Datenstand gesichert.'),
            if (snapshot.connectionState == ConnectionState.waiting)
              const LinearProgressIndicator(),
            if (snapshot.hasError)
              const Text('Ranglisten konnten nicht geladen werden.'),
            if (snapshot.hasData && snapshot.data!.isEmpty)
              const Card(child: ListTile(title: Text('Noch keine Ranglisten angelegt.'))),
            for (final ranking in snapshot.data ?? const <LocalRanking>[])
              Card(
                child: ListTile(
                  leading: Icon(ranking.type == RankingType.elo
                      ? Icons.trending_up
                      : Icons.emoji_events_outlined),
                  title: Text(ranking.name),
                  subtitle: Text(ranking.type == RankingType.elo
                      ? 'Klassische Elo-Wertung · Start ${ranking.startRating}'
                      : 'Turnierserie · Teilnahme, Sets, Platzierungen und Bestleistungen'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Fix 4.2: Einstellungen direkt zugänglich (statt nur im Menü)
                      IconButton(
                        tooltip: 'Einstellungen',
                        icon: const Icon(Icons.settings_outlined),
                        onPressed: () => _edit(ranking),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Weitere Aktionen',
                        onSelected: (value) {
                          if (value == 'players') _assignPlayers(ranking);
                          if (value == 'tournaments') _assignTournaments(ranking);
                          if (value == 'table') _openRanking(ranking);
                          if (value == 'delete') _delete(ranking);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'players', child: Text('Spieler zuweisen')),
                          PopupMenuItem(value: 'tournaments', child: Text('Turniere zuweisen')),
                          PopupMenuItem(value: 'table', child: Text('Ranglistenstand öffnen')),
                          PopupMenuItem(value: 'delete', child: Text('Rangliste löschen')),
                        ],
                      ),
                    ],
                  ),
                  onTap: () => _openRanking(ranking),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _RankingEditorDialog extends StatefulWidget {
  const _RankingEditorDialog({this.initial});
  final LocalRanking? initial;

  @override
  State<_RankingEditorDialog> createState() => _RankingEditorDialogState();
}

class _RankingEditorDialogState extends State<_RankingEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  RankingType _type = RankingType.elo;
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _dateError;
  final Map<String, TextEditingController> _numbers = {
    'Startwertung': TextEditingController(text: '1000'),
    'K-Faktor Neu': TextEditingController(text: '25'),
    'K-Faktor Normal': TextEditingController(text: '15'),
    'K-Faktor Pro': TextEditingController(text: '10'),
    'Spiele bis Normal': TextEditingController(text: '10'),
    'Pro-Spieler ab Wertung': TextEditingController(text: '2400'),
    'Punkte Teilnahme': TextEditingController(text: '1'),
    'Punkte je gewonnenem Set': TextEditingController(text: '1'),
    'Punkte Platz 1': TextEditingController(text: '10'),
    'Punkte Platz 2': TextEditingController(text: '6'),
    'Punkte Platz 3': TextEditingController(text: '3'),
    'Punkte je Bestleistung': TextEditingController(text: '1'),
  };

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial == null) return;
    _name.text = initial.name;
    _type = initial.type;
    _fromDate = initial.validFromDate ?? (initial.validFromYear == null ? null : DateTime(initial.validFromYear!, 1, 1));
    _toDate = initial.validToDate ?? (initial.validToYear == null ? null : DateTime(initial.validToYear!, 12, 31));
    for (final entry in _numbers.entries) {
      final values = <String, int>{
        'Startwertung': initial.startRating, 'K-Faktor Neu': initial.newPlayerK,
        'K-Faktor Normal': initial.normalPlayerK, 'K-Faktor Pro': initial.proPlayerK,
        'Spiele bis Normal': initial.matchesBeforeNormal, 'Pro-Spieler ab Wertung': initial.proRatingThreshold,
        'Punkte Teilnahme': initial.participationPoints, 'Punkte je gewonnenem Set': initial.setWinPoints,
        'Punkte Platz 1': initial.firstPlacePoints, 'Punkte Platz 2': initial.secondPlacePoints,
        'Punkte Platz 3': initial.thirdPlacePoints, 'Punkte je Bestleistung': initial.bestPerformancePoints,
      };
      entry.value.text = '${values[entry.key]}';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    for (final controller in _numbers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int _value(String label) => int.tryParse(_numbers[label]!.text.trim()) ?? 0;

  Future<void> _pickDate({required bool start}) async {
    final current = start ? _fromDate : _toDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(1980),
      lastDate: DateTime(2100),
      helpText: start ? 'Gültig ab Datum' : 'Gültig bis Datum',
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _fromDate = picked;
      } else {
        _toDate = picked;
      }
      if (_fromDate != null && _toDate != null && _toDate!.isBefore(_fromDate!)) {
        _dateError = 'Das Enddatum darf nicht vor dem Startdatum liegen.';
      } else {
        _dateError = null;
      }
    });
  }

  void _submit() {
    setState(() {
      if (_fromDate != null && _toDate != null && _toDate!.isBefore(_fromDate!)) {
        _dateError = 'Das Enddatum darf nicht vor dem Startdatum liegen.';
      } else {
        _dateError = null;
      }
    });
    if (!_formKey.currentState!.validate() || _dateError != null) return;

    Navigator.pop(context, LocalRanking(
      id: widget.initial?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      type: _type,
      startRating: _value('Startwertung'),
      newPlayerK: _value('K-Faktor Neu'),
      normalPlayerK: _value('K-Faktor Normal'),
      proPlayerK: _value('K-Faktor Pro'),
      matchesBeforeNormal: _value('Spiele bis Normal'),
      proRatingThreshold: _value('Pro-Spieler ab Wertung'),
      participationPoints: _value('Punkte Teilnahme'),
      setWinPoints: _value('Punkte je gewonnenem Set'),
      firstPlacePoints: _value('Punkte Platz 1'),
      secondPlacePoints: _value('Punkte Platz 2'),
      thirdPlacePoints: _value('Punkte Platz 3'),
      bestPerformancePoints: _value('Punkte je Bestleistung'),
      validFromYear: _fromDate?.year,
      validToYear: _toDate?.year,
      validFromDate: _fromDate,
      validToDate: _toDate,
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? 'Rangliste erstellen' : 'Rangliste bearbeiten'),
    scrollable: true,
    content: SizedBox(
      width: 480,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_dateError != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _dateError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            TextFormField(
              controller: _name,
              autofocus: widget.initial == null,
              maxLength: 80,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              decoration: const InputDecoration(
                labelText: 'Name der Rangliste',
                hintText: 'z. B. DC Unzenberg 2026',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value ?? '').trim().isEmpty ? 'Bitte einen Namen eingeben.' : null,
            ),
            const SizedBox(height: 20),
            Text(
              'Gültigkeitszeitraum (optional)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Ohne Angabe gelten alle Turniere.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickDate(start: true),
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(_fromDate == null
                      ? 'Startdatum wählen'
                      : 'Ab ${_fromDate!.day.toString().padLeft(2, '0')}.${_fromDate!.month.toString().padLeft(2, '0')}.${_fromDate!.year}'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickDate(start: false),
                  icon: const Icon(Icons.event, size: 18),
                  label: Text(_toDate == null
                      ? 'Enddatum wählen'
                      : 'Bis ${_toDate!.day.toString().padLeft(2, '0')}.${_toDate!.month.toString().padLeft(2, '0')}.${_toDate!.year}'),
                ),
                if (_fromDate != null || _toDate != null)
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _fromDate = null;
                      _toDate = null;
                      _dateError = null;
                    }),
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Zurücksetzen'),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Wertungsmodus',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<RankingType>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Typ',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: RankingType.elo, child: Text('Klassische Elo-Rangliste')),
                DropdownMenuItem(value: RankingType.series, child: Text('Turnierserie mit Punkten')),
              ],
              onChanged: (value) => setState(() => _type = value ?? RankingType.elo),
            ),
            const SizedBox(height: 20),
            Text(
              _type == RankingType.elo ? 'Elo-Parameter' : 'Punkte-Parameter',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            for (final entry in _numbers.entries)
              if (_type == RankingType.elo
                  ? entry.key.startsWith('Start') || entry.key.startsWith('K-Faktor') || entry.key.startsWith('Spiele') || entry.key.startsWith('Pro-Spieler')
                  : entry.key.startsWith('Punkte'))
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TextFormField(
                    controller: entry.value,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: entry.key,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (value) => int.tryParse((value ?? '').trim()) == null ? 'Bitte eine ganze Zahl eingeben.' : null,
                  ),
                ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
      FilledButton(onPressed: _submit, child: Text(widget.initial == null ? 'Rangliste erstellen' : 'Speichern')),
    ],
  );
}

class _RankingTournamentsPage extends StatefulWidget {
  const _RankingTournamentsPage({required this.ranking});
  final LocalRanking ranking;
  @override
  State<_RankingTournamentsPage> createState() => _RankingTournamentsPageState();
}

class _RankingTournamentsPageState extends State<_RankingTournamentsPage> {
  final _storage = TournamentStorage();
  // ignore: prefer_final_fields
  late final Future<List<CreatedTournament>> _future = _storage.loadTournaments();
  final Set<String> _selected = {};
  bool _ready = false, _saving = false;

  Future<void> _save(List<CreatedTournament> tournaments) async {
    setState(() => _saving = true);
    try {
      for (final tournament in tournaments) {
        final ids = tournament.rankingIds.toSet();
        if (_selected.contains(tournament.id)) { ids.add(widget.ranking.id); } else { ids.remove(widget.ranking.id); }
        await _storage.saveTournament(CreatedTournament.fromJson({
          ...tournament.toJson(),
          'countsForRanking': ids.isNotEmpty,
          'rankingIds': ids.toList(),
        }));
      }
      if (mounted) Navigator.pop(context);
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Turniere · ${widget.ranking.name}'), actions: [
      TextButton.icon(onPressed: _saving ? null : () async { final data = await _future; if (mounted) _save(data); }, icon: const Icon(Icons.save_outlined), label: const Text('Speichern')),
    ]),
    body: FutureBuilder<List<CreatedTournament>>(future: _future, builder: (context, snapshot) {
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final tournaments = snapshot.data!;
      if (!_ready) { for (final t in tournaments) { if (t.countsForRanking && t.rankingIds.contains(widget.ranking.id)) _selected.add(t.id); } _ready = true; }
      return AdaptiveContentList(children: [
        Text('Ranglistenturniere zuweisen', style: Theme.of(context).textTheme.headlineSmall),
        const Text('Bei Elo zählen nur Begegnungen, bei denen beide zugewiesenen Spieler Mitglieder dieser Rangliste sind.'),
        if (tournaments.isEmpty) const Text('Noch keine Turniere vorhanden.'),
        for (final tournament in tournaments) CheckboxListTile(
          value: _selected.contains(tournament.id),
          title: Text(tournament.name),
          subtitle: Text((tournament.finishedAt ?? tournament.createdAt).toLocal().toString().split(' ').first),
          onChanged: (checked) => setState(() { checked == true ? _selected.add(tournament.id) : _selected.remove(tournament.id); }),
        ),
      ]);
    }),
  );
}

class _RankingPlayersPage extends StatefulWidget {
  const _RankingPlayersPage({required this.database, required this.ranking});
  final LocalAppDatabase database;
  final LocalRanking ranking;

  @override
  State<_RankingPlayersPage> createState() => _RankingPlayersPageState();
}

class _RankingPlayersPageState extends State<_RankingPlayersPage> {
  // ignore: prefer_final_fields
  late Future<(List<PlayerProfile>, List<String>)> _load = _loadData();
  final Set<String> _selected = {};
  bool _initialized = false;
  bool _saving = false;

  Future<(List<PlayerProfile>, List<String>)> _loadData() async => (
    await widget.database.loadPlayerProfiles(),
    await widget.database.loadRankingPlayerIds(widget.ranking.id),
  );

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.database.setRankingPlayers(widget.ranking.id, _selected);
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.ranking.name),
      actions: [
        TextButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Speichern'),
        ),
      ],
    ),
    body: FutureBuilder<(List<PlayerProfile>, List<String>)>(
      future: _load,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final (players, assigned) = snapshot.data!;
        if (!_initialized) {
          _selected.addAll(assigned);
          _initialized = true;
        }
        return AdaptiveContentList(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Spieler zuweisen', style: Theme.of(context).textTheme.headlineSmall),
            const Text('Nur zugewiesene Spieler zählen in dieser Rangliste. Bei Elo werden Begegnungen nur gewertet, wenn beide Spieler Mitglied sind.'),
            if (players.isEmpty) const Card(child: ListTile(title: Text('Lege zuerst Spieler im Hauptmenü an.'))),
            for (final player in players)
              CheckboxListTile(
                value: _selected.contains(player.id),
                title: Text(player.displayName),
                onChanged: (checked) => setState(() {
                  if (checked == true) {
                    _selected.add(player.id);
                  } else {
                    _selected.remove(player.id);
                  }
                }),
              ),
          ],
        );
      },
    ),
  );
}

class LocalRankingStandingsPage extends StatefulWidget {
  const LocalRankingStandingsPage({
    super.key,
    required this.database,
    required this.ranking,
  });

  final LocalAppDatabase database;
  final LocalRanking ranking;

  @override
  State<LocalRankingStandingsPage> createState() =>
      _LocalRankingStandingsPageState();
}

class _LocalRankingStandingsPageState extends State<LocalRankingStandingsPage> {
  late Future<LocalEloSnapshot> _snapshot = _calculate();

  Future<LocalEloSnapshot> _calculate() =>
      LocalRankingEloService(database: widget.database).calculate(widget.ranking);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.ranking.name),
      actions: [
        IconButton(
          tooltip: 'Rangliste aktualisieren',
          onPressed: () => setState(() => _snapshot = _calculate()),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<LocalEloSnapshot>(
      future: _snapshot,
      builder: (context, snapshot) => AdaptiveContentList(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Aktueller Stand', style: Theme.of(context).textTheme.headlineSmall),
          if (snapshot.connectionState == ConnectionState.waiting)
            const LinearProgressIndicator(),
          if (snapshot.hasError)
            Text('Ranglistenstand konnte nicht berechnet werden: ${snapshot.error}'),
          if (snapshot.data case final entries?) ...[
            const Text('Elo wird chronologisch aus abgeschlossenen Turnierspielen berechnet. Nur zugewiesene Spieler und für diese Rangliste markierte Turniere zählen.'),
            for (var i = 0; i < entries.entries.length; i++)
              Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text(entries.entries[i].name),
                  subtitle: Text('${entries.entries[i].matches} gewertete Matches · ${entries.entries[i].wins} Siege · ${entries.entries[i].losses} Niederlagen'),
                  trailing: Text('${entries.entries[i].rating} Elo', style: Theme.of(context).textTheme.titleMedium),
                ),
              ),
            if (entries.entries.isEmpty)
              const Card(child: ListTile(title: Text('Noch keine gewerteten Ergebnisse.'), subtitle: Text('Spieler zuweisen und ein Turnier für diese Rangliste markieren.'))),
          ],
        ],
      ),
    ),
  );
}

class LocalRankingSeriesStandingsPage extends StatefulWidget {
  const LocalRankingSeriesStandingsPage({
    super.key,
    required this.database,
    required this.ranking,
  });

  final LocalAppDatabase database;
  final LocalRanking ranking;

  @override
  State<LocalRankingSeriesStandingsPage> createState() =>
      _LocalRankingSeriesStandingsPageState();
}

class _LocalRankingSeriesStandingsPageState
    extends State<LocalRankingSeriesStandingsPage> {
  late Future<List<LocalSeriesEntry>> _entries = _calculate();

  Future<List<LocalSeriesEntry>> _calculate() =>
      LocalRankingSeriesService(database: widget.database).calculate(widget.ranking);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.ranking.name),
      actions: [
        IconButton(
          tooltip: 'Rangliste aktualisieren',
          onPressed: () => setState(() => _entries = _calculate()),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<LocalSeriesEntry>>(
      future: _entries,
      builder: (context, snapshot) => AdaptiveContentList(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Serienwertung', style: Theme.of(context).textTheme.headlineSmall),
          Text('Teilnahme: ${widget.ranking.participationPoints} P. · gewonnenes Set: ${widget.ranking.setWinPoints} P. · Platz 1/2/3: ${widget.ranking.firstPlacePoints}/${widget.ranking.secondPlacePoints}/${widget.ranking.thirdPlacePoints} P.'),
          if (snapshot.connectionState == ConnectionState.waiting)
            const LinearProgressIndicator(),
          if (snapshot.hasError)
            Text('Serienwertung konnte nicht berechnet werden: ${snapshot.error}'),
          if (snapshot.hasData) ...[
            const Text('Erfasste Bestleistungen zählen mit den eingestellten Punkten zur Serienwertung.'),
            for (var i = 0; i < snapshot.data!.length; i++)
              Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text(snapshot.data![i].player.displayName),
                  subtitle: Text('${snapshot.data![i].participations} Teilnahmen · ${snapshot.data![i].setsWon} gewonnene Sets · ${snapshot.data![i].bestPerformances} Bestleistungen · Plätze 1/2/3: ${snapshot.data![i].firstPlaces}/${snapshot.data![i].secondPlaces}/${snapshot.data![i].thirdPlaces}'),
                  trailing: Text('${snapshot.data![i].points} P.', style: Theme.of(context).textTheme.titleMedium),
                ),
              ),
          ],
        ],
      ),
    ),
  );
}
