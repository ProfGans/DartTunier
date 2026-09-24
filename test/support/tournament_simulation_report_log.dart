import 'dart:io';

import 'tournament_simulation_engine.dart';
import 'package:dart_tournament_manager/features/dev_tools/domain/tournament_simulation_report.dart';
export 'package:dart_tournament_manager/features/dev_tools/domain/tournament_simulation_report.dart';

const tournamentSimulationLogPath =
    'build/tournament_simulation/tournament_trees.log';

void writeTournamentSimulationLog(List<TournamentSimulationReport> reports, {List<String> failures = const []}) {
  final file = File(tournamentSimulationLogPath);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync('${formatTournamentSimulationLog(reports)}\n${failures.map((error) => 'FEHLER: $error').join('\n')}');
}
