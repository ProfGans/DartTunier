import '../../scorer/domain/scorer_settings.dart';
import '../../scorer/domain/x01/x01_models.dart';
import '../domain/board_display.dart';

ScorerSettings deviceScorerSettings(BoardDisplay display) {
  final format = display.gameFormat;
  if (format == null || format.gameType != 'x01') {
    throw const FormatException(
      'Dieses Spielformat wird vom Geräte-Scorer noch nicht unterstützt.',
    );
  }
  return ScorerSettings(
    participants: [
      ScorerParticipant(display.home, members: display.homeMembers),
      ScorerParticipant(display.away, members: display.awayMembers),
    ],
    startScore: format.x01Score,
    bestOfLegs: format.bestOfLegs,
    bestOfSets: format.bestOfSets,
    startRequirement: format.doubleIn
        ? StartRequirement.doubleIn
        : StartRequirement.straightIn,
    checkoutRequirement: switch (format.checkoutType) {
      'single_out' => CheckoutRequirement.singleOut,
      'master_out' => CheckoutRequirement.masterOut,
      'double_out' => CheckoutRequirement.doubleOut,
      _ => throw const FormatException('Unbekannte Checkout-Regel'),
    },
  );
}
