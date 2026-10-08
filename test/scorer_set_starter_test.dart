import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/scorer/application/scorer_controller.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_settings.dart';
import 'package:dart_tournament_manager/features/scorer/data/scorer_draft_storage.dart';

void win(ScorerController c, int player) {
  if (c.activePlayer != player) c.submitScore(0);
  c.submitScore(40, checkoutDarts: 1, checkoutAttempts: 1);
}

void main() {
  for (final first in [0, 1]) {
    for (final length in [2, 3]) {
      test('set starts rotate after $length legs, first player $first; undo and reload agree', () {
        final c = ScorerController(ScorerSettings(startScore: 40, bestOfLegs: 3, bestOfSets: 5, startingPlayer: first,
          participants: const [ScorerParticipant('A'), ScorerParticipant('B')]));
        addTearDown(c.dispose);
        win(c, first);
        expect(c.legStarter, 1 - first);
        if (length == 3) win(c, 1 - first);
        win(c, first);
        expect(c.legStarter, 1 - first);
        expect(c.activePlayer, 1 - first);
        c.undo();
        expect(c.sets, [0, 0]);
        win(c, first);
        expect(c.legStarter, 1 - first);
        final checkpoint = ScorerDraftStorage.checkpoint(c, sessionId: 'test', playedAt: DateTime.utc(2026));
        final restored = ScorerController(ScorerDraftStorage.decodeSettings(checkpoint['settings'] as Map<String, dynamic>))
          ..restoreActions(checkpoint['actions'] as List);
        addTearDown(restored.dispose);
        expect(restored.legStarter, c.legStarter);
        expect(restored.sets, c.sets);
        win(restored, first);
        win(restored, first);
        expect(restored.legStarter, first);
      });
    }
  }
  test('legacy drafts retain continuous leg starts for faithful replay', () {
    final json = ScorerDraftStorage.encodeSettings(ScorerSettings(startScore: 40, bestOfLegs: 3, bestOfSets: 3, participants: const [ScorerParticipant('A'), ScorerParticipant('B')]))..remove('alternateSetStarts');
    final c = ScorerController(ScorerDraftStorage.decodeSettings(json));
    addTearDown(c.dispose);
    win(c, 0);
    win(c, 0);
    expect(c.legStarter, 0);
  });
}
