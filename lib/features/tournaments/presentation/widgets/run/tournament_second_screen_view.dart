import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../../../domain/knockout_round_names.dart';
import '../../../domain/tournament_models.dart';
import '../../../domain/engines/qualification_certainty.dart';
import '../../../application/tournament_timing.dart';
import '../../../application/order_of_play/order_of_play_controller.dart';
import '../../../../rankings/domain/local_elo_calculator.dart';
import '../../../../statistics/domain/best_performance.dart';

/// Dynamische Info-Tafel für den Vereinsheim-TV (2. Bildschirm).
/// Wechselt automatisch zwischen 4 inhaltsreichen Slides:
/// 1. Tabellen & Zwischenstände + KO-Prognose (Turnierbaum-Vorschau)
/// 2. Aktuelle & nächste Begegnungen + Priorisierte Partien + Tabellen
/// 3. Zuletzt beendete Matches + Live-Elo-Änderungen + Tabellen
/// 4. Etappen-Fortschritt (%) + Tabellen + Bestleistungen
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

class _TournamentSecondScreenViewState
    extends State<TournamentSecondScreenView> {
  int _currentSlide = 0;
  Timer? _rotationTimer;
  Timer? _clockTimer;

  static const int _slideCount = 4;

  @override
  void initState() {
    super.initState();
    _rotationTimer = Timer.periodic(const Duration(seconds: 10), (_) {
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
    final activeStage =
        t.runStages.isNotEmpty ? t.runStages[activeIndex] : null;

    final allMatches = TournamentTiming.matches(t);
    final playedMatches = allMatches.where((m) => m.hasResult).toList();
    final totalMatches = allMatches.where((m) => m.hasPlayers).length;
    final pct = totalMatches > 0
        ? ((playedMatches.length / totalMatches) * 100).round()
        : 0;

    final viewWidget = Container(
      decoration: BoxDecoration(
        color: widget.isStandaloneWindow
            ? const Color(0xFF0D1318)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(widget.isStandaloneWindow ? 0 : 16),
      ),
      padding: EdgeInsets.all(widget.isStandaloneWindow ? 20 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF144D34),
                      border: Border.all(color: const Color(0xFF70E0BA)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.tv, size: 16, color: Color(0xFF70E0BA)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              widget.isStandaloneWindow
                                  ? 'TV-LIVE-ÜBERSICHT'
                                  : 'LIVE-TICKER',
                              style: const TextStyle(
                                color: Color(0xFF70E0BA),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${t.name} · ${activeStage?.name ?? "Turnier"}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              // Slide Indicators
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < _slideCount; i++)
                    InkWell(
                      onTap: () => setState(() => _currentSlide = i),
                      child: Container(
                        width: i == _currentSlide ? 28 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i == _currentSlide
                              ? const Color(0xFF70E0BA)
                              : Colors.white30,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (widget.isStandaloneWindow)
                    IconButton(
                      tooltip: 'Schließen',
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Slide Content with Smooth Transition
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: KeyedSubtree(
                key: ValueKey(_currentSlide),
                child: _buildSlideContent(
                  context,
                  slide: _currentSlide,
                  t: t,
                  activeIndex: activeIndex,
                  activeStage: activeStage,
                  timing: timing,
                  progressPercent: pct,
                  playedMatches: playedMatches,
                  totalMatches: totalMatches,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (!widget.isStandaloneWindow) {
      return SizedBox(
        height: 520,
        child: viewWidget,
      );
    }
    return viewWidget;
  }

  Widget _buildSlideContent(
    BuildContext context, {
    required int slide,
    required CreatedTournament t,
    required int activeIndex,
    required TournamentRunStage? activeStage,
    required TimingSnapshot timing,
    required int progressPercent,
    required List<GroupMatch> playedMatches,
    required int totalMatches,
  }) {
    switch (slide) {
      case 0:
        return _buildSlide1(context, t, activeIndex, activeStage);
      case 1:
        return _buildSlide2(context, t, activeIndex, activeStage);
      case 2:
        return _buildSlide3(context, t, activeStage, playedMatches);
      case 3:
      default:
        return _buildSlide4(
          context,
          t: t,
          activeStage: activeStage,
          timing: timing,
          progressPercent: progressPercent,
          playedMatches: playedMatches,
          totalMatches: totalMatches,
        );
    }
  }

  // ==========================================
  // SLIDE 1: Tabellen & Zwischenstände + KO-Prognose
  // ==========================================
  Widget _buildSlide1(
    BuildContext context,
    CreatedTournament t,
    int activeIndex,
    TournamentRunStage? stage,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;

        if (wide) {
          final standingsWidget = _buildStandingsPanel(context, t, stage, full: true, expand: true);
          final prognosisWidget = _buildKoPrognosisPanel(context, t, activeIndex, stage, expand: true);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: standingsWidget),
              const SizedBox(width: 16),
              Expanded(flex: 5, child: prognosisWidget),
            ],
          );
        }

        final standingsWidget = _buildStandingsPanel(context, t, stage, full: true, expand: false);
        final prognosisWidget = _buildKoPrognosisPanel(context, t, activeIndex, stage, expand: false);
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              standingsWidget,
              const SizedBox(height: 16),
              prognosisWidget,
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // SLIDE 2: Aktuelle & nächste Begegnungen + Priorisierte Partien + Tabellen
  // ==========================================
  Widget _buildSlide2(
    BuildContext context,
    CreatedTournament t,
    int activeIndex,
    TournamentRunStage? stage,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;

        if (wide) {
          final matchesWidget = _buildBoardsAndPriorityPanel(context, t, activeIndex, stage, expand: true);
          final compactStandings = _buildCompactStandings(context, t, stage, expand: true);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: matchesWidget),
              const SizedBox(width: 16),
              Expanded(flex: 4, child: compactStandings),
            ],
          );
        }

        final matchesWidget = _buildBoardsAndPriorityPanel(context, t, activeIndex, stage, expand: false);
        final compactStandings = _buildCompactStandings(context, t, stage, expand: false);
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              matchesWidget,
              const SizedBox(height: 16),
              compactStandings,
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // SLIDE 3: Zuletzt beendete Matches + Live-Elo-Änderungen + Tabellen
  // ==========================================
  Widget _buildSlide3(
    BuildContext context,
    CreatedTournament t,
    TournamentRunStage? stage,
    List<GroupMatch> playedMatches,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;

        if (wide) {
          final recentAndEloWidget = _buildRecentMatchesAndEloPanel(context, t, playedMatches, expand: true);
          final compactStandings = _buildCompactStandings(context, t, stage, expand: true);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: recentAndEloWidget),
              const SizedBox(width: 16),
              Expanded(flex: 4, child: compactStandings),
            ],
          );
        }

        final recentAndEloWidget = _buildRecentMatchesAndEloPanel(context, t, playedMatches, expand: false);
        final compactStandings = _buildCompactStandings(context, t, stage, expand: false);
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              recentAndEloWidget,
              const SizedBox(height: 16),
              compactStandings,
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // SLIDE 4: Etappen-Fortschritt (%) + Bestleistungen + Tabellen
  // ==========================================
  Widget _buildSlide4(
    BuildContext context, {
    required CreatedTournament t,
    required TournamentRunStage? activeStage,
    required TimingSnapshot timing,
    required int progressPercent,
    required List<GroupMatch> playedMatches,
    required int totalMatches,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;

        if (wide) {
          final progressAndBestWidget = _buildProgressAndBestPerformancesPanel(
            context: context,
            t: t,
            timing: timing,
            progressPercent: progressPercent,
            playedMatches: playedMatches,
            totalMatches: totalMatches,
            expand: true,
          );
          final compactStandings = _buildCompactStandings(context, t, activeStage, expand: true);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: progressAndBestWidget),
              const SizedBox(width: 16),
              Expanded(flex: 4, child: compactStandings),
            ],
          );
        }

        final progressAndBestWidget = _buildProgressAndBestPerformancesPanel(
          context: context,
          t: t,
          timing: timing,
          progressPercent: progressPercent,
          playedMatches: playedMatches,
          totalMatches: totalMatches,
          expand: false,
        );
        final compactStandings = _buildCompactStandings(context, t, activeStage, expand: false);
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              progressAndBestWidget,
              const SizedBox(height: 16),
              compactStandings,
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------
  // HELPER: Standings Panel (Vollansicht)
  // ------------------------------------------
  Widget _buildStandingsPanel(
    BuildContext context,
    CreatedTournament t,
    TournamentRunStage? stage, {
    bool full = false,
    bool expand = true,
  }) {
    if (stage == null) {
      return const Center(child: Text('Keine aktive Etappe vorhanden', style: TextStyle(color: Colors.white70)));
    }

    if (stage is GroupTournamentRunStage) {
      final wrapContent = Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (var i = 0; i < stage.groups.length; i++)
            _buildGroupStandingsCard(
              context,
              stage.groups[i],
              groupNumber: i + 1,
              qualificationPlan: stage.qualificationPlan,
              tieBreakers: stage.tieBreakers,
              full: full,
            ),
        ],
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.leaderboard, size: 20, color: Color(0xFF70E0BA)),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Tabellen & Zwischenstände',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (expand)
            Expanded(
              child: SingleChildScrollView(
                child: wrapContent,
              ),
            )
          else
            wrapContent,
        ],
      );
    }

    return Card(
      color: const Color(0xFF16202A),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'K.-o.-Runde: ${stage.name}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Aktuelle Spiele und Paarungen siehe Spielansetzungen.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupStandingsCard(
    BuildContext context,
    TournamentGroup group, {
    required int groupNumber,
    required QualificationPlan? qualificationPlan,
    required List<String> tieBreakers,
    bool full = false,
  }) {
    final standings = _calculateGroupStandings(group, tieBreakers);
    final fixedPlaces = qualificationPlan?.fixedPerGroup ?? 2;

    return Container(
      constraints: BoxConstraints(minWidth: full ? 280 : 220, maxWidth: full ? 420 : 340),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF14202B),
        border: Border.all(color: const Color(0xFF263D52)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 2,
            children: [
              Text(
                group.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF70E0BA),
                ),
              ),
              Text(
                'Top $fixedPlaces weiter',
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ],
          ),
          const Divider(color: Color(0xFF263D52), height: 12),
          for (var r = 0; r < standings.length; r++)
            Builder(
              builder: (context) {
                final standing = standings[r];
                final place = r + 1;
                final isQualified = place <= fixedPlaces;
                final isCertain = const QualificationCertainty().isCertain(
                  standing: standing,
                  place: place,
                  fixedPlaces: fixedPlaces,
                  standings: standings,
                  matches: group.matches,
                  tieBreakers: tieBreakers,
                );

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  margin: const EdgeInsets.symmetric(vertical: 1),
                  decoration: BoxDecoration(
                    color: isCertain
                        ? const Color(0xFF144D34)
                        : isQualified
                            ? const Color(0xFF163828)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '$place.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isQualified ? const Color(0xFF86EFAC) : Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          standing.player.name,
                          style: TextStyle(
                            fontWeight: isQualified ? FontWeight.bold : FontWeight.normal,
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${standing.legsFor}:${standing.legsAgainst}',
                        style: const TextStyle(fontSize: 12, color: Colors.white60),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${standing.points} P',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF70E0BA),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ------------------------------------------
  // HELPER: Compact Standings (Side Column)
  // ------------------------------------------
  Widget _buildCompactStandings(
    BuildContext context,
    CreatedTournament t,
    TournamentRunStage? stage, {
    bool expand = true,
  }) {
    return _buildStandingsPanel(context, t, stage, full: false, expand: expand);
  }

  // ------------------------------------------
  // SLIDE 1 PROGNOSIS: KO-Prognose (Turnierbaum-Vorschau)
  // ------------------------------------------
  Widget _buildKoPrognosisPanel(
    BuildContext context,
    CreatedTournament t,
    int activeIndex,
    TournamentRunStage? currentStage, {
    bool expand = true,
  }) {
    // Find upcoming or current KO stage
    KnockoutTournamentRunStage? koStage;
    if (currentStage is KnockoutTournamentRunStage) {
      koStage = currentStage;
    } else {
      for (var i = activeIndex + 1; i < t.runStages.length; i++) {
        if (t.runStages[i] is KnockoutTournamentRunStage) {
          koStage = t.runStages[i] as KnockoutTournamentRunStage;
          break;
        }
      }
    }

    final hasPrognosis = currentStage is GroupTournamentRunStage && koStage != null;
    final prognosisContent = hasPrognosis
        ? _buildContenderPrognosisList(context, currentStage, koStage)
        : (koStage != null
            ? _buildKnockoutRoundsPreview(context, koStage)
            : const Center(
                child: Text(
                  'Keine K.-o.-Phase im aktuellen Turnier geplant.',
                  style: TextStyle(color: Colors.white54),
                ),
              ));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF14202B),
        border: Border.all(color: const Color(0xFF263D52)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree_outlined, size: 20, color: Color(0xFF70E0BA)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  hasPrognosis ? 'KO-Prognose & Weiterkommen' : 'Turnierbaum Vorschau',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasPrognosis
                ? 'Vorschau der K.-o.-Paarungen basierend auf aktuellen Tabellenständen und Siegesraten:'
                : 'Turnierbaum der finalen Phase:',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          if (expand)
            Expanded(
              child: SingleChildScrollView(
                child: prognosisContent,
              ),
            )
          else
            prognosisContent,
        ],
      ),
    );
  }

  Widget _buildContenderPrognosisList(
    BuildContext context,
    GroupTournamentRunStage groupStage,
    KnockoutTournamentRunStage koStage,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < groupStage.groups.length; i++)
          Builder(
            builder: (context) {
              final group = groupStage.groups[i];
              final standings = _calculateGroupStandings(group, groupStage.tieBreakers);
              final fixedPlaces = groupStage.qualificationPlan?.fixedPerGroup ?? 2;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF101922),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${group.name} Qualifikations-Chancen',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF70E0BA),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (var r = 0; r < min(standings.length, fixedPlaces + 2); r++)
                      Builder(
                        builder: (context) {
                          final standing = standings[r];
                          final place = r + 1;
                          final isCertain = const QualificationCertainty().isCertain(
                            standing: standing,
                            place: place,
                            fixedPlaces: fixedPlaces,
                            standings: standings,
                            matches: group.matches,
                            tieBreakers: groupStage.tieBreakers,
                          );

                          // Estimate probability based on played ratio and current rank
                          final remaining = group.matches
                              .where((m) =>
                                  !m.isResolved &&
                                  (m.homePlayer?.name == standing.player.name ||
                                      m.awayPlayer?.name == standing.player.name))
                              .length;
                          final played = standing.played;
                          final winRate = played > 0 ? (standing.wins / played) : 0.5;
                          int probability = 100;
                          if (!isCertain) {
                            if (place <= fixedPlaces) {
                              probability = (70 + (winRate * 25) - (remaining * 3)).clamp(35, 95).round();
                            } else {
                              probability = (winRate * 50 - ((place - fixedPlaces) * 15)).clamp(5, 45).round();
                            }
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Text(
                                  'Platz $place: ',
                                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                                ),
                                Expanded(
                                  child: Text(
                                    standing.player.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isCertain
                                        ? const Color(0xFF144D34)
                                        : (probability >= 70
                                            ? const Color(0xFF1D4E3A)
                                            : const Color(0xFF4A3B18)),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isCertain ? 'Fest im KO' : '$probability% Chance',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isCertain
                                          ? const Color(0xFF86EFAC)
                                          : (probability >= 70 ? Colors.white : Colors.amber.shade200),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildKnockoutRoundsPreview(
    BuildContext context,
    KnockoutTournamentRunStage koStage,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < koStage.rounds.length; i++) ...[
          Text(
            knockoutRoundName(i, koStage.rounds.length),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF70E0BA)),
          ),
          const SizedBox(height: 4),
          for (final m in koStage.rounds[i])
            Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF101922),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${m.homePlayer?.name ?? "Offen"} vs. ${m.awayPlayer?.name ?? "Offen"}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  if (m.hasResult)
                    Text(
                      '${m.homeScore} : ${m.awayScore}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF70E0BA)),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  // ------------------------------------------
  // SLIDE 2 HELPER: Boards & Priorisierte Partien
  // ------------------------------------------
  Widget _buildBoardsAndPriorityPanel(
    BuildContext context,
    CreatedTournament t,
    int activeIndex,
    TournamentRunStage? stage, {
    bool expand = true,
  }) {
    final matches = _matchesOf(stage).where((m) => m.hasPlayers && !m.isResolved).toList();

    // Calculate priority bottleneck match using OrderOfPlay
    String? priorityNotice;
    try {
      final schedule = const OrderOfPlayController().plan(t, activeIndex);
      final openCounts = <String, int>{};
      for (final assignment in schedule.planned) {
        for (final p in assignment.entry.players) {
          openCounts[p] = (openCounts[p] ?? 0) + 1;
        }
      }
      if (openCounts.isNotEmpty) {
        final maxOpen = openCounts.values.reduce(max);
        final minOpen = openCounts.values.reduce(min);
        if (maxOpen >= 2 && maxOpen - minOpen >= 1) {
          final pNames = openCounts.entries.where((e) => e.value == maxOpen).map((e) => e.key).join(', ');
          priorityNotice = 'Priorität: $pNames hat noch $maxOpen offene Partien (Schnitt: $minOpen). Bevorzugt aufrufen!';
        }
      }
    } catch (_) {}

    final matchesContent = matches.isEmpty
        ? const Center(
            child: Text(
              'Keine offenen Partien in dieser Etappe.',
              style: TextStyle(color: Colors.white70),
            ),
          )
        : Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < matches.take(8).length; i++)
                _buildMatchTile(context, matches[i]),
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.sports_esports, size: 20, color: Color(0xFF70E0BA)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Aktuelle & nächste Begegnungen (${t.boardCount} Boards)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (priorityNotice != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF3E2D12),
              border: Border.all(color: Colors.amber.shade700),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.priority_high, size: 18, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    priorityNotice,
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (expand)
          Expanded(
            child: SingleChildScrollView(
              child: matchesContent,
            ),
          )
        else
          matchesContent,
      ],
    );
  }

  Widget _buildMatchTile(BuildContext context, GroupMatch match) {
    final isRunning = match.boardNumber != null;

    return Container(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 340),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF14202B),
        border: Border.all(
          color: isRunning ? const Color(0xFF70E0BA) : const Color(0xFF263D52),
          width: isRunning ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isRunning ? const Color(0xFF144D34) : Colors.white12,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isRunning ? 'Board ${match.boardNumber} (Läuft)' : 'Nächste Partie',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isRunning ? const Color(0xFF86EFAC) : Colors.white70,
                  ),
                ),
              ),
              if (match.label != null && match.label!.isNotEmpty)
                Text(match.label!, style: const TextStyle(fontSize: 11, color: Colors.white54)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${match.homePlayer?.name ?? "Offen"} vs. ${match.awayPlayer?.name ?? "Offen"}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ------------------------------------------
  // SLIDE 3 HELPER: Zuletzt beendet + Live Elo
  // ------------------------------------------
  Widget _buildRecentMatchesAndEloPanel(
    BuildContext context,
    CreatedTournament t,
    List<GroupMatch> playedMatches, {
    bool expand = true,
  }) {
    final recent = playedMatches.reversed.take(6).toList();

    final recentContent = recent.isEmpty
        ? const Center(
            child: Text(
              'Noch keine beendeten Partien vorhanden.',
              style: TextStyle(color: Colors.white70),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final m in recent) ...[
                _buildRecentMatchWithEloRow(context, m),
                const SizedBox(height: 8),
              ],
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.history, size: 20, color: Color(0xFF70E0BA)),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Zuletzt beendete Matches & Live-Elo',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (expand)
          Expanded(
            child: SingleChildScrollView(
              child: recentContent,
            ),
          )
        else
          recentContent,
      ],
    );
  }

  Widget _buildRecentMatchWithEloRow(BuildContext context, GroupMatch m) {
    final homeWon = (m.homeScore ?? 0) > (m.awayScore ?? 0);
    final draw = m.homeScore == m.awayScore;
    final delta = eloDelta(1000, 1000, homeWon ? 1.0 : (draw ? 0.5 : 0.0), kFactor: 16);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF14202B),
        border: Border.all(color: const Color(0xFF263D52)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${m.homePlayer?.name ?? "?"} – ${m.awayPlayer?.name ?? "?"}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A2E),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${m.homeScore ?? 0} : ${m.awayScore ?? 0}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF86EFAC), fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF10263E),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Elo: ${delta > 0 ? "+$delta" : "$delta"}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF70E0BA)),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------
  // SLIDE 4 HELPER: Etappenfortschritt & Bestleistungen
  // ------------------------------------------
  Widget _buildProgressAndBestPerformancesPanel({
    required BuildContext context,
    required CreatedTournament t,
    required TimingSnapshot timing,
    required int progressPercent,
    required List<GroupMatch> playedMatches,
    required int totalMatches,
    bool expand = true,
  }) {
    // Gather best performances from all matches
    final allPerformances = <BestPerformance>[];
    for (final stage in t.runStages) {
      for (final m in _matchesOf(stage)) {
        allPerformances.addAll(m.bestPerformances);
      }
    }

    final oneEighties = allPerformances.where((p) => p.type == BestPerformanceType.score180).toList();
    final highFinishes = allPerformances.where((p) => p.type == BestPerformanceType.highFinish).toList();
    final shortLegs = allPerformances.where((p) => p.type == BestPerformanceType.shortLeg).toList();

    final breakdownContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Fortschritt nach Etappen:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70),
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < t.runStages.length; i++)
          Builder(
            builder: (context) {
              final stage = t.runStages[i];
              final sMatches = _matchesOf(stage).where((m) => m.hasPlayers).toList();
              final sPlayed = sMatches.where((m) => m.hasResult).length;
              final sTotal = sMatches.length;
              final sPct = sTotal > 0 ? ((sPlayed / sTotal) * 100).round() : 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF14202B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${i + 1}. ${stage.name}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                        ),
                        Text(
                          '$sPlayed von $sTotal Spielen ($sPct%)',
                          style: const TextStyle(color: Color(0xFF70E0BA), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: sTotal > 0 ? (sPlayed / sTotal).clamp(0.0, 1.0) : 0.0,
                        minHeight: 6,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF70E0BA)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

        const SizedBox(height: 10),
        // Best Performances section
        const Text(
          'Bestleistungen & Highlights:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF14202B),
            border: Border.all(color: const Color(0xFF263D52)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildHighlightItem('180er', '${oneEighties.length}x geworfen'),
                  _buildHighlightItem(
                    'High Finish',
                    highFinishes.isNotEmpty
                        ? '${highFinishes.map((p) => p.value ?? 100).reduce(max)} Punkte'
                        : '–',
                  ),
                  _buildHighlightItem(
                    'Bestes Shortleg',
                    shortLegs.isNotEmpty
                        ? '${shortLegs.map((p) => p.value ?? 18).reduce(min)} Darts'
                        : '–',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Overall timing
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.timer, size: 20, color: Color(0xFF70E0BA)),
                const SizedBox(width: 8),
                Text(
                  'Turnieruhr: ${_formatDuration(timing.elapsed)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                ),
              ],
            ),
            Text(
              '$progressPercent% Gesamt',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF70E0BA)),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Stages breakdown
        if (expand)
          Expanded(
            child: SingleChildScrollView(
              child: breakdownContent,
            ),
          )
        else
          breakdownContent,
      ],
    );
  }

  Widget _buildHighlightItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF70E0BA)),
        ),
      ],
    );
  }

  List<PlayerStanding> _calculateGroupStandings(TournamentGroup group, List<String> tieBreakers) {
    final standings = {
      for (final player in group.players) player.name: PlayerStanding(player),
    };

    for (final match in group.matches.where((m) => m.hasResult && !m.isDecider)) {
      final homePlayer = match.homePlayer;
      final awayPlayer = match.awayPlayer;
      if (homePlayer == null || awayPlayer == null) continue;
      final home = standings[homePlayer.name];
      final away = standings[awayPlayer.name];
      if (home == null || away == null) continue;
      final homeLegs = match.homeLegs ?? 0;
      final awayLegs = match.awayLegs ?? 0;

      home.played++;
      home.legsFor += homeLegs;
      home.legsAgainst += awayLegs;
      away.played++;
      away.legsFor += awayLegs;
      away.legsAgainst += homeLegs;

      if (match.winner == homePlayer) {
        home.wins++;
        home.points += 3;
        away.losses++;
      } else if (match.winner == awayPlayer) {
        away.wins++;
        away.points += 3;
        home.losses++;
      } else {
        home.draws++;
        home.points++;
        away.draws++;
        away.points++;
      }
    }

    final sorted = standings.values.toList();
    sorted.sort((a, b) {
      for (final rule in tieBreakers) {
        final cmp = switch (rule) {
          'points' => b.points.compareTo(a.points),
          'legDifference' => b.legDifference.compareTo(a.legDifference),
          'legsFor' => b.legsFor.compareTo(a.legsFor),
          _ => 0,
        };
        if (cmp != 0) return cmp;
      }
      return a.player.name.compareTo(b.player.name);
    });
    return sorted;
  }
}
