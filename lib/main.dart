import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

part 'tournament_models.dart';
part 'tournament_storage.dart';
part 'tournament_rules.dart';
part 'tournament_elimination.dart';
part 'home_page.dart';
part 'tournament_creation_page.dart';
part 'player_list.dart';
part 'tournament_run_page.dart';
part 'tournament_run_widgets.dart';
part 'tournament_creation_widgets.dart';

void main() {
  runApp(const DartTournamentApp());
}
