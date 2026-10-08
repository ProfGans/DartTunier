import 'package:flutter/material.dart';
import '../../domain/community_ranking.dart';

class RankingRulesDialog extends StatefulWidget {
  const RankingRulesDialog({super.key, required this.ranking});
  final CommunityRanking ranking;
  @override
  State<RankingRulesDialog> createState() => _State();
}

class _State extends State<RankingRulesDialog> {
  late final months = TextEditingController(text: '${widget.ranking.validityMonths ?? 3}');
  late bool limited = widget.ranking.validityMonths != null;
  final form = GlobalKey<FormState>();
  @override
  void dispose() { months.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    constraints: const BoxConstraints(maxWidth: 560),
    title: Text('Regeln · ${widget.ranking.name}'),
    scrollable: true,
    content: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Ergebnisse zeitlich begrenzen'), value: limited, onChanged: (v) => setState(() => limited = v)),
      if (limited) TextFormField(controller: months, keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Monate', helperText: '1 bis 120'),
        validator: (v) { final n = int.tryParse(v ?? ''); return n == null || n < 1 || n > 120 ? 'Bitte 1 bis 120 Monate eingeben.' : null; }),
      const SizedBox(height: 12),
      const Text('Elo wird aus den noch gültigen Spielen ab 1000 Punkten neu berechnet. Maßgeblich ist das Abschlussdatum des Spiels. Turniere und Statistiken bleiben erhalten.'),
    ])),
    actions: [
      TextButton(onPressed: () async {
        final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
          title: const Text('Rangliste löschen?'), scrollable: true,
          content: const Text('Die Rangliste verschwindet aus der Auswahl. Turniere und Statistiken bleiben erhalten. Bestehende Turniere werden keiner anderen Rangliste zugeordnet.'),
          actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Abbrechen')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Löschen'))]));
        if (yes == true && context.mounted) Navigator.pop(context, (deleted: true, months: widget.ranking.validityMonths));
      }, child: const Text('Rangliste löschen')),
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
      FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(context, (deleted: false, months: limited ? int.parse(months.text) : null)); }, child: const Text('Speichern')),
    ],
  );
}
