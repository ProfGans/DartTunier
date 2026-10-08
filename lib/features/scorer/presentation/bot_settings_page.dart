import '../../../shared/widgets/sport_settings_section.dart';
import 'package:dart_tournament_manager/shared/widgets/adaptive_content.dart';
import 'package:flutter/material.dart';
import '../../autoscoring/presentation/widgets/autoscoring_preference_tile.dart';
import '../data/bot_settings_storage.dart';
import '../domain/bot_settings.dart';
import '../application/theo_average_service.dart';
import 'widgets/theo_average_input.dart';
import 'monitor/scorer_monitor_preference_tile.dart';

class BotSettingsPage extends StatelessWidget {
  const BotSettingsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scorer · Bot-Einstellungen')),
    body: const BotSettingsPanel(),
  );
}

class BotSettingsPanel extends StatefulWidget {
  const BotSettingsPanel({super.key, this.storage});
  final BotSettingsStorage? storage;
  @override
  State<BotSettingsPanel> createState() => _BotSettingsPanelState();
}

class _BotSettingsPanelState extends State<BotSettingsPanel> {
  late final storage = widget.storage ?? BotSettingsStorage();
  int skill = 500, finish = 500, radius = 100, spread = 100, speed = 1;
  bool loading = true, saving = false;
  String? error;
  final average = TextEditingController(text: '60');
  final form = GlobalKey<FormState>();
  bool useTheo = true;
  @override
  void dispose() {
    average.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await storage.load();
      if (!mounted) return;
      setState(() {
        _assign(value);
        loading = false;
        error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Einstellungen nicht geladen: $e';
          loading = false;
        });
      }
    }
  }

  void _assign(BotSettings value) {
    skill = value.skill;
    finish = value.finishingSkill;
    radius = value.radiusPercent;
    spread = value.spreadPercent;
    speed = value.speedIndex;
    average.text = value.theoAverage.toString();
    useTheo = value.useTheoAverage;
  }

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    if (useTheo && TheoAverageService.parse(average.text) == null) {
      setState(
        () => error = 'Average größer als 0 bis höchstens 180 eingeben.',
      );
      return;
    }
    setState(() => saving = true);
    try {
      final target = TheoAverageService.parse(average.text) ?? 60;
      if (useTheo) {
        final resolution = await TheoAverageService.resolve(
          target,
          BotSettings(radiusPercent: radius, spreadPercent: spread),
        );
        if (!mounted) return;
        skill = resolution.skill;
        finish = resolution.finishingSkill;
      }
      await storage.save(
        BotSettings(
          skill: skill,
          finishingSkill: finish,
          radiusPercent: radius,
          spreadPercent: spread,
          speedIndex: speed,
          theoAverage: target,
          useTheoAverage: useTheo,
        ),
      );
      if (!mounted) return;
      setState(() => error = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bot-Einstellungen gespeichert.')),
      );
    } catch (e) {
      if (mounted) setState(() => error = 'Speichern fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _slider(
    String title,
    String explanation,
    int value,
    int min,
    int max,
    ValueChanged<int> changed, {
    String suffix = '',
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title: $value$suffix',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(explanation),
          Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            label: '$value$suffix',
            onChanged: saving
                ? null
                : (v) => setState(() => changed(v.round())),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return Form(
      key: form,
      child: AdaptiveContentList(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Bots fein abstimmen',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Text(
            'Diese Vorgaben gelten für neue Spiele. Einzelne Gegner lassen sich beim Spielstart zusätzlich anpassen.',
          ),
          if (error != null) ...[
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(onPressed: _load, child: const Text('Erneut laden')),
          ],
          SwitchListTile(
            title: const Text('Stärke über Theo-Average'),
            subtitle: const Text(
              'Scoring- und Checkout-Stärke automatisch bestimmen.',
            ),
            value: useTheo,
            onChanged: saving ? null : (v) => setState(() => useTheo = v),
          ),
          if (useTheo) ...[
            TheoAverageInput(controller: average, enabled: !saving),
            const Text(
              'Ein theoretischer Richtwert; einzelne Spiele können davon abweichen.',
            ),
          ],
          if (!useTheo) ...[
            _slider(
              'Scoring-Stärke',
              'Höher = stärker beim Punktesammeln (1–1000).',
              skill,
              1,
              1000,
              (v) => skill = v,
            ),
            _slider(
              'Checkout-Stärke',
              'Höher = stärker auf den Abschlussfeldern (1–1000).',
              finish,
              1,
              1000,
              (v) => finish = v,
            ),
          ],
          SportSettingsSection(
            title: 'Feinabstimmung',
            summary: 'Zielstreuung $radius % · Simulation $spread %',
            children: [
              _slider(
                'Zielstreuung',
                'Wie in der bisherigen App: niedrigere Werte machen Bots präziser, höhere ungenauer.',
                radius,
                50,
                150,
                (v) => radius = v,
                suffix: '%',
              ),
              _slider(
                'Simulationsstreuung',
                'Zusätzliche Feinabstimmung der Wurfstreuung. 100 % entspricht der bisherigen App.',
                spread,
                70,
                140,
                (v) => spread = v,
                suffix: '%',
              ),
            ],
          ),
          DropdownButtonFormField<int>(
            key: ValueKey(speed),
            initialValue: speed,
            decoration: const InputDecoration(labelText: 'Bot-Wurftempo'),
            items: const [
              DropdownMenuItem(value: 0, child: Text('Langsam')),
              DropdownMenuItem(value: 1, child: Text('Normal')),
              DropdownMenuItem(value: 2, child: Text('Schnell')),
            ],
            onChanged: saving ? null : (v) => setState(() => speed = v!),
          ),
          const SportSettingsSection(
            title: 'Anzeige & Kamera',
            summary: 'Monitor und automatische Erfassung',
            icon: Icons.devices_outlined,
            children: [
              AutoscoringPreferenceTile(),
              ScorerMonitorPreferenceTile(),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: saving ? null : _save,
            child: Text(saving ? 'Speichert …' : 'Einstellungen speichern'),
          ),
          TextButton(
            onPressed: saving
                ? null
                : () => setState(() => _assign(const BotSettings())),
            child: const Text('Standardwerte wiederherstellen'),
          ),
        ],
      ),
    );
  }
}
