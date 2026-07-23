part of '../../../../tournament_workspace.dart';

class TournamentRunPage extends StatefulWidget {
  const TournamentRunPage({super.key, required this.tournament});

  final CreatedTournament tournament;

  @override
  State<TournamentRunPage> createState() => _TournamentRunPageState();
}

class _TournamentRunPageState extends State<TournamentRunPage> {
  int _activeStageIndex = 0;
  int _viewStageIndex = 0;
  StageViewMode _stageViewMode = StageViewMode.overview;
  bool _isBracketEditMode = false;
  bool _isApplyingStartDraw = false;
  final Set<int> _completedStageIndexes = {};
  final _runController = const TournamentRunController();

  @override
  void initState() {
    super.initState();
    _activeStageIndex = widget.tournament.activeStageIndex.clamp(
      0,
      widget.tournament.runStages.isEmpty
          ? 0
          : widget.tournament.runStages.length - 1,
    );
    _viewStageIndex = _activeStageIndex;
    _completedStageIndexes.addAll(widget.tournament.completedStageIndexes);
    _advanceKnockoutWinners();
    _ensureGroupDeciders();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyPendingStartDrawForActiveStage();
    });
  }

  Future<void> _saveTournamentProgress() async {
    await _runController.saveProgress(
      tournament: widget.tournament,
      activeStageIndex: _activeStageIndex,
      completedStageIndexes: _completedStageIndexes,
    );
  }

  Future<void> _editResult(GroupMatch match) async {
    final result = await showDialog<MatchResult>(
      context: context,
      builder: (context) => ResultDialog(match: match),
    );

    if (result == null) {
      return;
    }

    setState(() {
      match.isAnnulled = result.isAnnulled;
      if (result.isAnnulled) {
        match.homeLegs = null;
        match.awayLegs = null;
      } else {
        match.homeLegs = result.homeLegs;
        match.awayLegs = result.awayLegs;
      }
      _advanceKnockoutWinners();
      _ensureGroupDeciders();
    });
    await _saveTournamentProgress();
  }

  bool _canEditKnockoutBracket(KnockoutTournamentRunStage stage) {
    return stage.rounds.isNotEmpty &&
        stage.rounds.first.isNotEmpty &&
        stage.matches.every((match) => !match.hasScore && !match.isAnnulled);
  }

  Future<void> _swapKnockoutRunSlots(
    KnockoutTournamentRunStage stage,
    int fromSlotIndex,
    int toSlotIndex,
  ) async {
    if (!_canEditKnockoutBracket(stage) ||
        fromSlotIndex == toSlotIndex ||
        fromSlotIndex < 0 ||
        toSlotIndex < 0) {
      return;
    }

    final firstRound = stage.rounds.first;
    final maxSlotIndex = firstRound.length * 2 - 1;
    if (fromSlotIndex > maxSlotIndex || toSlotIndex > maxSlotIndex) {
      return;
    }

    setState(() {
      final fromPlayer = _playerAtFirstRoundSlot(firstRound, fromSlotIndex);
      final toPlayer = _playerAtFirstRoundSlot(firstRound, toSlotIndex);
      _setPlayerAtFirstRoundSlot(firstRound, fromSlotIndex, toPlayer);
      _setPlayerAtFirstRoundSlot(firstRound, toSlotIndex, fromPlayer);
      _clearKnockoutProgress(stage.rounds);
      _clearPlacementMatches(stage.placementMatches);
      _advanceKnockoutWinners();
    });
    await _saveTournamentProgress();
  }

  TournamentPlayer? _playerAtFirstRoundSlot(
    List<GroupMatch> firstRound,
    int slotIndex,
  ) {
    final match = firstRound[slotIndex ~/ 2];
    return slotIndex.isEven ? match.homePlayer : match.awayPlayer;
  }

  void _setPlayerAtFirstRoundSlot(
    List<GroupMatch> firstRound,
    int slotIndex,
    TournamentPlayer? player,
  ) {
    final match = firstRound[slotIndex ~/ 2];
    if (slotIndex.isEven) {
      match.homePlayer = player;
    } else {
      match.awayPlayer = player;
    }
  }

  void _clearKnockoutProgress(List<List<GroupMatch>> rounds) {
    for (var roundIndex = 0; roundIndex < rounds.length; roundIndex++) {
      for (final match in rounds[roundIndex]) {
        match.homeLegs = null;
        match.awayLegs = null;
        match.isAnnulled = false;
        if (roundIndex > 0) {
          match.homePlayer = null;
          match.awayPlayer = null;
        }
      }
    }
  }

  void _clearPlacementMatches(List<GroupMatch> matches) {
    for (final match in matches) {
      match.homePlayer = null;
      match.awayPlayer = null;
      match.homeLegs = null;
      match.awayLegs = null;
      match.isAnnulled = false;
    }
  }

  void _advanceKnockoutWinners() {
    for (final stage in widget.tournament.runStages) {
      if (stage is KnockoutTournamentRunStage) {
        if (stage.eliminationLossLimit == 2) {
          _advanceDoubleEliminationRounds(stage.rounds);
        } else if (stage.eliminationLossLimit == 3) {
          _advanceTripleEliminationRounds(stage.rounds);
        } else {
          _advanceWinnersInRounds(stage.rounds);
          _advancePlacementMatches(stage.rounds, stage.placementMatches);
        }
      }

      if (stage is GroupTournamentRunStage) {
        for (final group in stage.groups) {
          if (_isEliminationGroupPlayType(group.playType)) {
            if (group.eliminationLossLimit == 2) {
              _advanceDoubleEliminationRounds(group.knockoutRounds);
              group.matches
                ..clear()
                ..addAll([
                  for (final round in group.knockoutRounds) ...round,
                  ...group.placementMatches,
                ]);
              continue;
            }
            if (group.eliminationLossLimit == 3) {
              _advanceTripleEliminationRounds(group.knockoutRounds);
              group.matches
                ..clear()
                ..addAll([
                  for (final round in group.knockoutRounds) ...round,
                  ...group.placementMatches,
                ]);
              continue;
            }
            _advanceWinnersInRounds(group.knockoutRounds);
            _advancePlacementMatches(
              group.knockoutRounds,
              group.placementMatches,
            );
          }
        }
      }
    }
  }

  void _advanceWinnersInRounds(List<List<GroupMatch>> rounds) {
    for (var roundIndex = 0; roundIndex < rounds.length - 1; roundIndex++) {
      final currentRound = rounds[roundIndex];
      final nextRound = rounds[roundIndex + 1];
      for (var matchIndex = 0; matchIndex < currentRound.length; matchIndex++) {
        final winner = currentRound[matchIndex].winner;
        final targetMatch = nextRound[matchIndex ~/ 2];
        if (matchIndex.isEven) {
          if (targetMatch.homePlayer != winner) {
            targetMatch.homeLegs = null;
            targetMatch.awayLegs = null;
            targetMatch.isAnnulled = false;
          }
          targetMatch.homePlayer = winner;
        } else {
          if (targetMatch.awayPlayer != winner) {
            targetMatch.homeLegs = null;
            targetMatch.awayLegs = null;
            targetMatch.isAnnulled = false;
          }
          targetMatch.awayPlayer = winner;
        }
      }
    }
  }

  void _ensureGroupDeciders() {
    for (final stage in widget.tournament.runStages) {
      if (stage is! GroupTournamentRunStage) {
        continue;
      }

      for (var groupIndex = 0; groupIndex < stage.groups.length; groupIndex++) {
        final group = stage.groups[groupIndex];
        if (group.playType != 'round_robin') {
          continue;
        }
        _ensureDecidersForGroup(stage, group, groupIndex);
      }
      _ensureBestOfDecidersForStage(stage);
    }
  }

  void _ensureBestOfDecidersForStage(GroupTournamentRunStage stage) {
    final plan = stage.qualificationPlan;
    if (plan == null || plan.extraCount < 1 || plan.extraGroups.isEmpty) {
      return;
    }

    final candidates = _bestOfCandidatesForStage(stage);
    if (candidates.length <= plan.extraCount) {
      return;
    }

    for (final groupNumber in plan.extraGroups) {
      final groupIndex = groupNumber - 1;
      if (groupIndex < 0 || groupIndex >= stage.groups.length) {
        return;
      }
      final group = stage.groups[groupIndex];
      final baseMatches = group.matches.where(
        (match) => match.label != 'Beste-N Decider',
      );
      if (baseMatches.any((match) => match.hasPlayers && !match.isResolved)) {
        return;
      }
    }

    final sortedByTieBreakers = List<BestOfCandidate>.from(candidates)
      ..sort(
        (a, b) => _compareBestOfTieBreakersOnly(stage, a, b),
      );
    final boundaryIndex = plan.extraCount - 1;
    if (boundaryIndex < 0 || boundaryIndex >= sortedByTieBreakers.length) {
      return;
    }

    final boundaryCandidate = sortedByTieBreakers[boundaryIndex];
    final tiedAtBoundary = sortedByTieBreakers
        .where(
          (candidate) =>
              _compareBestOfTieBreakersOnly(stage, candidate, boundaryCandidate) ==
              0,
        )
        .toList();
    final firstTiedIndex = sortedByTieBreakers.indexWhere(
      (candidate) =>
          _compareBestOfTieBreakersOnly(stage, candidate, boundaryCandidate) == 0,
    );
    final lastTiedIndex = sortedByTieBreakers.lastIndexWhere(
      (candidate) =>
          _compareBestOfTieBreakersOnly(stage, candidate, boundaryCandidate) == 0,
    );

    if (tiedAtBoundary.length < 2 ||
        firstTiedIndex >= plan.extraCount ||
        lastTiedIndex < plan.extraCount) {
      return;
    }

    for (var first = 0; first < tiedAtBoundary.length; first++) {
      for (var second = first + 1; second < tiedAtBoundary.length; second++) {
        _addBestOfDeciderIfMissing(
          stage,
          tiedAtBoundary[first],
          tiedAtBoundary[second],
        );
      }
    }
  }

  List<BestOfCandidate> _bestOfCandidatesForStage(
    GroupTournamentRunStage stage,
  ) {
    final plan = stage.qualificationPlan;
    if (plan == null || plan.extraCount < 1) {
      return const [];
    }

    final candidates = <BestOfCandidate>[];
    for (var groupIndex = 0; groupIndex < stage.groups.length; groupIndex++) {
      final groupNumber = groupIndex + 1;
      if (!plan.extraGroups.contains(groupNumber)) {
        continue;
      }

      final group = stage.groups[groupIndex];
      if (group.playType != 'round_robin') {
        continue;
      }

      final candidateIndex = plan.extraRank - 1;
      final standings = _standingsFor(group, stage.tieBreakers);
      if (candidateIndex < 0 || candidateIndex >= standings.length) {
        continue;
      }

      candidates.add(
        BestOfCandidate(
          groupName: group.name,
          groupNumber: groupNumber,
          place: plan.extraRank,
          standing: standings[candidateIndex],
        ),
      );
    }

    return candidates;
  }

  int _compareBestOfTieBreakersOnly(
    GroupTournamentRunStage stage,
    BestOfCandidate a,
    BestOfCandidate b,
  ) {
    for (final tieBreaker in stage.tieBreakers) {
      final comparison = switch (tieBreaker) {
        'points' => b.standing.points.compareTo(a.standing.points),
        'legDifference' => b.standing.legDifference.compareTo(
          a.standing.legDifference,
        ),
        'legsFor' => b.standing.legsFor.compareTo(a.standing.legsFor),
        _ => 0,
      };

      if (comparison != 0) {
        return comparison;
      }
    }

    return 0;
  }

  int _compareBestOfCandidates(
    GroupTournamentRunStage stage,
    BestOfCandidate a,
    BestOfCandidate b,
  ) {
    final tieBreakerComparison = _compareBestOfTieBreakersOnly(stage, a, b);
    if (tieBreakerComparison != 0) {
      return tieBreakerComparison;
    }

    final deciderComparison = _compareBestOfDeciders(stage, a, b);
    if (deciderComparison != 0) {
      return deciderComparison;
    }

    final groupCompare = a.groupNumber.compareTo(b.groupNumber);
    if (groupCompare != 0) {
      return groupCompare;
    }
    return a.standing.player.name.compareTo(b.standing.player.name);
  }

  int _compareBestOfDeciders(
    GroupTournamentRunStage stage,
    BestOfCandidate a,
    BestOfCandidate b,
  ) {
    for (final group in stage.groups) {
      for (final match in group.matches.where(
        (match) =>
            match.isDecider &&
            match.label == 'Beste-N Decider' &&
            match.hasResult,
      )) {
        final home = match.homePlayer;
        final away = match.awayPlayer;
        if (home == null || away == null || match.winner == null) {
          continue;
        }
        final isDirectMatch =
            (home.name == a.standing.player.name &&
                away.name == b.standing.player.name) ||
            (home.name == b.standing.player.name &&
                away.name == a.standing.player.name);
        if (!isDirectMatch) {
          continue;
        }
        return match.winner!.name == a.standing.player.name ? -1 : 1;
      }
    }

    return 0;
  }

  void _addBestOfDeciderIfMissing(
    GroupTournamentRunStage stage,
    BestOfCandidate first,
    BestOfCandidate second,
  ) {
    final alreadyExists = stage.groups.any((group) {
      return group.matches.any((match) {
        if (!match.isDecider || match.label != 'Beste-N Decider') {
          return false;
        }
        final home = match.homePlayer;
        final away = match.awayPlayer;
        return (home == first.standing.player && away == second.standing.player) ||
            (home == second.standing.player && away == first.standing.player);
      });
    });
    if (alreadyExists) {
      return;
    }

    final homeGroupIndex = first.groupNumber - 1;
    if (homeGroupIndex < 0 || homeGroupIndex >= stage.groups.length) {
      return;
    }

    final homeGroup = stage.groups[homeGroupIndex];
    homeGroup.matches.add(
      GroupMatch(
        homePlayer: first.standing.player,
        awayPlayer: second.standing.player,
        round: _nextDeciderRound(homeGroup),
        label: 'Beste-N Decider',
        isDecider: true,
      ),
    );
  }

  void _advanceDoubleEliminationRounds(List<List<GroupMatch>> rounds) {
    _repairDoubleEliminationRoundsIfNeeded(rounds);

    final winnersRoundCount = _doubleWinnersRoundCount(rounds);
    final losersRoundCount = _doubleLosersRoundCount(rounds);
    if (winnersRoundCount == 0 || losersRoundCount == 0) {
      return;
    }

    for (var roundNumber = 1; roundNumber <= winnersRoundCount; roundNumber++) {
      final currentWinnersRound = _doubleWinnersRoundMatches(
        rounds,
        roundNumber,
        includeAutoAdvances: roundNumber == 1,
      );
      if (currentWinnersRound.isEmpty) {
        continue;
      }

      if (roundNumber < winnersRoundCount) {
        final nextWinnersRound = _doubleWinnersRoundMatches(
          rounds,
          roundNumber + 1,
        );
        _advancePairedWinners(currentWinnersRound, nextWinnersRound);
      }

      final targetLosersRoundNumber = roundNumber == 1
          ? 1
          : roundNumber == winnersRoundCount
              ? losersRoundCount
              : roundNumber * 2 - 2;
      final targetLosersRound = _matchesWithLabel(
        rounds,
        _doubleLosersLabel(targetLosersRoundNumber),
      );
      if (roundNumber == 1) {
        _dropFirstWinnersLosersToInitialLosersRound(
          currentWinnersRound,
          targetLosersRound,
        );
      } else {
        _dropWinnersLosersToLosersRound(
          currentWinnersRound,
          targetLosersRound,
        );
      }
    }

    for (var roundNumber = 1; roundNumber < losersRoundCount; roundNumber++) {
      final currentLosersRound = _matchesWithLabel(
        rounds,
        _doubleLosersLabel(roundNumber),
      );
      final nextLosersRound = _matchesWithLabel(
        rounds,
        _doubleLosersLabel(roundNumber + 1),
      );
      if (currentLosersRound.isEmpty || nextLosersRound.isEmpty) {
        continue;
      }

      if (nextLosersRound.length == currentLosersRound.length) {
        for (var index = 0; index < currentLosersRound.length; index++) {
          _setMatchHomePlayer(nextLosersRound[index], currentLosersRound[index].winner);
        }
      } else {
        _advancePairedWinners(currentLosersRound, nextLosersRound);
      }
    }

    final grandFinal = _matchesWithLabel(rounds, _doubleGrandFinalLabel);
    if (grandFinal.isEmpty) {
      return;
    }

    final winnersFinal = _matchesWithLabel(
      rounds,
      _doubleWinnersLabel(winnersRoundCount),
    );
    final losersFinal = _matchesWithLabel(
      rounds,
      _doubleLosersLabel(losersRoundCount),
    );
    _setMatchHomePlayer(
      grandFinal.first,
      winnersFinal.isEmpty ? null : winnersFinal.first.winner,
    );
    _setMatchAwayPlayer(
      grandFinal.first,
      losersFinal.isEmpty ? null : losersFinal.first.winner,
    );

    if (grandFinal.first.hasResult &&
        grandFinal.first.winner == grandFinal.first.awayPlayer &&
        _matchesWithLabel(rounds, _doubleResetFinalLabel).isEmpty) {
      rounds.add([
        GroupMatch(
          round: rounds.length + 1,
          label: _doubleResetFinalLabel,
          homePlayer: grandFinal.first.homePlayer,
          awayPlayer: grandFinal.first.awayPlayer,
        ),
      ]);
    }
  }

  void _advanceTripleEliminationRounds(List<List<GroupMatch>> rounds) {
    _repairTripleEliminationRoundsIfNeeded(rounds);

    _advanceLossLevelWinners(rounds, 0);
    _dropLossLevelLosersToNextLossLevel(rounds, 0);
    _advanceLossLevelWinners(rounds, 1);
    _dropLossLevelLosersToNextLossLevel(rounds, 1);
    _advanceLossLevelWinners(rounds, 2);

    final finalMatches = _matchesWithLabel(rounds, _tripleFinalLabel);
    if (finalMatches.isEmpty) {
      return;
    }

    final winnersFinal = _matchesWithLabel(
      rounds,
      _lossLevelMatchLabel(0, _lossLevelRoundCount(rounds, 0)),
    );
    final oneLossFinal = _matchesWithLabel(
      rounds,
      _lossLevelMatchLabel(1, _lossLevelRoundCount(rounds, 1)),
    );
    final twoLossFinal = _matchesWithLabel(
      rounds,
      _lossLevelMatchLabel(2, _lossLevelRoundCount(rounds, 2)),
    );

    _setMatchHomePlayer(
      finalMatches.first,
      winnersFinal.isEmpty ? null : winnersFinal.first.winner,
    );
    _setMatchAwayPlayer(
      finalMatches.first,
      twoLossFinal.isNotEmpty && twoLossFinal.first.winner != null
          ? twoLossFinal.first.winner
          : oneLossFinal.isEmpty
              ? null
              : oneLossFinal.first.winner,
    );
  }

  void _repairTripleEliminationRoundsIfNeeded(List<List<GroupMatch>> rounds) {
    if (rounds.isEmpty || rounds.first.isEmpty) {
      return;
    }

    if (_matchesWithLabel(rounds, _lossLevelMatchLabel(1, 1)).isNotEmpty &&
        _matchesWithLabel(rounds, _lossLevelMatchLabel(2, 1)).isNotEmpty &&
        _matchesWithLabel(rounds, _tripleFinalLabel).isNotEmpty) {
      return;
    }

    final repairedRounds = _buildTripleEliminationRoundsFromFirstRound(
      rounds.first,
    );
    rounds
      ..clear()
      ..addAll(repairedRounds);
  }

  void _advanceLossLevelWinners(
    List<List<GroupMatch>> rounds,
    int lossCount,
  ) {
    final roundCount = _lossLevelRoundCount(rounds, lossCount);
    for (var roundNumber = 2; roundNumber <= roundCount; roundNumber++) {
      final previous = lossCount == 0 && roundNumber == 2
          ? _lossLevelMatches(
              rounds,
              lossCount,
              roundNumber - 1,
              includeAutoAdvances: true,
            )
          : _lossLevelMatches(rounds, lossCount, roundNumber - 1);
      final current = _lossLevelMatches(rounds, lossCount, roundNumber);
      if (previous.isEmpty || current.isEmpty) {
        continue;
      }

      if (current.length == previous.length) {
        for (var index = 0; index < current.length; index++) {
          _setMatchHomePlayer(current[index], previous[index].winner);
        }
      } else {
        _advancePairedWinners(previous, current);
      }
    }
  }

  void _dropLossLevelLosersToNextLossLevel(
    List<List<GroupMatch>> rounds,
    int sourceLossCount,
  ) {
    final targetLossCount = sourceLossCount + 1;
    final sourceRoundCount = _lossLevelRoundCount(rounds, sourceLossCount);
    final targetRoundCount = _lossLevelRoundCount(rounds, targetLossCount);
    if (sourceRoundCount == 0 || targetRoundCount == 0) {
      return;
    }

    for (var roundNumber = 1; roundNumber <= sourceRoundCount; roundNumber++) {
      final sourceRound = _lossLevelMatches(
        rounds,
        sourceLossCount,
        roundNumber,
        includeAutoAdvances: sourceLossCount == 0 && roundNumber == 1,
      );
      if (sourceRound.isEmpty) {
        continue;
      }

      final targetRoundNumber = roundNumber == 1
          ? 1
          : roundNumber == sourceRoundCount
              ? targetRoundCount
              : roundNumber * 2 - 2;
      final targetRound = _lossLevelMatches(
        rounds,
        targetLossCount,
        targetRoundNumber,
      );
      if (targetRound.isEmpty) {
        continue;
      }

      if (roundNumber == 1) {
        _dropFirstWinnersLosersToInitialLosersRound(sourceRound, targetRound);
      } else {
        _dropWinnersLosersToLosersRound(sourceRound, targetRound);
      }
    }
  }

  List<GroupMatch> _lossLevelMatches(
    List<List<GroupMatch>> rounds,
    int lossCount,
    int roundNumber, {
    bool includeAutoAdvances = false,
  }) {
    if (lossCount == 0 &&
        roundNumber == 1 &&
        includeAutoAdvances &&
        rounds.isNotEmpty) {
      return rounds.first;
    }
    return _matchesWithLabel(rounds, _lossLevelMatchLabel(lossCount, roundNumber));
  }

  void _repairDoubleEliminationRoundsIfNeeded(List<List<GroupMatch>> rounds) {
    if (!_doubleEliminationRoundsNeedRepair(rounds)) {
      return;
    }

    final repairedRounds = _buildDoubleEliminationRoundsFromFirstRound(
      rounds.first,
    );
    rounds
      ..clear()
      ..addAll(repairedRounds);
  }

  void _advancePairedWinners(
    List<GroupMatch> currentRound,
    List<GroupMatch> nextRound,
  ) {
    for (var matchIndex = 0; matchIndex < currentRound.length; matchIndex++) {
      final winner = currentRound[matchIndex].winner;
      if (winner == null || nextRound.isEmpty) {
        continue;
      }

      final targetIndex = matchIndex ~/ 2;
      if (targetIndex >= nextRound.length) {
        continue;
      }

      final targetMatch = nextRound[targetIndex];
      if (matchIndex.isEven) {
        _setMatchHomePlayer(targetMatch, winner);
      } else {
        _setMatchAwayPlayer(targetMatch, winner);
      }
    }
  }

  void _dropFirstWinnersLosersToInitialLosersRound(
    List<GroupMatch> winnersRound,
    List<GroupMatch> losersRound,
  ) {
    final losers = <TournamentPlayer>[];
    for (final match in winnersRound) {
      final loser = match.loser;
      if (loser == null || losers.any((entry) => entry.name == loser.name)) {
        continue;
      }
      losers.add(loser);
    }

    for (var matchIndex = 0; matchIndex < losersRound.length; matchIndex++) {
      _setMatchPlayers(losersRound[matchIndex], null, null);
    }

    if (losers.length <= losersRound.length) {
      for (var index = 0; index < losers.length; index++) {
        final targetIndex = (index * losersRound.length) ~/ losers.length;
        _setMatchPlayers(losersRound[targetIndex], losers[index], null);
      }
      return;
    }

    for (var index = 0; index < losers.length; index++) {
      var targetIndex = (index * losersRound.length) ~/ losers.length;
      while (targetIndex < losersRound.length &&
          losersRound[targetIndex].homePlayer != null &&
          losersRound[targetIndex].awayPlayer != null) {
        targetIndex++;
      }
      if (targetIndex >= losersRound.length) {
        break;
      }
      final targetMatch = losersRound[targetIndex];
      if (targetMatch.homePlayer == null) {
        _setMatchHomePlayer(targetMatch, losers[index]);
      } else {
        _setMatchAwayPlayer(targetMatch, losers[index]);
      }
    }
  }

  void _dropWinnersLosersToLosersRound(
    List<GroupMatch> winnersRound,
    List<GroupMatch> losersRound,
  ) {
    for (var matchIndex = 0; matchIndex < winnersRound.length; matchIndex++) {
      final loser = winnersRound[matchIndex].loser;
      if (loser == null || matchIndex >= losersRound.length) {
        continue;
      }
      _setMatchAwayPlayer(losersRound[matchIndex], loser);
    }
  }

  void _setMatchHomePlayer(GroupMatch match, TournamentPlayer? player) {
    if (match.homePlayer != player) {
      match.homeLegs = null;
      match.awayLegs = null;
      match.isAnnulled = false;
    }
    match.homePlayer = player;
  }

  void _setMatchAwayPlayer(GroupMatch match, TournamentPlayer? player) {
    if (match.awayPlayer != player) {
      match.homeLegs = null;
      match.awayLegs = null;
      match.isAnnulled = false;
    }
    match.awayPlayer = player;
  }

  List<TournamentPlayer> _playersInEliminationRounds(
    List<List<GroupMatch>> rounds,
  ) {
    final players = <TournamentPlayer>[];
    void add(TournamentPlayer? player) {
      if (player == null || players.any((entry) => entry.name == player.name)) {
        return;
      }
      players.add(player);
    }

    for (final round in rounds) {
      for (final match in round) {
        add(match.homePlayer);
        add(match.awayPlayer);
      }
    }

    return players;
  }

  Map<String, int> _lossCountsForElimination(List<List<GroupMatch>> rounds) {
    final losses = <String, int>{};
    for (final player in _playersInEliminationRounds(rounds)) {
      losses[player.name] = 0;
    }

    for (final round in rounds) {
      for (final match in round.where((match) => match.hasResult)) {
        final loser = match.loser;
        if (loser != null) {
          losses[loser.name] = (losses[loser.name] ?? 0) + 1;
        }
      }
    }

    return losses;
  }

  List<TournamentPlayer> _activeEliminationPlayers(
    List<List<GroupMatch>> rounds,
    int lossLimit,
  ) {
    final losses = _lossCountsForElimination(rounds);
    return [
      for (final player in _playersInEliminationRounds(rounds))
        if ((losses[player.name] ?? 0) < lossLimit) player,
    ];
  }

  void _ensureDecidersForGroup(
    GroupTournamentRunStage stage,
    TournamentGroup group,
    int groupIndex,
  ) {
    final regularMatches = group.matches
        .where((match) => !match.isDecider)
        .toList();
    if (regularMatches.any((match) => match.hasPlayers && !match.isResolved)) {
      return;
    }

    final standings = _standingsFor(group, stage.tieBreakers);
    final relevantPlaces = _relevantPlacesForDeciders(stage, groupIndex);
    if (relevantPlaces.isEmpty) {
      return;
    }

    for (final place in relevantPlaces) {
      final index = place - 1;
      if (index < 0 || index >= standings.length) {
        continue;
      }

      final tied = <PlayerStanding>[standings[index]];
      for (var above = index - 1; above >= 0; above--) {
        if (_compareTieBreakersOnly(
              standings[index],
              standings[above],
              stage.tieBreakers,
              group.matches,
            ) !=
            0) {
          break;
        }
        tied.add(standings[above]);
      }
      for (var below = index + 1; below < standings.length; below++) {
        if (_compareTieBreakersOnly(
              standings[index],
              standings[below],
              stage.tieBreakers,
              group.matches,
            ) !=
            0) {
          break;
        }
        tied.add(standings[below]);
      }

      if (tied.length < 2) {
        continue;
      }

      for (var first = 0; first < tied.length; first++) {
        for (var second = first + 1; second < tied.length; second++) {
          _addDeciderIfMissing(
            group,
            tied[first].player,
            tied[second].player,
          );
        }
      }
    }
  }

  Set<int> _relevantPlacesForDeciders(
    GroupTournamentRunStage stage,
    int groupIndex,
  ) {
    final plan = stage.qualificationPlan;
    if (plan == null) {
      return const {};
    }

    final fixedForGroup = groupIndex < plan.fixedByGroup.length
        ? plan.fixedByGroup[groupIndex]
        : plan.fixedPerGroup;
    final groupNumber = groupIndex + 1;
    return {
      for (var place = 1; place <= fixedForGroup; place++) place,
      if (plan.extraGroups.contains(groupNumber)) plan.extraRank,
    };
  }

  int _compareTieBreakersOnly(
    PlayerStanding a,
    PlayerStanding b,
    List<String> tieBreakers,
    List<GroupMatch> matches,
  ) {
    for (final tieBreaker in tieBreakers) {
      final comparison = switch (tieBreaker) {
        'points' => b.points.compareTo(a.points),
        'legDifference' => b.legDifference.compareTo(a.legDifference),
        'legsFor' => b.legsFor.compareTo(a.legsFor),
        'headToHead' => _compareHeadToHead(a, b, matches),
        _ => 0,
      };

      if (comparison != 0) {
        return comparison;
      }
    }

    return 0;
  }

  void _addDeciderIfMissing(
    TournamentGroup group,
    TournamentPlayer first,
    TournamentPlayer second,
  ) {
    final alreadyExists = group.matches.any((match) {
      if (!match.isDecider) {
        return false;
      }
      final home = match.homePlayer;
      final away = match.awayPlayer;
      return (home == first && away == second) || (home == second && away == first);
    });
    if (alreadyExists) {
      return;
    }

    group.matches.add(
      GroupMatch(
        homePlayer: first,
        awayPlayer: second,
        round: _nextDeciderRound(group),
        label: 'Decider',
        isDecider: true,
      ),
    );
  }

  int _nextDeciderRound(TournamentGroup group) {
    final highestRound = group.matches.fold<int>(
      0,
      (highest, match) => match.round > highest ? match.round : highest,
    );
    return highestRound + 1;
  }

  void _advancePlacementMatches(
    List<List<GroupMatch>> rounds,
    List<GroupMatch> placementMatches,
  ) {
    if (rounds.length >= 2 && placementMatches.isNotEmpty) {
      final semifinalRound = rounds.last.length >= 2
          ? rounds.last
          : rounds[rounds.length - 2];
      final semifinalLosers = semifinalRound
          .map((match) => match.loser)
          .whereType<TournamentPlayer>()
          .toList();
      final thirdPlaceMatches = placementMatches
          .where((match) => match.label == 'Spiel um Platz 3')
          .toList();
      final thirdPlaceMatch = thirdPlaceMatches.isEmpty
          ? null
          : thirdPlaceMatches.first;
      if (thirdPlaceMatch != null && semifinalLosers.length >= 2) {
        _setMatchPlayers(
          thirdPlaceMatch,
          semifinalLosers[0],
          semifinalLosers[1],
        );
      }
    }

    final fifthSemis = placementMatches
        .where(
          (match) => match.label?.startsWith('Platz 5 Halbfinale') ?? false,
        )
        .toList();
    if (fifthSemis.isNotEmpty) {
      final quarterfinalRound = rounds.last.length >= 4
          ? rounds.last
          : rounds.length >= 3
          ? rounds[rounds.length - 3]
          : const <GroupMatch>[];
      final quarterfinalLosers = quarterfinalRound
          .map((match) => match.loser)
          .whereType<TournamentPlayer>()
          .toList();
      if (quarterfinalLosers.length >= 4 && fifthSemis.length >= 2) {
        _setMatchPlayers(
          fifthSemis[0],
          quarterfinalLosers[0],
          quarterfinalLosers[1],
        );
        _setMatchPlayers(
          fifthSemis[1],
          quarterfinalLosers[2],
          quarterfinalLosers[3],
        );
      }

      final fifthFinalMatches = placementMatches
          .where((match) => match.label == 'Spiel um Platz 5')
          .toList();
      final fifthFinal = fifthFinalMatches.isEmpty
          ? null
          : fifthFinalMatches.first;
      if (fifthFinal != null && fifthSemis.length >= 2) {
        _setMatchPlayers(fifthFinal, fifthSemis[0].winner, fifthSemis[1].winner);
      }

      final seventhPlaceMatches = placementMatches
          .where((match) => match.label == 'Spiel um Platz 7')
          .toList();
      if (seventhPlaceMatches.isNotEmpty && fifthSemis.length >= 2) {
        _setMatchPlayers(
          seventhPlaceMatches.first,
          fifthSemis[0].loser,
          fifthSemis[1].loser,
        );
      }
    }
  }

  void _setMatchPlayers(
    GroupMatch match,
    TournamentPlayer? homePlayer,
    TournamentPlayer? awayPlayer,
  ) {
    if (match.homePlayer != homePlayer || match.awayPlayer != awayPlayer) {
      match.homeLegs = null;
      match.awayLegs = null;
      match.isAnnulled = false;
    }
    match.homePlayer = homePlayer;
    match.awayPlayer = awayPlayer;
  }

  List<PlayerStanding> _standingsFor(
    TournamentGroup group,
    List<String> tieBreakers,
  ) {
    final standings = {
      for (final player in group.players) player.name: PlayerStanding(player),
    };

    for (final match in group.matches.where(
      (match) => match.hasResult && !match.isDecider,
    )) {
      final homePlayer = match.homePlayer!;
      final awayPlayer = match.awayPlayer!;
      final home = standings[homePlayer.name]!;
      final away = standings[awayPlayer.name]!;
      final homeLegs = match.homeLegs!;
      final awayLegs = match.awayLegs!;

      home.played++;
      home.legsFor += homeLegs;
      home.legsAgainst += awayLegs;
      away.played++;
      away.legsFor += awayLegs;
      away.legsAgainst += homeLegs;

      if (homeLegs > awayLegs) {
        home.wins++;
        home.points += 3;
        away.losses++;
      } else if (awayLegs > homeLegs) {
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
      final comparison = _compareStandings(
        a,
        b,
        tieBreakers,
        matches: group.matches,
      );
      if (comparison != 0) {
        return comparison;
      }
      return a.player.name.compareTo(b.player.name);
    });

    return sorted;
  }

  int _compareStandings(
    PlayerStanding a,
    PlayerStanding b,
    List<String> tieBreakers, {
    List<GroupMatch> matches = const [],
  }) {
    for (final tieBreaker in tieBreakers) {
      final comparison = switch (tieBreaker) {
        'points' => b.points.compareTo(a.points),
        'legDifference' => b.legDifference.compareTo(a.legDifference),
        'legsFor' => b.legsFor.compareTo(a.legsFor),
        'headToHead' => _compareHeadToHead(a, b, matches),
        _ => 0,
      };

      if (comparison != 0) {
        return comparison;
      }
    }

    return _compareDecider(a, b, matches);
  }

  int _compareDecider(
    PlayerStanding a,
    PlayerStanding b,
    List<GroupMatch> matches,
  ) {
    for (final match in matches.where((match) => match.isDecider && match.hasResult)) {
      final home = match.homePlayer!;
      final away = match.awayPlayer!;
      final isDirectMatch =
          (home.name == a.player.name && away.name == b.player.name) ||
          (home.name == b.player.name && away.name == a.player.name);
      if (!isDirectMatch || match.winner == null) {
        continue;
      }
      return match.winner!.name == a.player.name ? -1 : 1;
    }

    return 0;
  }

  int _compareHeadToHead(
    PlayerStanding a,
    PlayerStanding b,
    List<GroupMatch> matches,
  ) {
    var aPoints = 0;
    var bPoints = 0;
    var aLegs = 0;
    var bLegs = 0;

    for (final match in matches.where(
      (match) => match.hasResult && !match.isDecider,
    )) {
      final home = match.homePlayer!;
      final away = match.awayPlayer!;
      final isDirectMatch =
          (home.name == a.player.name && away.name == b.player.name) ||
          (home.name == b.player.name && away.name == a.player.name);
      if (!isDirectMatch) {
        continue;
      }

      final aIsHome = home.name == a.player.name;
      final aMatchLegs = aIsHome ? match.homeLegs! : match.awayLegs!;
      final bMatchLegs = aIsHome ? match.awayLegs! : match.homeLegs!;
      aLegs += aMatchLegs;
      bLegs += bMatchLegs;

      if (aMatchLegs > bMatchLegs) {
        aPoints += 3;
      } else if (bMatchLegs > aMatchLegs) {
        bPoints += 3;
      } else {
        aPoints++;
        bPoints++;
      }
    }

    final pointCompare = bPoints.compareTo(aPoints);
    if (pointCompare != 0) return pointCompare;
    final diffCompare = (bLegs - aLegs).compareTo(aLegs - bLegs);
    if (diffCompare != 0) return diffCompare;
    return bLegs.compareTo(aLegs);
  }

  bool _stageHasOpenMatches(TournamentRunStage stage) {
    if (stage is KnockoutTournamentRunStage) {
      return !_knockoutHasWinner(stage) || _hasOpenPlacementMatches(stage.placementMatches);
    }
    if (stage is GroupTournamentRunStage) {
      return stage.groups.any((group) {
        if (_isEliminationGroupPlayType(group.playType)) {
          final groupIndex = stage.groups.indexOf(group);
          return !_eliminationGroupQualifiersKnown(stage, group, groupIndex);
        }

        return group.matches.any((match) => !match.isResolved);
      });
    }

    return _matchesForStage(stage).any((match) => !match.isResolved);
  }

  bool _hasOpenPlacementMatches(List<GroupMatch> matches) {
    return matches.any((match) => match.hasPlayers && !match.isResolved);
  }

  bool _knockoutHasWinner(KnockoutTournamentRunStage stage) {
    if (stage.eliminationLossLimit > 1) {
      return stage.rounds.isNotEmpty &&
          stage.rounds.last.every((match) => match.isResolved) &&
          _activeEliminationPlayers(
                stage.rounds,
                stage.eliminationLossLimit,
              ).length <=
              1;
    }

    return stage.rounds.isNotEmpty &&
        stage.rounds.last.length == 1 &&
        stage.rounds.last.first.winner != null;
  }

  bool _eliminationGroupQualifiersKnown(
    GroupTournamentRunStage stage,
    TournamentGroup group,
    int groupIndex,
  ) {
    final requiredRank = _requiredRankForGroupStage(stage, groupIndex);
    if (requiredRank >= group.players.length) {
      return true;
    }
    if (group.knockoutRounds.isEmpty) {
      return false;
    }

    if (group.eliminationLossLimit > 1) {
      return _activeEliminationPlayers(
            group.knockoutRounds,
            group.eliminationLossLimit,
          ).length <=
          requiredRank;
    }

    return group.knockoutRounds.last.every((match) => match.isResolved) &&
        !_hasOpenPlacementMatches(group.placementMatches);
  }

  int _requiredRankForGroupStage(GroupTournamentRunStage stage, int groupIndex) {
    final plan = stage.qualificationPlan;
    if (plan == null) {
      return 1;
    }

    final fixedForGroup = groupIndex >= 0 && groupIndex < plan.fixedByGroup.length
        ? plan.fixedByGroup[groupIndex]
        : plan.fixedPerGroup;
    final groupNumber = groupIndex + 1;
    final extraRank = plan.extraGroups.contains(groupNumber)
        ? plan.extraRank
        : 0;
    final requiredRank = fixedForGroup > extraRank ? fixedForGroup : extraRank;
    return requiredRank < 1 ? 1 : requiredRank;
  }

  List<GroupMatch> _matchesForStage(TournamentRunStage stage) {
    if (stage is GroupTournamentRunStage) {
      return [for (final group in stage.groups) ...group.matches];
    }
    if (stage is KnockoutTournamentRunStage) {
      return stage.matches;
    }

    return const [];
  }

  int _requiredRankForRunStage(int stageIndex) {
    if (stageIndex >= widget.tournament.stages.length - 1) {
      return 1;
    }

    final stage = widget.tournament.runStages[stageIndex];
    final availablePlayers = _participantCountForRunStage(stage);
    final nextStage = widget.tournament.stages[stageIndex + 1];
    final requiredPlayers = nextStage.type == 'groups'
        ? nextStage.groupSizes.fold<int>(0, (sum, size) => sum + size)
        : nextStage.knockoutParticipantCount ?? availablePlayers;
    return requiredPlayers.clamp(1, availablePlayers).toInt();
  }

  int _participantCountForRunStage(TournamentRunStage stage) {
    if (stage is KnockoutTournamentRunStage) {
      if (stage.rounds.isEmpty) {
        return 0;
      }
      return stage.rounds.first.fold<int>(
        0,
        (sum, match) =>
            sum +
            (match.homePlayer == null ? 0 : 1) +
            (match.awayPlayer == null ? 0 : 1),
      );
    }
    if (stage is GroupTournamentRunStage) {
      return stage.groups.fold<int>(
        0,
        (sum, group) => sum + group.players.length,
      );
    }
    return 0;
  }

  List<TournamentPlayer> _advancingPlayersFromStage(TournamentRunStage stage) {
    if (stage is GroupTournamentRunStage) {
      return _advancingPlayersFromGroupStage(stage);
    }

    if (stage is KnockoutTournamentRunStage) {
      if (stage.eliminationLossLimit > 1) {
        return _multiEliminationRanking(
          stage.rounds,
          stage.eliminationLossLimit,
          fallbackPlayers: const [],
        );
      }
      return _knockoutRanking(
        stage.rounds,
        stage.placementMatches,
        fallbackPlayers: const [],
      );
    }

    return const [];
  }

  TournamentRunStage _stageForView(int stageIndex) {
    if (stageIndex <= _activeStageIndex) {
      return widget.tournament.runStages[stageIndex];
    }

    var incomingPlayers = _advancingPlayersFromStage(
      widget.tournament.runStages[_activeStageIndex],
    );
    late TournamentRunStage previewStage;

    for (
      var index = _activeStageIndex + 1;
      index <= stageIndex && index < widget.tournament.stages.length;
      index++
    ) {
      previewStage = _buildRunStageFromPlayers(
        widget.tournament.stages[index],
        incomingPlayers,
      );
      if (index < stageIndex) {
        incomingPlayers = _advancingPlayersFromStage(previewStage);
      }
    }

    return previewStage;
  }

  List<TournamentPlayer> _advancingPlayersFromGroupStage(
    GroupTournamentRunStage stage,
  ) {
    if (stage.groups.any((group) => _isEliminationGroupPlayType(group.playType))) {
      return _advancingPlayersFromMixedGroups(stage);
    }

    final plan = stage.qualificationPlan;
    if (plan == null) {
      return [
        for (final group in stage.groups)
          for (final standing in _standingsFor(group, stage.tieBreakers))
            standing.player,
      ];
    }

    final advancingPlayers = <TournamentPlayer>[];
    final extraCandidates = <BestOfCandidate>[];

    for (var groupIndex = 0; groupIndex < stage.groups.length; groupIndex++) {
      final groupNumber = groupIndex + 1;
      final standings = _standingsFor(
        stage.groups[groupIndex],
        stage.tieBreakers,
      );

      final fixedForGroup = groupIndex < plan.fixedByGroup.length
          ? plan.fixedByGroup[groupIndex]
          : plan.fixedPerGroup;
      advancingPlayers.addAll(
        standings.take(fixedForGroup).map((standing) => standing.player),
      );

      final extraIndex = plan.extraRank - 1;
      if (plan.extraGroups.contains(groupNumber) &&
          extraIndex >= 0 &&
          extraIndex < standings.length) {
        extraCandidates.add(
          BestOfCandidate(
            groupName: stage.groups[groupIndex].name,
            groupNumber: groupNumber,
            place: plan.extraRank,
            standing: standings[extraIndex],
          ),
        );
      }
    }

    extraCandidates.sort((a, b) => _compareBestOfCandidates(stage, a, b));
    advancingPlayers.addAll(
      extraCandidates
          .take(plan.extraCount)
          .map((candidate) => candidate.standing.player),
    );

    return advancingPlayers;
  }

  List<TournamentPlayer> _advancingPlayersFromMixedGroups(GroupTournamentRunStage stage) {
    final plan = stage.qualificationPlan;
    if (plan == null) {
      return [
        for (final group in stage.groups)
          ..._orderedPlayersForGroup(stage, group),
      ];
    }

    final advancingPlayers = <TournamentPlayer>[];
    final extraCandidates = <TournamentPlayer>[];

    for (var groupIndex = 0; groupIndex < stage.groups.length; groupIndex++) {
      final groupNumber = groupIndex + 1;
      final ranking = _orderedPlayersForGroup(stage, stage.groups[groupIndex]);

      final fixedForGroup = groupIndex < plan.fixedByGroup.length
          ? plan.fixedByGroup[groupIndex]
          : plan.fixedPerGroup;
      advancingPlayers.addAll(ranking.take(fixedForGroup));

      final extraIndex = plan.extraRank - 1;
      if (plan.extraGroups.contains(groupNumber) &&
          extraIndex >= 0 &&
          extraIndex < ranking.length) {
        extraCandidates.add(ranking[extraIndex]);
      }
    }

    advancingPlayers.addAll(extraCandidates.take(plan.extraCount));
    return advancingPlayers;
  }

  List<TournamentPlayer> _orderedPlayersForGroup(
    GroupTournamentRunStage stage,
    TournamentGroup group,
  ) {
    if (_isEliminationGroupPlayType(group.playType)) {
      return _miniKnockoutRankingForGroup(group);
    }

    return _standingsFor(group, stage.tieBreakers)
        .map((standing) => standing.player)
        .toList();
  }

  List<TournamentPlayer> _miniKnockoutRankingForGroup(TournamentGroup group) {
    if (group.eliminationLossLimit > 1) {
      return _multiEliminationRanking(
        group.knockoutRounds,
        group.eliminationLossLimit,
        fallbackPlayers: group.players,
      );
    }

    return _knockoutRanking(
      group.knockoutRounds,
      group.placementMatches,
      fallbackPlayers: group.players,
    );
  }

  List<TournamentPlayer> _multiEliminationRanking(
    List<List<GroupMatch>> rounds,
    int lossLimit, {
    required List<TournamentPlayer> fallbackPlayers,
  }) {
    final players = _playersInEliminationRounds(rounds);
    final losses = _lossCountsForElimination(rounds);
    final lastResolvedRound = <String, int>{};
    for (final round in rounds) {
      for (final match in round.where((match) => match.hasResult)) {
        final loser = match.loser;
        final winner = match.winner;
        if (loser != null) {
          lastResolvedRound[loser.name] = match.round;
        }
        if (winner != null) {
          lastResolvedRound[winner.name] = match.round;
        }
      }
    }

    final ranked = [...players];
    ranked.sort((a, b) {
      final aLosses = losses[a.name] ?? 0;
      final bLosses = losses[b.name] ?? 0;
      final lossCompare = aLosses.compareTo(bLosses);
      if (lossCompare != 0) {
        return lossCompare;
      }

      final roundCompare = (lastResolvedRound[b.name] ?? 0).compareTo(
        lastResolvedRound[a.name] ?? 0,
      );
      if (roundCompare != 0) {
        return roundCompare;
      }

      return a.name.compareTo(b.name);
    });

    for (final player in fallbackPlayers) {
      if (!ranked.any((entry) => entry.name == player.name)) {
        ranked.add(player);
      }
    }

    return ranked;
  }

  List<TournamentPlayer> _knockoutRanking(
    List<List<GroupMatch>> rounds,
    List<GroupMatch> placementMatches, {
    required List<TournamentPlayer> fallbackPlayers,
  }) {
    final rankedPlayers = <TournamentPlayer>[];

    void addPlayer(TournamentPlayer? player) {
      if (player == null) {
        return;
      }
      if (rankedPlayers.any((ranked) => ranked.name == player.name)) {
        return;
      }
      rankedPlayers.add(player);
    }

    if (rounds.isNotEmpty) {
      final isTruncatedQualificationRound = rounds.last.length > 1;
      if (isTruncatedQualificationRound) {
        for (final match in rounds.last) {
          addPlayer(match.winner);
        }
      } else {
        addPlayer(rounds.last.first.winner);
        addPlayer(rounds.last.first.loser);
      }

      final thirdPlaceMatches = placementMatches
          .where((match) => match.label == 'Spiel um Platz 3')
          .toList();
      if (thirdPlaceMatches.isNotEmpty) {
        addPlayer(thirdPlaceMatches.first.winner);
        addPlayer(thirdPlaceMatches.first.loser);
      } else if (rounds.length >= 2) {
        for (final match in rounds[rounds.length - 2]) {
          addPlayer(match.loser);
        }
      }

      final fifthPlaceMatches = placementMatches
          .where((match) => match.label == 'Spiel um Platz 5')
          .toList();
      if (fifthPlaceMatches.isNotEmpty) {
        addPlayer(fifthPlaceMatches.first.winner);
        addPlayer(fifthPlaceMatches.first.loser);
      }

      final seventhPlaceMatches = placementMatches
          .where((match) => match.label == 'Spiel um Platz 7')
          .toList();
      if (seventhPlaceMatches.isNotEmpty) {
        addPlayer(seventhPlaceMatches.first.winner);
        addPlayer(seventhPlaceMatches.first.loser);
      }

      for (var roundIndex = rounds.length - 1; roundIndex >= 0; roundIndex--) {
        for (final match in rounds[roundIndex]) {
          addPlayer(match.loser);
        }
      }
    }

    for (final player in fallbackPlayers) {
      addPlayer(player);
    }

    return rankedPlayers;
  }

  TournamentRunStage _buildRunStageFromPlayers(
    TournamentStage stage,
    List<TournamentPlayer> players,
  ) {
    if (_isKnockoutStageType(stage.type)) {
      final participantCount = stage.knockoutParticipantCount == null
          ? players.length
          : stage.knockoutParticipantCount!.clamp(0, players.length).toInt();
      final participants = players.take(participantCount).toList();
      final lossLimit = _lossLimitForStageType(stage.type);
      return KnockoutTournamentRunStage(
        name: stage.name,
        rounds: lossLimit == 1
            ? _buildKnockoutRoundsForPlayers(
                participants,
                slotOrder: stage.knockoutSlotOrder,
              )
            : lossLimit == 2
                ? _buildDoubleEliminationRoundsForPlayers(
                    participants,
                    slotOrder: stage.knockoutSlotOrder,
                  )
            : _buildTripleEliminationRoundsForPlayers(
                participants,
                slotOrder: stage.knockoutSlotOrder,
              ),
        placementMatches: lossLimit == 1
            ? _buildPlacementMatchesForPlayers(participants.length, 1)
            : const [],
        eliminationLossLimit: lossLimit,
      );
    }

    final groupParticipantCount = stage.groupSizes.fold<int>(
      0,
      (sum, size) => sum + size,
    );
    final groupPlayers = _playersInStageOrder(
      players,
      stage.groupSlotOrder,
      groupParticipantCount,
    );

    return GroupTournamentRunStage(
      name: stage.name,
      groupPlayType: stage.groupPlayType,
      groups: _buildTournamentGroupsForPlayers(
        stage,
        groupPlayers,
        requiredRankForGroup: _requiredRankForStageGroup,
      ),
      qualificationPlan: _qualificationPlanForStage(stage),
      tieBreakers: stage.groupTieBreakers,
    );
  }

  List<TournamentPlayer> _playersInStageOrder(
    List<TournamentPlayer> players,
    List<int?> slotOrder,
    int participantCount,
  ) {
    if (!_isValidPlayerSlotOrder(slotOrder, participantCount)) {
      return players;
    }

    return [
      for (final seed in slotOrder)
        if (seed != null && seed <= players.length) players[seed - 1],
    ];
  }

  bool _isValidPlayerSlotOrder(List<int?> slotOrder, int participantCount) {
    if (participantCount < 1 || slotOrder.length != participantCount) {
      return false;
    }

    final seen = <int>{};
    for (final seed in slotOrder) {
      if (seed == null || seed < 1 || seed > participantCount) {
        return false;
      }
      if (!seen.add(seed)) {
        return false;
      }
    }
    return true;
  }

  QualificationPlan? _qualificationPlanForStage(TournamentStage stage) {
    if (stage.groupSizes.isEmpty || stage.qualifiedParticipantCount == null) {
      return null;
    }

    final groupCount = stage.groupSizes.length;
    final maxQualifiers = stage.groupSizes.fold<int>(
      0,
      (sum, size) => sum + size,
    );
    final totalQualifiers = stage.qualifiedParticipantCount! > maxQualifiers
        ? maxQualifiers
        : stage.qualifiedParticipantCount!;
    final fixedPerGroup = totalQualifiers ~/ groupCount;
    final fixedByGroup = stage.fixedQualifiersByGroup.length == groupCount
        ? [
            for (var index = 0; index < groupCount; index++)
              stage.fixedQualifiersByGroup[index]
                  .clamp(0, stage.groupSizes[index])
                  .toInt(),
          ]
        : [
            for (final groupSize in stage.groupSizes)
              fixedPerGroup > groupSize ? groupSize : fixedPerGroup,
          ];
    final fixedTotal = fixedByGroup.fold<int>(0, (sum, value) => sum + value);
    final automaticExtraCount = (totalQualifiers - fixedTotal)
        .clamp(0, groupCount)
        .toInt();
    final extraCount = stage.qualificationAutoAdjust
        ? automaticExtraCount
        : (stage.extraQualifierCount ?? automaticExtraCount)
              .clamp(0, groupCount)
              .toInt();
    final extraRank = stage.extraQualifierRank ?? fixedPerGroup + 1;
    final extraGroups = extraCount == 0
        ? const <int>[]
        : stage.qualifiersByGroup.isNotEmpty
        ? stage.qualifiersByGroup
        : [
            for (var index = 0; index < stage.groupSizes.length; index++)
              if (stage.groupSizes[index] >= extraRank) index + 1,
          ];
    final eligibleGroupSize = extraCount == 0
        ? null
        : stage.groupSizes
              .where((size) => size >= extraRank)
              .fold<int>(0, (largest, size) => size > largest ? size : largest);

    return QualificationPlan(
      totalQualifiers: totalQualifiers,
      fixedPerGroup: fixedPerGroup,
      extraCount: extraCount,
      extraRank: extraRank,
      eligibleGroupSize: eligibleGroupSize,
      extraGroups: extraGroups,
      fixedByGroup: fixedByGroup,
    );
  }

  int _requiredRankForStageGroup(TournamentStage stage, int groupIndex) {
    final plan = _qualificationPlanForStage(stage);
    if (plan == null) {
      return 1;
    }

    final fixedForGroup = groupIndex < plan.fixedByGroup.length
        ? plan.fixedByGroup[groupIndex]
        : plan.fixedPerGroup;
    final groupNumber = groupIndex + 1;
    final extraRank = plan.extraGroups.contains(groupNumber)
        ? plan.extraRank
        : 0;
    final requiredRank = fixedForGroup > extraRank ? fixedForGroup : extraRank;
    return requiredRank < 1 ? 1 : requiredRank;
  }

  Future<void> _applyPendingStartDrawForActiveStage() async {
    if (!mounted ||
        _isApplyingStartDraw ||
        _activeStageIndex >= widget.tournament.stages.length ||
        _activeStageIndex >= widget.tournament.runStages.length) {
      return;
    }

    final stageConfig = widget.tournament.stages[_activeStageIndex];
    if (!_stageNeedsStartDraw(stageConfig)) {
      return;
    }

    final runStage = widget.tournament.runStages[_activeStageIndex];
    if (_matchesForStage(runStage).any((match) => match.hasResult)) {
      return;
    }

    final incomingPlayers = _incomingPlayersForStage(_activeStageIndex);
    final participantCount = _drawParticipantCount(stageConfig, incomingPlayers);
    if (participantCount < 2) {
      return;
    }

    _isApplyingStartDraw = true;
    final labels = incomingPlayers
        .take(participantCount)
        .map((player) => player.name)
        .toList();
    final slotOrder = await showDialog<List<int?>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RandomDrawDialog(
        stageName: stageConfig.name,
        participantLabels: labels,
        bracketSize: stageConfig.type == 'groups'
            ? participantCount
            : _drawBracketSize(stageConfig, participantCount),
        useBracketSlots: stageConfig.type != 'groups',
        groupSizes:
            stageConfig.type == 'groups' ? stageConfig.groupSizes : const [],
      ),
    );
    _isApplyingStartDraw = false;

    if (!mounted || slotOrder == null) {
      return;
    }

    setState(() {
      final updatedStage = _copyStageWithStartDraw(stageConfig, slotOrder);
      widget.tournament.stages[_activeStageIndex] = updatedStage;
      widget.tournament.runStages[_activeStageIndex] =
          _buildRunStageFromPlayers(updatedStage, incomingPlayers);
      _advanceKnockoutWinners();
      _ensureGroupDeciders();
    });
    await _saveTournamentProgress();
  }

  bool _stageNeedsStartDraw(TournamentStage stage) {
    if (stage.type == 'groups') {
      return stage.groupDrawOnStart && stage.groupSlotOrder.isEmpty;
    }

    return _isKnockoutStageType(stage.type) &&
        stage.knockoutSeedingMode == 'random' &&
        stage.knockoutDrawOnStart &&
        stage.knockoutSlotOrder.isEmpty;
  }

  List<TournamentPlayer> _incomingPlayersForStage(int stageIndex) {
    if (stageIndex <= 0) {
      return List<TournamentPlayer>.from(widget.tournament.players);
    }

    return _advancingPlayersFromStage(widget.tournament.runStages[stageIndex - 1]);
  }

  int _drawParticipantCount(
    TournamentStage stage,
    List<TournamentPlayer> incomingPlayers,
  ) {
    if (stage.type == 'groups') {
      final groupParticipantCount = stage.groupSizes.fold<int>(
        0,
        (sum, size) => sum + size,
      );
      return groupParticipantCount.clamp(0, incomingPlayers.length).toInt();
    }

    final participantCount =
        stage.knockoutParticipantCount ?? incomingPlayers.length;
    return participantCount.clamp(0, incomingPlayers.length).toInt();
  }

  int _drawBracketSize(TournamentStage stage, int participantCount) {
    final storedBracketSize = stage.knockoutBracketSize;
    if (storedBracketSize != null && storedBracketSize >= participantCount) {
      return storedBracketSize;
    }

    return _nextPowerOfTwo(participantCount);
  }

  TournamentStage _copyStageWithStartDraw(
    TournamentStage stage,
    List<int?> slotOrder,
  ) {
    return TournamentStage(
      name: stage.name,
      type: stage.type,
      groupCount: stage.groupCount,
      groupSizes: stage.groupSizes,
      groupPlayType: stage.groupPlayType,
      groupPlayTypes: stage.groupPlayTypes,
      groupRoundRobinRepeats: stage.groupRoundRobinRepeats,
      groupTieBreakers: stage.groupTieBreakers,
      groupDrawOnStart: stage.groupDrawOnStart,
      groupSlotOrder: stage.type == 'groups'
          ? List.unmodifiable(slotOrder)
          : stage.groupSlotOrder,
      knockoutParticipantCount: stage.knockoutParticipantCount,
      knockoutBracketSize: stage.knockoutBracketSize,
      knockoutByeCount: stage.knockoutByeCount,
      knockoutSlotOrder: stage.type == 'groups'
          ? stage.knockoutSlotOrder
          : List.unmodifiable(slotOrder),
      knockoutSeedingMode: stage.knockoutSeedingMode,
      knockoutDrawOnStart: stage.knockoutDrawOnStart,
      qualifiersByGroup: stage.qualifiersByGroup,
      fixedQualifiersByGroup: stage.fixedQualifiersByGroup,
      extraQualifierRank: stage.extraQualifierRank,
      extraQualifierCount: stage.extraQualifierCount,
      qualificationAutoAdjust: stage.qualificationAutoAdjust,
      qualifiedParticipantCount: stage.qualifiedParticipantCount,
      qualificationSummary: stage.qualificationSummary,
    );
  }

  Future<void> _completeCurrentStage() async {
    final nextStageIndex = _activeStageIndex + 1;
    final hasNextStage = nextStageIndex < widget.tournament.runStages.length;
    final advancingPlayers = hasNextStage
        ? _advancingPlayersFromStage(widget.tournament.runStages[_activeStageIndex])
        : const <TournamentPlayer>[];

    setState(() {
      if (hasNextStage) {
        final nextStageConfig = widget.tournament.stages[nextStageIndex];
        widget.tournament.runStages[nextStageIndex] =
            _buildRunStageFromPlayers(nextStageConfig, advancingPlayers);
      }

      _completedStageIndexes.add(_activeStageIndex);
      if (hasNextStage) {
        _activeStageIndex++;
      }
      _viewStageIndex = _activeStageIndex;
    });
    _advanceKnockoutWinners();
    await _saveTournamentProgress();
    if (!mounted) {
      return;
    }
    if (!hasNextStage) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => TournamentResultsPage(tournament: widget.tournament),
        ),
      );
      return;
    }
    await _applyPendingStartDrawForActiveStage();
  }

  void _finishCurrentStageEarly() {
    setState(() {
      for (final match in _matchesForStage(
        widget.tournament.runStages[_activeStageIndex],
      )) {
        if (match.hasPlayers && !match.isResolved) {
          match.isAnnulled = true;
          match.homeLegs = null;
          match.awayLegs = null;
        }
      }
      _advanceKnockoutWinners();
    });
    _completeCurrentStage();
  }

  @override
  Widget build(BuildContext context) {
    final activeStage = _stageForView(_viewStageIndex);
    final isViewingActiveStage = _viewStageIndex == _activeStageIndex;
    final canCompleteStage =
        isViewingActiveStage &&
        !_stageHasOpenMatches(widget.tournament.runStages[_activeStageIndex]);
    final isLastStage =
        _activeStageIndex == widget.tournament.runStages.length - 1;
    final canEditResults = isViewingActiveStage;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tournament.name),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.home_outlined),
            label: const Text('Hauptmenue'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            StageProgressBar(
              stages: widget.tournament.runStages,
              activeStageIndex: _viewStageIndex,
              completedStageIndexes: _completedStageIndexes,
              onStageSelected: (index) {
                setState(() {
                  _viewStageIndex = index;
                  _isBracketEditMode = false;
                });
              },
            ),
            StageViewModeSwitch(
              selectedMode: _stageViewMode,
              onModeChanged: (mode) {
                setState(() {
                  _stageViewMode = mode;
                });
              },
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_stageViewMode == StageViewMode.overview) ...[
                    if (activeStage is GroupTournamentRunStage)
                      GroupStageRunSection(
                        stage: activeStage,
                        standingsFor: _standingsFor,
                        onEditResult: _editResult,
                        canEditResults: canEditResults,
                        miniKnockoutBracketBuilder:
                            (group, qualifyingRank, onEditResult, canEditResults) {
                              return _KnockoutBracketView(
                                stage: KnockoutTournamentRunStage(
                                  name: group.name,
                                  rounds: group.knockoutRounds,
                                  eliminationLossLimit:
                                      group.eliminationLossLimit,
                                ),
                                placementMatches: group.placementMatches,
                                qualifyingRank: qualifyingRank,
                                onEditResult: onEditResult,
                                canEditResults: canEditResults,
                              );
                            },
                      )
                    else if (activeStage is KnockoutTournamentRunStage)
                      KnockoutRunSection(
                        stage: activeStage,
                        qualifyingRank: _requiredRankForRunStage(
                          _viewStageIndex,
                        ),
                        onEditResult: _editResult,
                        canEditResults: canEditResults,
                        isEditMode: _isBracketEditMode && canEditResults,
                        canEditBracket:
                            canEditResults && _canEditKnockoutBracket(activeStage),
                        onEditModeChanged: (enabled) {
                          setState(() {
                            _isBracketEditMode = enabled;
                          });
                        },
                        onSwapSlot: (fromSlotIndex, toSlotIndex) {
                          _swapKnockoutRunSlots(
                            activeStage,
                            fromSlotIndex,
                            toSlotIndex,
                          );
                        },
                        bracketBuilder:
                            (
                              stage,
                              qualifyingRank,
                              onEditResult,
                              canEditResults,
                              isEditMode,
                              onSwapSlot,
                            ) {
                              return _KnockoutBracketView(
                                stage: stage,
                                placementMatches: stage.placementMatches,
                                qualifyingRank: qualifyingRank,
                                onEditResult: onEditResult,
                                canEditResults: canEditResults,
                                isEditMode: isEditMode,
                                onSwapSlot: onSwapSlot,
                              );
                            },
                      ),
                  ] else
                    StagePlayOrderSection(
                      stage: activeStage,
                      matches: _matchesForStage(activeStage),
                      onEditResult: _editResult,
                      canEditResults: canEditResults,
                    ),
                ],
              ),
            ),
            StageFooter(
              canCompleteStage: canCompleteStage,
              isLastStage: isLastStage,
              isViewingActiveStage: isViewingActiveStage,
              activeStageName: widget.tournament.runStages[_activeStageIndex].name,
              onCompleteStage: _completeCurrentStage,
              onFinishEarly: _finishCurrentStageEarly,
            ),
          ],
        ),
      ),
    );
  }
}

