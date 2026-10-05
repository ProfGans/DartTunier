import 'dart:math';
import 'package:flutter/foundation.dart';

import '../../devices/application/device_result_importer.dart';
import '../../devices/application/device_scorer_settings.dart';
import '../../devices/domain/board_display.dart';
import '../../scorer/application/scorer_controller.dart';
import '../../scorer/data/repositories/checkout_route_repository.dart';

import '../domain/tournament_models.dart';

// Native Flutter runs compute in an isolate: checkout searches cannot block UI.
Future<List<List<int>>> _simulateBotMatch((BoardDisplay, int) input) async {
  await CheckoutRouteRepository.instance.initialize();
  final controller = ScorerController(
    deviceScorerSettings(input.$1),
    random: Random(input.$2),
  );
  try {
    for (var darts = 0; !controller.isComplete; darts++) {
      if (darts >= 100000) {
        throw StateError('Bot-Spiel konnte nicht beendet werden.');
      }
      controller.playBotDart();
      controller.discardReplayHistory();
    }
    return [
      controller.statistics.players.map((p) => p.legsWon).toList(),
      controller.sets.toList(),
    ];
  } finally {
    controller.dispose();
  }
}

/// Runs only the earliest unfinished round, across all groups in a stage.
/// Unknown participants and matches involving a human hold back that round.
class TournamentBotRoundSimulator {
  bool _running = false;

  Future<int> run({
    required List<GroupMatch> Function() matches,
    required TournamentGameFormat format,
    required void Function() advance,
    required bool Function() isActive,
    Future<void> Function()? checkpoint,
    Random? random,
  }) async {
    if (_running) return 0;
    _running = true;
    var count = 0;
    try {
      while (isActive()) {
        final open = matches().where((m) => !m.isResolved).toList();
        if (open.isEmpty) break;
        final round = open.map((m) => m.round).reduce(min);
        final wave = open.where((m) => m.round == round).toList();
        if (wave.any(
          (m) =>
              !m.hasPlayers ||
              m.homePlayer?.bot == null ||
              m.awayPlayer?.bot == null ||
              m.startedAt != null,
        )) {
          break;
        }
        for (final match in wave) {
          final home = match.homePlayer!;
          final away = match.awayPlayer!;
          final result = await compute(_simulateBotMatch, (
            BoardDisplay(
              tournamentId: '',
              tournamentName: '',
              board: 1,
              state: 'planned',
              home: home.name,
              away: away.name,
              homeBot: home.bot,
              awayBot: away.bot,
              gameFormat: format,
            ),
            (random ?? Random()).nextInt(1 << 31),
          ));
          if (!isActive()) { return count; }
          // Results may have been edited or a device started while yielding.
          if (match.isResolved ||
              match.startedAt != null ||
              match.homePlayer != home ||
              match.awayPlayer != away ||
              matches().any(
                (m) =>
                    !m.isResolved &&
                    m.round <= round &&
                    (!m.hasPlayers ||
                        m.homePlayer?.bot == null ||
                        m.awayPlayer?.bot == null),
              )) {
            return count;
          }
          final now = DateTime.now();
          final id = 'bot-${now.microsecondsSinceEpoch}';
          const DeviceResultImporter().apply(match, {
            'version': 1,
            'matchId': id,
            'automaticallySimulated': true,
            'legs': result[0],
            'sets': result[1],
          }, format);
          count++;
          await checkpoint?.call();
        }
        advance();
        await checkpoint?.call();
      }
      return count;
    } finally {
      _running = false;
    }
  }
}
