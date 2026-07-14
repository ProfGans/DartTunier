import 'package:flutter/material.dart';

import 'app/dart_tournament_app.dart';

export 'app/dart_tournament_app.dart';
export 'features/tournaments/application/tournament_creation_controller.dart';
export 'features/tournaments/application/tournament_run_controller.dart';
export 'features/tournaments/data/tournament_storage.dart';
export 'features/tournaments/domain/engines/tournament_engine.dart';
export 'features/tournaments/domain/tournament_models.dart'
    hide defaultGroupTieBreakers, groupLabel;
export 'tournament_workspace.dart';

void main() {
  runApp(const DartTournamentApp());
}
