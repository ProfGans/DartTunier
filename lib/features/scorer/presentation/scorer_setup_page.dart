import '../../../shared/widgets/sport_form_section.dart';
import 'widgets/scorer_doubles_dialog.dart';
import 'package:dart_tournament_manager/shared/widgets/adaptive_content.dart';
import 'package:flutter/material.dart';
import '../../accounts/domain/account_user.dart';
import '../data/repositories/checkout_route_repository.dart';
import '../domain/scorer_settings.dart';
import '../domain/x01/x01_models.dart';
import 'scorer_match_page.dart';
import 'checkout_page.dart' show checkoutLabel;
import '../domain/scorer_opponents.dart';
import '../data/bot_settings_storage.dart';
import '../domain/bot_settings.dart';
import '../application/theo_average_service.dart';
import 'widgets/theo_average_input.dart';
import '../application/scorer_lobby_controller.dart';
import '../data/scorer_lobby_repository.dart';
import 'lobby/scorer_lobby_panel.dart';

class ScorerSetupPage extends StatefulWidget {
  const ScorerSetupPage({
    super.key,
    this.botStorage,
    this.account,
    required this.opponents,
    this.lobbyRepository,
    this.remoteStart,
  });
  final ScorerLobbyRepository? lobbyRepository;
  final Future<bool> Function(ScorerSettings settings)? remoteStart;
  final AccountUser? account;
  final ScorerOpponents opponents;
  final BotSettingsStorage? botStorage;
  @override
  State<ScorerSetupPage> createState() => _ScorerSetupPageState();
}

class _ScorerSetupPageState extends State<ScorerSetupPage> {
  late final lobby = ScorerLobbyController(
    widget.lobbyRepository ?? ScorerLobbyRepository(),
  );
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
    lobby.addListener(_syncMembers);
    participants.first.name.text = widget.account?.displayName ?? 'Spieler 1';
    participants.first.accountId = widget.account?.id;
    if (widget.opponents != ScorerOpponents.players) {
      participants[1].bot = true;
      participants[1].name.text = 'Bot 1';
    }
    if (widget.opponents == ScorerOpponents.mixed) {
      participants.add(_ParticipantInput('Spieler 2'));
    }
    if (widget.opponents == ScorerOpponents.players) {
      settingsLoaded = true;
    } else {
      _loadBotSettings();
    }
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

