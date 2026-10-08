import '../domain/fixed_checkouts.dart';
import '../domain/x01/x01_models.dart';
import 'scorer_controller.dart';

List<String> monitorCheckouts(ScorerController scorer, int player) {
  if (scorer.isComplete) return const [];
  final active = player == scorer.activePlayer;
  if (scorer.settings.startRequirement == StartRequirement.doubleIn &&
      !(active ? scorer.progress.openedLeg : scorer.opened[player])) {
    return const [];
  }
  return [
    for (final route in FixedCheckouts.routes(
      active ? scorer.remaining : scorer.scores[player],
      dartsLeft: active ? scorer.dartsLeft : 3,
      requirement: scorer.settings.checkoutRequirement,
    ))
      route.map((dart) => dart.label).join(' → '),
  ];
}
