import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/adaptive_content.dart';
import '../domain/local_elo_calculator.dart';
import '../../tournaments/data/app_database.dart';
import '../../tournaments/data/tournament_storage.dart';
import '../../tournaments/domain/tournament_models.dart';
import '../application/local_ranking_elo_service.dart';
import '../application/local_ranking_series_service.dart';
import '../application/ranking_year_review_service.dart';
import '../domain/local_ranking.dart';

class RankingsPage extends StatefulWidget {
  const RankingsPage({super.key, LocalAppDatabase? database})
    : _database = database;

  final LocalAppDatabase? _database;

  @override
  State<RankingsPage> createState() => _RankingsPageState();
}

class RankingYearReviewPage extends StatefulWidget {
  const RankingYearReviewPage({super.key});
  @override
  State<RankingYearReviewPage> createState() => _RankingYearReviewPageState();
}

class _RankingYearReviewPageState extends State<RankingYearReviewPage> {
  final _database = LocalAppDatabase();
  late Future<List<LocalRanking>> _rankings = _database.loadLocalRankings();
  LocalRanking? _selected;
  int _year = DateTime.now().year;
  Future<RankingYearReview>? _review;

  void _select(LocalRanking? ranking) {
    setState(() {
      _selected = ranking;
      _review = ranking == null ? null : const RankingYearReviewService().calculate(ranking, _year);
    });
  }

  void _setYear(int year) {
    setState(() {
      _year = year;
      if (_selected != null) _review = const RankingYearReviewService().calculate(_selected!, year);
    });
  }

  Future<void> _exportReview(LocalRanking ranking, RankingYearReview review) async {
    final location = await getSaveLocation(suggestedName: 'ranglisten-rueckblick-${review.year}.html', acceptedTypeGroups: [
      const XTypeGroup(label: 'HTML', extensions: ['html']),
    ]);
    if (location == null) return;
    final max = review.monthlyTournaments.fold<int>(0, (a, b) => a > b ? a : b);
    final bars = [for (var i = 0; i < 12; i++) '<div class="month"><span>${i + 1}.</span><div class="track"><i style="width:${max == 0 ? 0 : review.monthlyTournaments[i] * 100 ~/ max}%"></i></div><b>${review.monthlyTournaments[i]}</b></div>'].join();
    final leaders = review.players.entries.toList()..sort((a, b) => b.value.tournamentWins.compareTo(a.value.tournamentWins));
    final rows = [for (final entry in leaders.take(10)) '<tr><td>${_escape(entry.key)}</td><td>${entry.value.participations}</td><td>${entry.value.tournamentWins}</td><td>${entry.value.legsWon}</td><td>${entry.value.bestPerformances}</td></tr>'].join();
    final html = '''<!doctype html><html lang="de"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>${_escape(ranking.name)} · ${review.year}</title><style>body{font:16px system-ui;margin:32px auto;padding:0 20px;max-width:900px;color:#18212b}h1{color:#146356}.cards{display:flex;gap:12px;flex-wrap:wrap}.card{background:#edf5f3;padding:16px;border-radius:12px;min-width:120px}.month{display:flex;gap:12px;align-items:center;margin:7px 0}.month span{width:32px}.track{height:14px;background:#e7eeec;border-radius:8px;flex:1;overflow:hidden}.track i{display:block;height:100%;background:#17806d}.month b{width:24px}table{width:100%;border-collapse:collapse;margin-top:24px}td,th{text-align:left;padding:9px;border-bottom:1px solid #ddd}@media print{body{margin:0}}</style><body><h1>${_escape(ranking.name)} · Jahresrückblick ${review.year}</h1><div class="cards"><div class="card"><b>${review.tournaments}</b><br>Turniere</div><div class="card"><b>${review.totalLegs}</b><br>gewonnene Legs</div><div class="card"><b>${review.totalBestPerformances}</b><br>Bestleistungen</div><div class="card"><b>${review.total180}</b><br>180+</div><div class="card"><b>${review.total170}</b><br>170+</div><div class="card"><b>${review.totalShortLegs}</b><br>Shortlegs</div><div class="card"><b>${review.totalHighFinishes}</b><br>High Finishes</div></div><h2>Turniere pro Monat</h2>$bars<h2>Spielerübersicht</h2><table><thead><tr><th>Spieler</th><th>Teilnahmen</th><th>Siege</th><th>Legs</th><th>Bestleistungen</th></tr></thead><tbody>$rows</tbody></table></body></html>''';
    await File(location.path).writeAsString(html, flush: true);
  }

