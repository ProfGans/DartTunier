import '../data/fixed_checkout_labels.dart';
import 'x01/x01_models.dart';
import 'x01/x01_rules.dart';

/// No search or route calculation is performed at runtime.
class FixedCheckouts {
  static final _throws = {
    for (final dart in const X01Rules().buildAllThrows()) dart.label: dart,
  };

  static List<List<DartThrowResult>> routes(
    int score, {
    int dartsLeft = 3,
    CheckoutRequirement requirement = CheckoutRequirement.doubleOut,
  }) => [
    for (final route
        in fixedCheckoutLabels['${requirement.name}/$dartsLeft/$score'] ??
            const <List<String>>[])
      List.unmodifiable(route.map((label) => _throws[label]!)),
  ];
}
