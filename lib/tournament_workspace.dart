import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'features/players/presentation/players_page.dart';
import 'features/accounts/presentation/widgets/account_menu_card.dart';
import 'features/communities/presentation/community_page.dart';
import 'features/tournaments/application/tournament_creation_controller.dart';
import 'features/tournaments/application/tournament_run_controller.dart';
import 'features/tournaments/data/app_database.dart';
import 'features/tournaments/data/tournament_storage.dart';
import 'features/tournaments/domain/engines/tournament_engine.dart';
import 'features/tournaments/domain/tournament_models.dart'
    hide defaultGroupTieBreakers, groupLabel;
import 'features/tournaments/presentation/models/match_result.dart';
import 'features/tournaments/presentation/widgets/creation/stage_setup_widgets.dart';
import 'features/tournaments/presentation/widgets/run/group_stage_run_section.dart';
import 'features/tournaments/presentation/widgets/run/knockout_run_section.dart';
import 'features/tournaments/presentation/widgets/run/result_entry.dart';
import 'features/tournaments/presentation/widgets/run/stage_controls.dart';
import 'features/tournaments/presentation/widgets/run/stage_play_order_section.dart';

part 'features/home/presentation/home_page.dart';
part 'features/tournaments/domain/rules/tournament_rules.dart';
part 'features/tournaments/modes/common/tournament_mode_common.dart';
part 'features/tournaments/modes/groups/tournament_mode_groups.dart';
part 'features/tournaments/modes/double_ko/tournament_mode_double_ko.dart';
part 'features/tournaments/modes/triple_ko/tournament_mode_triple_ko.dart';
part 'features/tournaments/presentation/pages/tournament_creation_page.dart';
part 'features/tournaments/presentation/pages/tournament_run_page.dart';
part 'features/tournaments/presentation/widgets/player_list.dart';
part 'features/tournaments/presentation/widgets/creation/random_draw_dialog.dart';
part 'features/tournaments/presentation/widgets/tournament_creation_widgets.dart';
part 'features/tournaments/presentation/widgets/run/brackets/knockout_bracket_view.dart';
