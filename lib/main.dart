import 'package:flutter/material.dart';

import 'app/app_bootstrap.dart';
import 'app/storage_session_root.dart';

export 'app/dart_tournament_app.dart';
export 'features/accounts/application/account_session_store.dart';
export 'features/accounts/domain/account_user.dart';
export 'features/accounts/presentation/widgets/account_menu_card.dart';
export 'features/communities/presentation/community_page.dart';
export 'features/tournaments/application/tournament_creation_controller.dart';
export 'features/tournaments/application/tournament_run_controller.dart';
export 'features/tournaments/data/tournament_storage.dart';
export 'features/tournaments/domain/engines/tournament_engine.dart';
export 'features/tournaments/domain/tournament_models.dart'
    hide defaultGroupTieBreakers, groupLabel;
export 'tournament_workspace.dart';

Future<void> main() async {
  final startupError = await AppBootstrap.initialize();
  runApp(StorageSessionRoot(startupError: startupError));
}
