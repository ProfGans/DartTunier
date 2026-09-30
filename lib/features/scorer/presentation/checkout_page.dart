import 'package:dart_tournament_manager/shared/widgets/adaptive_content.dart';
import 'package:flutter/material.dart';
import '../domain/fixed_checkouts.dart';
import '../domain/x01/x01_models.dart';

String checkoutLabel(CheckoutRequirement value) => switch (value) {
  CheckoutRequirement.singleOut => 'Single Out',
  CheckoutRequirement.doubleOut => 'Double Out',
  CheckoutRequirement.masterOut => 'Master Out',
};

class CheckoutRoutes extends StatelessWidget {
  const CheckoutRoutes({
    super.key,
    required this.score,
    this.dartsLeft = 3,
    this.requirement = CheckoutRequirement.doubleOut,
  });
  final int score, dartsLeft;
  final CheckoutRequirement requirement;
  @override
  Widget build(BuildContext context) {
    final routes = FixedCheckouts.routes(
      score,
      dartsLeft: dartsLeft,
      requirement: requirement,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Checkout · $score Rest · $dartsLeft Darts',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (routes.isEmpty)
          const Text('Kein Checkout mit den verbleibenden Darts möglich.'),
        for (var i = 0; i < routes.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '${i + 1}.  ${routes[i].map((d) => d.label).join(' → ')}',
            ),
          ),
      ],
    );
  }
}

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});
  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  int? score = 170;
  int darts = 3;
  CheckoutRequirement requirement = CheckoutRequirement.doubleOut;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Checkoutrechner')),
    body: AdaptiveContentList(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Bis zu fünf feste Wege pro Restpunktzahl und Out-Regel. '
          'Existieren weniger gültige Wege, werden nur diese angezeigt. Bull zählt 50, 25 zählt Outer Bull.',
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: '170',
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Restpunkte (1–180)',
            errorText: score == null || score! < 1 || score! > 180
                ? 'Bitte 1 bis 180 eingeben.'
                : null,
          ),
          onChanged: (value) => setState(() => score = int.tryParse(value)),
        ),
        DropdownButtonFormField<CheckoutRequirement>(
          isExpanded: true, isDense: false,
          itemHeight: null,
          initialValue: requirement,
          decoration: const InputDecoration(labelText: 'Out-Regel'),
          items: [
            for (final r in CheckoutRequirement.values)
              DropdownMenuItem(value: r, child: Text(checkoutLabel(r))),
          ],
          onChanged: (v) => setState(() => requirement = v!),
        ),
        DropdownButtonFormField<int>(
          initialValue: darts,
          decoration: const InputDecoration(labelText: 'Verbleibende Darts'),
          items: [
            for (final n in [1, 2, 3])
              DropdownMenuItem(value: n, child: Text('$n')),
          ],
          onChanged: (v) => setState(() => darts = v!),
        ),
        const SizedBox(height: 24),
        if (score != null && score! >= 1 && score! <= 180)
          CheckoutRoutes(
            score: score!,
            dartsLeft: darts,
            requirement: requirement,
          ),
      ],
    ),
  );
}
