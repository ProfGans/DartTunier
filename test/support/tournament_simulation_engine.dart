import 'package:dart_tournament_manager/features/tournaments/domain/engines/tournament_engine.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';

class TournamentSimulationScenario {
  const TournamentSimulationScenario({
    required this.name,
    required this.playerCount,
    required this.stages,
  });

  final String name;
  final int playerCount;
  final List<SimulationStageSpec> stages;
}

sealed class SimulationStageSpec {
  const SimulationStageSpec({
    required this.name,
    required this.qualifiers,
  });

  final String name;
  final int qualifiers;
}

class SimulationGroupStageSpec extends SimulationStageSpec {
  const SimulationGroupStageSpec({
    required super.name,
    required super.qualifiers,
    required this.groupSizes,
    this.playTypes = const [],
    this.roundRobinRepeats = const [],
    this.fixedPerGroup = 1,
    this.fixedByGroup = const [],
    this.extraRank = 0,
    this.extraCount = 0,
    this.extraGroups = const [],
  });

  final List<int> groupSizes;
  final List<String> playTypes;
  final List<int> roundRobinRepeats;
  final int fixedPerGroup;
  final List<int> fixedByGroup;
  final int extraRank;
  final int extraCount;
  final List<int> extraGroups;
}

class SimulationEliminationStageSpec extends SimulationStageSpec {
  const SimulationEliminationStageSpec({
    required super.name,
    required super.qualifiers,
    required this.lossLimit,
  });

  final int lossLimit;
}

class TournamentSimulationReport {
  const TournamentSimulationReport({
    required this.scenarioName,
    required this.finalPlayers,
    required this.stageReports,
    required this.totalMatches,
  });

  final String scenarioName;
  final List<TournamentPlayer> finalPlayers;
  final List<SimulationStageReport> stageReports;
  final int totalMatches;
}

class SimulationStageReport {
  const SimulationStageReport({
    required this.name,
    required this.inputCount,
    required this.outputCount,
    required this.matchCount,
    required this.matches,
    required this.matchRecords,
  });

  final String name;
  final int inputCount;
  final int outputCount;
  final int matchCount;
  final List<GroupMatch> matches;
  final List<SimulationMatchRecord> matchRecords;
}

class SimulationMatchRecord {
  const SimulationMatchRecord({
    required this.number,
    required this.match,
    required this.bracket,
    required this.homeSource,
    required this.awaySource,
  });

  final int number;
  final GroupMatch match;
  final String bracket;
  final String homeSource;
  final String awaySource;
}

