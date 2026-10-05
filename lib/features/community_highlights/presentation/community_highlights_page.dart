import '../../../shared/widgets/sport_menu.dart';
import 'package:flutter/material.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../../statistics/domain/statistics_period.dart';
import '../../statistics/presentation/statistics_date_dialog.dart';
import '../../tournaments/domain/tournament_models.dart';
import '../data/community_highlights_repository.dart';
import '../domain/community_highlight.dart';
import 'highlight_editor_page.dart';

class CommunityHighlightsPage extends StatefulWidget {
  const CommunityHighlightsPage({
    super.key,
    required this.communityId,
    required this.communityName,
    required this.tournaments,
    this.repository,
  });
  final String communityId, communityName;
  final List<CreatedTournament> tournaments;
  final CommunityHighlightsRepository? repository;
  @override
  State<CommunityHighlightsPage> createState() => _HighlightsState();
}

class _HighlightsState extends State<CommunityHighlightsPage> {
  late final _automaticEntries = const CommunityHighlights().automatic(
    widget.communityId,
    widget.tournaments,
  );
  late final _repository = widget.repository ?? CommunityHighlightsRepository();
  List<CommunityHighlight> _saved = [];
  bool _loading = true, _failed = false, _canManage = false, _busy = false;
  String _query = '';
  HighlightCategory? _category;
  String? _player, _tournament;
  bool? _automatic;
  StatisticsPeriod? _period;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
      _canManage = false;
    });
    try {
      final result = await Future.wait<Object>([
        _repository.load(widget.communityId),
        _repository.canManage(widget.communityId),
      ]);
      if (mounted) {
        setState(() {
          _saved = result[0] as List<CommunityHighlight>;
          _canManage = result[1] as bool;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _edit([CommunityHighlight? highlight]) async {
    final result = await Navigator.of(context).push<CommunityHighlight>(
      MaterialPageRoute(
        builder: (_) => HighlightEditorPage(
          communityId: widget.communityId,
          repository: _repository,
          highlight: highlight,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(
        () => _saved = [..._saved.where((h) => h.key != result.key), result],
      );
    }
  }

  Future<void> _delete(CommunityHighlight highlight) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Highlight löschen?'),
        content: Text(
          '„${highlight.title}“ wird aus der Highlight-Liste entfernt. Die Spielergebnisse bleiben erhalten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final saved = await _repository.save(
        widget.communityId,
        highlight.removed(),
      );
      if (mounted) {
        setState(
          () => _saved = [..._saved.where((h) => h.key != saved.key), saved],
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Löschen nicht bestätigt. Verbindung und Rechte prüfen.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const service = CommunityHighlights();
    final all = service.merge(_automaticEntries, _saved);
    final players = {
      ...all.map((h) => h.player).where((s) => s.isNotEmpty),
      ?_player,
    }.toList()..sort();
    final tournaments = {
      ...all.map((h) => h.tournament).where((s) => s.isNotEmpty),
      ?_tournament,
    }.toList()..sort();
    final visible = service.filter(
      all,
      query: _query,
      category: _category,
      player: _player,
      tournament: _tournament,
      period: _period,
      automatic: _automatic,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Highlight-Liste')),
      body: AdaptiveContentList(
        children: [
          Text(
            widget.communityName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Wrap(
            spacing: 12,
            children: [
              if (_canManage)
                FilledButton.icon(
                  onPressed: _busy ? null : () => _edit(),
                  icon: const Icon(Icons.add),
                  label: const Text('Highlight hinzufügen'),
                ),
              TextButton.icon(
                onPressed: _loading || _busy ? null : _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Aktualisieren'),
              ),
            ],
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_failed)
            const Text(
              'Highlights konnten nicht geladen werden. Bitte erneut versuchen.',
            ),
          if (!_loading && !_failed) ...[
            if (_repository.cached)
              const Text(
                'Offline: zuletzt gespeicherter Stand. Änderungen benötigen Internet.',
              ),
            const Text(
              'Automatische Einträge zeigen die erfassten Bestwerte pro Spieler und Turnier. Teams haben gemeinsame Werte. Manuelle Korrekturen sind gekennzeichnet.',
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Highlights suchen',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            AdaptiveTileLayout(
              children: [
                DropdownButtonFormField<HighlightCategory>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Kategorie'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Alle Kategorien'),
                    ),
                    for (final c in HighlightCategory.values)
                      DropdownMenuItem(value: c, child: Text(c.label)),
                  ],
                  onChanged: (value) => setState(() => _category = value),
                ),
                _select(
                  'Spieler / Team',
                  _player,
                  players,
                  (value) => setState(() => _player = value),
                ),
                _select(
                  'Turnier',
                  _tournament,
                  tournaments,
                  (value) => setState(() => _tournament = value),
                ),
                DropdownButtonFormField<bool>(
                  initialValue: _automatic,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Herkunft'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Alle Einträge')),
                    DropdownMenuItem(
                      value: true,
                      child: Text('Aus Scorer-Daten'),
                    ),
                    DropdownMenuItem(
                      value: false,
                      child: Text('Manuell hinzugefügt'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _automatic = value),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    _period == null
                        ? 'Zeitraum wählen'
                        : '${highlightDate(_period!.start)} – ${highlightDate(_period!.endExclusive.subtract(const Duration(days: 1)))}',
                  ),
                  onPressed: () async {
                    final range = await showDialog<DateTimeRange>(
                      context: context,
                      builder: (_) => StatisticsDateDialog(
                        initialRange: _period == null
                            ? null
                            : DateTimeRange(
                                start: _period!.start,
                                end: _period!.endExclusive.subtract(
                                  const Duration(microseconds: 1),
                                ),
                              ),
                      ),
                    );
                    if (range != null && mounted) {
                      setState(
                        () =>
                            _period = StatisticsPeriod(range.start, range.end),
                      );
                    }
                  },
                ),
                if (_period != null)
                  TextButton(
                    onPressed: () => setState(() => _period = null),
                    child: const Text('Alle Zeiträume'),
                  ),
              ],
            ),
            Text('${visible.length} Highlights'),
            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Keine Highlights für diese Filter vorhanden.'),
              ),
            for (final h in visible)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(h.category.label),
                          if (_canManage)
                            PopupMenuButton<String>(
                              tooltip: 'Highlight verwalten',
                              enabled: !_busy,
                              onSelected: (value) =>
                                  value == 'edit' ? _edit(h) : _delete(h),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: SportMenuLabel(
                                    label: 'Bearbeiten',
                                    icon: Icons.edit_outlined,
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: SportMenuLabel(
                                    label: 'Löschen',
                                    icon: Icons.delete_outline,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      Text(
                        h.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        h.value,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (h.player.isNotEmpty) Text(h.player),
                      if (h.tournament.isNotEmpty) Text(h.tournament),
                      Text(
                        '${highlightDate(h.date)} · ${h.automatic
                            ? h.edited
                                  ? 'Manuell korrigiert'
                                  : 'Automatisch'
                            : 'Manuell hinzugefügt'}',
                      ),
                      if (h.note.isNotEmpty) Text(h.note),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _select(
    String label,
    String? value,
    List<String> values,
    ValueChanged<String?> onChanged,
  ) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      const DropdownMenuItem(value: null, child: Text('Alle')),
      for (final s in values) DropdownMenuItem(value: s, child: Text(s)),
    ],
    onChanged: onChanged,
  );
}
