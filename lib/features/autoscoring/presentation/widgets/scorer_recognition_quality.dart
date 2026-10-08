import 'package:flutter/material.dart';
import '../../domain/board_geometry.dart';

/// Shows measured camera agreement, not an uncalibrated accuracy percentage.
class ScorerRecognitionQuality extends StatelessWidget {
  const ScorerRecognitionQuality({
    super.key,
    required this.hits,
    required this.corrected,
    this.diagnosticPath,
    this.diagnosticSaving,
    this.diagnosticError,
    this.onExportDiagnostic,
  });
  final List<FusedHit?> hits;
  final List<bool> corrected;
  final String? Function(int)? diagnosticPath, diagnosticError;
  final bool Function(int)? diagnosticSaving;
  final ValueChanged<int>? onExportDiagnostic;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(child: Text('Erkennungssicherheit')),
          IconButton(
            tooltip:
                'Kameraübereinstimmung, keine gemessene Trefferquote. Der Wert in mm beschreibt die Abweichung der Kameralinien voneinander, nicht den tatsächlichen Positionsfehler. Auch bei guter Übereinstimmung sind Fehler möglich.',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                scrollable: true,
                title: const Text('Erkennungssicherheit'),
                content: const Text(
                  'Die Anzeige berücksichtigt die Anzahl beteiligter Kameras, deren Übereinstimmung und die Nähe zum Draht. Millimeter geben die Abweichung der Kameralinien an, nicht den tatsächlichen Positionsfehler. Eine verlässliche Genauigkeit in Prozent erfordert unabhängig überprüfte Treffer.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Schließen'),
                  ),
                ],
              ),
            ),
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      if (hits.isEmpty) const Text('Wartet auf den ersten Dart.'),
      for (var i = 0; i < hits.length; i++) _line(context, i),
    ],
  );

  Widget _line(BuildContext context, int i) {
    final hit = hits[i];
    final manual = corrected[i];
    final review = hit?.needsReview ?? true;
    final label = manual
        ? 'Manuell korrigiert'
        : hit == null
        ? 'Keine Position erkannt'
        : review
        ? 'Schätzung · prüfen'
        : 'Gute Übereinstimmung';
    final color = manual
        ? Theme.of(context).colorScheme.primary
        : review
        ? Theme.of(context).colorScheme.error
        : Colors.green.shade700;
    final reasons = hit == null
        ? ''
        : [
            '${hit.views}/3 Kameras',
            '${hit.residual.toStringAsFixed(1)} mm Linienabweichung',
            if (hit.forcedDecision) 'unsichere Entscheidung',
            if (BoardGeometry.nearWire(hit.point)) 'nahe am Draht',
          ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            manual
                ? Icons.edit_outlined
                : review
                ? Icons.warning_amber
                : Icons.check_circle_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dart ${i + 1}: $label${reasons.isEmpty ? '' : '\n${manual ? 'Ursprüngliche Erkennung: ' : ''}$reasons'}',
                ),
                if (manual && diagnosticSaving?.call(i) == true)
                  const Text('Diagnose wird gespeichert …'),
                if (manual && diagnosticError?.call(i) != null)
                  Text(diagnosticError!(i)!),
                if (manual && diagnosticPath?.call(i) != null)
                  OutlinedButton.icon(
                    onPressed: onExportDiagnostic == null
                        ? null
                        : () => onExportDiagnostic!(i),
                    icon: const Icon(Icons.save_alt),
                    label: Text('Diagnose für Dart ${i + 1} speichern'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
