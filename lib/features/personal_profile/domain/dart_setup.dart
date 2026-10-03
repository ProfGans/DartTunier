/// Versioned equipment details; missing data in older profiles becomes empty.
class DartSetup {
  const DartSetup({
    this.barrel = '',
    this.weight = '',
    this.shaft = '',
    this.flights = '',
    this.points = '',
    this.notes = '',
  });
  final String barrel, weight, shaft, flights, points, notes;
  bool get isEmpty =>
      [barrel, weight, shaft, flights, points, notes].every((v) => v.isEmpty);
  Map<String, dynamic> toJson() => {
    'version': 1,
    'barrel': barrel,
    'weight': weight,
    'shaft': shaft,
    'flights': flights,
    'points': points,
    'notes': notes,
  };
  factory DartSetup.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unbekannte Dart-Setup-Version');
    }
    return DartSetup(
      barrel: json['barrel'] as String? ?? '',
      weight: json['weight'] as String? ?? '',
      shaft: json['shaft'] as String? ?? '',
      flights: json['flights'] as String? ?? '',
      points: json['points'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
    );
  }
}
