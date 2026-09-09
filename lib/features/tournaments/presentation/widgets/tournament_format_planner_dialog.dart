part of '../../../../tournament_workspace.dart';

class TournamentFormatPlannerDialog extends StatefulWidget {
  const TournamentFormatPlannerDialog({super.key});
  @override
  State<TournamentFormatPlannerDialog> createState() => _TournamentFormatPlannerDialogState();
}

class _TournamentFormatPlannerDialogState extends State<TournamentFormatPlannerDialog> {
  final _players = TextEditingController(text: '8');
  final _boards = TextEditingController(text: '2');
  final _minimumMatches = TextEditingController(text: '3');
  final _minHours = TextEditingController(text: '2');
  final _maxHours = TextEditingController(text: '4');
  String _checkoutType = 'double_out';
  String _x01Selection = 'variable_301_501';
  List<TournamentFormatSuggestion>? _suggestions;

  @override
  void dispose() { _players.dispose(); _boards.dispose(); _minimumMatches.dispose(); _minHours.dispose(); _maxHours.dispose(); super.dispose(); }

  void _calculate() => setState(() {
    _suggestions = const TournamentFormatPlanner().suggest(TournamentPlanningRequest(
      players: int.tryParse(_players.text) ?? 0,
      boards: int.tryParse(_boards.text) ?? 0,
      minimumMatchesPerPlayer: int.tryParse(_minimumMatches.text) ?? 1,
      minimumMinutes: (int.tryParse(_minHours.text) ?? 0) * 60,
      maximumMinutes: (int.tryParse(_maxHours.text) ?? 24) * 60,
      x01Selection: _x01Selection,
      checkoutType: _checkoutType,
    ));
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Passende Turnierform finden'),
    content: SizedBox(width: 650, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Die Schätzung berücksichtigt Runden, begrenzt nutzbare Boards und Wartezeiten zwischen KO-Runden.'),
      const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 12, children: [_numberField(_players, 'Anzahl Spieler'), _numberField(_boards, 'Anzahl Boards'), _numberField(_minimumMatches, 'Mindestens Spiele/Spieler'), _numberField(_minHours, 'Mind. Dauer (Stunden)'), _numberField(_maxHours, 'Max. Dauer (Stunden)')]),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: _x01Selection, isExpanded: true, decoration: const InputDecoration(labelText: 'X01-Punktzahl', border: OutlineInputBorder()), items: const [
        DropdownMenuItem(value: '101', child: Text('101')), DropdownMenuItem(value: '170', child: Text('170')), DropdownMenuItem(value: '201', child: Text('201')), DropdownMenuItem(value: '301', child: Text('301')), DropdownMenuItem(value: '401', child: Text('401')), DropdownMenuItem(value: '501', child: Text('501')), DropdownMenuItem(value: '701', child: Text('701')), DropdownMenuItem(value: '901', child: Text('901')), DropdownMenuItem(value: 'variable_301_501', child: Text('Variabel (301 oder 501)')),
      ], onChanged: (value) => setState(() => _x01Selection = value!)),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: _checkoutType, isExpanded: true, decoration: const InputDecoration(labelText: 'Checkout-Modus', border: OutlineInputBorder()), items: const [
        DropdownMenuItem(value: 'double_out', child: Text('Double Out')), DropdownMenuItem(value: 'single_out', child: Text('Single Out')), DropdownMenuItem(value: 'master_out', child: Text('Master Out')), DropdownMenuItem(value: 'double_in_out', child: Text('Double In / Double Out')),
      ], onChanged: (value) => setState(() => _checkoutType = value!)),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: _calculate, icon: const Icon(Icons.search), label: const Text('Vorschläge berechnen')),
      if (_suggestions != null) ...[const SizedBox(height: 16), ..._suggestions!.map(_suggestionCard)],
    ]))),
    actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen'))],
  );

  Widget _suggestionCard(TournamentFormatSuggestion suggestion) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).pop(suggestion),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(suggestion.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(suggestion.format.label),
            Text('${suggestion.totalMatches} Spiele gesamt · mind. ${suggestion.minimumMatchesPerPlayer} je Spieler'),
            Text('ca. ${suggestion.estimatedMinutes ~/ 60} h ${suggestion.estimatedMinutes % 60} min · ${suggestion.effectiveBoards} Boards nutzbar'),
            if (suggestion.isClosestAlternative) const Padding(padding: EdgeInsets.only(top: 6), child: Text('Nächstbeste Lösung außerhalb der gewünschten Vorgaben')),
          ])),
          const Icon(Icons.chevron_right),
        ]),
      ),
    ),
  );

  Widget _numberField(TextEditingController controller, String label) => SizedBox(width: 195, child: TextField(controller: controller, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())));
}

class _StageGameFormatSetup extends StatelessWidget {
  const _StageGameFormatSetup({required this.value, required this.onChanged});
  final TournamentGameFormat value;
  final ValueChanged<TournamentGameFormat> onChanged;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Spielformat', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
    const SizedBox(height: 12),
    Wrap(spacing: 12, runSpacing: 12, children: [
      _field(width: 160, child: DropdownButtonFormField<int>(value: value.x01Score, isExpanded: true, decoration: const InputDecoration(labelText: 'X01-Punktzahl', border: OutlineInputBorder()), items: const [101, 170, 201, 301, 401, 501, 701, 901].map((score) => DropdownMenuItem(value: score, child: Text('$score'))).toList(), onChanged: (score) => _change(x01Score: score))),
      _field(width: 180, child: DropdownButtonFormField<String>(value: value.checkoutType, isExpanded: true, decoration: const InputDecoration(labelText: 'Checkout', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'double_out', child: Text('Double Out')), DropdownMenuItem(value: 'single_out', child: Text('Single Out')), DropdownMenuItem(value: 'master_out', child: Text('Master Out'))], onChanged: (checkout) => _change(checkoutType: checkout))),
      _field(width: 145, child: DropdownButtonFormField<int>(value: value.bestOfLegs, isExpanded: true, decoration: const InputDecoration(labelText: 'Best of Legs', border: OutlineInputBorder()), items: const [1, 3, 5, 7, 9].map((legs) => DropdownMenuItem(value: legs, child: Text('$legs Legs'))).toList(), onChanged: (legs) => _change(bestOfLegs: legs))),
      _field(width: 160, child: DropdownButtonFormField<bool>(value: value.doubleIn, isExpanded: true, decoration: const InputDecoration(labelText: 'Double In', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: false, child: Text('Nein')), DropdownMenuItem(value: true, child: Text('Ja'))], onChanged: (doubleIn) => _change(doubleIn: doubleIn))),
    ]),
  ]);

  Widget _field({required double width, required Widget child}) => SizedBox(width: width, child: child);
  void _change({int? x01Score, String? checkoutType, int? bestOfLegs, bool? doubleIn}) => onChanged(TournamentGameFormat(x01Score: x01Score ?? value.x01Score, checkoutType: checkoutType ?? value.checkoutType, bestOfLegs: bestOfLegs ?? value.bestOfLegs, doubleIn: doubleIn ?? value.doubleIn));
}