  String _escape(String value) => value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Jahresrückblick')),
    body: FutureBuilder<List<LocalRanking>>(
      future: _rankings,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final rankings = snapshot.data!;
        final years = [_year, _year - 1, _year - 2, _year - 3];
        return AdaptiveContentList(children: [
          Text('Rückblick nach Rangliste', style: Theme.of(context).textTheme.headlineSmall),
          DropdownButtonFormField<LocalRanking>(
            value: _selected,
            decoration: const InputDecoration(labelText: 'Rangliste'),
            items: [for (final ranking in rankings) DropdownMenuItem(value: ranking, child: Text(ranking.name))],
            onChanged: _select,
          ),
          DropdownButtonFormField<int>(
            value: _year,
            decoration: const InputDecoration(labelText: 'Jahr'),
            items: [for (final year in years) DropdownMenuItem(value: year, child: Text('$year'))],
            onChanged: (value) { if (value != null) _setYear(value); },
          ),
          if (rankings.isEmpty) const Text('Lege zuerst eine Rangliste an und weise Spieler zu.'),
          if (_review != null) FutureBuilder<RankingYearReview>(
            future: _review,
            builder: (context, data) {
              if (!data.hasData) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
              final review = data.data!;
              final rows = review.players.entries.toList();
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 20),
                Text('${review.tournaments} Turniere · ${review.totalLegs} Legs · ${review.totalBestPerformances} Bestleistungen · ${review.total180} × 180+ · ${review.total170} × 170+ · ${review.totalShortLegs} Shortlegs · ${review.totalHighFinishes} High Finishes', style: Theme.of(context).textTheme.titleMedium),
                Align(alignment: Alignment.centerRight, child: OutlinedButton.icon(onPressed: () => _exportReview(_selected!, review), icon: const Icon(Icons.ios_share), label: const Text('Rückblick als Grafik exportieren'))),
                const SizedBox(height: 12),
                Text('Turniere pro Monat', style: Theme.of(context).textTheme.titleLarge),
                for (var i = 0; i < 12; i++) _MonthBar(month: i + 1, count: review.monthlyTournaments[i], max: review.monthlyTournaments.fold<int>(0, (a, b) => a > b ? a : b)),
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
        ]);
      },
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
      label: const Text('Rangliste hinzufügen'),
    ),
    body: SafeArea(
      child: FutureBuilder<List<LocalRanking>>(
        future: _rankings,
        builder: (context, snapshot) => AdaptiveContentList(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
          children: [
            Text('Vereinsranglisten', style: Theme.of(context).textTheme.headlineSmall),
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
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Ranglistenaktionen',
                    onSelected: (value) {
                      if (value == 'players') _assignPlayers(ranking);
                      if (value == 'tournaments') _assignTournaments(ranking);
                      if (value == 'settings') _edit(ranking);
                      if (value == 'table') _openRanking(ranking);
                      if (value == 'delete') _delete(ranking);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'players', child: Text('Spieler zuweisen')),
                      PopupMenuItem(value: 'tournaments', child: Text('Turniere zuweisen')),
                      PopupMenuItem(value: 'settings', child: Text('Ranglisteneinstellungen')),
                      PopupMenuItem(value: 'table', child: Text('Ranglistenstand öffnen')),
                      PopupMenuItem(value: 'delete', child: Text('Rangliste löschen')),
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
  final _fromYear = TextEditingController();
  final _toYear = TextEditingController();
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
    _fromYear.text = initial.validFromYear?.toString() ?? '';
    _toYear.text = initial.validToYear?.toString() ?? '';
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
    _fromYear.dispose();
    _toYear.dispose();
    for (final controller in _numbers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int _value(String label) => int.tryParse(_numbers[label]!.text.trim()) ?? 0;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final fromYear = int.tryParse(_fromYear.text.trim());
    final toYear = int.tryParse(_toYear.text.trim());
    if (fromYear != null && toYear != null && toYear < fromYear) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Das Endjahr muss nach dem Startjahr liegen.')));
      return;
    }
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
      validFromYear: fromYear,
      validToYear: toYear,
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? 'Rangliste erstellen' : 'Rangliste bearbeiten'),
    scrollable: true,
    content: SizedBox(
      width: 460,
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(
            controller: _name,
            autofocus: true,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Name, z. B. DC Unzenberg 2026'),
            validator: (value) => (value ?? '').trim().isEmpty ? 'Bitte einen Namen eingeben.' : null,
          ),
          TextFormField(controller: _fromYear, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Turniere gültig ab Jahr (optional)'), validator: (value) => (value ?? '').trim().isEmpty || int.tryParse(value!.trim()) != null ? null : 'Jahr als Zahl eingeben.'),
          TextFormField(controller: _toYear, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Turniere gültig bis Jahr (optional)'), validator: (value) => (value ?? '').trim().isEmpty || int.tryParse(value!.trim()) != null ? null : 'Jahr als Zahl eingeben.'),
          DropdownButtonFormField<RankingType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Ranglistentyp'),
            items: const [
              DropdownMenuItem(value: RankingType.elo, child: Text('Klassische Elo-Rangliste')),
              DropdownMenuItem(value: RankingType.series, child: Text('Turnierserie mit Punkten')),
            ],
            onChanged: (value) => setState(() => _type = value ?? RankingType.elo),
          ),
          const SizedBox(height: 12),
          for (final entry in _numbers.entries)
            if (_type == RankingType.elo
                ? entry.key.startsWith('Start') || entry.key.startsWith('K-Faktor') || entry.key.startsWith('Spiele') || entry.key.startsWith('Pro-Spieler')
                : entry.key.startsWith('Punkte'))
              TextFormField(
                controller: entry.value,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: entry.key),
                validator: (value) => int.tryParse((value ?? '').trim()) == null ? 'Bitte eine ganze Zahl eingeben.' : null,
              ),
        ]),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
      FilledButton(onPressed: _submit, child: Text(widget.initial == null ? 'Erstellen' : 'Speichern')),
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
  late Future<List<CreatedTournament>> _future = _storage.loadTournaments();
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
