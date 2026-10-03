import 'dart:math';

import '../../devices/application/device_result_importer.dart';
import '../../devices/application/device_scorer_settings.dart';
import '../../devices/domain/board_display.dart';
import '../../scorer/application/scorer_controller.dart';

import '../domain/tournament_models.dart';

/// Runs only the earliest unfinished round, across all groups in a stage.
/// Unknown participants and matches involving a human hold back that round.
class TournamentBotRoundSimulator {
  bool _running = false;

  Future<int> run({
    required List<GroupMatch> Function() matches,
    required TournamentGameFormat format,
    required void Function() advance,
    required bool Function() isActive,
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
          final controller = ScorerController(
            deviceScorerSettings(
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
            ),
            random: random,
          );
          try {
            for (var darts = 0; !controller.isComplete; darts++) {
              if (darts >= 1000000) {
                throw StateError('Bot-Spiel konnte nicht beendet werden.');
              }
              controller.playBotDart();
              if (darts % 300 == 0) await Future<void>.delayed(Duration.zero);
              if (!isActive()) return count;
            }
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
              'legs': controller.statistics.players
                  .map((p) => p.legsWon)
                  .toList(),
              'sets': controller.sets.toList(),

            }, format);
            count++;
          } finally {
            controller.dispose();
          }
        }
        advance();
      }
      return count;
    } finally {
      _running = false;
    }
  }
}
