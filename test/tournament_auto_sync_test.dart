import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/tournaments/application/tournament_sync_service.dart';
import 'package:dart_tournament_manager/features/tournaments/data/tournament_storage.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'package:dart_tournament_manager/features/league/domain/league_match.dart';

class RecordingStorage extends TournamentStorage {
  int attempts = 0;
  Completer<void>? pending;
  @override
  Future<void> synchronize({String? tournamentId}) async {
    attempts++;
    await pending?.future;
  }
}

void main() {
  testWidgets('starts, retries every two minutes, avoids overlap and stops', (
    tester,
  ) async {
    final storage = RecordingStorage();
    final service = TournamentSyncService(storage: storage);
    service.start();
    service.start();
    await tester.pump();
    expect(storage.attempts, 1);
    await tester.pump(const Duration(minutes: 2));
    expect(storage.attempts, 2);
    storage.pending = Completer<void>();
    await tester.pump(const Duration(minutes: 2));
    await tester.pump(const Duration(minutes: 2));
    expect(storage.attempts, 3);
    storage.pending!.complete();
    await tester.pump();
    service.dispose();
    await tester.pump(const Duration(minutes: 4));
    expect(storage.attempts, 3);
  });
  test(
    'an in-flight upload cannot block saves or acknowledge newer changes',
    () async {
      final dir = await Directory.systemTemp.createTemp('sync_concurrency');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/tournaments.json');
      final started = Completer<void>();
      final release = Completer<void>();
      final rows = <Map<String, dynamic>>[];
      final storage = TournamentStorage(
        file: file,
        currentUserId: () => 'u',
        authorize: (_, _) async {},
        upload: (row) async {
          rows.add(row);
          if (rows.length == 1) {
            started.complete();
            await release.future;
          }
        },
      );
      final tournament = CreatedTournament(
        id: 't',
        name: 'Initial',
        communityId: 'c',
        players: [],
        stages: [],
        runStages: [],
      );
      await storage.saveTournament(tournament);
      final upload = storage.synchronize();
      await started.future;
      final changed = CreatedTournament.fromJson(
        tournament.toJson()..['name'] = 'Latest',
      );
      try {
        await storage
            .saveTournament(changed)
            .timeout(const Duration(seconds: 2));
        final document = jsonDecode(await file.readAsString()) as Map;
        expect(document['tournaments'][0]['name'], 'Latest');
        expect(document['pending']['t']['payload']['name'], 'Latest');
      } finally {
        release.complete();
        await upload;
      }
      expect(
        (jsonDecode(await file.readAsString()) as Map)['pending'],
        isNotEmpty,
      );
      await storage.synchronize();
      expect(rows.last['payload']['name'], 'Latest');
      expect(
        (jsonDecode(await file.readAsString()) as Map)['pending'],
        isEmpty,
      );
      expect((await storage.loadTournaments()).single.name, 'Latest');
    },
  );
  test(
    'league completion is uploaded and offline completion survives restart',
    () async {
      final dir = await Directory.systemTemp.createTemp('league_sync');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/tournaments.json');
      var attempts = 0;
      final storage = TournamentStorage(
        file: file,
        currentUserId: () => 'u',
        authorize: (_, _) async {},
        upload: (_) async {
          attempts++;
          throw const SocketException('offline');
        },
      );
      final league = LeagueMatch.rhl(
        homeTeam: 'H',
        awayTeam: 'A',
        homePlayers: ['1', '2', '3', '4'],
        awayPlayers: ['5', '6', '7', '8'],
      );
      for (final game in league.games) {
        game.score(3, 1);
      }
      await storage.saveTournament(
        CreatedTournament(
          id: 'l',
          name: 'League',
          communityId: 'c',
          players: [],
          stages: [],
          runStages: [],
          leagueMatch: league,
        ),
      );
      // Queued behind the automatic completion attempt.
      await storage.synchronize();
      expect(attempts, greaterThanOrEqualTo(1));
      final uploaded = <Map<String, dynamic>>[];
      final restarted = TournamentStorage(
        file: file,
        currentUserId: () => 'u',
        upload: (row) async => uploaded.add(row),
      );
      await restarted.synchronize();
      expect(uploaded.single['client_tournament_id'], 'l');
      expect(
        (await restarted.loadTournaments()).single.leagueMatch!.complete,
        isTrue,
      );
    },
  );
}
