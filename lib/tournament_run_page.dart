part of 'main.dart';

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
  final Set<int> _completedStageIndexes = {};
  final _storage = TournamentStorage();

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
  }

  Future<void> _saveTournamentProgress() async {
    widget.tournament.activeStageIndex = _activeStageIndex;
    widget.tournament.completedStageIndexes
      ..clear()
      ..addAll(_completedStageIndexes);
    await _storage.saveTournament(widget.tournament);
  }

  Future<void> _editResult(GroupMatch match) async {
    final result = await showDialog<MatchResult>(
      context: context,
      builder: (context) => _ResultDialog(match: match),
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
        } else if (stage.eliminationLossLimit > 1) {
          _advanceMultiEliminationRounds(
            stage.rounds,
            stage.eliminationLossLimit,
          );
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
            if (group.eliminationLossLimit > 1) {
              _advanceMultiEliminationRounds(
                group.knockoutRounds,
                group.eliminationLossLimit,
              );
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
    }
  }

  void _advanceMultiEliminationRounds(
    List<List<GroupMatch>> rounds,
    int lossLimit,
  ) {
    if (rounds.isEmpty || lossLimit < 2) {
      return;
    }

    while (rounds.isNotEmpty &&
        rounds.last.isNotEmpty &&
        rounds.last.every((match) => match.isResolved)) {
      final activePlayers = _activeEliminationPlayers(rounds, lossLimit);
      if (activePlayers.length <= 1) {
        return;
      }

      final nextRoundNumber = rounds.length + 1;
      final nextRound = _pairEliminationRound(
        activePlayers,
        _lossCountsForElimination(rounds),
        nextRoundNumber,
        lossLimit,
      );
      if (nextRound.isEmpty) {
        return;
      }

      rounds.add(nextRound);
    }
  }

  List<GroupMatch> _pairEliminationRound(
    List<TournamentPlayer> activePlayers,
    Map<String, int> losses,
    int roundNumber,
    int lossLimit,
  ) {
    final matches = <GroupMatch>[];
    final unpaired = <TournamentPlayer>[];

    for (var lossCount = 0; lossCount < lossLimit; lossCount++) {
      final bucket = [
        for (final player in activePlayers)
          if ((losses[player.name] ?? 0) == lossCount) player,
      ]..sort((a, b) => a.name.compareTo(b.name));

      while (bucket.length >= 2) {
        final homePlayer = bucket.removeAt(0);
        final awayPlayer = bucket.removeLast();
        matches.add(
          GroupMatch(
            homePlayer: homePlayer,
            awayPlayer: awayPlayer,
            round: roundNumber,
            label: _lossLevelMatchLabel(lossCount, roundNumber),
          ),
        );
      }

      if (bucket.isNotEmpty) {
        unpaired.add(bucket.single);
      }
    }

    if (matches.isEmpty && unpaired.length >= 2) {
      unpaired.sort((a, b) {
        final lossCompare = (losses[a.name] ?? 0).compareTo(
          losses[b.name] ?? 0,
        );
        if (lossCompare != 0) {
          return lossCompare;
        }
        return a.name.compareTo(b.name);
      });
      final homePlayer = unpaired.first;
      final awayPlayer = unpaired.last;
      matches.add(
        GroupMatch(
          homePlayer: homePlayer,
          awayPlayer: awayPlayer,
          round: roundNumber,
          label: _tripleFinalLabel,
        ),
      );
    }

    return matches;
  }

  void _advanceDoubleEliminationRounds(List<List<GroupMatch>> rounds) {
    final winnersRoundCount = _doubleWinnersRoundCount(rounds);
    final losersRoundCount = _doubleLosersRoundCount(rounds);
    if (winnersRoundCount == 0 || losersRoundCount == 0) {
      return;
    }

    for (var roundNumber = 1; roundNumber <= winnersRoundCount; roundNumber++) {
      final currentWinnersRound = _matchesWithLabel(
        rounds,
        _doubleWinnersLabel(roundNumber),
      );
      if (currentWinnersRound.isEmpty) {
        continue;
      }

      if (roundNumber < winnersRoundCount) {
        final nextWinnersRound = _matchesWithLabel(
          rounds,
          _doubleWinnersLabel(roundNumber + 1),
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

  void _advancePairedWinners(
    List<GroupMatch> currentRound,
    List<GroupMatch> nextRound,
  ) {
    for (var matchIndex = 0; matchIndex < currentRound.length; matchIndex++) {
      final winner = currentRound[matchIndex].winner;
      if (winner == null || nextRound.isEmpty) {
        continue;
      }

      final targetMatch = nextRound[matchIndex ~/ 2];
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
    for (var matchIndex = 0; matchIndex < winnersRound.length; matchIndex++) {
      final loser = winnersRound[matchIndex].loser;
      if (loser == null || losersRound.isEmpty) {
        continue;
      }

      final targetMatch = losersRound[matchIndex ~/ 2];
      if (matchIndex.isEven) {
        _setMatchHomePlayer(targetMatch, loser);
      } else {
        _setMatchAwayPlayer(targetMatch, loser);
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
      final semifinalLosers = rounds[rounds.length - 2]
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

    if (rounds.length >= 3 && placementMatches.length >= 4) {
      final quarterfinalLosers = rounds[rounds.length - 3]
          .map((match) => match.loser)
          .whereType<TournamentPlayer>()
          .toList();
      final fifthSemis = placementMatches
          .where(
            (match) => match.label?.startsWith('Platz 5 Halbfinale') ?? false,
          )
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
          return !_miniKnockoutGroupHasWinner(group) ||
              _hasOpenPlacementMatches(group.placementMatches);
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

  bool _miniKnockoutGroupHasWinner(TournamentGroup group) {
    if (group.eliminationLossLimit > 1) {
      return group.knockoutRounds.isNotEmpty &&
          group.knockoutRounds.last.every((match) => match.isResolved) &&
          _activeEliminationPlayers(
                group.knockoutRounds,
                group.eliminationLossLimit,
              ).length <=
              1;
    }

    return group.knockoutRounds.isNotEmpty &&
        group.knockoutRounds.last.length == 1 &&
        group.knockoutRounds.last.first.winner != null;
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
    final extraCandidates = <PlayerStanding>[];

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
        extraCandidates.add(standings[extraIndex]);
      }
    }

    extraCandidates.sort((a, b) => _compareStandings(a, b, stage.tieBreakers));
    advancingPlayers.addAll(
      extraCandidates.take(plan.extraCount).map((standing) => standing.player),
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
      addPlayer(rounds.last.first.winner);
      addPlayer(rounds.last.first.loser);

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
            : _buildInitialEliminationRoundsForPlayers(
                participants,
                slotOrder: stage.knockoutSlotOrder,
                initialLabel: _lossLevelMatchLabel(0, 1),
              ),
        placementMatches: lossLimit == 1
            ? _buildPlacementMatchesForPlayers(participants.length, 1)
            : const [],
        eliminationLossLimit: lossLimit,
      );
    }

    return GroupTournamentRunStage(
      name: stage.name,
      groupPlayType: stage.groupPlayType,
      groups: _buildTournamentGroupsForPlayers(stage, players),
      qualificationPlan: _qualificationPlanForStage(stage),
      tieBreakers: stage.groupTieBreakers,
    );
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

  List<GroupMatch> _buildPlacementMatchesForPlayers(
    int participantCount,
    int requiredRank,
  ) {
    if (participantCount < 4 || requiredRank < 3) {
      return const [];
    }

    final matches = <GroupMatch>[
      GroupMatch(round: 100, label: 'Spiel um Platz 3'),
    ];

    if (participantCount >= 8 && requiredRank >= 5) {
      matches.addAll([
        GroupMatch(round: 101, label: 'Platz 5 Halbfinale 1'),
        GroupMatch(round: 101, label: 'Platz 5 Halbfinale 2'),
        GroupMatch(round: 102, label: 'Spiel um Platz 5'),
        if (requiredRank >= 7)
          GroupMatch(round: 102, label: 'Spiel um Platz 7'),
      ]);
    }

    return matches;
  }

  List<TournamentGroup> _buildTournamentGroupsForPlayers(
    TournamentStage stage,
    List<TournamentPlayer> players,
  ) {
    final groups = <TournamentGroup>[];
    var playerIndex = 0;

    for (
      var groupIndex = 0;
      groupIndex < stage.groupSizes.length;
      groupIndex++
    ) {
      final groupPlayType = _groupPlayTypeForStage(stage, groupIndex);
      final groupPlayers = <TournamentPlayer>[];
      for (var slot = 0; slot < stage.groupSizes[groupIndex]; slot++) {
        if (playerIndex >= players.length) {
          break;
        }
        groupPlayers.add(players[playerIndex]);
        playerIndex++;
      }

      if (_isEliminationGroupPlayType(groupPlayType)) {
        final lossLimit = _lossLimitForGroupPlayType(groupPlayType);
        final rounds = lossLimit == 1
            ? _buildKnockoutRoundsForPlayers(groupPlayers)
            : lossLimit == 2
                ? _buildDoubleEliminationRoundsForPlayers(groupPlayers)
                : _buildInitialEliminationRoundsForPlayers(
                    groupPlayers,
                    initialLabel: _lossLevelMatchLabel(0, 1),
                  );
        final placementMatches = lossLimit == 1
            ? _buildPlacementMatchesForPlayers(
                groupPlayers.length,
                _requiredRankForStageGroup(stage, groupIndex),
              )
            : const <GroupMatch>[];
        groups.add(
          TournamentGroup(
            name: groupLabel(groupIndex + 1),
            playType: groupPlayType,
            players: groupPlayers,
            matches: [
              for (final round in rounds) ...round,
              ...placementMatches,
            ],
            knockoutRounds: rounds,
            placementMatches: placementMatches,
            eliminationLossLimit: lossLimit,
          ),
        );
      } else {
        groups.add(
          TournamentGroup(
            name: groupLabel(groupIndex + 1),
            playType: groupPlayType,
            players: groupPlayers,
            matches: _buildRoundRobinMatchesForPlayers(
              groupPlayers,
              repeatCount: _roundRobinRepeatForStage(stage, groupIndex),
            ),
          ),
        );
      }
    }

    return groups;
  }

  List<List<GroupMatch>> _buildKnockoutRoundsForPlayers(
    List<TournamentPlayer> players, {
    List<int?> slotOrder = const [],
  }) {
    if (players.length < 2) {
      return const [];
    }

    var bracketSize = 2;
    while (bracketSize < players.length) {
      bracketSize *= 2;
    }

    final slots =
        _isValidSlotOrder(slotOrder, players.length, bracketSize) &&
            _slotOrderAvoidsByePair(slotOrder)
        ? List<int?>.from(slotOrder)
        : _automaticSlotOrder(players.length, bracketSize);
    final rounds = <List<GroupMatch>>[];
    final firstRound = <GroupMatch>[];
    for (var index = 0; index < bracketSize; index += 2) {
      final homeSeed = slots[index];
      final awaySeed = slots[index + 1];
      firstRound.add(
        GroupMatch(
          homePlayer: homeSeed == null ? null : players[homeSeed - 1],
          awayPlayer: awaySeed == null ? null : players[awaySeed - 1],
          round: 1,
          allowsBye: true,
        ),
      );
    }
    rounds.add(firstRound);

    var matchesInRound = firstRound.length ~/ 2;
    var roundNumber = 2;
    while (matchesInRound >= 1) {
      rounds.add(
        List.generate(matchesInRound, (_) => GroupMatch(round: roundNumber)),
      );
      matchesInRound ~/= 2;
      roundNumber++;
    }

    _advanceKnockoutWinnersInBuiltRounds(rounds);
    return rounds;
  }

  List<List<GroupMatch>> _buildInitialEliminationRoundsForPlayers(
    List<TournamentPlayer> players, {
    List<int?> slotOrder = const [],
    String? initialLabel,
  }) {
    if (players.length < 2) {
      return const [];
    }

    var bracketSize = 2;
    while (bracketSize < players.length) {
      bracketSize *= 2;
    }

    final slots =
        _isValidSlotOrder(slotOrder, players.length, bracketSize) &&
            _slotOrderAvoidsByePair(slotOrder)
        ? List<int?>.from(slotOrder)
        : _automaticSlotOrder(players.length, bracketSize);
    final firstRound = <GroupMatch>[];
    for (var index = 0; index < bracketSize; index += 2) {
      final homeSeed = slots[index];
      final awaySeed = slots[index + 1];
      firstRound.add(
        GroupMatch(
          homePlayer: homeSeed == null ? null : players[homeSeed - 1],
          awayPlayer: awaySeed == null ? null : players[awaySeed - 1],
          round: 1,
          allowsBye: true,
          label: initialLabel,
        ),
      );
    }

    return [firstRound];
  }

  List<List<GroupMatch>> _buildDoubleEliminationRoundsForPlayers(
    List<TournamentPlayer> players, {
    List<int?> slotOrder = const [],
  }) {
    if (players.length < 2) {
      return const [];
    }

    var bracketSize = 2;
    while (bracketSize < players.length) {
      bracketSize *= 2;
    }

    final slots =
        _isValidSlotOrder(slotOrder, players.length, bracketSize) &&
            _slotOrderAvoidsByePair(slotOrder)
        ? List<int?>.from(slotOrder)
        : _automaticSlotOrder(players.length, bracketSize);
    return _buildDoubleEliminationRoundsFromSlots(players, slots);
  }

  void _advanceKnockoutWinnersInBuiltRounds(List<List<GroupMatch>> rounds) {
    for (var roundIndex = 0; roundIndex < rounds.length - 1; roundIndex++) {
      final currentRound = rounds[roundIndex];
      final nextRound = rounds[roundIndex + 1];
      for (var matchIndex = 0; matchIndex < currentRound.length; matchIndex++) {
        final winner = currentRound[matchIndex].winner;
        if (winner == null) {
          continue;
        }

        final targetMatch = nextRound[matchIndex ~/ 2];
        if (matchIndex.isEven) {
          targetMatch.homePlayer = winner;
        } else {
          targetMatch.awayPlayer = winner;
        }
      }
    }
  }

  List<GroupMatch> _buildRoundRobinMatchesForPlayers(
    List<TournamentPlayer> players, {
    int repeatCount = 1,
  }) {
    return _buildRoundRobinMatches(players, repeatCount: repeatCount);
  }

  List<int?> _automaticSlotOrder(int participantCount, int bracketSize) {
    return [
      for (final seed in _seedOrder(bracketSize))
        seed <= participantCount ? seed : null,
    ];
  }

  List<int> _seedOrder(int bracketSize) {
    var order = <int>[1, 2];
    var size = 2;
    while (size < bracketSize) {
      final nextSize = size * 2;
      order = [
        for (final seed in order) ...[seed, nextSize + 1 - seed],
      ];
      size = nextSize;
    }

    return order;
  }

  bool _isValidSlotOrder(
    List<int?> slotOrder,
    int participantCount,
    int bracketSize,
  ) {
    if (slotOrder.length != bracketSize) {
      return false;
    }

    final values = slotOrder.whereType<int>().toList()..sort();
    if (values.length != participantCount) {
      return false;
    }

    for (var index = 0; index < values.length; index++) {
      if (values[index] != index + 1) {
        return false;
      }
    }

    return true;
  }

  bool _slotOrderAvoidsByePair(List<int?> slotOrder) {
    for (var index = 0; index < slotOrder.length; index += 2) {
      final first = slotOrder[index];
      final second = index + 1 < slotOrder.length ? slotOrder[index + 1] : null;
      if (first == null && second == null) {
        return false;
      }
    }
    return true;
  }

  void _completeCurrentStage() {
    setState(() {
      if (_activeStageIndex < widget.tournament.runStages.length - 1) {
        final advancingPlayers = _advancingPlayersFromStage(
          widget.tournament.runStages[_activeStageIndex],
        );
        final nextStageConfig = widget.tournament.stages[_activeStageIndex + 1];
        widget.tournament.runStages[_activeStageIndex + 1] =
            _buildRunStageFromPlayers(nextStageConfig, advancingPlayers);
      }

      _completedStageIndexes.add(_activeStageIndex);
      if (_activeStageIndex < widget.tournament.runStages.length - 1) {
        _activeStageIndex++;
      }
      _viewStageIndex = _activeStageIndex;
    });
    _advanceKnockoutWinners();
    _saveTournamentProgress();
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
      appBar: AppBar(title: Text(widget.tournament.name)),
      body: SafeArea(
        child: Column(
          children: [
            _StageProgressBar(
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
            _StageViewModeSwitch(
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
                      _GroupStageRunSection(
                        stage: activeStage,
                        standingsFor: _standingsFor,
                        onEditResult: _editResult,
                        canEditResults: canEditResults,
                      )
                    else if (activeStage is KnockoutTournamentRunStage)
                      _KnockoutRunSection(
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
                      ),
                  ] else
                    _StagePlayOrderSection(
                      stage: activeStage,
                      matches: _matchesForStage(activeStage),
                      onEditResult: _editResult,
                      canEditResults: canEditResults,
                    ),
                ],
              ),
            ),
            _StageFooter(
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

