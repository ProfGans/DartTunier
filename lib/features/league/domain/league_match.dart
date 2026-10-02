class LeagueGame {
  LeagueGame({
    required this.home,
    required this.away,
    this.homeLegs,
    this.awayLegs,
    this.runtime,
  });
  List<int> home;
  List<int> away;
  int? homeLegs;
  int? awayLegs;
  Map<String, dynamic>? runtime;
  bool get isDouble => home.length == 2;
  bool get complete => homeLegs != null && awayLegs != null;

  void score(int? home, int? away) {
    if (home == null && away == null) {
      homeLegs = awayLegs = null;
      return;
    }
    if (home == null ||
        away == null ||
        home < 0 ||
        away < 0 ||
        !((home == 3 && away < 3) || (away == 3 && home < 3))) {
      throw const FormatException(
        'Ein gültiges Ergebnis ist 3:0, 3:1 oder 3:2 (oder umgekehrt).',
      );
    }
    homeLegs = home;
    awayLegs = away;
  }

  Map<String, dynamic> toJson() => {
    'home': home,
    'away': away,
    'homeLegs': homeLegs,
    'awayLegs': awayLegs,
    if (runtime != null) 'runtime': runtime,
  };
  factory LeagueGame.fromJson(Map<String, dynamic> json) {
    final game = LeagueGame(
      home: List<int>.from(json['home'] as List),
      away: List<int>.from(json['away'] as List),
      runtime: json['runtime'] == null
          ? null
          : Map<String, dynamic>.from(json['runtime'] as Map),
    );
    game.score(json['homeLegs'] as int?, json['awayLegs'] as int?);
    return game;
  }
}

/// RHL rules: 18 matches, one team point per match, 9:9 is a draw.
/// Pairing order is an editable proposal, not the official report sheet.
class LeagueMatch {
  LeagueMatch({
    required this.homeTeam,
    required this.awayTeam,
    required this.homePlayers,
    required this.awayPlayers,
    required this.games,
  });
  final String homeTeam;
  final String awayTeam;
  final List<String> homePlayers;
  final List<String> awayPlayers;
  final List<LeagueGame> games;
  int get homePoints =>
      games.where((g) => g.complete && g.homeLegs! > g.awayLegs!).length;
  int get awayPoints =>
      games.where((g) => g.complete && g.awayLegs! > g.homeLegs!).length;
  bool get complete => games.every((g) => g.complete);
  String get outcome => !complete
      ? 'Noch nicht abgeschlossen'
      : homePoints == awayPoints
      ? 'Unentschieden'
      : 'Sieger: ${homePoints > awayPoints ? homeTeam : awayTeam}';

  factory LeagueMatch.rhl({
    required String homeTeam,
    required String awayTeam,
    required List<String> homePlayers,
    required List<String> awayPlayers,
  }) {
    final match = LeagueMatch(
      homeTeam: homeTeam.trim(),
      awayTeam: awayTeam.trim(),
      homePlayers: homePlayers.map((p) => p.trim()).toList(),
      awayPlayers: awayPlayers.map((p) => p.trim()).toList(),
      games: [
        for (var round = 0; round < 4; round++)
          for (var home = 0; home < 4; home++)
            LeagueGame(home: [home], away: [(home + round) % 4]),
        LeagueGame(home: [0, 1], away: [0, 1]),
        LeagueGame(home: [2, 3], away: [2, 3]),
      ],
    );
    match.validate();
    return match;
  }

  void validate() {
    if (homeTeam.isEmpty || awayTeam.isEmpty) {
      throw const FormatException('Mannschaftsnamen fehlen.');
    }
    for (final roster in [homePlayers, awayPlayers]) {
      if (roster.length < 4 ||
          roster.length > 9 ||
          roster.any((p) => p.trim().isEmpty)) {
        throw const FormatException(
          'Je Mannschaft werden 4 Stammspieler benötigt; maximal 4 Ersatzspieler und 1 Aushilfe sind möglich.',
        );
      }
    }
    if (games.length != 18 || games.where((g) => g.isDouble).length != 2) {
      throw const FormatException(
        'Ein RHL-Ligaspiel benötigt 16 Einzel und 2 Doppel.',
      );
    }
    for (final game in games) {
      if (game.home.length != game.away.length ||
          ![1, 2].contains(game.home.length) ||
          game.home.toSet().length != game.home.length ||
          game.away.toSet().length != game.away.length ||
          game.home.any((i) => i < 0 || i >= homePlayers.length) ||
          game.away.any((i) => i < 0 || i >= awayPlayers.length)) {
        throw const FormatException('Ungültige Aufstellung.');
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'version': 2,
    'preset': 'rhl',
    'homeTeam': homeTeam,
    'awayTeam': awayTeam,
    'homePlayers': homePlayers,
    'awayPlayers': awayPlayers,
    'games': games.map((g) => g.toJson()).toList(),
  };
  factory LeagueMatch.fromJson(Map<String, dynamic> json) {
    if (![1, 2].contains(json['version']) || json['preset'] != 'rhl') {
      throw const FormatException('Nicht unterstützte Ligaspiel-Version.');
    }
    final match = LeagueMatch(
      homeTeam: json['homeTeam'] as String,
      awayTeam: json['awayTeam'] as String,
      homePlayers: List<String>.from(json['homePlayers'] as List),
      awayPlayers: List<String>.from(json['awayPlayers'] as List),
      games: (json['games'] as List)
          .map((g) => LeagueGame.fromJson(Map<String, dynamic>.from(g as Map)))
          .toList(),
    );
    match.validate();
    return match;
  }
}
