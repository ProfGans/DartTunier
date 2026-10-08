import 'dart:convert';
import '../domain/tournament_models.dart';
import 'tournament_result_importer.dart';

enum TournamentResultReceipt { accepted, alreadyAccepted }

/// Transport-independent result port. Adapters must authenticate their source;
/// authorization, saving and production advancement are supplied by the host.
class TournamentResultReceiver {
  TournamentResultReceiver({
    required this.tournament,
    required this.authorize,
    required this.save,
    required this.advance,
  });
  final CreatedTournament tournament;
  final Future<void> Function() authorize;
  final Future<void> Function() save;
  final Future<void> Function() advance;
  Future<void> _queue = Future.value();

  Future<TournamentResultReceipt> submit(Map<String, dynamic> payload) async {
    // Detach before waiting: an adapter must not mutate a queued request.
    final result = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
    if (result['version'] != 1 ||
        result['matchId'] is! String ||
        (result['matchId'] as String).isEmpty ||
        result['legs'] is! List ||
        result['sets'] is! List ||
        (result['legs'] as List).any((n) => n is! int) ||
        (result['sets'] as List).any((n) => n is! int)) {
      throw const FormatException('Ungültiges Ergebnisformat (Version 1)');
    }
    final operation = _queue.then((_) async {
      await authorize();
      const importer = TournamentResultImporter();
      final match = importer.validate(tournament, result);
      final duplicate = match.deviceResult?['matchId'] == result['matchId'];
      if (!duplicate) {
        final previous = GroupMatch.fromJson(match.toJson());
        importer.apply(
          match,
          result,
          tournament.stages[tournament.activeStageIndex].gameFormat,
        );
        try {
          await save();
        } catch (_) {
          match.homeLegs = previous.homeLegs;
          match.awayLegs = previous.awayLegs;
          match.homeSets = previous.homeSets;
          match.awaySets = previous.awaySets;
          match.finishedAt = previous.finishedAt;
          match.deviceResult = previous.deviceResult;
          rethrow;
        }
      }
      // Retrying also repairs an interrupted advance after the durable result.
      await advance();
      await save();
      return duplicate
          ? TournamentResultReceipt.alreadyAccepted
          : TournamentResultReceipt.accepted;
    });
    _queue = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }
}
