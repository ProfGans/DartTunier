import 'group_size_rules.dart';
import 'dart:math';
import 'planning_duration.dart';
import 'planning_format_progression.dart';

import 'tournament_models.dart';
import 'planning_match_breakdown.dart';
import 'tournament_planning_parameters.dart';

class TournamentPlanningRequest {
  const TournamentPlanningRequest({
    required this.players,
    required this.boards,
    required this.minimumMatchesPerPlayer,
    required this.minimumMinutes,
    required this.maximumMinutes,
    required this.x01Selection,
    required this.checkoutType,
    this.maximumGroups,
    this.bestOfLegs = 3,
    this.allowSets = false,
    this.allowDraws = false,
  });

  final int players;
  final int boards;
  final int bestOfLegs;
  final bool allowSets;
  final bool allowDraws;

  /// Null uses the saved planner setting; a value overrides it for this search.
  final int? maximumGroups;
  final int minimumMatchesPerPlayer;
  final int minimumMinutes;
  final int maximumMinutes;

  /// A numeric score as a string, or `variable_301_501`.
  final String x01Selection;
  final String checkoutType;
}

class TournamentFormatSuggestion {
  const TournamentFormatSuggestion({
    required this.title,
    required this.stages,
    required this.minimumMatchesPerPlayer,
    required this.totalMatches,
    required this.estimatedMinutes,
    required this.effectiveBoards,
    required this.participantCount,
    this.isClosestAlternative = false,
    this.qualifiersPerGroup = 2,
    this.duration,
    this.boardCount = 1,
  });

  final String title;
  final List<PlannedStage> stages;
  final int minimumMatchesPerPlayer;
  final int totalMatches;
  final int estimatedMinutes;
  final int effectiveBoards;
  final int participantCount;
  final bool isClosestAlternative;
  final int qualifiersPerGroup;
  final PlanningDuration? duration;
  final int boardCount;
  TournamentGameFormat get format => stages.first.format;
  PlanningMatchBreakdown get matchBreakdown {
    final groups = stages.first.groupCount;
    return PlanningMatchBreakdown(
      groupSizes: List.generate(
        groups,
        (index) =>
            participantCount ~/ groups +
            (index < participantCount % groups ? 1 : 0),
      ),
      qualifiersPerGroup: qualifiersPerGroup,
    );
  }
}

class PlannedStage {
  const PlannedStage({
    required this.type,
    required this.groupCount,
    required this.format,
  });
  final String type;
  final int groupCount;
  final TournamentGameFormat format;
  String get label => type == 'groups'
      ? '$groupCount Gruppen (Jeder gegen jeden)'
      : 'K.-o.-Finalrunde';
}

/// Estimates dependencies per round. This prevents unrealistically counting
/// four boards for a 3-player group or a later knockout round.
class TournamentFormatPlanner {
  const TournamentFormatPlanner({
    this.parameters = const TournamentPlanningParameters(),
  });
  final TournamentPlanningParameters parameters;

  /// Formats are searched independently for each stage. Board scheduling is
  /// computed once per layout; only the duration of its blocks varies.
  List<TournamentFormatSuggestion> suggestFormats(
    TournamentPlanningRequest request,
  ) => _suggest(request, automatic: true);

  List<TournamentFormatSuggestion> suggest(TournamentPlanningRequest request) =>
      _suggest(request, automatic: false);

