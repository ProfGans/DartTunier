import 'scorer_settings.dart';
import 'x01/x01_models.dart';

String scorerMonitorFormat(ScorerSettings settings) {
  final entry = settings.startRequirement == StartRequirement.doubleIn
      ? 'Double In'
      : 'Straight In';
  final out = switch (settings.checkoutRequirement) {
    CheckoutRequirement.singleOut => 'Single Out',
    CheckoutRequirement.doubleOut => 'Double Out',
    CheckoutRequirement.masterOut => 'Master Out',
  };
  final legs = settings.allowsDraws
      ? '${settings.bestOfLegs} Legs · Unentschieden möglich'
      : 'Best of ${settings.bestOfLegs} Legs';
  return '${settings.startScore} · $entry · $out · $legs${settings.bestOfSets > 1 ? ' pro Satz · Best of ${settings.bestOfSets} Sätze' : ''}';
}
