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

enum LeagueMatchVariant { traditional, adjusted }

/// A league match supports the fixed traditional format and an even-roster
/// adjusted format. Each fixture awards one team point.
class LeagueMatch {
  LeagueMatch({
    required this.homeTeam,
    required this.awayTeam,
    required this.homePlayers,
    required this.awayPlayers,
    required this.games,
    this.variant = LeagueMatchVariant.traditional,
    this.singlesPerPlayer = 4,
    this.doublesCount = 2,
  });
  final String homeTeam;
  final String awayTeam;
  final List<String> homePlayers;
  final List<String> awayPlayers;
  final List<LeagueGame> games;
  final LeagueMatchVariant variant;
  final int singlesPerPlayer;
  final int doublesCount;
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
      variant: LeagueMatchVariant.traditional,
      singlesPerPlayer: 4,
      doublesCount: 2,
    );
    match.validate();
    return match;
  }

  factory LeagueMatch.adjusted({
    required String homeTeam,
    required String awayTeam,
    required List<String> homePlayers,
    required List<String> awayPlayers,
    required int singlesPerPlayer,
    required int doublesCount,
  }) {
    if (homePlayers.length != awayPlayers.length || homePlayers.isEmpty) {
      throw const FormatException(
        'Im angepassten Modus müssen beide Teams gleich viele Spieler haben.',
      );
    }
    if (singlesPerPlayer < 1) {
      throw const FormatException(
        'Jeder Spieler muss mindestens ein Einzel spielen.',
      );
    }
    if (doublesCount < 0 || doublesCount > homePlayers.length ~/ 2) {
      throw const FormatException(
        'Die Anzahl der Doppel darf höchstens der Hälfte der Spieler je Team entsprechen.',
      );
    }
    final games = <LeagueGame>[];
    for (var round = 0; round < singlesPerPlayer; round++) {
      for (var player = 0; player < homePlayers.length; player++) {
        games.add(
          LeagueGame(
            home: [player],
            away: [(player + round) % awayPlayers.length],
          ),
        );
      }
    }
    for (var pair = 0; pair < doublesCount; pair++) {
      games.add(
        LeagueGame(
          home: [pair * 2, pair * 2 + 1],
          away: [pair * 2, pair * 2 + 1],
        ),
      );
    }
    final match = LeagueMatch(
      homeTeam: homeTeam.trim(),
      awayTeam: awayTeam.trim(),
      homePlayers: homePlayers.map((p) => p.trim()).toList(),
      awayPlayers: awayPlayers.map((p) => p.trim()).toList(),
      games: games,
      variant: LeagueMatchVariant.adjusted,
      singlesPerPlayer: singlesPerPlayer,
      doublesCount: doublesCount,
    );
    match.validate();
    return match;
  }

  void validate() {
    if (homeTeam.isEmpty || awayTeam.isEmpty) {
      throw const FormatException('Mannschaftsnamen fehlen.');
    }
    for (final roster in [homePlayers, awayPlayers]) {
      if (roster.length <
              (variant == LeagueMatchVariant.traditional ? 4 : 1) ||
          roster.any((p) => p.trim().isEmpty)) {
        throw FormatException(
          variant == LeagueMatchVariant.traditional
              ? 'Je Mannschaft werden mindestens 4 Spieler benötigt.'
              : 'Spielernamen dürfen nicht leer sein.',
        );
      }
    }
    if (variant == LeagueMatchVariant.traditional &&
        (games.length != 18 || games.where((g) => g.isDouble).length != 2)) {
      throw const FormatException(
        'Ein RHL-Ligaspiel benötigt 16 Einzel und 2 Doppel.',
      );
    }
    if (variant == LeagueMatchVariant.adjusted) {
      if (singlesPerPlayer < 1 ||
          doublesCount < 0 ||
          doublesCount > homePlayers.length ~/ 2 ||
          homePlayers.length != awayPlayers.length ||
          games.length != homePlayers.length * singlesPerPlayer + doublesCount ||
          games.where((g) => g.isDouble).length != doublesCount) {
        throw const FormatException('Ungültiger angepasster Spielplan.');
      }
      for (var player = 0; player < homePlayers.length; player++) {
        if (games
                .where((game) => !game.isDouble && game.home.contains(player))
                .length !=
            singlesPerPlayer ||
            games
                    .where((game) => !game.isDouble && game.away.contains(player))
                    .length !=
                singlesPerPlayer) {
          throw const FormatException(
            'Die Einzel müssen gleichmäßig auf alle Spieler verteilt sein.',
          );
        }
        if (games
                    .where(
                      (game) => game.isDouble && game.home.contains(player),
                    )
                    .length >
                1 ||
            games
                    .where(
                      (game) => game.isDouble && game.away.contains(player),
                    )
                    .length >
                1) {
          throw const FormatException(
            'Ein Spieler darf höchstens ein Doppel bestreiten.',
          );
        }
      }
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
    'version': variant == LeagueMatchVariant.adjusted ? 3 : 2,
    'preset': 'rhl',
    if (variant == LeagueMatchVariant.adjusted) ...{
      'variant': variant.name,
      'singlesPerPlayer': singlesPerPlayer,
      'doublesCount': doublesCount,
    },
    'homeTeam': homeTeam,
    'awayTeam': awayTeam,
    'homePlayers': homePlayers,
    'awayPlayers': awayPlayers,
    'games': games.map((g) => g.toJson()).toList(),
  };
  factory LeagueMatch.fromJson(Map<String, dynamic> json) {
    if (![1, 2, 3].contains(json['version']) || json['preset'] != 'rhl') {
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
      variant: json['variant'] == LeagueMatchVariant.adjusted.name
          ? LeagueMatchVariant.adjusted
          : LeagueMatchVariant.traditional,
      singlesPerPlayer: json['singlesPerPlayer'] as int? ?? 4,
      doublesCount: json['doublesCount'] as int? ?? 2,
    );
    match.validate();
    return match;
  }
}