  List<TournamentFormatSuggestion> _suggest(
    TournamentPlanningRequest request, {
    required bool automatic,
  }) {
    if (request.players < 2 ||
        request.boards < 1 ||
        request.bestOfLegs < 1 ||
        (request.bestOfLegs.isEven && !request.allowDraws)) {
      return const [];
    }
    final limit = request.maximumGroups ?? parameters.maximumGroups;
    if (!PlanningParameter.maximumGroups.accepts(limit)) return const [];
    final candidates = <TournamentFormatSuggestion>[];
    final options = <TournamentGameFormat>[
      for (final score
          in request.x01Selection == 'variable_301_501'
              ? [301, 501]
              : [int.parse(request.x01Selection)])
        for (final sets in request.allowSets ? [1, 3, 5] : [1])
          for (final legs in [
            ...TournamentGameFormat.supportedBestOfLegs,
            if (request.allowDraws && sets == 1)
              ...TournamentGameFormat.supportedDrawLegs,
          ])
            if (sets == 1 || legs >= 3)
              TournamentGameFormat(
                x01Score: score,
                bestOfLegs: legs,
                bestOfSets: sets,
                checkoutType: request.checkoutType == 'double_in_out'
                    ? 'double_out'
                    : request.checkoutType,
                doubleIn: request.checkoutType == 'double_in_out',
              ),
    ];
    for (var groups = 1; groups <= min(request.players ~/ minimumPlayersPerGroup, limit); groups++) {
      final sizes = _balancedSizes(request.players, groups);
      final minimumGames = sizes.map((size) => size - 1).reduce(min);
      final effectiveBoards = min(
        request.boards,
        sizes.fold<int>(0, (total, size) => total + size ~/ 2),
      );
      final breakdown = PlanningMatchBreakdown(
        groupSizes: sizes,
        qualifiersPerGroup: parameters.qualifiersPerGroup,
      );
      final qualifiers = groups == 1
          ? 0
          : sizes.fold<int>(
              0,
              (sum, size) => sum + min(parameters.qualifiersPerGroup, size),
            );
      final slots = PlanningDuration.calculate(
        groupSizes: sizes,
        qualifiers: qualifiers,
        boards: request.boards,
        matchMinutes: 1,
      );
      final formats = automatic
          ? options
          : [_formatFor(request, sizes, qualifiers)];
      final finalFormats = !automatic && formats.single.allowsDraws
          ? [
              TournamentGameFormat(
                x01Score: formats.single.x01Score,
                bestOfLegs: formats.single.bestOfLegs + 1,
                checkoutType: formats.single.checkoutType,
                doubleIn: formats.single.doubleIn,
              ),
            ]
          : formats;
      for (final groupFormat in formats) {
        for (final finalFormat
            in qualifiers > 1 ? finalFormats : [groupFormat]) {
          if (qualifiers > 1 && finalFormat.allowsDraws) continue;
          if (!isPlanningFormatProgressionAllowed(groupFormat, finalFormat)) {
            continue;
          }
          final groupMatchMinutes = _matchMinutes(groupFormat);
          final finalMatchMinutes = _matchMinutes(finalFormat);
          // Later stages may be longer, while keeping early matches affordable.
          if (automatic && finalMatchMinutes < groupMatchMinutes) continue;
          final duration = PlanningDuration(
            groupSlots: slots.groupSlots,
            knockoutSlots: slots.knockoutSlots,
            matchMinutes: groupMatchMinutes,
            knockoutMatchMinutes: finalMatchMinutes,
          );
          final fits =
              minimumGames >= request.minimumMatchesPerPlayer &&
              duration.totalMinutes >= request.minimumMinutes &&
              duration.totalMinutes <= request.maximumMinutes;
          candidates.add(
            TournamentFormatSuggestion(
              title: groups == 1
                  ? 'Jeder gegen jeden'
                  : '$groups Gruppen mit K.-o.-Finale',
              stages: [
                PlannedStage(
                  type: 'groups',
                  groupCount: groups,
                  format: groupFormat,
                ),
                if (qualifiers > 1)
                  PlannedStage(
                    type: 'single_knockout',
                    groupCount: 0,
                    format: finalFormat,
                  ),
              ],
              minimumMatchesPerPlayer: minimumGames,
              totalMatches: breakdown.total,
              estimatedMinutes: duration.totalMinutes,
              duration: duration,
              effectiveBoards: effectiveBoards,
              boardCount: request.boards,
              participantCount: request.players,
              qualifiersPerGroup: parameters.qualifiersPerGroup,
              isClosestAlternative: !fits,
            ),
          );
        }
      }
    }
    final fitting = candidates.where((c) => _fits(c, request)).toList();
    final ranked = fitting.isEmpty ? candidates : fitting;
    ranked.sort((a, b) {
      final penalty = _penalty(a, request).compareTo(_penalty(b, request));
      if (penalty != 0) return penalty;
      final groups = a.stages.first.groupCount.compareTo(
        b.stages.first.groupCount,
      );
      if (groups != 0) return groups;
      final length = _matchMinutes(b.format).compareTo(_matchMinutes(a.format));
      if (length != 0) return length;
      // Prefer the simpler leg-only format when the time estimate is identical.
      return a.format.bestOfSets.compareTo(b.format.bestOfSets);
    });
    return ranked.take(parameters.maximumSuggestions).toList();
  }

