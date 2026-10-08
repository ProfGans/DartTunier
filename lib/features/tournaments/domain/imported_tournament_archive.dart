/// Versioned source evidence, with an optional production-runtime comparison.
class ImportedTournamentArchive {
  const ImportedTournamentArchive({
    required this.sourceId,
    required this.url,
    required this.mode,
    required this.participants,
    required this.matches,
    this.nativeValidation,
  });
  final String sourceId, url, mode;
  final List<Map<String, dynamic>> participants, matches;
  final Map<String, dynamic>? nativeValidation;
  bool get usesNativeLogic => nativeValidation != null;
  factory ImportedTournamentArchive.fromJson(Map<String, dynamic> json) {
    if (![1, 2, 3].contains(json['version']) || json['source'] != 'challonge') {
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
      nativeValidation: json['nativeValidation'] is Map
          ? Map<String, dynamic>.from(json['nativeValidation'] as Map)
          : null,
    );
  }
  Map<String, dynamic> toJson() => {
    'version': 3,
    'source': 'challonge',
    'sourceId': sourceId,
    'url': url,
    'mode': mode,
    'participants': participants,
    'matches': matches,
    'nativeValidation': nativeValidation,
  };
}
