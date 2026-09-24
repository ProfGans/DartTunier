import '../../backups/presentation/backup_panel.dart';
import '../../updates/presentation/android_updates_panel.dart';
import 'package:flutter/material.dart';
import '../data/planning_settings_storage.dart';

import '../../tournaments/domain/tournament_planning_parameters.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Einstellungen')),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: constraints.maxWidth < 600 ? 128 : 240,
              child: ListView(
                primary: false,
                padding: const EdgeInsets.all(8),
                children: [
                  ListTile(
                    selected: _selected == 0,
                    selectedTileColor: Theme.of(
                      context,
                    ).colorScheme.secondaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    title: const Text('Passende Turnierform'),
                    onTap: () => setState(() => _selected = 0),
                  ),
                  ListTile(
                    selected: _selected == 1,
                    title: const Text('Datensicherung'),
                    onTap: () => setState(() => _selected = 1),
                  ),
                  ListTile(
                    selected: _selected == 2,
                    title: const Text('Updates'),
                    onTap: () => setState(() => _selected = 2),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: IndexedStack(
                index: _selected,
                children: const [
                  _PlanningParametersPanel(),
                  BackupPanel(),
                  AndroidUpdatesPanel(),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PlanningParametersPanel extends StatefulWidget {
  const _PlanningParametersPanel();

  @override
  State<_PlanningParametersPanel> createState() =>
      _PlanningParametersPanelState();
}

class _PlanningParametersPanelState extends State<_PlanningParametersPanel> {
  final _storage = PlanningSettingsStorage();
  final _form = GlobalKey<FormState>();
  final _controllers = {
    for (final parameter in PlanningParameter.values)
      parameter: TextEditingController(text: '${parameter.defaultValue}'),
  };
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final parameters = await _storage.load();
      if (!mounted) return;
      for (final entry in _controllers.entries) {
        entry.value.text = '${parameters.value(entry.key)}';
      }
    } catch (_) {
      if (!mounted) return;
      _error = 'Einstellungen konnten nicht geladen werden.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _storage.save(
        TournamentPlanningParameters.fromValues({
          for (final entry in _controllers.entries)
            entry.key: int.parse(entry.value.text.trim()),
        }),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Einstellungen gespeichert. Sie gelten für die nächste Turniersuche.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speichern fehlgeschlagen. Bitte erneut versuchen.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
              TextButton(onPressed: _load, child: const Text('Erneut laden')),
            ],
          ),
        ),
      );
    }
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Passende Turnierform',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Die Parameter gelten nach dem Speichern für neue Berechnungen. Bereits erstellte Turniere bleiben unverändert.',
          ),
          const SizedBox(height: 16),
          for (final category
              in PlanningParameter.values.map((p) => p.category).toSet())
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      category,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final parameter in PlanningParameter.values.where(
                      (p) => p.category == category,
                    ))
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(parameter.label),
                            const SizedBox(height: 6),
                            TextFormField(
                              key: ValueKey(parameter.name),
                              controller: _controllers[parameter],
                              enabled: !_saving,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                helperText:
                                    '${parameter.minimum}–${parameter.maximum}',
                                errorMaxLines: 3,
                              ),
                              validator: (text) {
                                final value = int.tryParse(text?.trim() ?? '');
                                return value != null && parameter.accepts(value)
                                    ? null
                                    : 'Ganze Zahl von ${parameter.minimum} bis ${parameter.maximum} eingeben.';
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'Leg-Dauern sind Schätzwerte. Pro Match gilt der Mittelwert aus minimaler und maximaler Leg-Zahl: Bo3 = 2,5; Bo5 = 4; Bo101 = 76; Bo1 = 1 Leg. Bei Sets wird zusätzlich mit der mittleren Set-Zahl gerechnet. Double In verwendet die Double-Out-Dauer. Weniger Strafpunkte bedeuten eine bessere Platzierung. Spielerzahl, Boards, Zeitfenster, Punktzahl und Checkout werden weiterhin je Turniersuche festgelegt.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Speichert …' : 'Speichern'),
              ),
              OutlinedButton(
                onPressed: _saving
                    ? null
                    : () {
                        for (final entry in _controllers.entries) {
                          entry.value.text = '${entry.key.defaultValue}';
                        }
                        _form.currentState?.validate();
                      },
                child: const Text('Standardwerte einsetzen'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
