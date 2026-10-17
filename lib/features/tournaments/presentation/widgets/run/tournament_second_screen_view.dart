import 'dart:async';
import 'package:flutter/material.dart';

import '../../../domain/tournament_models.dart';
import '../../../application/tournament_timing.dart';

/// Dynamische Info-Tafel für den Vereinsheim-TV (2. Bildschirm)
/// oder als Hero-Webpart auf dem Dashboard.
/// Wechselt automatisch zwischen Tabellen, nächsten Spielen,
/// neuesten Ergebnissen und Turnieruhr.
class TournamentSecondScreenView extends StatefulWidget {
  const TournamentSecondScreenView({
    super.key,
    required this.tournament,
    this.isStandaloneWindow = false,
  });

  final CreatedTournament tournament;
  final bool isStandaloneWindow;

  @override
  State<TournamentSecondScreenView> createState() =>
      _TournamentSecondScreenViewState();
}

class _TournamentSecondScreenViewState extends State<TournamentSecondScreenView> {
  int _currentSlide = 0;
  Timer? _rotationTimer;
  Timer? _clockTimer;

  static const int _slideCount = 4;

  @override
  void initState() {
    super.initState();
    _rotationTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) {
        setState(() {
          _currentSlide = (_currentSlide + 1) % _slideCount;
        });
      }
    });
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '$h Std. $m Min. ${s}s';
    return '$m Min. ${s}s';
  }

  List<GroupMatch> _matchesOf(TournamentRunStage? stage) {
    if (stage is GroupTournamentRunStage) {
      return stage.groups.expand((g) => g.matches).toList();
    } else if (stage is KnockoutTournamentRunStage) {
      return [
        ...stage.rounds.expand((r) => r),
        ...stage.placementMatches,
      ];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tournament;
    final theme = Theme.of(context);
    final timing = TournamentTiming.snapshot(t, DateTime.now());

    final activeIndex = t.activeStageIndex.clamp(
      0,
      t.runStages.isEmpty ? 0 : t.runStages.length - 1,
    );
    final activeStage = t.runStages.isNotEmpty ? t.runStages[activeIndex] : null;

    final allMatches = TournamentTiming.matches(t);
    final playedMatches = allMatches.where((m) => m.hasResult).toList();
    final totalMatches = allMatches.where((m) => m.hasPlayers).length;
    final pct = totalMatches > 0
        ? ((playedMatches.length / totalMatches) * 100).round()
        : 0;

    return Container(
      decoration: BoxDecoration(
        color: widget.isStandaloneWindow
            ? Colors.black
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(widget.isStandaloneWindow ? 0 : 16),
      ),
      padding: EdgeInsets.all(widget.isStandaloneWindow ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tv, size: 18, color: Colors.white),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        widget.isStandaloneWindow ? 'TV-LIVE-ÜBERSICHT' : 'LIVE-TICKER',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${t.name} · ${activeStage?.name ?? "Turnier"}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: widget.isStandaloneWindow ? Colors.white : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              // Slide-Indikatoren
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < _slideCount; i++)
                    InkWell(
                      onTap: () => setState(() => _currentSlide = i),
                      child: Container(
                        width: i == _currentSlide ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i == _currentSlide
                              ? theme.colorScheme.primary
                              : (widget.isStandaloneWindow ? Colors.white38 : Colors.black26),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
              if (widget.isStandaloneWindow)
                IconButton(
                  tooltip: 'Schließen',
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Slide-Inhalt
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: KeyedSubtree(
              key: ValueKey(_currentSlide),
              child: _buildSlideContent(
                context,
                slide: _currentSlide,
                t: t,
                activeStage: activeStage,
                timing: timing,
                progressPercent: pct,
                playedMatches: playedMatches,
                totalMatches: totalMatches,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlideContent(
    BuildContext context, {
    required int slide,
    required CreatedTournament t,
    required TournamentRunStage? activeStage,
    required TimingSnapshot timing,
    required int progressPercent,
    required List<GroupMatch> playedMatches,
    required int totalMatches,
  }) {
    switch (slide) {
      case 0:
        return _buildStandingsSlide(context, activeStage);
      case 1:
        return _buildBoardsSlide(context, t, activeStage);
      case 2:
        return _buildRecentResultsSlide(context, playedMatches);
      case 3:
      default:
        return _buildTimingSlide(
          context,
          t: t,
          timing: timing,
          progressPercent: progressPercent,
          playedMatches: playedMatches.length,
          totalMatches: totalMatches,
        );
    }
  }

  // Slide 0: Tabellen & Zwischenstände
  Widget _buildStandingsSlide(BuildContext context, TournamentRunStage? stage) {
    if (stage == null) {
      return const SizedBox(
        height: 140,
        child: Center(child: Text('Keine aktive Etappe vorhanden')),
      );
    }

    if (stage is GroupTournamentRunStage) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.leaderboard, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tabellen & Zwischenstände',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: widget.isStandaloneWindow ? Colors.white : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              for (var i = 0; i < stage.groups.length; i++)
                Container(
                  constraints: const BoxConstraints(minWidth: 200, maxWidth: 420),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.isStandaloneWindow
                        ? const Color(0xFF1E1E1E)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stage.groups[i].name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: widget.isStandaloneWindow ? Colors.white : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (var r = 0; r < stage.groups[i].players.length; r++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Text(
                                '${r + 1}. ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: r < (stage.qualificationPlan?.fixedPerGroup ?? 2)
                                      ? Colors.green
                                      : (widget.isStandaloneWindow ? Colors.white70 : null),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  stage.groups[i].players[r].name,
                                  style: TextStyle(
                                    color: widget.isStandaloneWindow ? Colors.white : null,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      );
    }

    return SizedBox(
      height: 120,
      child: Center(
        child: Text(
          'K.-o.-Runde: ${stage.name}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: widget.isStandaloneWindow ? Colors.white : null,
          ),
        ),
      ),
    );
  }

  // Slide 1: Boards & Laufende Spiele
  Widget _buildBoardsSlide(
    BuildContext context,
    CreatedTournament t,
    TournamentRunStage? stage,
  ) {
    final matches = _matchesOf(stage).where((m) => m.hasPlayers && !m.isResolved).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.sports_esports, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Aktuelle & nächste Begegnungen (${t.boardCount} Boards)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: widget.isStandaloneWindow ? Colors.white : null,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (matches.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text(
                'Keine offenen Spiele in dieser Etappe.',
                style: TextStyle(
                  color: widget.isStandaloneWindow ? Colors.white70 : null,
                ),
              ),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              for (var i = 0; i < matches.take(6).length; i++)
                Container(
                  constraints: const BoxConstraints(minWidth: 260, maxWidth: 360),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: widget.isStandaloneWindow
                        ? const Color(0xFF1E1E1E)
                        : Theme.of(context).colorScheme.surface,
                    border: Border.all(
                      color: matches[i].boardNumber != null
                          ? Theme.of(context).colorScheme.primary
                          : (widget.isStandaloneWindow ? Colors.white24 : Colors.black12),
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            matches[i].boardNumber != null
                                ? 'Board ${matches[i].boardNumber} (Läuft)'
                                : 'Vorbereitung',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: matches[i].boardNumber != null
                                  ? Theme.of(context).colorScheme.primary
                                  : (widget.isStandaloneWindow ? Colors.white54 : Colors.grey),
                            ),
                          ),
                          Text(
                            matches[i].label ?? '',
                            style: TextStyle(
                              fontSize: 11,
                              color: widget.isStandaloneWindow ? Colors.white38 : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${matches[i].homePlayer?.name ?? "Offen"} vs. ${matches[i].awayPlayer?.name ?? "Offen"}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: widget.isStandaloneWindow ? Colors.white : null,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }

  // Slide 2: Neueste Ergebnisse
  Widget _buildRecentResultsSlide(
    BuildContext context,
    List<GroupMatch> playedMatches,
  ) {
    final recent = playedMatches.reversed.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.history, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Zuletzt beendete Matches',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: widget.isStandaloneWindow ? Colors.white : null,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (recent.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text(
                'Noch keine beendeten Matches vorhanden.',
                style: TextStyle(
                  color: widget.isStandaloneWindow ? Colors.white70 : null,
                ),
              ),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final m in recent)
                Container(
                  constraints: const BoxConstraints(minWidth: 260, maxWidth: 360),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.isStandaloneWindow
                        ? const Color(0xFF1E1E1E)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${m.homePlayer?.name ?? "?"} – ${m.awayPlayer?.name ?? "?"}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: widget.isStandaloneWindow ? Colors.white : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${m.homeScore ?? 0} : ${m.awayScore ?? 0}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }

  // Slide 3: Turnieruhr & Fortschritt
  Widget _buildTimingSlide(
    BuildContext context, {
    required CreatedTournament t,
    required TimingSnapshot timing,
    required int progressPercent,
    required int playedMatches,
    required int totalMatches,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.timer, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Turnieruhr & Gesamtfortschritt',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: widget.isStandaloneWindow ? Colors.white : null,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gesamtdauer: ${_formatDuration(timing.elapsed)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: widget.isStandaloneWindow ? Colors.white : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (t.isClockPaused)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'UHR PAUSIERT',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    )
                  else if (timing.forecast != null)
                    Text(
                      'Geschätztes Turnierende: ${timing.forecast!.toLocal().hour.toString().padLeft(2, '0')}:${timing.forecast!.toLocal().minute.toString().padLeft(2, '0')} Uhr',
                      style: TextStyle(
                        color: widget.isStandaloneWindow ? Colors.white70 : Colors.black87,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$progressPercent%',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(
                  '$playedMatches von $totalMatches Spielen',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isStandaloneWindow ? Colors.white54 : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: totalMatches > 0 ? (playedMatches / totalMatches).clamp(0.0, 1.0) : 0.0,
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