  double _matchMinutes(TournamentGameFormat format) =>
      _legMinutes(format) * PlanningDuration.estimatedMatchLegs(format);

  bool _fits(
    TournamentFormatSuggestion suggestion,
    TournamentPlanningRequest request,
  ) =>
      suggestion.minimumMatchesPerPlayer >= request.minimumMatchesPerPlayer &&
      suggestion.estimatedMinutes >= request.minimumMinutes &&
      suggestion.estimatedMinutes <= request.maximumMinutes;

  int _penalty(
    TournamentFormatSuggestion suggestion,
    TournamentPlanningRequest request,
  ) {
    final missingGames = max(
      0,
      request.minimumMatchesPerPlayer - suggestion.minimumMatchesPerPlayer,
    );
    final tooShort = max(
      0,
      request.minimumMinutes - suggestion.estimatedMinutes,
    );
    final tooLong = max(
      0,
      suggestion.estimatedMinutes - request.maximumMinutes,
    );
    return missingGames * parameters.missingMatchPenalty +
        (tooShort + tooLong) * parameters.timeWindowPenalty +
        (suggestion.estimatedMinutes - request.maximumMinutes).abs() *
            parameters.targetDurationPenalty;
  }

  TournamentGameFormat _formatFor(
    TournamentPlanningRequest request,
    List<int> sizes,
    int qualifiers,
  ) {
    if (request.x01Selection != 'variable_301_501') {
      return TournamentGameFormat(
        x01Score: int.parse(request.x01Selection),
        bestOfLegs: request.bestOfLegs,
        checkoutType: request.checkoutType == 'double_in_out'
            ? 'double_out'
            : request.checkoutType,
        doubleIn: request.checkoutType == 'double_in_out',
      );
    }
    final format501 = TournamentGameFormat(
      x01Score: 501,
      bestOfLegs: request.bestOfLegs,
      checkoutType: request.checkoutType == 'double_in_out'
          ? 'double_out'
          : request.checkoutType,
      doubleIn: request.checkoutType == 'double_in_out',
    );
    final estimated501 = PlanningDuration.calculate(
      groupSizes: sizes,
      qualifiers: qualifiers,
      boards: request.boards,
      matchMinutes:
          _legMinutes(format501) *
          PlanningDuration.estimatedLegs(format501.bestOfLegs),
    ).totalMinutes;
    return estimated501 > request.maximumMinutes
        ? TournamentGameFormat(
            x01Score: 301,
            bestOfLegs: request.bestOfLegs,
            checkoutType: format501.checkoutType,
            doubleIn: format501.doubleIn,
          )
        : format501;
  }

  int _legMinutes(TournamentGameFormat format) {
    if (format.x01Score == 301 && format.checkoutType == 'double_out') {
      return parameters.minutes301DoubleOut;
    }
    if (format.x01Score == 501 && format.checkoutType == 'double_out') {
      return parameters.minutes501DoubleOut;
    }
    if (format.x01Score == 301 && format.checkoutType == 'single_out') {
      return parameters.minutes301SingleOut;
    }
    if (format.x01Score == 501 && format.checkoutType == 'single_out') {
      return parameters.minutes501SingleOut;
    }
    return format.checkoutType == 'single_out'
        ? parameters.fallbackSingleOutMinutes
        : parameters.fallbackOtherMinutes;
  }

  List<int> _balancedSizes(int players, int groups) => List.generate(
    groups,
    (index) => players ~/ groups + (index < players % groups ? 1 : 0),
  );
}
