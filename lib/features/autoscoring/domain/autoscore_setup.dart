class AutoscoreSetup {
  AutoscoreSetup({
    required this.id,
    required this.name,
    this.cameraKeys = const [],
    this.caller = true,
    this.sounds = true,
    this.volume = .7,
    this.total = 0,
    this.correct = 0,
    this.incorrect = 0,
    this.estimated = 0,
    this.missing = 0,
    this.bouncers = 0,
    this.verifiedCorrect = 0,
    this.verifiedIncorrect = 0,
    this.verifiedMissing = 0,
    this.verifiedExtra = 0,
  });
  final String id;
  String name;
  List<String> cameraKeys;
  bool caller, sounds;
  double volume;
  int total, correct, incorrect, estimated, missing, bouncers;
  int verifiedCorrect, verifiedIncorrect, verifiedMissing, verifiedExtra;
  int get independentlyReviewed => verifiedCorrect + verifiedIncorrect;
  double? get independentAccuracy => independentlyReviewed == 0
      ? null
      : 100 * verifiedCorrect / independentlyReviewed;
  int get reviewed => correct + incorrect;
  int get pending => total - reviewed;
  double? get accuracy => reviewed == 0 ? null : 100 * correct / reviewed;
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'cameraKeys': cameraKeys,
    'caller': caller,
    'sounds': sounds,
    'volume': volume,
    'total': total,
    'correct': correct,
    'incorrect': incorrect,
    'estimated': estimated,
    'missing': missing,
    'bouncers': bouncers,
    'verifiedCorrect': verifiedCorrect,
    'verifiedIncorrect': verifiedIncorrect,
    'verifiedMissing': verifiedMissing,
    'verifiedExtra': verifiedExtra,
  };
  factory AutoscoreSetup.fromJson(Map<String, dynamic> json) {
    int count(String key) => (json[key] as num? ?? 0).toInt();
    final setup = AutoscoreSetup(
      id: json['id'] as String,
      name: json['name'] as String,
      cameraKeys: (json['cameraKeys'] as List? ?? []).cast<String>(),
      caller: json['caller'] as bool? ?? true,
      sounds: json['sounds'] as bool? ?? true,
      volume: (json['volume'] as num? ?? .7).toDouble(),
      total: count('total'),
      correct: count('correct'),
      incorrect: count('incorrect'),
      estimated: count('estimated'),
      missing: count('missing'),
      bouncers: count('bouncers'),
      verifiedCorrect: count('verifiedCorrect'),
      verifiedIncorrect: count('verifiedIncorrect'),
      verifiedMissing: count('verifiedMissing'),
      verifiedExtra: count('verifiedExtra'),
    );
    if (setup.id.isEmpty ||
        setup.name.trim().isEmpty ||
        !setup.volume.isFinite ||
        setup.volume < 0 ||
        setup.volume > 1 ||
        [
          setup.total,
          setup.correct,
          setup.incorrect,
          setup.estimated,
          setup.missing,
          setup.bouncers,
          setup.verifiedCorrect,
          setup.verifiedIncorrect,
          setup.verifiedMissing,
          setup.verifiedExtra,
        ].any((n) => n < 0) ||
        setup.reviewed > setup.total ||
        setup.independentlyReviewed > setup.total ||
        setup.verifiedMissing > setup.verifiedIncorrect ||
        setup.verifiedExtra > setup.verifiedIncorrect) {
      throw const FormatException('Ungültiges Autoscorer-Setup');
    }
    return setup;
  }
}

enum AutoscoreReview { pending, correct, incorrect }

/// Stable attribution even when a different setup is selected later.
class AutoscoreSetupThrow {
  AutoscoreSetupThrow(this.setupId, {this.statisticsGeneration = 0});
  final String setupId;
  final int statisticsGeneration;
  String detectedLabel = '';
  String eventId = '';
  String? validationSeriesId;
  AutoscoreReview verification = AutoscoreReview.pending;
  bool verifiedMissing = false, verifiedExtra = false;
  AutoscoreReview review = AutoscoreReview.pending;
}
