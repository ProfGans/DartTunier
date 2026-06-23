part of 'main.dart';

class TournamentStorage {
  static const _schemaVersion = 1;

  Future<List<CreatedTournament>> loadTournaments() async {
    final file = _storageFile();
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

    return _mapListFromJson(
      decoded['tournaments'],
      CreatedTournament.fromJson,
    )..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
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
  }

  Future<void> deleteTournament(String id) async {
    final tournaments = await loadTournaments();
    tournaments.removeWhere((tournament) => tournament.id == id);
    await _writeTournaments(tournaments);
  }

  Future<void> _writeTournaments(List<CreatedTournament> tournaments) async {
    final file = _storageFile();
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(
      encoder.convert({
        'schemaVersion': _schemaVersion,
        'tournaments': tournaments.map((item) => item.toJson()).toList(),
      }),
    );
  }

  File _storageFile() {
    final appData = Platform.environment['APPDATA'];
    final basePath = appData == null || appData.isEmpty
        ? Directory.current.path
        : appData;
    return File('$basePath${Platform.pathSeparator}DartTournamentManager'
        '${Platform.pathSeparator}tournaments.json');
  }
}

