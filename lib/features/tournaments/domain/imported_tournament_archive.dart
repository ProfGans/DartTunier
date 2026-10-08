/// Versioned source results. Historical brackets are never regenerated.
class ImportedTournamentArchive {
  const ImportedTournamentArchive({
    required this.sourceId,
    required this.url,
    required this.mode,
    required this.participants,
    required this.matches,
  });
  final String sourceId, url, mode;
  final List<Map<String, dynamic>> participants, matches;
  factory ImportedTournamentArchive.fromJson(Map<String, dynamic> json) {
    if (![1, 2].contains(json['version']) || json['source'] != 'challonge') {
      throw const FormatException('Unbekannte Importversion.');
    }
    return ImportedTournamentArchive(
      sourceId: json['sourceId'] as String,
      url: json['url'] as String,
      mode: json['mode'] as String,
      participants: (json['participants'] as List)
          .map((p) => Map<String, dynamic>.from(p as Map))
          .toList(),
      matches: (json['matches'] as List)
          .map((m) => Map<String, dynamic>.from(m as Map))
          .toList(),
    );
  }
  Map<String, dynamic> toJson() => {
    'version': 2,
    'source': 'challonge',
    'sourceId': sourceId,
    'url': url,
    'mode': mode,
    'participants': participants,
    'matches': matches,
  };
}
