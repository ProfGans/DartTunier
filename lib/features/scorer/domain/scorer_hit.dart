/// Physical board coordinates in millimetres; no coordinate is invented for
/// unlocated darts, bouncers, manual score totals or simulated bot throws.
class DartLocation {
  const DartLocation(
    this.x,
    this.y, {
    this.estimated = false,
    this.corrected = false,
  });
  final double x, y;
  final bool estimated, corrected;
  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'estimated': estimated,
    'corrected': corrected,
  };
  factory DartLocation.fromJson(Map<String, dynamic> json) {
    final x = (json['x'] as num).toDouble(), y = (json['y'] as num).toDouble();
    if (!x.isFinite || !y.isFinite || x * x + y * y > 300 * 300) {
      throw const FormatException('Ungültige Trefferposition');
    }
    return DartLocation(
      x,
      y,
      estimated: json['estimated'] == true,
      corrected: json['corrected'] == true,
    );
  }
}

class ScorerHit {
  const ScorerHit({
    required this.location,
    required this.player,
    required this.leg,
    required this.thrower,
    required this.label,
    required this.points,
    required this.checkoutAttempt,
  });
  final DartLocation location;
  final int player, leg, points;
  final String thrower, label;
  final bool? checkoutAttempt;
  Map<String, dynamic> toJson() => {
    'location': location.toJson(),
    'player': player,
    'leg': leg,
    'thrower': thrower,
    'label': label,
    'points': points,
    'checkoutAttempt': checkoutAttempt,
  };
  factory ScorerHit.fromJson(Map<String, dynamic> json) => ScorerHit(
    location: DartLocation.fromJson(
      Map<String, dynamic>.from(json['location'] as Map),
    ),
    player: json['player'] as int,
    leg: json['leg'] as int,
    thrower: json['thrower'] as String,
    label: json['label'] as String,
    points: json['points'] as int,
    checkoutAttempt: json['checkoutAttempt'] as bool?,
  );
}