class TournamentSimulationFailure implements Exception {
  const TournamentSimulationFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class TournamentSimulationEngine {
  TournamentSimulationReport run(TournamentSimulationScenario scenario) {
    if (scenario.playerCount < 2) {
      throw TournamentSimulationFailure(
        '${scenario.name}: mindestens 2 Spieler benoetigt.',
      );
    }

    var players = [
      for (var index = 1; index <= scenario.playerCount; index++)
        TournamentPlayer.generated(index),
    ];
    final seedRank = {
      for (var index = 0; index < players.length; index++)
        players[index].name: index,
    };
    final reports = <SimulationStageReport>[];

    for (final stage in scenario.stages) {
      final inputPlayers = List<TournamentPlayer>.from(players);
      final result = switch (stage) {
        SimulationGroupStageSpec() => _runGroupStage(
            stage,
            inputPlayers,
            seedRank,
          ),
        SimulationEliminationStageSpec() => _runEliminationStage(
            stage,
            inputPlayers,
            seedRank,
          ),
      };

      _validateUniquePlayers(
        result.advancingPlayers,
        '${scenario.name} / ${stage.name}: Weiterkommende',
      );
      _validateMatches(
        result.matches,
        '${scenario.name} / ${stage.name}',
      );

      reports.add(
        SimulationStageReport(
          name: stage.name,
          inputCount: inputPlayers.length,
          outputCount: result.advancingPlayers.length,
          matchCount: result.matches.length,
          matches: result.matches,
          matchRecords: result.matchRecords,
        ),
      );

      players = result.advancingPlayers;
    }

    return TournamentSimulationReport(
      scenarioName: scenario.name,
      finalPlayers: players,
      stageReports: reports,
      totalMatches: reports.fold(0, (sum, report) => sum + report.matchCount),
    );
  }

  _StageSimulationResult _runGroupStage(
    SimulationGroupStageSpec stage,
    List<TournamentPlayer> players,
    Map<String, int> seedRank,
  ) {
    final groups = _splitIntoGroups(players, stage.groupSizes);
    final groupRankings = <List<TournamentPlayer>>[];
    final matches = <GroupMatch>[];
    final matchRecords = <SimulationMatchRecord>[];

    for (var index = 0; index < groups.length; index++) {
      final groupPlayers = groups[index];
      final playType = _groupPlayType(stage, index);
      final ranking = playType == 'round_robin'
          ? _runRoundRobinGroup(
              groupPlayers,
              _roundRobinRepeats(stage, index),
              seedRank,
              matches,
              matchRecords,
              groupName: 'Gruppe ${index + 1}',
            )
          : _runEliminationRanking(
              players: groupPlayers,
              lossLimit: _lossLimitForPlayType(playType),
              targetQualifiers: 1,
              seedRank: seedRank,
              matchSink: matches,
              recordSink: matchRecords,
              roundOffset: index * 1000,
              bracketPrefix: 'Gruppe ${index + 1}',
            );
      groupRankings.add(ranking);
    }

    final advancing = <TournamentPlayer>[];
    for (var index = 0; index < groupRankings.length; index++) {
      final fixedCount = _fixedQualifierCount(stage, index);
      advancing.addAll(groupRankings[index].take(fixedCount));
    }

    if (stage.extraCount > 0 && stage.extraRank > 0) {
      final eligibleGroups = stage.extraGroups.isEmpty
          ? [for (var index = 1; index <= groupRankings.length; index++) index]
          : stage.extraGroups;
      final candidates = <TournamentPlayer>[];
      for (final groupNumber in eligibleGroups) {
        final groupIndex = groupNumber - 1;
        if (groupIndex < 0 || groupIndex >= groupRankings.length) {
          continue;
        }
        final candidateIndex = stage.extraRank - 1;
        if (candidateIndex < groupRankings[groupIndex].length) {
          candidates.add(groupRankings[groupIndex][candidateIndex]);
        }
      }
      candidates.sort((a, b) => _compareBySeed(a, b, seedRank));
      advancing.addAll(candidates.take(stage.extraCount));
    }

    final fallback = [
      for (final ranking in groupRankings)
        for (final player in ranking) player,
    ]..sort((a, b) => _compareBySeed(a, b, seedRank));

    for (final player in fallback) {
      if (advancing.length >= stage.qualifiers) {
        break;
      }
      if (!advancing.any((existing) => existing.name == player.name)) {
        advancing.add(player);
      }
    }

    if (advancing.length != stage.qualifiers) {
      throw TournamentSimulationFailure(
        '${stage.name}: ${stage.qualifiers} Weiterkommende erwartet, '
        'aber ${advancing.length} ermittelt.',
      );
    }

    return _StageSimulationResult(advancing, matches, matchRecords);
  }

  _StageSimulationResult _runEliminationStage(
    SimulationEliminationStageSpec stage,
    List<TournamentPlayer> players,
    Map<String, int> seedRank,
  ) {
    if (stage.qualifiers < 1 || stage.qualifiers > players.length) {
      throw TournamentSimulationFailure(
        '${stage.name}: ungueltige Weiterkommendenzahl ${stage.qualifiers}.',
      );
    }

    final matches = <GroupMatch>[];
    final matchRecords = <SimulationMatchRecord>[];
    final ranking = _runEliminationRanking(
      players: players,
      lossLimit: stage.lossLimit,
      targetQualifiers: stage.qualifiers,
      seedRank: seedRank,
      matchSink: matches,
      recordSink: matchRecords,
    );

    return _StageSimulationResult(
      ranking.take(stage.qualifiers).toList(),
      matches,
      matchRecords,
    );
  }

  List<TournamentPlayer> _runRoundRobinGroup(
    List<TournamentPlayer> players,
    int repeatCount,
    Map<String, int> seedRank,
    List<GroupMatch> matchSink,
    List<SimulationMatchRecord> recordSink, {
    required String groupName,
  }) {
    final matches = tournamentEngine.buildRoundRobinMatches(
      players,
      repeatCount: repeatCount,
    );
    for (final match in matches) {
      _playMatch(match, seedRank);
    }
    matchSink.addAll(matches);
    for (final match in matches) {
      recordSink.add(
        SimulationMatchRecord(
          number: recordSink.length + 1,
          match: match,
          bracket: '$groupName - Liga',
          homeSource: match.homePlayer?.name ?? 'Freilos',
          awaySource: match.awayPlayer?.name ?? 'Freilos',
        ),
      );
    }

    final standings = {
      for (final player in players) player.name: PlayerStanding(player),
    };
    for (final match in matches) {
      final home = match.homePlayer;
      final away = match.awayPlayer;
      if (home == null || away == null || !match.hasResult) {
        continue;
      }
      final homeStanding = standings[home.name]!;
      final awayStanding = standings[away.name]!;
      homeStanding
        ..played += 1
        ..legsFor += match.homeLegs!
        ..legsAgainst += match.awayLegs!;
      awayStanding
        ..played += 1
        ..legsFor += match.awayLegs!
        ..legsAgainst += match.homeLegs!;

      if (match.homeLegs! > match.awayLegs!) {
        homeStanding
          ..wins += 1
          ..points += 3;
        awayStanding.losses += 1;
      } else if (match.homeLegs! < match.awayLegs!) {
        awayStanding
          ..wins += 1
          ..points += 3;
        homeStanding.losses += 1;
      } else {
        homeStanding
          ..draws += 1
          ..points += 1;
        awayStanding
          ..draws += 1
          ..points += 1;
      }
    }

    final sorted = standings.values.toList()
      ..sort((a, b) {
        final byPoints = b.points.compareTo(a.points);
        if (byPoints != 0) return byPoints;
        final byDiff = b.legDifference.compareTo(a.legDifference);
        if (byDiff != 0) return byDiff;
        final byLegs = b.legsFor.compareTo(a.legsFor);
        if (byLegs != 0) return byLegs;
        return _compareBySeed(a.player, b.player, seedRank);
      });

    return [for (final standing in sorted) standing.player];
  }

  List<TournamentPlayer> _runEliminationRanking({
    required List<TournamentPlayer> players,
    required int lossLimit,
    required int targetQualifiers,
    required Map<String, int> seedRank,
    required List<GroupMatch> matchSink,
    required List<SimulationMatchRecord> recordSink,
    int roundOffset = 0,
    String? bracketPrefix,
  }) {
    final safeLossLimit = lossLimit < 1 ? 1 : lossLimit;
    final losses = {for (final player in players) player.name: 0};
    final sources = {
      for (final player in players)
        player.name: '${player.name} (Startplatz ${seedRank[player.name]! + 1})',
    };
    final eliminated = <TournamentPlayer>[];
    var active = List<TournamentPlayer>.from(players)
      ..sort((a, b) => _compareBySeed(a, b, seedRank));
    var round = 1;

    while (active.length > targetQualifiers) {
      final paired = _pairByLossBracket(active, losses, seedRank);
      final nextActive = <TournamentPlayer>[];
      var playedThisRound = 0;

      for (final pair in paired) {
        if (pair.away == null) {
          nextActive.add(pair.home);
          continue;
        }

        final match = GroupMatch(
          homePlayer: pair.home,
          awayPlayer: pair.away,
          round: roundOffset + round,
          allowsBye: true,
        );
        _playMatch(match, seedRank);
        matchSink.add(match);
        playedThisRound++;
        final recordNumber = recordSink.length + 1;
        recordSink.add(
          SimulationMatchRecord(
            number: recordNumber,
            match: match,
            bracket: _bracketLabelForPair(
              pair.home,
              pair.away!,
              losses,
              safeLossLimit,
              bracketPrefix,
            ),
            homeSource: sources[pair.home.name] ?? pair.home.name,
            awaySource: sources[pair.away!.name] ?? pair.away!.name,
          ),
        );

        final winner = match.winner!;
        final loser = match.loser!;
        losses[loser.name] = losses[loser.name]! + 1;
        sources[winner.name] = 'Sieger Spiel $recordNumber';
        sources[loser.name] = 'Verlierer Spiel $recordNumber';
        nextActive.add(winner);

        if (losses[loser.name]! >= safeLossLimit) {
          eliminated.add(loser);
        } else {
          nextActive.add(loser);
        }
      }

      active = nextActive
        ..sort((a, b) {
          final byLosses = losses[a.name]!.compareTo(losses[b.name]!);
          if (byLosses != 0) return byLosses;
          return _compareBySeed(a, b, seedRank);
        });
      round++;

      if (playedThisRound == 0 && active.length > targetQualifiers) {
        final crossBracketPair = _pairWithoutByeDuel(active, seedRank).first;
        if (crossBracketPair.away == null) {
          throw TournamentSimulationFailure(
            'Eliminationsmodus kommt nicht weiter: '
            '${active.length} aktiv, Ziel $targetQualifiers.',
          );
        }
        final match = GroupMatch(
          homePlayer: crossBracketPair.home,
          awayPlayer: crossBracketPair.away,
          round: roundOffset + round,
          allowsBye: true,
        );
        _playMatch(match, seedRank);
        matchSink.add(match);
        final recordNumber = recordSink.length + 1;
        recordSink.add(
          SimulationMatchRecord(
            number: recordNumber,
            match: match,
            bracket: _bracketLabelForPair(
              crossBracketPair.home,
              crossBracketPair.away!,
              losses,
              safeLossLimit,
              bracketPrefix,
            ),
            homeSource:
                sources[crossBracketPair.home.name] ?? crossBracketPair.home.name,
            awaySource:
                sources[crossBracketPair.away!.name] ?? crossBracketPair.away!.name,
          ),
        );

        final winner = match.winner!;
        final loser = match.loser!;
        losses[loser.name] = losses[loser.name]! + 1;
        sources[winner.name] = 'Sieger Spiel $recordNumber';
        sources[loser.name] = 'Verlierer Spiel $recordNumber';
        active = [winner];
        if (losses[loser.name]! < safeLossLimit) {
          active.add(loser);
        } else {
          eliminated.add(loser);
        }
        active.sort((a, b) => _compareBySeed(a, b, seedRank));
        round++;
        continue;
      }

      if (round > players.length * safeLossLimit * 3) {
        throw TournamentSimulationFailure(
          'Eliminationsmodus hat die Sicherheitsgrenze ueberschritten.',
        );
      }
    }

    active.sort((a, b) => _compareBySeed(a, b, seedRank));
    eliminated.sort((a, b) => _compareBySeed(a, b, seedRank));
    return [...active, ...eliminated];
  }

  List<_Pairing> _pairByLossBracket(
    List<TournamentPlayer> active,
    Map<String, int> losses,
    Map<String, int> seedRank,
  ) {
    final lossValues = {
      for (final player in active) losses[player.name] ?? 0,
    }.toList()
      ..sort();

    return [
      for (final lossValue in lossValues)
        ..._pairWithoutByeDuel(
          [
            for (final player in active)
              if ((losses[player.name] ?? 0) == lossValue) player,
          ],
          seedRank,
        ),
    ];
  }

  String _bracketLabelForPair(
    TournamentPlayer home,
    TournamentPlayer away,
    Map<String, int> losses,
    int lossLimit,
    String? prefix,
  ) {
    final homeLosses = losses[home.name] ?? 0;
    final awayLosses = losses[away.name] ?? 0;
    final lossText = homeLosses == awayLosses
        ? _lossBracketLabel(homeLosses, lossLimit)
        : '${_lossBracketLabel(homeLosses, lossLimit)} / '
              '${_lossBracketLabel(awayLosses, lossLimit)}';
    return prefix == null ? lossText : '$prefix - $lossText';
  }

  String _lossBracketLabel(int losses, int lossLimit) {
    if (lossLimit <= 1) {
      return 'K.-o.-Bracket';
    }
    if (losses == 0) {
      return 'Winners Bracket';
    }
    if (lossLimit == 2) {
      return 'Losers Bracket';
    }
    return '$losses Niederlage${losses == 1 ? '' : 'n'} Bracket';
  }

  List<List<TournamentPlayer>> _splitIntoGroups(
    List<TournamentPlayer> players,
    List<int> groupSizes,
  ) {
    final groups = <List<TournamentPlayer>>[];
    var playerIndex = 0;
    for (final size in groupSizes) {
      final group = <TournamentPlayer>[];
      for (var index = 0; index < size && playerIndex < players.length; index++) {
        group.add(players[playerIndex]);
        playerIndex++;
      }
      groups.add(group);
    }

    if (playerIndex != players.length) {
      throw TournamentSimulationFailure(
        'Gruppengroessen decken ${players.length} Spieler nicht ab.',
      );
    }
    return groups;
  }

  List<_Pairing> _pairWithoutByeDuel(
    List<TournamentPlayer> active,
    Map<String, int> seedRank,
  ) {
    final ordered = List<TournamentPlayer>.from(active)
      ..sort((a, b) => _compareBySeed(a, b, seedRank));
    final pairings = <_Pairing>[];
    var left = 0;
    var right = ordered.length - 1;
    while (left < right) {
      pairings.add(_Pairing(ordered[left], ordered[right]));
      left++;
      right--;
    }
    if (left == right) {
      pairings.add(_Pairing(ordered[left], null));
    }
    return pairings;
  }

  void _playMatch(GroupMatch match, Map<String, int> seedRank) {
    final home = match.homePlayer;
    final away = match.awayPlayer;
    if (home == null || away == null) {
      return;
    }
    final homeWins = _compareBySeed(home, away, seedRank) <= 0;
    match
      ..homeLegs = homeWins ? 2 : 1
      ..awayLegs = homeWins ? 1 : 2;
  }

  String _groupPlayType(SimulationGroupStageSpec stage, int groupIndex) {
    if (groupIndex >= 0 && groupIndex < stage.playTypes.length) {
      return stage.playTypes[groupIndex];
    }
    return 'round_robin';
  }

  int _roundRobinRepeats(SimulationGroupStageSpec stage, int groupIndex) {
    if (groupIndex >= 0 && groupIndex < stage.roundRobinRepeats.length) {
      return stage.roundRobinRepeats[groupIndex] < 1
          ? 1
          : stage.roundRobinRepeats[groupIndex];
    }
    return 1;
  }

  int _fixedQualifierCount(SimulationGroupStageSpec stage, int groupIndex) {
    if (groupIndex >= 0 && groupIndex < stage.fixedByGroup.length) {
      return stage.fixedByGroup[groupIndex];
    }
    return stage.fixedPerGroup;
  }

  int _lossLimitForPlayType(String playType) {
    return switch (playType) {
      'double_knockout' => 2,
      'triple_knockout' => 3,
      _ => 1,
    };
  }

  int _compareBySeed(
    TournamentPlayer a,
    TournamentPlayer b,
    Map<String, int> seedRank,
  ) {
    return (seedRank[a.name] ?? 1 << 30).compareTo(seedRank[b.name] ?? 1 << 30);
  }

  void _validateUniquePlayers(List<TournamentPlayer> players, String context) {
    final seen = <String>{};
    for (final player in players) {
      if (!seen.add(player.name)) {
        throw TournamentSimulationFailure(
          '$context enthaelt ${player.name} doppelt.',
        );
      }
    }
  }

  void _validateMatches(List<GroupMatch> matches, String context) {
    for (final match in matches) {
      final home = match.homePlayer;
      final away = match.awayPlayer;
      if (home != null && away != null && home.name == away.name) {
        throw TournamentSimulationFailure(
          '$context: ${home.name} spielt gegen sich selbst.',
        );
      }
      if (home == null && away == null) {
        throw TournamentSimulationFailure(
          '$context: Freilos gegen Freilos erzeugt.',
        );
      }
      if (home != null && away != null && !match.hasResult) {
        throw TournamentSimulationFailure(
          '$context: ${home.name} vs ${away.name} hat kein Ergebnis.',
        );
      }
    }
  }
}

class _StageSimulationResult {
  const _StageSimulationResult(
    this.advancingPlayers,
    this.matches,
    this.matchRecords,
  );

  final List<TournamentPlayer> advancingPlayers;
  final List<GroupMatch> matches;
  final List<SimulationMatchRecord> matchRecords;
}

class _Pairing {
  const _Pairing(this.home, this.away);

  final TournamentPlayer home;
  final TournamentPlayer? away;
}