  @override
  void dispose() {
    lobby.removeListener(_syncMembers);
    lobby.dispose();
    score.dispose();
    legs.dispose();
    sets.dispose();
    for (final p in participants) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _start() async {
    if (loading || lobby.busy) return;
    if (!form.currentState!.validate()) return;
    final humanNames = participants
        .where((p) => !p.bot)
        .expand(
          (p) => p.teamMembers.isEmpty ? [p.name.text.trim()] : p.teamMembers,
        )
        .map((name) => name.toLowerCase())
        .toList();
    if (humanNames.toSet().length != humanNames.length) {
      setState(
        () => error =
            'Ein Spieler darf nur einem Teilnehmer oder Doppelteam zugeordnet sein. Bitte doppelte Namen prüfen.',
      );
      return;
    }
    // ListView can unmount fields outside its viewport; validate the full draft.
    final inputErrors = [
      _number(score.text),
      _number(legs.text, odd: true),
      _number(sets.text, odd: true),
      for (final p in participants) ...[
        p.name.text.trim().isEmpty
            ? 'Für alle Teilnehmer einen Namen eingeben.'
            : null,
        _number(p.score.text, optional: true),
        if (p.bot &&
            p.useTheo &&
            TheoAverageService.parse(p.average.text) == null)
          'Für jeden Bot einen gültigen Theo-Average eingeben.',
      ],
    ].whereType<String>();
    if (inputErrors.isNotEmpty) {
      setState(() => error = inputErrors.first);
      return;
    }
    if (!widget.opponents.accepts(
      participants.where((p) => !p.bot).length,
      participants.where((p) => p.bot).length,
    )) {
      setState(() => error = widget.opponents.requirement);
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await lobby.close();
      if (!mounted) return;
      if (!widget.opponents.accepts(
        participants.where((p) => !p.bot).length,
        participants.where((p) => p.bot).length,
      )) {
        throw StateError(widget.opponents.requirement);
      }
      final tuning = widget.opponents == ScorerOpponents.players
          ? const BotSettings()
          : await botStorage.load();
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
            p.teamMembers.isEmpty
                ? p.name.text.trim()
                : p.teamMembers.join(' / '),
            accountId: p.accountId,
            startScore: int.tryParse(p.score.text),
            bot: profile,
            members: p.teamMembers,
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
      final profilePlayer = widget.account == null ? null : 0;
      if (widget.remoteStart != null) {
        final accepted = await widget.remoteStart!(settings);
        if (!mounted) return;
        if (accepted) {
          Navigator.of(context).pop();
        } else {
          setState(
            () => error =
                'Das Hauptgerät hat den Spielstart nicht bestätigt. Verbindung und laufende Partie prüfen.',
          );
        }
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ScorerMatchPage(
            settings: settings,
            accountId: profilePlayer != null && profilePlayer >= 0
                ? widget.account!.id
                : null,
            profilePlayerIndex: profilePlayer != null && profilePlayer >= 0
                ? profilePlayer
                : null,
          ),
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
    appBar: AppBar(title: Text(widget.opponents.label)),
    body: AbsorbPointer(
      absorbing: loading,
      child: Form(
        key: form,
        child: AdaptiveContentList(
          padding: const EdgeInsets.all(24),
          children: [
            if (!settingsLoaded && error != null)
              TextButton(
                onPressed: _loadBotSettings,
                child: const Text('Einstellungen erneut laden'),
              ),
            const SizedBox(height: 16),
            SportFormSection(
              title: 'X01 einrichten',
              description:
                  'Lege Punkte und Spielregeln fest. Best of 5 bedeutet: drei Siege zum Gewinn.',
              children: [
                TextFormField(
                  controller: score,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Startpunkte'),
                  validator: _number,
                ),
                DropdownButtonFormField<StartRequirement>(
                  isExpanded: true,
                  isDense: false,
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
                  isExpanded: true,
                  isDense: false,
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
                    helperMaxLines: 3,
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
              ],
            ),
            const SizedBox(height: 24),
            Text('Teilnehmer', style: Theme.of(context).textTheme.titleLarge),
            if (widget.opponents != ScorerOpponents.bots)
              ScorerLobbyPanel(controller: lobby),
            for (var i = 0; i < participants.length; i++) _participant(i),
            Wrap(
              spacing: 12,
              children: [
                if (widget.opponents != ScorerOpponents.bots)
                  TextButton.icon(
                    onPressed: () => _addParticipant(false),
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('Spieler hinzufügen'),
                  ),
                if (widget.opponents != ScorerOpponents.players)
                  TextButton.icon(
                    onPressed: () => _addParticipant(true),
                    icon: const Icon(Icons.smart_toy_outlined),
                    label: const Text('Bot hinzufügen'),
                  ),
              ],
            ),
            DropdownButtonFormField<int>(
              isExpanded: true,
              isDense: false,
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
              onPressed: loading || !settingsLoaded || lobby.busy
                  ? null
                  : _start,
              icon: const Icon(Icons.play_arrow),
              label: Text(loading ? 'Spiel wird geöffnet …' : 'Spiel starten'),
            ),
          ],
        ),
      ),
    ),
  );

  void _syncMembers() {
    if (!mounted) return;
    setState(() {
      if (lobby.lobby == null) return;
      final members = lobby.lobby!.members;
      final starting = participants[starter];
      for (final p in participants.skip(1).toList()) {
        if (p.accountId != null && !members.any((m) => m.id == p.accountId)) {
          participants.remove(p);
          p.dispose();
        }
      }
      for (final member in members) {
        if (!participants.any((p) => p.accountId == member.id)) {
          participants.add(
            _ParticipantInput(member.name)..accountId = member.id,
          );
        }
      }
      starter = participants.indexOf(starting);
      if (starter < 0) starter = 0;
    });
  }

  void _addParticipant(bool bot) {
    setState(() {
      final p = _ParticipantInput(
        bot
            ? 'Bot ${participants.where((p) => p.bot).length + 1}'
            : 'Spieler ${participants.where((p) => !p.bot).length + 1}',
      );
      p.bot = bot;
      p.skill = botSettings.skill.toDouble();
      p.finish = botSettings.finishingSkill.toDouble();
      p.average.text = botSettings.theoAverage.toString();
      p.useTheo = botSettings.useTheoAverage;
      participants.add(p);
    });
  }

  Widget _participant(int index) {
    final p = participants[index];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: p.name,
              readOnly: p.accountId != null,
              decoration: InputDecoration(
                labelText: 'Teilnehmer ${index + 1} · Name',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name eingeben.' : null,
            ),
            if (p.accountId != null) const Text('Mit Konto angemeldet'),
            if (!p.bot) ...[
              if (p.teamMembers.isNotEmpty)
                Text('Doppel: ${p.teamMembers.join(' / ')}'),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: loading
                        ? null
                        : () async {
                            final members = await showDialog<List<String>>(
                              context: context,
                              builder: (_) => ScorerDoublesDialog(
                                first: p.name.text,
                                second: p.partners.text,
                                lockFirst: p.accountId != null,
                                allowCommunity: widget.account != null,
                              ),
                            );
                            if (!mounted || members == null) return;
                            setState(() {
                              p.name.text = members[0];
                              p.partners.text = members[1];
                            });
                          },
                    icon: const Icon(Icons.group_add_outlined),
                    label: Text(
                      p.teamMembers.isEmpty
                          ? 'Doppelteam erstellen'
                          : 'Doppelteam bearbeiten',
                    ),
                  ),
                  if (p.teamMembers.isNotEmpty)
                    TextButton(
                      onPressed: loading
                          ? null
                          : () => setState(p.partners.clear),
                      child: const Text('Als Einzelspieler spielen'),
                    ),
                ],
              ),
            ],
            TextFormField(
              controller: p.score,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Eigene Startpunkte (optional)',
                helperText: 'Leer = gemeinsame Startpunkte',
                helperMaxLines: 3,
              ),
              validator: (v) => _number(v, optional: true),
            ),
            if (p.bot && p.useTheo)
              TheoAverageInput(controller: p.average, enabled: !loading),
            if (p.bot && !p.useTheo)
              const Text(
                'Die manuell gespeicherte Bot-Stärke wird verwendet. Theo-Average kann in den Einstellungen aktiviert werden.',
              ),
            if (index > 0)
              TextButton(
                onPressed: loading
                    ? null
                    : p.accountId != null && lobby.lobby?.open == true
                    ? () => lobby.remove(p.accountId!)
                    : () => setState(() {
                        if (starter > index) starter--;
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
  final partners = TextEditingController();
  List<String> get teamMembers {
    final others = partners.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return others.isEmpty ? const [] : [name.text.trim(), ...others];
  }

  final score = TextEditingController();
  final average = TextEditingController(text: '60');
  bool useTheo = true;
  bool bot = false;
  String? accountId;
  double skill = 500, finish = 500;
  void dispose() {
    name.dispose();
    partners.dispose();
    score.dispose();
    average.dispose();
  }
}
