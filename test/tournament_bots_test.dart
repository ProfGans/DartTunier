import 'dart:math';
import 'package:dart_tournament_manager/features/communities/domain/community.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_elo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/tournaments/application/tournament_bot_factory.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'package:dart_tournament_manager/features/devices/domain/board_display.dart';
import 'package:dart_tournament_manager/features/devices/application/board_display_projector.dart';
import 'package:dart_tournament_manager/features/devices/application/device_scorer_settings.dart';
import 'package:dart_tournament_manager/features/devices/application/device_result_importer.dart';
import 'package:dart_tournament_manager/features/tournaments/application/order_of_play/order_of_play_controller.dart';
import 'package:dart_tournament_manager/features/scorer/application/scorer_controller.dart';
import 'package:dart_tournament_manager/features/scorer/data/scorer_draft_storage.dart';
import 'package:dart_tournament_manager/features/statistics/domain/saved_scorer_match.dart';

void main() {
  test(
    'batch bots have unique names and persistent Theo profiles in range',
    () async {
      final bots = await TournamentBotFactory.create(
        count: 10,
        minimum: 40,
        maximum: 70,
        existingNames: ['Bot 1'],
        random: Random(42),
      );
      expect(bots.length, 10);
      expect(bots.map((p) => p.name).toSet().length, 10);
      expect(bots.any((p) => p.name == 'Bot 1'), isFalse);
      expect(
        bots.map((p) => p.bot!.targetAverage).toSet().length,
        greaterThan(1),
      );
      for (final p in bots) {
        expect(p.bot!.targetAverage, inInclusiveRange(40, 70));
        expect(TournamentPlayer.fromJson(p.toJson()), p);
        expect(p.copyWith(name: 'Neu').bot, p.bot);
      }
      expect(
        TournamentPlayer.fromJson({'name': 'Alt', 'isGenerated': false}).bot,
        isNull,
      );
      await expectLater(
        TournamentBotFactory.create(
          count: 10,
          minimum: 70,
          maximum: 40,
          existingNames: [],
        ),
        throwsArgumentError,
      );
    },
  );
  test(
    'bot versus bot travels through board scorer and result import',
    () async {
      final bots = await TournamentBotFactory.create(
        count: 2,
        minimum: 70,
        maximum: 70,
        existingNames: [],
      );
      final match = GroupMatch(
        homePlayer: bots[0],
        awayPlayer: bots[1],
        round: 1,
      );
      const format = TournamentGameFormat(x01Score: 40, bestOfLegs: 1);
      final t = CreatedTournament(
        name: 'Bots',
        communityId: 'community',
        players: bots,
        stages: const [
          TournamentStage(
            name: 'Finale',
            type: 'single_knockout',
            gameFormat: format,
          ),
        ],
        runStages: [
          KnockoutTournamentRunStage(
            name: 'Finale',
            rounds: [
              [match],
            ],
          ),
        ],
      );
      const OrderOfPlayController().start(t, 0, match, 1);
      final display = BoardDisplay.fromJson(
        const BoardDisplayProjector().project(t, 0)[1]!.toJson(),
      );
      final settings = deviceScorerSettings(display);
      expect(settings.participants.every((p) => p.bot != null), isTrue);
      final restored = ScorerDraftStorage.decodeSettings(
        ScorerDraftStorage.encodeSettings(settings),
      );
      final controller = ScorerController(restored, random: Random(7));
      addTearDown(controller.dispose);
      for (var i = 0; i < 10000 && !controller.isComplete; i++) {
        controller.playBotDart();
      }
      expect(controller.isComplete, isTrue);
      final stats = SavedScorerMatch(
        id: display.matchId!,
        accountId: '',
        playedAt: DateTime.now(),
        playerIndex: 0,
        names: bots.map((p) => p.name).toList(),
        startScores: [40, 40],
        standard501Rules: true,
        doubleOut: true,
        visits: controller.statisticsVisits,
        winner: controller.winner,
      );
      final result = <String, dynamic>{
        'version': 1,
        'matchId': display.matchId,
        'legs': controller.statistics.players.map((p) => p.legsWon).toList(),
        'sets': controller.sets.toList(),
        'statistics': stats.toJson(),
      };
      const importer = DeviceResultImporter();
      expect(importer.validate(t, result), same(match));
      importer.apply(match, result, format);
      final copy = CreatedTournament.fromJson(t.toJson());
      expect(copy.players.first.bot, bots.first.bot);
      expect(match.hasResult, isTrue);
      final elo = const CommunityEloCalculator().calculate(
        members: [
          for (final p in bots)
            CommunityMember(
              userId: p.name,
              displayName: p.name,
              role: 'member',
              joinedAt: DateTime(2026),
            ),
        ],
        tournaments: [t],
        currentYearOnly: false,
      );
      expect(
        elo.entries,
        isEmpty,
        reason:
            'Bots must not be mistaken for community members with the same name',
      );
    },
  );
}
