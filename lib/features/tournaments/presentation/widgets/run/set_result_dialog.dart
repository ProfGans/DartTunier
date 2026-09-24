import 'package:flutter/material.dart';
import '../../../domain/tournament_models.dart';
import '../../../domain/set_result_validation.dart';
import '../../models/match_result.dart';

class SetResultDialog extends StatefulWidget {
  const SetResultDialog({super.key, required this.match, required this.format});
  final GroupMatch match;
  final TournamentGameFormat format;
  @override
  State<SetResultDialog> createState() => _SetResultDialogState();
}

class _SetResultDialogState extends State<SetResultDialog> {
  late final List<TextEditingController> fields;
  String? error;
  @override
  void initState() {
    super.initState();
    fields = [
      for (final value in [
        widget.match.homeSets,
        widget.match.awaySets,
        widget.match.homeLegs,
        widget.match.awayLegs,
      ])
        TextEditingController(text: value?.toString() ?? ''),
    ];
  }

  @override
  void dispose() {
    for (final field in fields) {
      field.dispose();
    }
    super.dispose();
  }

  void save() {
    final values = fields.map((f) => int.tryParse(f.text)).toList();
    if (values.any((v) => v == null) ||
        !isValidSetResult(
          widget.format,
          homeSets: values[0]!,
          awaySets: values[1]!,
          homeLegs: values[2]!,
          awayLegs: values[3]!,
        )) {
      setState(
        () => error =
            'Bitte ein vollständiges Set-Ergebnis mit dazu passenden Leg-Summen eingeben.',
      );
      return;
    }
    Navigator.of(context).pop(
      MatchResult(
        homeSets: values[0],
        awaySets: values[1],
        homeLegs: values[2],
        awayLegs: values[3],
      ),
    );
  }

  Widget scoreRow(String label, int start) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      const SizedBox(height: 8),
      Row(
        children: [
          for (var i = 0; i < 2; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: ValueKey('set-result-${start + i}'),
                controller: fields[start + i],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: i == 0
                      ? widget.match.homePlayer?.name
                      : widget.match.awayPlayer?.name,
                ),
              ),
            ),
          ],
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Set-Ergebnis eingeben'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.format.label),
            const SizedBox(height: 16),
            scoreRow('Gewonnene Sets', 0),
            const SizedBox(height: 16),
            scoreRow('Gewonnene Legs insgesamt (für die Tabelle)', 2),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      if (widget.match.hasScore || widget.match.isAnnulled)
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(const MatchResult.cleared()),
          child: const Text('Ergebnis entfernen'),
        ),
      TextButton(
        onPressed: () =>
            Navigator.of(context).pop(const MatchResult.annulled()),
        child: const Text('Spiel annullieren'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Abbrechen'),
      ),
      FilledButton(onPressed: save, child: const Text('Speichern')),
    ],
  );
}
