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
  final _structureKey = GlobalKey<SportSettingsSectionState>();
  final _minimumMatches = TextEditingController(text: '3');
  final _minHours = TextEditingController(text: '2');
  final _maxHours = TextEditingController(text: '4');
  final _targetHours = TextEditingController(text: '3');
  bool _useTargetDuration = false;
  String? _targetError;
  String _checkoutType = 'double_out';

  String _x01Selection = 'variable_301_501';
  List<TournamentFormatSuggestion>? _suggestions;
  bool _calculating = false;
  bool _cancelled = false;
  VoidCallback? _cancelCalculation;
  void _cancel() {
    _cancelled = true;
    _cancelCalculation?.call();
  }

  bool _allowSets = false;
  bool _allowDraws = false;
  bool _requireGroupPhase = false;
  int _maximumStages = 3;
  int _maximumLives = 5;
  int _suggestionPageSize = 3;
  final Set<String> _enabledModes = TournamentPlanningRequest.modeLabels.keys
      .toSet();

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _players,
      _boards,
      _maximumGroups,
      _minimumMatches,
      _minHours,
      _maxHours,
      _targetHours,
    ]) {
      controller.addListener(() {
        if (_calculating) _cancel();
        if (mounted && _suggestions != null) {
          setState(() => _suggestions = null);
        }
      });
    }
  }

  String get _inputSignature => [
    _players.text,
    _boards.text,
    _maximumGroups.text,
    _minimumMatches.text,
    _minHours.text,
    _maxHours.text,
    _targetHours.text,
    _useTargetDuration,
    _checkoutType,
    _x01Selection,
    _allowSets,
    _allowDraws,
    _requireGroupPhase,
    _maximumStages,
    _maximumLives,
    (_enabledModes.toList()..sort()).join(','),
  ].join('|');

  @override
  void dispose() {
    _cancel();
    _maximumGroups.dispose();
    _players.dispose();
    _boards.dispose();
    _minimumMatches.dispose();
    _minHours.dispose();
    _maxHours.dispose();
    _targetHours.dispose();
    super.dispose();
  }

  Future<void> _calculate() async {
    final targetHours = double.tryParse(
      _targetHours.text.trim().replaceAll(',', '.'),
    );
    if (_useTargetDuration &&
        (targetHours == null ||
            !targetHours.isFinite ||
            targetHours <= 0 ||
            targetHours > 8760 ||
            (targetHours * 60).round() < 1)) {
      setState(() {
        _targetError = 'Gültige Dauer von 1 Minute bis 8760 Stunden eingeben.';
        _suggestions = null;
      });
      return;
    }
    setState(() => _targetError = null);
    final groupText = _maximumGroups.text.trim();
    final groupLimit = int.tryParse(groupText);
    if (groupText.isNotEmpty &&
        (groupLimit == null || groupLimit < 1 || groupLimit > 64)) {
      _structureKey.currentState?.expand();
      setState(() {
        _maximumGroupsError = 'Ganze Zahl von 1 bis 64 eingeben.';
        _suggestions = null;
      });
      return;
    }
    setState(() => _maximumGroupsError = null);
    _cancelled = false;
    setState(() => _calculating = true);
    final inputSignature = _inputSignature;
    try {
      final parameters = await PlanningSettingsStorage().load();
      if (!mounted || _cancelled) return;
      final suggestions = await ExpandedFormatPlanner(parameters: parameters)
          .suggest(
            TournamentPlanningRequest(
              players: int.tryParse(_players.text) ?? 0,
              boards: int.tryParse(_boards.text) ?? 0,
              maximumGroups: groupLimit,
              requireGroupPhase: _requireGroupPhase,
              maximumStages: _maximumStages,
              maximumLives: _maximumLives,
              enabledModes: Set.unmodifiable(_enabledModes),

              minimumMatchesPerPlayer: int.tryParse(_minimumMatches.text) ?? 1,
              minimumMinutes: (int.tryParse(_minHours.text) ?? 0) * 60,
              maximumMinutes: (int.tryParse(_maxHours.text) ?? 24) * 60,
              targetMinutes: _useTargetDuration
                  ? (targetHours! * 60).round()
                  : null,
              x01Selection: _x01Selection,
              checkoutType: _checkoutType,
              allowSets: _allowSets,
              allowDraws: _allowDraws,
            ),
            allResults: true,
            onCancel: (cancel) => _cancelCalculation = cancel,
          );
      if (!mounted) return;
      if (_inputSignature != inputSignature) return;
      setState(() {
        _suggestions = suggestions;
        _suggestionPageSize = parameters.maximumSuggestions;
      });
    } catch (_) {
      if (!mounted || _cancelled) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Einstellungen konnten nicht geladen werden. Bitte erneut versuchen.',
          ),
        ),
      );
    } finally {
      _cancelCalculation = null;
      if (mounted) setState(() => _calculating = false);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => AlertDialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: constraints.maxWidth < 600 ? 12 : 40,
        vertical: 20,
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      title: const Text('Passende Turnierform finden'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Die Schätzung berücksichtigt Runden, begrenzt nutzbare Boards und Wartezeiten zwischen KO-Runden.',
              ),
              const SizedBox(height: 16),
              AdaptiveTileLayout(
                minTileWidth: 220,
                children: [
                  _numberField(_players, 'Anzahl Spieler'),
                  _numberField(_boards, 'Anzahl Boards'),
                  _numberField(_minimumMatches, 'Mindestens Spiele/Spieler'),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final target in [false, true])
                    ChoiceChip(
                      label: Text(target ? 'Wunschdauer' : 'Zeitfenster'),
                      selected: _useTargetDuration == target,
                      padding: const EdgeInsets.all(12),
                      onSelected: _calculating
                          ? null
                          : (_) => setState(() {
                              _useTargetDuration = target;
                              _suggestions = null;
                              _targetError = null;
                            }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_useTargetDuration)
                TextField(
                  controller: _targetHours,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Wunschdauer (Stunden)',
                    helperText:
                        'Zum Beispiel 2,5 für 2 h 30 min. Vorschläge werden nach Nähe zur Wunschdauer sortiert.',
                    helperMaxLines: 3,
                    errorText: _targetError,
                    border: const OutlineInputBorder(),
                  ),
                )
              else
                AdaptiveTileLayout(
                  minTileWidth: 220,
                  children: [
                    _numberField(_minHours, 'Mind. Dauer (Stunden)'),
                    _numberField(_maxHours, 'Max. Dauer (Stunden)'),
                  ],
                ),
              const SizedBox(height: 12),
              const SizedBox(height: 16),
              SportSettingsSection(
                title: 'Turnierformen',
                summary:
                    '${_enabledModes.length} Formen in der Suche berücksichtigt',
                icon: Icons.account_tree_outlined,
                children: [
                  const Text('Berücksichtigte Turnierformen'),
                  const Text(
                    'Die Auswahl gilt für jede Etappe. Gruppen-Spielarten können unabhängig von den KO-Etappen gewählt werden.',
                  ),
                  for (final mode
                      in TournamentPlanningRequest.modeLabels.entries)
                    CheckboxListTile(
                      key: ValueKey('planner-mode-${mode.key}'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(mode.value),
                      value: _enabledModes.contains(mode.key),
                      onChanged: _calculating
                          ? null
                          : (selected) => setState(() {
                              if (selected == true) {
                                _enabledModes.add(mode.key);
                              } else {
                                _enabledModes.remove(mode.key);
                              }
                              _suggestions = null;
                            }),
                    ),
                  if (_enabledModes.isEmpty)
                    const Text('Bitte mindestens eine Turnierform auswählen.'),
                  if (_requireGroupPhase &&
                      !_enabledModes.any((m) => m.startsWith('groups:')))
                    const Text(
                      'Für die erforderliche Gruppenphase bitte eine Gruppen-Spielart auswählen.',
                    ),
                  const SizedBox(height: 16),
                ],
              ),
              SportSettingsSection(
                key: _structureKey,
                title: 'Aufbau & Gruppen',
                summary:
                    'Bis zu $_maximumStages Etappen · ${_requireGroupPhase ? 'mit Gruppenphase' : 'Gruppenphase optional'}',
                icon: Icons.groups_outlined,
                children: [
                  TextField(
                    key: const ValueKey('planner-maximum-groups'),
                    controller: _maximumGroups,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Maximale Gruppenzahl',
                      helperText:
                          'Obergrenze je Gruppenphase, keine Pflicht für Gruppen. Leer: gespeicherter Wert. Mindestens 3 Spieler je Gruppe.',
                      helperMaxLines: 3,
                      errorText: _maximumGroupsError,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    key: const ValueKey('planner-require-groups'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Gruppenphase erforderlich'),
                    value: _requireGroupPhase,
                    onChanged: _calculating
                        ? null
                        : (value) => setState(() {
                            _requireGroupPhase = value;
                            _suggestions = null;
                          }),
                  ),
                  const Text(
                    'Nur Vorschläge mit Gruppenphase. Weitere Etappen bleiben möglich.',
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: _maximumStages,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Maximale Etappen',
                      helperText: 'Suche nach Kombinationen aller Turniermodi.',
                      helperMaxLines: 3,
                    ),
                    items: [
                      for (var n = 1; n <= 4; n++)
                        DropdownMenuItem(value: n, child: Text('$n')),
                    ],
                    onChanged: _calculating
                        ? null
                        : (n) => setState(() {
                            _maximumStages = n!;
                            _suggestions = null;
                          }),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: _maximumLives,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Maximale Leben im Kratzer-Modus',
                    ),
                    items: [
                      for (var n = 2; n <= 10; n++)
                        DropdownMenuItem(value: n, child: Text('$n')),
                    ],
                    onChanged: _calculating
                        ? null
                        : (n) => setState(() {
                            _maximumLives = n!;
                            _suggestions = null;
                          }),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
              SportSettingsSection(
                title: 'Spielregeln',
                summary:
                    '${_x01Selection == 'variable_301_501' ? '301 oder 501' : _x01Selection} · ${_checkoutType == 'double_out'
                        ? 'Double Out'
                        : _checkoutType == 'single_out'
                        ? 'Single Out'
                        : _checkoutType == 'master_out'
                        ? 'Master Out'
                        : 'Double In / Double Out'} · ${_allowSets ? 'Legs und Sets' : 'Legs'}',
                icon: Icons.sports_score,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _x01Selection,
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
                    onChanged: (value) => setState(() {
                      _x01Selection = value!;
                      _suggestions = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _checkoutType,
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
                    onChanged: (value) => setState(() {
                      _checkoutType = value!;
                      _suggestions = null;
                    }),
                  ),
                  const SizedBox(height: 16),
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
                ],
              ),
              SportSettingsSection(
                title: 'So entsteht die Schätzung',
                summary: 'Spieldistanz, Zeitansatz und weitere Etappen',
                icon: Icons.info_outline,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Spätere Etappen bleiben bei gleicher Distanz oder steigen höchstens um eine Best-of-Stufe (Bo3 → Bo5); dies gilt für Legs und Sets. Jede Etappe erhält einen eigenen Vorschlag: Best of 1 bis 101 Legs; bei erlaubtem Unentschieden zusätzlich gerade Leg-Längen bis 100 und optional Best of 3 oder 5 Sets. Bei variabler Punktzahl werden 301 und 501 je Etappe verglichen. Zeitansatz: Mittelwert aus minimaler und maximaler Anzahl Legs bzw. Sets. Bo3 = 2,5; Bo4 = 3,5; Bo5 = 4; Bo101 = 76. Bo1 = 1.',
                    ),
                  ),
                ],
              ),
              if (_calculating)
                TextButton(
                  onPressed: _cancel,
                  child: const Text('Berechnung abbrechen'),
                ),
              if (_suggestions != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Mehr Boards ändern bei gleichem Turnieraufbau nur die Dauer, nicht die Spielanzahl. Dadurch können andere Gruppenaufteilungen ins Zeitfenster passen und die Vorschläge anders sortiert werden. Bei variabler Punktzahl kann sich auch 301/501 ändern.',
                ),
                const SizedBox(height: 12),
                if (_suggestions!.isEmpty)
                  Text(
                    _requireGroupPhase
                        ? 'Keine Gruppenaufteilung möglich: Jede Gruppe benötigt mindestens 3 Spieler.'
                        : 'Keine Turnierform für diese Eingaben gefunden.',
                  ),
                PlanningSuggestionList(
                  suggestions: _suggestions!,
                  pageSize: _suggestionPageSize,
                  onSelected: (suggestion) =>
                      Navigator.of(context).pop(suggestion),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton.icon(
          onPressed:
              _calculating ||
                  _enabledModes.isEmpty ||
                  (_requireGroupPhase &&
                      !_enabledModes.any((m) => m.startsWith('groups:')))
              ? null
              : _calculate,
          icon: const Icon(Icons.search),
          label: Text(_calculating ? 'Berechnet …' : 'Vorschläge berechnen'),
        ),

        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
      ],
    ),
  );

  Widget _numberField(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
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
              key: ValueKey('x01-${value.x01Score}'),
              initialValue: value.x01Score,
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
              key: ValueKey('checkout-${value.checkoutType}'),
              initialValue: value.checkoutType,
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
              key: ValueKey('legs-${value.bestOfLegs}'),
              initialValue: value.bestOfLegs,
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
              key: ValueKey('sets-${value.bestOfSets}'),
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
              key: ValueKey('double-in-${value.doubleIn}'),
              initialValue: value.doubleIn,
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
