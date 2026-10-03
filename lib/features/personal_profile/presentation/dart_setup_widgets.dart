import 'package:flutter/material.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../domain/dart_setup.dart';

class DartSetupSummary extends StatelessWidget {
  const DartSetupSummary({super.key, required this.setup});
  final DartSetup setup;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Mein Dart-Setup', style: Theme.of(context).textTheme.titleLarge),
      if (setup.isEmpty) const Text('Noch kein Dart-Setup eingetragen.'),
      for (final entry in {
        'Darts / Barrel': setup.barrel,
        'Gewicht': setup.weight,
        'Shafts': setup.shaft,
        'Flights': setup.flights,
        'Spitzen': setup.points,
        'Weitere Angaben': setup.notes,
      }.entries)
        if (entry.value.isNotEmpty) Text('${entry.key}: ${entry.value}'),
    ],
  );
}

class DartSetupFields extends StatefulWidget {
  const DartSetupFields({
    super.key,
    required this.initialValue,
    required this.onChanged,
    required this.enabled,
  });
  final DartSetup initialValue;
  final ValueChanged<DartSetup> onChanged;
  final bool enabled;
  @override
  State<DartSetupFields> createState() => _DartSetupFieldsState();
}

class _DartSetupFieldsState extends State<DartSetupFields> {
  late final controllers = [
    widget.initialValue.barrel,
    widget.initialValue.weight,
    widget.initialValue.shaft,
    widget.initialValue.flights,
    widget.initialValue.points,
    widget.initialValue.notes,
  ].map((v) => TextEditingController(text: v)).toList();
  void changed() {
    final v = controllers.map((c) => c.text.trim()).toList();
    widget.onChanged(
      DartSetup(
        barrel: v[0],
        weight: v[1],
        shaft: v[2],
        flights: v[3],
        points: v[4],
        notes: v[5],
      ),
    );
  }

  @override
  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Mein Dart-Setup', style: Theme.of(context).textTheme.titleLarge),
      const Text(
        'Trage die Komponenten deiner Darts ein. Alle Angaben sind optional.',
      ),
      const SizedBox(height: 12),
      AdaptiveTileLayout(
        minTileWidth: 350,
        children: [
          for (var i = 0; i < controllers.length; i++)
            TextFormField(
              key: ValueKey('dart-setup-field-$i'),
              controller: controllers[i],
              enabled: widget.enabled,
              maxLength: i == 5 ? 500 : 100,
              minLines: i == 5 ? 2 : 1,
              maxLines: i == 5 ? 4 : 1,
              onChanged: (_) => changed(),
              decoration: InputDecoration(
                labelText: [
                  'Darts / Barrel',
                  'Gewicht',
                  'Shafts',
                  'Flights',
                  'Spitzen',
                  'Weitere Angaben',
                ][i],
                hintText: [
                  'Marke und Modell',
                  'z. B. 23 g',
                  'Marke, Modell und Länge',
                  'Modell, Form oder Größe',
                  'Modell, Länge; Steel oder Soft',
                  'z. B. Grip, Ringe oder Zubehör',
                ][i],
              ),
            ),
        ],
      ),
    ],
  );
}
