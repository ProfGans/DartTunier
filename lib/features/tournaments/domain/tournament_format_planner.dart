import 'dart:math';

import 'tournament_models.dart';

class TournamentPlanningRequest {
  const TournamentPlanningRequest({
    required this.players,
    required this.boards,
    required this.minimumMatchesPerPlayer,
    required this.minimumMinutes,
    required this.maximumMinutes,
    required this.x01Selection,
    required this.checkoutType,
  });

  final int players;
  final int boards;
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
  });

  final String title;
  final List<PlannedStage> stages;
  final int minimumMatchesPerPlayer;
  final int totalMatches;
  final int estimatedMinutes;
  final int effectiveBoards;
  final int participantCount;
  final bool isClosestAlternative;
  TournamentGameFormat get format => stages.first.format;
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
  const TournamentFormatPlanner();

  List<TournamentFormatSuggestion> suggest(TournamentPlanningRequest request) {
    if (request.players < 2 || request.boards < 1) return const [];
    final candidates = <TournamentFormatSuggestion>[];
    for (var groups = 1; groups <= min(request.players, 4); groups++) {
      final sizes = _balancedSizes(request.players, groups);
      final minimumGames = sizes
          .map((size) => size - 1)
          .reduce((first, second) => first < second ? first : second);
      final groupRounds =
          sizes.map((size) => size.isEven ? size - 1 : size).reduce(max);
      final effectiveBoards = min(
        request.boards,
        groups * sizes.map((size) => size ~/ 2).reduce(max),
      ).toInt();
      final groupMatches = sizes
          .map((size) => size * (size - 1) ~/ 2)
          .fold<int>(0, (sum, value) => sum + value);
      final qualifierCount = groups == 1
          ? 0
          : sizes.map((size) => min(2, size)).fold<int>(0, (a, b) => a + b);
      final knockoutPlayers = qualifierCount < 2 ? 0 : _nextPowerOfTwo(qualifierCount);
      final knockoutMatches = knockoutPlayers == 0 ? 0 : knockoutPlayers - 1;
      final estimatedLegsPerMatch = 3;
      final format = _formatFor(request, groups, groupRounds, effectiveBoards, knockoutPlayers);
      final legMinutes = _legMinutes(format);
      final groupMinutes =
          (groupRounds * legMinutes * estimatedLegsPerMatch * groups / max(1, effectiveBoards)).ceil();
      final knockoutMinutes = _knockoutMinutes(
        knockoutPlayers,
        request.boards,
        legMinutes * estimatedLegsPerMatch,
      );
      candidates.add(TournamentFormatSuggestion(
        title: groups == 1
            ? 'Jeder gegen jeden'
            : '$groups Gruppen mit K.-o.-Finale',
        stages: [
          PlannedStage(type: 'groups', groupCount: groups, format: format),
          if (knockoutPlayers > 1)
            PlannedStage(type: 'single_knockout', groupCount: 0, format: format),
        ],
        minimumMatchesPerPlayer: minimumGames,
        totalMatches: groupMatches + knockoutMatches,
        estimatedMinutes: groupMinutes + knockoutMinutes,
        effectiveBoards: effectiveBoards,
        participantCount: request.players,
      ));
    }
    final fitting = candidates.where((candidate) => _fits(candidate, request)).toList();
    final source = fitting.isEmpty ? candidates : fitting;
    source.sort((a, b) => _penalty(a, request).compareTo(_penalty(b, request)));
    return [
      for (final candidate in source.take(3))
        TournamentFormatSuggestion(
          title: candidate.title,
          stages: candidate.stages,
          minimumMatchesPerPlayer: candidate.minimumMatchesPerPlayer,
          totalMatches: candidate.totalMatches,
          estimatedMinutes: candidate.estimatedMinutes,
          effectiveBoards: candidate.effectiveBoards,
          participantCount: candidate.participantCount,
          isClosestAlternative: fitting.isEmpty,
        ),
    ];
  }

  bool _fits(TournamentFormatSuggestion suggestion, TournamentPlanningRequest request) =>
      suggestion.minimumMatchesPerPlayer >= request.minimumMatchesPerPlayer &&
      suggestion.estimatedMinutes >= request.minimumMinutes &&
      suggestion.estimatedMinutes <= request.maximumMinutes;

  int _penalty(TournamentFormatSuggestion suggestion, TournamentPlanningRequest request) {
    final missingGames = max(0, request.minimumMatchesPerPlayer - suggestion.minimumMatchesPerPlayer);
    final tooShort = max(0, request.minimumMinutes - suggestion.estimatedMinutes);
    final tooLong = max(0, suggestion.estimatedMinutes - request.maximumMinutes);
    return missingGames * 10000 + (tooShort + tooLong) * 10 +
        (suggestion.estimatedMinutes - request.maximumMinutes).abs();
  }

  TournamentGameFormat _formatFor(
    TournamentPlanningRequest request,
    int groups,
    int rounds,
    int boards,
    int knockoutPlayers,
  ) {
    if (request.x01Selection != 'variable_301_501') {
      return TournamentGameFormat(
        x01Score: int.parse(request.x01Selection),
        checkoutType: request.checkoutType == 'double_in_out'
            ? 'double_out'
            : request.checkoutType,
        doubleIn: request.checkoutType == 'double_in_out',
      );
    }
    final format501 = TournamentGameFormat(
      x01Score: 501,
      checkoutType: request.checkoutType == 'double_in_out'
          ? 'double_out'
          : request.checkoutType,
      doubleIn: request.checkoutType == 'double_in_out',
    );
    final estimated501 = (rounds * _legMinutes(format501) * 3 * groups / max(1, boards)).ceil() +
        _knockoutMinutes(knockoutPlayers, boards, _legMinutes(format501) * 3);
    return estimated501 > request.maximumMinutes
        ? TournamentGameFormat(
            x01Score: 301,
            checkoutType: format501.checkoutType,
            doubleIn: format501.doubleIn,
          )
        : format501;
  }

  int _legMinutes(TournamentGameFormat format) {
    if (format.x01Score == 301 && format.checkoutType == 'double_out') return 8;
    if (format.x01Score == 501 && format.checkoutType == 'double_out') return 10;
    if (format.x01Score == 301 && format.checkoutType == 'single_out') return 5;
    if (format.x01Score == 501 && format.checkoutType == 'single_out') return 7;
    return format.checkoutType == 'single_out' ? 7 : 10;
  }

  int _knockoutMinutes(int players, int boards, int matchMinutes) {
    if (players < 2) return 0;
    var total = 0;
    for (var matches = players ~/ 2; matches >= 1; matches ~/= 2) {
      total += (matches / min(boards, matches)).ceil() * matchMinutes;
    }
    return total;
  }

  List<int> _balancedSizes(int players, int groups) => List.generate(
    groups,
    (index) => players ~/ groups + (index < players % groups ? 1 : 0),
  );

  int _nextPowerOfTwo(int value) {
    var result = 1;
    while (result < value) { result *= 2; }
    return result;
  }
}
