import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_lobby.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_opponents.dart';
import 'package:dart_tournament_manager/features/scorer/application/scorer_lobby_controller.dart';
import 'support/scorer_lobby_fake.dart';

void main() {
  test('Only scorer links and complete random codes are accepted', () {
    const code = '0123456789ABCDEF0123456789ABCDEF';
    expect(ScorerJoinCode.parse(ScorerJoinCode.link(code)), code);
    expect(ScorerJoinCode.parse(code.toLowerCase()), code);
    for (final invalid in [
      'ABCD1234',
      'https://scorer/join?code=$code',
      'dartturnier://community/join?code=$code',
      'dartturnier://scorer/join?code=$code&code=$code',
      'dartturnier://user@scorer/join?code=$code',
      'dartturnier://scorer:99/join?code=$code',
      'dartturnier://scorer/join?code=$code#fragment',
    ]) {
      expect(ScorerJoinCode.parse(invalid), isNull);
    }
  });
  test(
    'Opponent modes enforce their own roster rules with multiple opponents',
    () {
      expect(ScorerOpponents.players.accepts(4, 0), true);
      expect(ScorerOpponents.players.accepts(2, 1), false);
      expect(ScorerOpponents.bots.accepts(1, 4), true);
      expect(ScorerOpponents.bots.accepts(2, 1), false);
      expect(ScorerOpponents.mixed.accepts(3, 2), true);
      expect(ScorerOpponents.mixed.accepts(1, 2), false);
      expect(ScorerOpponents.mixed.accepts(2, 0), false);
    },
  );
  test(
    'Lobby refresh deduplicates by server identity and close captures last join',
    () async {
      final repo = FakeScorerLobbyRepository();
      final controller = ScorerLobbyController(repo);
      addTearDown(controller.dispose);
      await controller.create();
      repo.members = [const LobbyMember('a', 'Anna')];
      await controller.refresh();
      expect(controller.lobby!.members.single.id, 'a');
      repo.members.add(const LobbyMember('b', 'Ben'));
      await controller.close();
      expect(controller.lobby!.members.length, 2);
      expect(controller.lobby!.open, false);
    },
  );
  test('Failed closing can be retried without losing participants', () async {
    final repo = FakeScorerLobbyRepository()
      ..members = [const LobbyMember('a', 'Anna')];
    final controller = ScorerLobbyController(repo);
    addTearDown(controller.dispose);
    await controller.create();
    repo.failClose = true;
    await expectLater(controller.close(), throwsStateError);
    expect(controller.busy, false);
    expect(controller.lobby!.open, true);
    repo.failClose = false;
    await controller.close();
    expect(controller.lobby!.members.single.name, 'Anna');
  });
}
