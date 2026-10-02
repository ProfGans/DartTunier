import 'package:flutter/material.dart';
import '../../../scorer/domain/x01/x01_rules.dart';

class DartCorrectionDialog extends StatefulWidget {
  const DartCorrectionDialog({super.key});
  @override
  State<DartCorrectionDialog> createState() => DartCorrectionDialogState();
}

class DartCorrectionDialogState extends State<DartCorrectionDialog> {
  int value = 20, multiplier = 1;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Treffer korrigieren'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int>(
            initialValue: value,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Segment'),
            items: [
              for (var i = 1; i <= 20; i++)
                DropdownMenuItem(value: i, child: Text('$i')),
            ],
            onChanged: (v) => setState(() => value = v!),
          ),
          DropdownButtonFormField<int>(
            initialValue: multiplier,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Ring'),
            items: const [
              DropdownMenuItem(value: 1, child: Text('Single')),
              DropdownMenuItem(value: 2, child: Text('Double')),
              DropdownMenuItem(value: 3, child: Text('Triple')),
            ],
            onChanged: (v) => setState(() => multiplier = v!),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, const X01Rules().createOuterBull()),
                child: const Text('25'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, const X01Rules().createBull()),
                child: const Text('Bull 50'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, const X01Rules().createMiss()),
                child: const Text('Fehlwurf'),
              ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, switch (multiplier) {
          2 => const X01Rules().createDouble(value),
          3 => const X01Rules().createTriple(value),
          _ => const X01Rules().createSingle(value),
        }),
        child: const Text('Übernehmen'),
      ),
    ],
  );
}
