part of '../../../../tournament_workspace.dart';

class TournamentFormatPlannerDialog extends StatefulWidget {
  const TournamentFormatPlannerDialog({super.key});
  @override
  State<TournamentFormatPlannerDialog> createState() =>
      _TournamentFormatPlannerDialogState();
}

class _TournamentFormatPlannerDialogState
    extends State<TournamentFormatPlannerDialog> {
  final _players = TextEditingController(text: '8');
  final _boards = TextEditingController(text: '2');
  final _maximumGroups = TextEditingController();
  String? _maximumGroupsError;
  final _minimumMatches = TextEditingController(text: '3');
  final _minHours = TextEditingController(text: '2');
  final _maxHours = TextEditingController(text: '4');
  String _checkoutType = 'double_out';

  String _x01Selection = 'variable_301_501';
  List<TournamentFormatSuggestion>? _suggestions;
  bool _calculating = false;
  bool _allowSets = false;
  bool _allowDraws = false;

  @override
  void dispose() {
    _maximumGroups.dispose();
    _players.dispose();
    _boards.dispose();
    _minimumMatches.dispose();
    _minHours.dispose();
    _maxHours.dispose();
    super.dispose();
  }

  Future<void> _calculate() async {
    final groupText = _maximumGroups.text.trim();
    final groupLimit = int.tryParse(groupText);
    if (groupText.isNotEmpty &&
        (groupLimit == null || groupLimit < 1 || groupLimit > 64)) {
      setState(() {
        _maximumGroupsError = 'Ganze Zahl von 1 bis 64 eingeben.';
        _suggestions = null;
      });
      return;
    }
    setState(() => _maximumGroupsError = null);
    setState(() => _calculating = true);
    try {
      final parameters = await PlanningSettingsStorage().load();
      if (!mounted) return;
      setState(() {
        _suggestions = TournamentFormatPlanner(parameters: parameters)
            .suggestFormats(
              TournamentPlanningRequest(
                players: int.tryParse(_players.text) ?? 0,
                boards: int.tryParse(_boards.text) ?? 0,
                maximumGroups: groupLimit,

                minimumMatchesPerPlayer:
                    int.tryParse(_minimumMatches.text) ?? 1,
                minimumMinutes: (int.tryParse(_minHours.text) ?? 0) * 60,
                maximumMinutes: (int.tryParse(_maxHours.text) ?? 24) * 60,
                x01Selection: _x01Selection,
                checkoutType: _checkoutType,
                allowSets: _allowSets,
                allowDraws: _allowDraws,
              ),
            );
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Einstellungen konnten nicht geladen werden. Bitte erneut versuchen.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _calculating = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Passende Turnierform finden'),
    content: SizedBox(
      width: 650,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Die Schätzung berücksichtigt Runden, begrenzt nutzbare Boards und Wartezeiten zwischen KO-Runden.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _numberField(_players, 'Anzahl Spieler'),
                _numberField(_boards, 'Anzahl Boards'),
                _numberField(_minimumMatches, 'Mindestens Spiele/Spieler'),
                _numberField(_minHours, 'Mind. Dauer (Stunden)'),
                _numberField(_maxHours, 'Max. Dauer (Stunden)'),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('planner-maximum-groups'),
              controller: _maximumGroups,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Maximale Gruppenzahl',
                helperText:
                    'Leer: gespeicherten Einstellungswert verwenden. Mindestens 3 Spieler je Gruppe.',
                helperMaxLines: 3,
                errorText: _maximumGroupsError,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _x01Selection,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'X01-Punktzahl',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '101', child: Text('101')),
                DropdownMenuItem(value: '170', child: Text('170')),
                DropdownMenuItem(value: '201', child: Text('201')),
                DropdownMenuItem(value: '301', child: Text('301')),
                DropdownMenuItem(value: '401', child: Text('401')),
                DropdownMenuItem(value: '501', child: Text('501')),
                DropdownMenuItem(value: '701', child: Text('701')),
                DropdownMenuItem(value: '901', child: Text('901')),
                DropdownMenuItem(
                  value: 'variable_301_501',
                  child: Text('Variabel (301 oder 501)'),
                ),
              ],
              onChanged: (value) => setState(() => _x01Selection = value!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _checkoutType,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Checkout-Modus',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'double_out',
                  child: Text('Double Out'),
                ),
                DropdownMenuItem(
                  value: 'single_out',
                  child: Text('Single Out'),
                ),
                DropdownMenuItem(
                  value: 'master_out',
                  child: Text('Master Out'),
                ),
                DropdownMenuItem(
                  value: 'double_in_out',
                  child: Text('Double In / Double Out'),
                ),
              ],
              onChanged: (value) => setState(() => _checkoutType = value!),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Spätere Etappen bleiben bei gleicher Distanz oder steigen höchstens um eine Best-of-Stufe (Bo3 → Bo5); dies gilt für Legs und Sets. Jede Etappe erhält einen eigenen Vorschlag: Best of 1 bis 101 Legs; bei erlaubtem Unentschieden zusätzlich gerade Leg-Längen bis 100 und optional Best of 3 oder 5 Sets. Bei variabler Punktzahl werden 301 und 501 je Etappe verglichen. Zeitansatz: Mittelwert aus minimaler und maximaler Anzahl Legs bzw. Sets. Bo3 = 2,5; Bo4 = 3,5; Bo5 = 4; Bo101 = 76. Bo1 = 1.',
              ),
            ),
            SwitchListTile(
              key: const ValueKey('planner-allow-draws'),
              title: const Text('Unentschieden erlauben'),
              subtitle: const Text(
                'Zusätzlich gerade Leg-Längen in Liga-/Gruppenphasen: 1 Punkt je Spieler. K.-o. und Set-Formate benötigen einen Sieger.',
              ),
              value: _allowDraws,
              onChanged: _calculating
                  ? null
                  : (value) => setState(() {
                      _allowDraws = value;
                      _suggestions = null;
                    }),
            ),
            SwitchListTile(
              key: const ValueKey('planner-allow-sets'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Sets in Vorschlägen erlauben'),
              subtitle: const Text(
                'Ausgeschaltet: nur Legs. Eingeschaltet: zusätzlich Best of 3 oder 5 Sets.',
              ),
              value: _allowSets,
              onChanged: _calculating
                  ? null
                  : (value) => setState(() {
                      _allowSets = value;
                      _suggestions = null;
                    }),
            ),
            FilledButton.icon(
              onPressed: _calculating ? null : _calculate,
              icon: const Icon(Icons.search),
              label: Text(
                _calculating ? 'Berechnet …' : 'Vorschläge berechnen',
              ),
            ),
            if (_suggestions != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Mehr Boards ändern bei gleichem Turnieraufbau nur die Dauer, nicht die Spielanzahl. Dadurch können andere Gruppenaufteilungen ins Zeitfenster passen und die Vorschläge anders sortiert werden. Bei variabler Punktzahl kann sich auch 301/501 ändern.',
              ),
              const SizedBox(height: 12),
              if (_suggestions!.isEmpty) const Text('Keine Gruppenaufteilung möglich: Jede Gruppe benötigt mindestens 3 Spieler.'),
            ..._suggestions!.map(
                (suggestion) => PlanningSuggestionCard(
                  suggestion: suggestion,
                  onSelected: () => Navigator.of(context).pop(suggestion),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Abbrechen'),
      ),
    ],
  );

  Widget _numberField(TextEditingController controller, String label) =>
      SizedBox(
        width: 195,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      );
}

