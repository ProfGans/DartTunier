import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/tournament_models.dart';

class TournamentStorage {
  static const _schemaVersion = 1;

  Future<List<CreatedTournament>> loadTournaments() async {
    final file = await _storageFile();
    if (!file.existsSync()) {
      return [];
    }

    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      return [];
    }

    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      return [];
    }

    final tournamentJson = decoded['tournaments'];
    if (tournamentJson is! List) {
      return [];
    }

    return [
      for (final item in tournamentJson)
        if (item is Map<String, dynamic>) CreatedTournament.fromJson(item),
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> saveTournament(CreatedTournament tournament) async {
    final tournaments = await loadTournaments();
    tournament.updatedAt = DateTime.now();
    final index = tournaments.indexWhere((item) => item.id == tournament.id);
    if (index == -1) {
      tournaments.insert(0, tournament);
    } else {
      tournaments[index] = tournament;
    }
    await _writeTournaments(tournaments);
    if (tournament.communityId != null) {
      await _saveCommunityTournament(tournament);
    }
  }

  Future<void> _saveCommunityTournament(CreatedTournament tournament) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Community-Turniere benoetigen eine Anmeldung.');
    }
    await client.from('tournaments').upsert({
      'client_tournament_id': tournament.id,
      'owner_user_id': userId,
      'community_id': tournament.communityId,
      'name': tournament.name,
      'payload': tournament.toJson(),
      'is_deleted': false,
    }, onConflict: 'client_tournament_id');
  }

  Future<void> deleteTournament(String id) async {
    final tournaments = await loadTournaments();
    tournaments.removeWhere((tournament) => tournament.id == id);
    await _writeTournaments(tournaments);
  }

  Future<void> _writeTournaments(List<CreatedTournament> tournaments) async {
    final file = await _storageFile();
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(
      encoder.convert({
        'schemaVersion': _schemaVersion,
        'tournaments': tournaments.map((item) => item.toJson()).toList(),
      }),
    );
  }

  Future<File> _storageFile() async {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      final directory = await _applicationSupportDirectory();
      return File(
        '${directory.path}${Platform.pathSeparator}tournaments.json',
      );
    }

    final appData = Platform.environment['APPDATA'];
    final basePath = appData == null || appData.isEmpty
        ? Directory.current.path
        : appData;
    return File('$basePath${Platform.pathSeparator}DartTournamentManager'
        '${Platform.pathSeparator}tournaments.json');
  }

  Future<Directory> _applicationSupportDirectory() async {
    try {
      return await getApplicationSupportDirectory();
    } catch (_) {
      return Directory.systemTemp.createTemp(
        'dart_tournament_manager_test_',
      );
    }
  }
}

