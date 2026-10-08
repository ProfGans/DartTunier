import 'package:flutter/material.dart';
import '../../application/autoscore_demo_controller.dart';
import '../../application/autoscore_validation_series.dart';

class AutoscoreValidationPanel extends StatefulWidget {
  const AutoscoreValidationPanel({super.key, required this.controller});
  final AutoscoreDemoController controller;
  @override
  State<AutoscoreValidationPanel> createState() =>
      _AutoscoreValidationPanelState();
}

class _AutoscoreValidationPanelState extends State<AutoscoreValidationPanel> {
  final series = AutoscoreValidationSeries();
  String scenario = 'normal', partition = 'test';
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_observe);
    series.addListener(_changed);
  }

  void _observe() => series.observe(widget.controller.history);
  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_observe);
    series.removeListener(_changed);
    series.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text('Prüfserie: richtige und falsche Würfe sammeln'),
    children: [
      const Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          'Sammelt komplette Diagnose-ZIPs auch für richtige Würfe. Bitte jedes Ergebnis prüfen und bestätigen oder korrigieren. Nur manuelle Prüfungen zählen als unabhängige Referenz. Nicht erkannte Würfe nachtragen.',
        ),
      ),
      DropdownButtonFormField<String>(
        itemHeight: null,
        initialValue: scenario,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Wurfsituation'),
        items: [
          for (final pair in const [
            ('normal', 'Normale Würfe'),
            ('tightGroups', 'Enge Gruppen'),
            ('outerRim', 'Double und schwarzer Außenrand'),
            ('bouncers', 'Bouncer und Robin Hood'),
            ('lighting', 'Andere Beleuchtung'),
          ])
            DropdownMenuItem(value: pair.$1, child: Text(pair.$2)),
        ],
        onChanged: series.active || series.pending > 0
            ? null
            : (v) => setState(() => scenario = v!),
      ),
      DropdownButtonFormField<String>(
        itemHeight: null,
        initialValue: partition,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Datensatz'),
        items: [
          for (final pair in const [
            ('train', 'Training'),
            ('validation', 'Validierung'),
            ('test', 'Unabhängige Testserie'),
          ])
            DropdownMenuItem(value: pair.$1, child: Text(pair.$2)),
        ],
        onChanged: series.active || series.pending > 0
            ? null
            : (v) => setState(() => partition = v!),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: series.pending > 0 && !series.active
                ? null
                : () => series.active
                      ? series.stop()
                      : series.start(
                          widget.controller.history.length,
                          scenario: scenario,
                          partition: partition,
                        ),
            icon: Icon(series.active ? Icons.stop : Icons.fiber_manual_record),
            label: Text(
              series.active ? 'Prüfserie beenden' : 'Prüfserie starten',
            ),
          ),
        ],
      ),
      Text(
        '${series.events.length} Würfe · ${series.independentlyReviewed} manuell geprüft · ${series.pending} Exporte ausstehend',
      ),
      if (series.folder != null)
        SelectableText('Gespeichert: ${series.folder}'),
      if (series.dropped > 0)
        Text(
          '${series.dropped} Exporte ausgelassen. Diese Serie ist für einen vollständigen Genauigkeitsnachweis unvollständig.',
        ),
      if (series.error != null) Text(series.error!),
    ],
  );
}
