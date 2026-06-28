import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

part 'tournament_models.dart';
part 'tournament_storage.dart';
part 'tournament_rules.dart';
part 'tournament_mode_common.dart';
part 'tournament_mode_groups.dart';
part 'tournament_mode_double_ko.dart';
part 'tournament_mode_triple_ko.dart';
part 'home_page.dart';
part 'tournament_creation_page.dart';
part 'player_list.dart';
part 'tournament_run_page.dart';
part 'tournament_run_widgets.dart';
part 'tournament_creation_widgets.dart';

void main() {
  runApp(const DartTournamentApp());
}
