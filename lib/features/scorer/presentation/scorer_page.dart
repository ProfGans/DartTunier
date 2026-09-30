import 'package:dart_tournament_manager/shared/widgets/adaptive_content.dart';
import 'package:flutter/material.dart';
import '../data/repositories/checkout_route_repository.dart';
import '../domain/scorer_settings.dart';
import '../domain/x01/x01_models.dart';
import 'checkout_page.dart';
import 'scorer_match_page.dart';
import 'bot_settings_page.dart';
import '../data/bot_settings_storage.dart';
import '../domain/bot_settings.dart';
import '../application/theo_average_service.dart';
import 'widgets/theo_average_input.dart';

class ScorerPage extends StatefulWidget {
  const ScorerPage({super.key, this.botStorage});
  final BotSettingsStorage? botStorage;
  @override
  State<ScorerPage> createState() => _ScorerPageState();
}

class _ScorerPageState extends State<ScorerPage> {
  late final botStorage = widget.botStorage ?? BotSettingsStorage();
  final form = GlobalKey<FormState>();
  final score = TextEditingController(text: '501');
  final legs = TextEditingController(text: '3');
  final sets = TextEditingController(text: '1');
  final participants = [
    _ParticipantInput('Spieler 1'),
    _ParticipantInput('Spieler 2'),
  ];
  StartRequirement start = StartRequirement.straightIn;
  CheckoutRequirement checkout = CheckoutRequirement.doubleOut;
  int starter = 0;
  bool loading = false;
  String? error;
  BotSettings botSettings = const BotSettings();
  bool settingsLoaded = false;
  @override
  void initState() {
    super.initState();
    _loadBotSettings();
  }

  Future<void> _loadBotSettings() async {
    try {
      final value = await botStorage.load();
      if (!mounted) return;
      setState(() {
        botSettings = value;
        for (final p in participants) {
          p.skill = value.skill.toDouble();
          p.finish = value.finishingSkill.toDouble();
          p.average.text = value.theoAverage.toString();
          p.useTheo = value.useTheoAverage;
        }
        settingsLoaded = true;
        error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => error = 'Bot-Einstellungen konnten nicht geladen werden: $e',
        );
      }
    }
  }

