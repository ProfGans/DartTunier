import 'dart:math';

enum BullOffRule { none, wdf, pdc }

extension BullOffRuleLabel on BullOffRule {
  String get label => switch (this) {
    BullOffRule.none => 'Ohne Ausbullen',
    BullOffRule.wdf => 'WDF',
    BullOffRule.pdc => 'PDC / DRA',
  };

  String get description => switch (this) {
    BullOffRule.none => 'Den Anwerfer direkt auswählen.',
    BullOffRule.wdf =>
      'Bull vor 25; außerhalb zählt die Nähe zum Mittelpunkt. '
          'Der Gewinner beginnt. Gleiche Bull-Felder oder gleicher Abstand: '
          'erneut in umgekehrter Reihenfolge werfen.',
    BullOffRule.pdc =>
      'Bull vor 25 vor außerhalb. Außerhalb zählt kein Abstand. '
          'Bei Gleichstand erneut in umgekehrter Reihenfolge werfen. '
          'Der Gewinner entscheidet, wer beginnt.',
  };
}

/// Outside distances are measured at the entry point, in millimetres.
class BullOffHit {
  const BullOffHit.bull() : zone = 2, distance = 0;
  const BullOffHit.outerBull() : zone = 1, distance = 0;
  BullOffHit.outside([this.distance = 16]) : zone = 0 {
    if (!distance.isFinite || distance <= 15.9) {
      throw ArgumentError.value(distance, 'distance', 'Must be outside 25');
    }
  }
  final int zone;
  final double distance;
  String label(BullOffRule rule) => switch (zone) {
    2 => 'Bull · 50',
    1 => 'Outer Bull · 25',
    _ =>
      rule == BullOffRule.wdf
          ? 'Außerhalb · ${distance.toStringAsFixed(1)} mm'
          : 'Außerhalb',
  };
}

/// WDF 12.01–12.03 / DRA 2026 6.13. Two sides are standard;
/// more sides use the same comparison with a playoff among tied leaders.
class BullOff {
  BullOff({required this.rule, required int players, Random? random}) {
    if (rule == BullOffRule.none || players < 2) throw ArgumentError();
    order = List.generate(players, (i) => i)..shuffle(random ?? Random());
  }
  final BullOffRule rule;
  late List<int> order;
  final Map<int, BullOffHit> hits = {};
  int round = 1;
  int? winner;
  bool get ready => hits.length == order.length;
  int? get current => winner != null || ready ? null : order[hits.length];

  void record(BullOffHit hit) {
    final player = current;
    if (player == null) throw StateError('No throw expected');
    hits[player] = hit;
  }

  void undo() {
    if (hits.isEmpty || winner != null) return;
    hits.remove(hits.keys.last);
  }

  void resolve() {
    if (!ready || winner != null) throw StateError('Round is not ready');
    var leaders = <int>[];
    for (final player in order) {
      if (leaders.isEmpty) {
        leaders.add(player);
        continue;
      }
      final a = hits[player]!;
      final b = hits[leaders.first]!;
      var comparison = a.zone.compareTo(b.zone);
      if (comparison == 0 && a.zone == 0 && rule == BullOffRule.wdf) {
        comparison = b.distance.compareTo(a.distance);
      }
      if (comparison > 0) leaders = [player];
      if (comparison == 0) leaders.add(player);
    }
    if (leaders.length == 1) {
      winner = leaders.single;
    } else {
      order = leaders.reversed.toList();
      hits.clear();
      round++;
    }
  }
}
