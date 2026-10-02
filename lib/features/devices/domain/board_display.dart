import '../../tournaments/domain/tournament_models.dart';

class BoardDisplay {
  const BoardDisplay({
    required this.tournamentId,
    required this.tournamentName,
    required this.board,
    required this.state,
    this.home = '',
    this.away = '',
    this.detail = '',
    this.format = '',
    this.score = '',
    this.matchId,
    this.gameFormat,
    this.homeMembers = const [],
    this.awayMembers = const [],
  });
  final String tournamentId;
  final String tournamentName;
  final int board;
  final String state;
  final String home;
  final String away;
  final List<String> homeMembers, awayMembers;
  final String detail;
  final String format;
  final String score;
  final String? matchId;
  final TournamentGameFormat? gameFormat;
  Map<String, dynamic> toJson() => {
    'version': 3,
    'homeMembers': homeMembers,
    'awayMembers': awayMembers,
    'matchId': matchId,
    'gameFormat': gameFormat?.toJson(),
    'tournamentId': tournamentId,
    'tournamentName': tournamentName,
    'board': board,
    'state': state,
    'home': home,
    'away': away,
    'detail': detail,
    'format': format,
    'score': score,
  };
  factory BoardDisplay.fromJson(Map<String, dynamic> json) {
    final board = json['board'];
    if (![1, 2, 3].contains(json['version']) ||
        board is! int ||
        board < 1 ||
        board > 64 ||
        ![
          'running',
          'planned',
          'waiting',
          'finished',
          'released',
        ].contains(json['state'])) {
      throw const FormatException('Ungültige Board-Anzeige');
    }
    String field(String key) {
      final value = json[key];
      if (value is! String || value.length > 512) {
        throw const FormatException('Ungültiges Anzeigefeld');
      }
      return value;
    }

    return BoardDisplay(
      tournamentId: field('tournamentId'),
      tournamentName: field('tournamentName'),
      board: board,
      state: field('state'),
      home: field('home'),
      away: field('away'),
      homeMembers: List<String>.from(json['homeMembers'] as List? ?? const []),
      awayMembers: List<String>.from(json['awayMembers'] as List? ?? const []),
      detail: field('detail'),
      format: field('format'),
      score: field('score'),
      matchId: json['matchId'] as String?,
      gameFormat: json['gameFormat'] is Map<String, dynamic>
          ? TournamentGameFormat.fromJson(
              json['gameFormat'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}
