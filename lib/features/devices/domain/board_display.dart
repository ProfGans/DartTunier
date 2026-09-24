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
  });
  final String tournamentId;
  final String tournamentName;
  final int board;
  final String state;
  final String home;
  final String away;
  final String detail;
  final String format;
  final String score;
  Map<String, dynamic> toJson() => {
    'version': 1,
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
    if (json['version'] != 1 ||
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
      detail: field('detail'),
      format: field('format'),
      score: field('score'),
    );
  }
}
