import 'dart:math';
import 'package:dart_tournament_manager/tournament_workspace.dart'
    show ProductionTournamentRuntime;
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
    this.gameFormat = const TournamentGameFormat(),
    this.placementPlaces = const [],
  });

  final String name;
  final int qualifiers;
  final TournamentGameFormat gameFormat;
  final List<int> placementPlaces;
}

class SimulationGroupStageSpec extends SimulationStageSpec {
  const SimulationGroupStageSpec({
    required super.name,
    required super.qualifiers,
    super.gameFormat,
    super.placementPlaces,
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
    super.gameFormat,
    super.placementPlaces,
    required this.lossLimit,
    this.finalEndsTournament = false,
  });

  final int lossLimit;
  final bool finalEndsTournament;
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
    this.groupTables = const {},
    this.lossLimit = 1,
    this.finalEndsTournament = false,
  });

  final String name;
  final int inputCount;
  final int outputCount;
  final int matchCount;
  final List<GroupMatch> matches;
  final List<SimulationMatchRecord> matchRecords;
  final Map<String, List<PlayerStanding>> groupTables;
  final int lossLimit;
  final bool finalEndsTournament;
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
  TournamentSimulationReport run(
    TournamentSimulationScenario scenario, {
    int? seed,
    bool randomResults = false,
  }) {
    final resultsRandom = Random(seed);
    if (scenario.playerCount < 2 || scenario.stages.isEmpty) {
      throw const TournamentSimulationFailure('Ungültiges Szenario');
    }
    final players = [
      for (var i = 1; i <= scenario.playerCount; i++)
        TournamentPlayer.generated(i),
    ];
    final strength = [...players];
    if (seed != null) strength.shuffle(Random(seed));
    final ranks = {
      for (var i = 0; i < strength.length; i++) strength[i].name: i,
    };
    var count = players.length;
    final configs = <TournamentStage>[];
    for (final spec in scenario.stages) {
      if (spec.qualifiers < 1 || spec.qualifiers > count) {
        throw const TournamentSimulationFailure('Ungültige Qualifikation');
      }
      if (spec is SimulationGroupStageSpec) {
        if (spec.groupSizes.fold<int>(0, (a, b) => a + b) != count) {
          throw const TournamentSimulationFailure(
            'Gruppengrößen passen nicht zur Spielerzahl',
          );
        }
        configs.add(
          TournamentStage(
            name: spec.name,
            gameFormat: spec.gameFormat,
            placementPlaces: spec.placementPlaces,
            type: 'groups',
            finalEndsTournament: false,
            groupCount: spec.groupSizes.length,
            groupSizes: spec.groupSizes,
            groupPlayType: 'round_robin',
            groupPlayTypes: spec.playTypes,
            groupRoundRobinRepeats: spec.roundRobinRepeats,
            qualifiedParticipantCount: spec.qualifiers,
            fixedQualifiersByGroup: spec.fixedByGroup.isNotEmpty
                ? spec.fixedByGroup
                : [
                    for (final size in spec.groupSizes)
                      min(size, spec.fixedPerGroup),
                  ],
            qualificationAutoAdjust: false,
            extraQualifierCount: spec.extraCount,
            extraQualifierRank: spec.extraRank,
            qualifiersByGroup: spec.extraGroups,
          ),
        );
      } else if (spec is SimulationEliminationStageSpec) {
        configs.add(
          TournamentStage(
            name: spec.name,
            gameFormat: spec.gameFormat,
            placementPlaces: spec.placementPlaces,
            finalEndsTournament: spec.finalEndsTournament,
            knockoutLives: spec.lossLimit,
            type: spec.lossLimit >= 3
                ? 'triple_knockout'
                : spec.lossLimit == 2
                ? 'double_knockout'
                : 'single_knockout',
            groupCount: 0,
            groupSizes: const [],
            knockoutParticipantCount: count,
          ),
        );
      }
      count = spec.qualifiers;
    }
    // The live runtime obtains a stage's target from the following stage.
    // A sentinel supplies the final scenario target without changing the rules.
    configs.add(
      TournamentStage(
        name: 'Simulationsziel',
        type: 'single_knockout',
        groupCount: 0,
        groupSizes: const [],
        knockoutParticipantCount: count,
      ),
    );
    final tournament = CreatedTournament(
      name: scenario.name,
      players: players,
      stages: configs,
      runStages: [],
    );
    final runtime = ProductionTournamentRuntime(tournament);
    var incoming = players;
    final reports = <SimulationStageReport>[];
    for (var index = 0; index < scenario.stages.length; index++) {
      final stage = runtime.build(configs[index], incoming);
      tournament.runStages.add(stage);
      runtime.activate(index);
      final sources = <String, String>{
        for (final player in incoming) player.name: player.name,
      };
      final records = <SimulationMatchRecord>[];
      final recorded = <GroupMatch>{};
      var iterations = 0;
      while (true) {
        runtime.advance();
        final all = runtime.matches(stage);
        for (final match in all.where(
          (m) =>
              m.round == 1 &&
              m.isResolved &&
              !m.hasPlayers &&
              (m.homePlayer != null || m.awayPlayer != null),
        )) {
          if (recorded.add(match)) {
            records.add(_record(stage, match, records.length + 1, sources));
            if (match.winner != null) {
              sources[match.winner!.name] = 'Sieger Spiel ${records.last.number}';
            }
          }
        }
        if (!runtime.hasOpen(stage)) break;
        final ready = all.where((m) => m.hasPlayers && !m.isResolved).toList();
        if (ready.isEmpty || ++iterations > 10000) {
          throw TournamentSimulationFailure(
            '${scenario.name} / ${stage.name}: Produktiver Ablauf blockiert',
          );
        }
        final match = ready.first;
        final record = _record(stage, match, records.length + 1, sources);
        final homeWins = randomResults
            ? resultsRandom.nextBool()
            : ranks[match.homePlayer!.name]! < ranks[match.awayPlayer!.name]!;
        final format = configs[index].gameFormat;
        final target = format.bestOfLegs ~/ 2 + 1;
        if (format.bestOfSets > 1) {
          final setTarget = format.bestOfSets ~/ 2 + 1;
          final lostSets = randomResults
              ? resultsRandom.nextInt(setTarget)
              : setTarget - 1;
          match.homeSets = homeWins ? setTarget : lostSets;
          match.awaySets = homeWins ? lostSets : setTarget;
          match.homeLegs = match.homeSets! * target;
          match.awayLegs = match.awaySets! * target;
          if (randomResults) {
            for (var i = 0; i < match.awaySets!; i++) {
              match.homeLegs = match.homeLegs! + resultsRandom.nextInt(target);
            }
            for (var i = 0; i < match.homeSets!; i++) {
              match.awayLegs = match.awayLegs! + resultsRandom.nextInt(target);
            }
          }
        } else if (format.allowsDraws &&
            !match.isDecider &&
            (randomResults
                ? resultsRandom.nextInt(3) == 0
                : iterations % 3 == 0)) {
          match.homeLegs = format.bestOfLegs ~/ 2;
          match.awayLegs = format.bestOfLegs ~/ 2;
        } else {
          final maximumLost = format.allowsDraws && !match.isDecider
              ? target - 2
              : target - 1;
          final lostLegs = randomResults
              ? resultsRandom.nextInt(maximumLost + 1)
              : maximumLost;
          match.homeLegs = homeWins ? target : lostLegs;
          match.awayLegs = homeWins ? lostLegs : target;
        }
        records.add(record);
        recorded.add(match);
        if (match.winner != null) {
          sources[match.winner!.name] = 'Sieger Spiel ${record.number}';
          sources[match.loser!.name] = 'Verlierer Spiel ${record.number}';
        }
      }
      final advancing = runtime
          .qualifiers(stage)
          .take(scenario.stages[index].qualifiers)
          .toList();
      if (advancing.length != scenario.stages[index].qualifiers) {
        throw const TournamentSimulationFailure('Zu wenige Weiterkommende');
      }
      final tables = <String, List<PlayerStanding>>{};
      if (stage is GroupTournamentRunStage) {
        for (final group in stage.groups.where(
          (g) => g.playType == 'round_robin',
        )) {
          tables[group.name] = runtime.standings(group, stage.tieBreakers);
        }
      }
      final played = records
          .where((r) => r.match.hasResult)
          .map((r) => r.match)
          .toList();
      reports.add(
        SimulationStageReport(
          name: stage.name,
          lossLimit: stage is KnockoutTournamentRunStage ? stage.eliminationLossLimit : 1,
          finalEndsTournament: stage is KnockoutTournamentRunStage && stage.finalEndsTournament,
          inputCount: incoming.length,
          outputCount: advancing.length,
          matchCount: played.length,
          matches: played,
          matchRecords: records,
          groupTables: tables,
        ),
      );
      incoming = advancing;
    }
    return TournamentSimulationReport(
      scenarioName: scenario.name,
      finalPlayers: incoming,
      stageReports: reports,
      totalMatches: reports.fold<int>(0, (sum, r) => sum + r.matchCount),
    );
  }

  SimulationMatchRecord _record(
    TournamentRunStage stage,
    GroupMatch match,
    int number,
    Map<String, String> sources,
  ) {
    var bracket = stage.name;
    if (stage is GroupTournamentRunStage) {
      for (final group in stage.groups) {
        if (group.matches.contains(match)) {
          bracket =
              '${group.name} - ${group.playType == 'round_robin' ? 'Liga' : group.playType}';
          break;
        }
      }
    }
    return SimulationMatchRecord(
      number: number,
      match: match,
      bracket: bracket,
      homeSource: match.homePlayer == null
          ? 'Freilos'
          : sources[match.homePlayer!.name] ?? match.homePlayer!.name,
      awaySource: match.awayPlayer == null
          ? 'Freilos'
          : sources[match.awayPlayer!.name] ?? match.awayPlayer!.name,
    );
  }
}