  Future<void> _openBotSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const BotSettingsPage()));
    if (mounted) await _loadBotSettings();
  }

  @override
  void dispose() {
    score.dispose();
    legs.dispose();
    sets.dispose();
    for (final p in participants) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _start() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final tuning = await botStorage.load();
      await CheckoutRouteRepository.instance.initialize();
      if (!mounted) return;
      final resolvedParticipants = <ScorerParticipant>[];
      for (final p in participants) {
        BotProfile? profile;
        if (p.bot) {
          if (p.useTheo) {
            final target = TheoAverageService.parse(p.average.text);
            if (target == null) {
              throw ArgumentError(
                'Ungültiger Theo-Average für ${p.name.text}.',
              );
            }
            final resolution = await TheoAverageService.resolve(target, tuning);
            if (!mounted) return;
            profile = tuning.profile(
              scoring: resolution.skill,
              finishing: resolution.finishingSkill,
            );
          } else {
            profile = tuning.profile(
              scoring: p.skill.round(),
              finishing: p.finish.round(),
            );
          }
        }
        resolvedParticipants.add(
          ScorerParticipant(
            p.name.text.trim(),
            startScore: int.tryParse(p.score.text),
            bot: profile,
          ),
        );
      }
      final settings = ScorerSettings(
        startScore: int.parse(score.text),
        bestOfLegs: int.parse(legs.text),
        bestOfSets: int.parse(sets.text),
        startRequirement: start,
        checkoutRequirement: checkout,
        startingPlayer: starter,
        botThrowDelay: tuning.throwDelay,
        participants: resolvedParticipants,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ScorerMatchPage(settings: settings),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => error = 'Spiel konnte nicht gestartet werden: $e');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String? _number(String? value, {bool odd = false, bool optional = false}) {
    if (optional && (value == null || value.trim().isEmpty)) return null;
    final n = int.tryParse(value ?? '');
    if (n == null || n < (odd ? 1 : 2) || n > 9999 || (odd && n.isEven)) {
      return odd
          ? 'Positive ungerade Zahl eingeben.'
          : 'Zahl zwischen 2 und 9999 eingeben.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Scorer'),
      actions: [
        IconButton(
          tooltip: 'Bot-Einstellungen',
          onPressed: loading ? null : _openBotSettings,
          icon: const Icon(Icons.tune),
        ),
      ],
    ),
    body: AbsorbPointer(
      absorbing: loading,
      child: Form(
        key: form,
        child: AdaptiveContentList(
          padding: const EdgeInsets.all(24),
          children: [
            FilledButton.icon(
              onPressed: loading || !settingsLoaded
                  ? null
                  : () => setState(() {
                      if (participants.length < 2) {
                        participants.add(_ParticipantInput('Bot'));
                      }
                      final p = participants[1];
                      p.bot = true;
                      p.name.text = 'Bot';
                      p.skill = botSettings.skill.toDouble();
                      p.finish = botSettings.finishingSkill.toDouble();
                      p.average.text = botSettings.theoAverage.toString();
                      p.useTheo = botSettings.useTheoAverage;
                    }),
              icon: const Icon(Icons.smart_toy_outlined),
              label: const Text('Gegen Bot spielen'),
            ),
            if (participants.any((p) => p.bot))
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'Bot ausgewählt. Spieleinstellungen prüfen und unten „Spiel starten“ wählen.',
                ),
              ),
            TextButton.icon(
              onPressed: loading ? null : _openBotSettings,
              icon: const Icon(Icons.tune),
              label: const Text('Bot-Stärke & Feinabstimmung'),
            ),
            if (!settingsLoaded && error != null)
              TextButton(
                onPressed: _loadBotSettings,
                child: const Text('Einstellungen erneut laden'),
              ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.calculate_outlined),
                title: const Text('Checkoutrechner'),
                subtitle: const Text(
                  'Feste Wege für Single, Double und Master Out',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const CheckoutPage()),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'X01 · Spieleinstellungen',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Freies Spiel oder Training gegen Bots. Best of 5 bedeutet: drei Siege zum Gewinn.',
            ),
            TextFormField(
              controller: score,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Startpunkte'),
              validator: _number,
            ),
            DropdownButtonFormField<StartRequirement>(
              isExpanded: true, isDense: false,
              itemHeight: null,
              initialValue: start,
              decoration: const InputDecoration(labelText: 'In-Regel'),
              items: const [
                DropdownMenuItem(
                  value: StartRequirement.straightIn,
                  child: Text('Straight In'),
                ),
                DropdownMenuItem(
                  value: StartRequirement.doubleIn,
                  child: Text('Double In'),
                ),
              ],
              onChanged: (v) => setState(() => start = v!),
            ),
            DropdownButtonFormField<CheckoutRequirement>(
              isExpanded: true, isDense: false,
              itemHeight: null,
              initialValue: checkout,
              decoration: const InputDecoration(labelText: 'Out-Regel'),
              items: [
                for (final r in CheckoutRequirement.values)
                  DropdownMenuItem(value: r, child: Text(checkoutLabel(r))),
              ],
              onChanged: (v) => setState(() => checkout = v!),
            ),
            TextFormField(
              controller: legs,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Best of Legs (je Set)',
                helperText:
                    'Ungerade Zahl; keine Unentschieden im freien Spiel.',
              ),
              validator: (v) => _number(v, odd: true),
            ),
            TextFormField(
              controller: sets,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Best of Sets',
                helperText: '1 = ausschließlich Legs',
              ),
              validator: (v) => _number(v, odd: true),
            ),
            const SizedBox(height: 24),
            Text('Teilnehmer', style: Theme.of(context).textTheme.titleLarge),
            for (var i = 0; i < participants.length; i++) _participant(i),
            TextButton.icon(
              onPressed: loading
                  ? null
                  : () => setState(() {
                      participants.add(
                        _ParticipantInput('Spieler ${participants.length + 1}'),
                      );
                      participants.last.skill = botSettings.skill.toDouble();
                      participants.last.average.text = botSettings.theoAverage
                          .toString();
                      participants.last.useTheo = botSettings.useTheoAverage;
                      participants.last.finish = botSettings.finishingSkill
                          .toDouble();
                    }),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Teilnehmer hinzufügen'),
            ),
            DropdownButtonFormField<int>(
              isExpanded: true, isDense: false,
              itemHeight: null,
              key: ValueKey(participants.length),
              initialValue: starter,
              decoration: const InputDecoration(
                labelText: 'Anwurf · Ergebnis des Ausbullens',
              ),
              items: [
                for (var i = 0; i < participants.length; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text('Teilnehmer ${i + 1}'),
                  ),
              ],
              onChanged: (v) => setState(() => starter = v!),
            ),
            const Text(
              'Bei Ausbullen zuerst am Board ausbullen, dann den Gewinner als Anwerfer wählen. '
              'Der Anwurf wechselt nach jedem Leg.',
            ),
            const SizedBox(height: 24),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            FilledButton.icon(
              onPressed: loading || !settingsLoaded ? null : _start,
              icon: const Icon(Icons.play_arrow),
              label: Text(loading ? 'Spiel wird geöffnet …' : 'Spiel starten'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _participant(int index) {
    final p = participants[index];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: p.name,
              decoration: InputDecoration(
                labelText: 'Teilnehmer ${index + 1} · Name',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name eingeben.' : null,
            ),
            if (index > 0)
              SwitchListTile(
                title: const Text('Computergegner (Bot)'),
                value: p.bot,
                onChanged: (v) => setState(() => p.bot = v),
              ),
            TextFormField(
              controller: p.score,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Eigene Startpunkte (optional)',
                helperText: 'Leer = gemeinsame Startpunkte',
              ),
              validator: (v) => _number(v, optional: true),
            ),
            if (p.bot) ...[
              SwitchListTile(
                title: const Text('Stärke über Theo-Average'),
                value: p.useTheo,
                onChanged: loading
                    ? null
                    : (v) => setState(() => p.useTheo = v),
              ),
              if (p.useTheo)
                TheoAverageInput(controller: p.average, enabled: !loading),
              if (!p.useTheo) ...[
                Text('Scoring-Stärke: ${p.skill.round()} / 1000'),
                Slider(
                  value: p.skill,
                  min: 1,
                  max: 1000,
                  onChanged: (v) => setState(() => p.skill = v),
                ),
                Text('Checkout-Stärke: ${p.finish.round()} / 1000'),
                Slider(
                  value: p.finish,
                  min: 1,
                  max: 1000,
                  onChanged: (v) => setState(() => p.finish = v),
                ),
              ],
            ],
            if (index > 0)
              TextButton(
                onPressed: loading
                    ? null
                    : () => setState(() {
                        participants.removeAt(index).dispose();
                        if (starter >= participants.length) starter = 0;
                      }),
                child: const Text('Teilnehmer entfernen'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ParticipantInput {
  _ParticipantInput(String value) : name = TextEditingController(text: value);
  final TextEditingController name;
  final score = TextEditingController();
  final average = TextEditingController(text: '60');
  bool useTheo = true;
  bool bot = false;
  double skill = 500, finish = 500;
  void dispose() {
    name.dispose();
    score.dispose();
    average.dispose();
  }
}
