import 'package:flutter/material.dart';
import '../../domain/x01/x01_rules.dart';

/// Optional intent recorded before a throw, never inferred from its result.
class HeatmapTargetPicker extends StatelessWidget {
  const HeatmapTargetPicker({
    super.key,
    required this.target,
    required this.player,
    required this.onChanged,
  });
  final String? target;
  final int player;
  final ValueChanged<String?>? onChanged;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    key: ValueKey(player),
    tilePadding: EdgeInsets.zero,
    title: Text('Heatmap-Ziel: ${target ?? 'nicht angegeben'}'),
    children: [
      DropdownButtonFormField<String>(
        key: ValueKey('$player-$target'),
        initialValue: target,
        isExpanded: true,
        itemHeight: null,
        decoration: const InputDecoration(labelText: 'Anvisiertes Ziel'),
        items: [
          const DropdownMenuItem<String>(
            value: null,
            child: Text('Ziel nicht angegeben'),
          ),
          for (final dart in const X01Rules().buildAllThrows().where(
            (d) => !d.isMiss,
          ))
            DropdownMenuItem(value: dart.label, child: Text(dart.label)),
        ],
        onChanged: onChanged,
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Optional: vor dem Wurf für Zielanalyse und Training wählen. Wird beim Spieler- und Legwechsel zurückgesetzt.',
        ),
      ),
    ],
  );
}