class _StageGameFormatSetup extends StatelessWidget {
  const _StageGameFormatSetup({required this.value, required this.onChanged});
  final TournamentGameFormat value;
  final ValueChanged<TournamentGameFormat> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Spielformat',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _field(
            width: 160,
            child: DropdownButtonFormField<int>(
              value: value.x01Score,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'X01-Punktzahl',
                border: OutlineInputBorder(),
              ),
              items: const [101, 170, 201, 301, 401, 501, 701, 901]
                  .map(
                    (score) =>
                        DropdownMenuItem(value: score, child: Text('$score')),
                  )
                  .toList(),
              onChanged: (score) => _change(x01Score: score),
            ),
          ),
          _field(
            width: 180,
            child: DropdownButtonFormField<String>(
              value: value.checkoutType,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Checkout',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'double_out',
                  child: Text('Double Out'),
                ),
                DropdownMenuItem(
                  value: 'single_out',
                  child: Text('Single Out'),
                ),
                DropdownMenuItem(
                  value: 'master_out',
                  child: Text('Master Out'),
                ),
              ],
              onChanged: (checkout) => _change(checkoutType: checkout),
            ),
          ),
          _field(
            width: 145,
            child: DropdownButtonFormField<int>(
              value: value.bestOfLegs,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Best of Legs',
                border: OutlineInputBorder(),
              ),
              items:
                  ([
                        ...TournamentGameFormat.supportedBestOfLegs,
                        if (value.bestOfSets == 1)
                          ...TournamentGameFormat.supportedDrawLegs,
                      ]..sort())
                      .map(
                        (legs) => DropdownMenuItem(
                          value: legs,
                          child: Text('$legs Legs'),
                        ),
                      )
                      .toList(),
              onChanged: (legs) => _change(bestOfLegs: legs),
            ),
          ),
          _field(
            width: 180,
            child: DropdownButtonFormField<int>(
              initialValue: value.bestOfSets,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Best of Sets',
                border: OutlineInputBorder(),
              ),
              items: const [1, 3, 5]
                  .map(
                    (sets) => DropdownMenuItem(
                      value: sets,
                      child: Text(sets == 1 ? 'Nur Legs' : '$sets Sets'),
                    ),
                  )
                  .toList(),
              onChanged: (sets) => _change(bestOfSets: sets),
            ),
          ),
          _field(
            width: 160,
            child: DropdownButtonFormField<bool>(
              value: value.doubleIn,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Double In',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: false, child: Text('Nein')),
                DropdownMenuItem(value: true, child: Text('Ja')),
              ],
              onChanged: (doubleIn) => _change(doubleIn: doubleIn),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _field({required double width, required Widget child}) =>
      SizedBox(width: width, child: child);
  void _change({
    int? x01Score,
    String? checkoutType,
    int? bestOfLegs,
    int? bestOfSets,
    bool? doubleIn,
  }) => onChanged(
    TournamentGameFormat(
      x01Score: x01Score ?? value.x01Score,
      checkoutType: checkoutType ?? value.checkoutType,
      bestOfLegs:
          bestOfSets != null && bestOfSets > 1 && value.bestOfLegs.isEven
          ? value.bestOfLegs + 1
          : bestOfLegs ?? value.bestOfLegs,
      bestOfSets: bestOfSets ?? value.bestOfSets,
      doubleIn: doubleIn ?? value.doubleIn,
    ),
  );
}
