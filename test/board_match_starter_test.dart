import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/devices/application/board_match_starter.dart';
import 'package:dart_tournament_manager/features/devices/application/board_display_projector.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'order_of_play_test.dart' show fixture;

void main() {
  test(
    'device starts default off and persist with backwards compatible migration',
    () {
      final t = fixture();
      expect(t.allowDeviceStart, isFalse);
      t.allowDeviceStart = true;
      expect(CreatedTournament.fromJson(t.toJson()).allowDeviceStart, isTrue);
      expect(
        CreatedTournament.fromJson(
          t.toJson()..remove('allowDeviceStart'),
        ).allowDeviceStart,
        isFalse,
      );
    },
  );
  test('only allowed current assignment can start on its free board', () {
    final t = fixture();
    final preview = const BoardDisplayProjector().project(t, 0)[1]!;
    const starter = BoardMatchStarter();
    expect(starter.start(t, 0, 1, preview.matchId!), isNull);
    t.allowDeviceStart = true;
    expect(starter.start(t, 0, 1, 'stale'), isNull);
    expect(starter.start(t, 0, 2, preview.matchId!), isNull);
    final match = starter.start(t, 0, 1, preview.matchId!);
    expect(match, isNotNull);
    expect(match!.boardNumber, 1);
    expect(match.startedAt, isNotNull);
    expect(starter.start(t, 0, 1, preview.matchId!), isNull);
  });
  test('blocked boards and completed stages reject starts', () {
    final t = fixture()..allowDeviceStart = true;
    final id = const BoardDisplayProjector().project(t, 0)[1]!.matchId!;
    t.blockedBoards.add(1);
    expect(const BoardMatchStarter().start(t, 0, 1, id), isNull);
    t.blockedBoards.clear();
    t.completedStageIndexes.add(0);
    expect(const BoardMatchStarter().start(t, 0, 1, id), isNull);
  });
}
