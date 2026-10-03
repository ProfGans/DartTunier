import 'package:flutter/material.dart';
import 'calendar_labels.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../../communities/presentation/widgets/community_ranking_picker.dart';
import '../../tournaments/domain/tournament_models.dart';
import '../data/community_calendar_repository.dart';
import '../domain/community_calendar.dart';

class CalendarEventEditor extends StatefulWidget {
  const CalendarEventEditor({
    super.key,
    required this.communityId,
    required this.repository,
    required this.presets,
    this.event,
    this.initialDate,
    this.copy = false,
    this.canSavePreset = true,
    this.isTournament = true,
  });
  final String communityId;
  final CommunityCalendarRepository repository;
  final List<CalendarPreset> presets;
  final CommunityCalendarEvent? event;
  final bool copy;
  final DateTime? initialDate;
  final bool canSavePreset;
  final bool isTournament;
  @override
  State<CalendarEventEditor> createState() => _CalendarEventEditorState();
}

class _CalendarEventEditorState extends State<CalendarEventEditor> {
  bool get _isTournament => widget.event?.isTournament ?? widget.isTournament;
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.event?.title);
  late final _location = TextEditingController(text: widget.event?.location);
  late final _notes = TextEditingController(text: widget.event?.notes);
  final _boards = TextEditingController(), _players = TextEditingController();
  final _score = TextEditingController(),
      _legs = TextEditingController(),
      _sets = TextEditingController();
  late DateTime _date = widget.copy || widget.event == null
      ? (widget.initialDate == null
            ? DateTime.now().add(const Duration(days: 1))
            : DateTime(
                widget.initialDate!.year,
                widget.initialDate!.month,
                widget.initialDate!.day,
                18,
              ))
      : widget.event!.startsAt;
  String _mode = 'groups', _checkout = 'double_out';
  bool _doubleIn = false, _ranked = true, _busy = false;
  List<String> _rankingIds = ['default'];
  @override
  void initState() {
    super.initState();
    _apply(widget.event?.settings ?? const CommunityTournamentPreset());
  }

  void _apply(CommunityTournamentPreset preset) {
    _boards.text = '${preset.boardCount}';
    _players.text = '${preset.playerCount}';
    _score.text = '${preset.gameFormat.x01Score}';
    _legs.text = '${preset.gameFormat.bestOfLegs}';
    _sets.text = '${preset.gameFormat.bestOfSets}';
    _mode = preset.stageType;
    _checkout = preset.gameFormat.checkoutType;
    _doubleIn = preset.gameFormat.doubleIn;
    _ranked = preset.countsForRanking;
    _rankingIds = [...preset.rankingIds];
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _location,
      _notes,
      _boards,
      _players,
      _score,
      _legs,
      _sets,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  CommunityTournamentPreset _settings() => CommunityTournamentPreset(
    boardCount: int.parse(_boards.text),
    playerCount: int.parse(_players.text),
    stageType: _mode,
    gameFormat: TournamentGameFormat(
      x01Score: int.parse(_score.text),
      bestOfLegs: int.parse(_legs.text),
      bestOfSets: int.parse(_sets.text),
      checkoutType: _checkout,
      doubleIn: _doubleIn,
    ),
    countsForRanking: _ranked,
    rankingIds: _rankingIds,
  );
  Future<void> _dateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (time == null || !mounted) return;
    setState(
      () => _date = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _save({bool preset = false}) async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (preset) {
        await widget.repository.savePreset(
          widget.communityId,
          _title.text,
          _settings(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Vorlage gespeichert. Der Termin kann jetzt gespeichert werden.',
              ),
            ),
          );
        }
      } else {
        final event = CommunityCalendarEvent(
          id: widget.event?.id ?? '',
          communityId: widget.communityId,
          title: _title.text,
          startsAt: _date,
          location: _location.text,
          notes: _notes.text,
          isTournament: _isTournament,
          settings: _isTournament
              ? _settings()
              : const CommunityTournamentPreset(),
        );
        final saved = await widget.repository.save(
          event,
          create: widget.event == null || widget.copy,
        );
        if (mounted) Navigator.pop(context, saved);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              preset
                  ? 'Vorlage konnte nicht gespeichert werden. Namen, Verbindung und Rechte prüfen.'
                  : 'Termin konnte nicht gespeichert werden. Verbindung und Rechte prüfen. Deine Eingaben bleiben erhalten.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _number(
    TextEditingController controller,
    String label,
    int min,
    int max, {
    bool odd = false,
  }) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      final n = int.tryParse(value ?? '');
      return n == null || n < min || n > max || (odd && n.isEven)
          ? '$min–$max${odd ? ', ungerade' : ''} eingeben.'
          : null;
    },
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.copy
            ? 'Termin kopieren'
            : widget.event == null
            ? (_isTournament ? 'Turnier eintragen' : 'Termin eintragen')
            : 'Termin bearbeiten',
      ),
    ),
    body: AbsorbPointer(
      absorbing: _busy,
      child: Form(
        key: _form,
        child: AdaptiveContentList(
          children: [
            if (_isTournament && widget.presets.isNotEmpty)
              DropdownButtonFormField<String>(
                isExpanded: true,
                itemHeight: null,
                decoration: const InputDecoration(
                  labelText: 'Vorlage übernehmen',
                ),
                items: [
                  for (final preset in widget.presets)
                    DropdownMenuItem(
                      value: preset.id,
                      child: Text(preset.name),
                    ),
                ],
                onChanged: (id) {
                  final preset = widget.presets.singleWhere((p) => p.id == id);
                  setState(() {
                    _apply(preset.settings);
                    _title.text = preset.name;
                  });
                },
              ),
            TextFormField(
              controller: _title,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: _isTournament
                    ? 'Turniername / Vorlagenname'
                    : 'Terminname',
              ),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Bitte einen Namen eingeben.'
                  : null,
            ),
            OutlinedButton.icon(
              onPressed: _dateTime,
              icon: const Icon(Icons.event),
              label: Text(calendarDateTimeLabel(_date)),
            ),
            const Text(
              'Datum und Uhrzeit werden in deiner lokalen Zeitzone angezeigt.',
            ),
            TextFormField(
              controller: _location,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Ort'),
            ),
            TextFormField(
              controller: _notes,
              maxLength: 1000,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: _isTournament ? 'Hinweise' : 'Beschreibung',
              ),
            ),
            const SizedBox(height: 16),
            if (_isTournament) ...[
              Text(
                'Turniereinstellungen',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                'Die Vorlage übernimmt Modus und Spielformat der ersten Etappe. Weitere Etappen und Teilnehmer legst du beim Erstellen des Turniers fest.',
              ),
              DropdownButtonFormField<String>(
                key: ValueKey('mode:$_mode'),
                initialValue: _mode,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Modus'),
                items: [
                  for (final type in {
                    'groups': 'Gruppen',
                    'single_knockout': 'Einfach-K.-o.',
                    'double_knockout': 'Doppel-K.-o.',
                    'triple_knockout': 'Dreifach-K.-o.',
                    'kratzer': 'Kratzer',
                  }.entries)
                    DropdownMenuItem(value: type.key, child: Text(type.value)),
                ],
                onChanged: (value) => setState(() => _mode = value!),
              ),
              _number(_players, 'Geplante Spielerzahl', 2, 256),
              _number(_boards, 'Boards', 1, 64),
              _number(_score, 'X01-Startpunkte', 2, 1001),
              _number(
                _legs,
                'Legs (gerade Anzahl erlaubt Unentschieden in Gruppen)',
                1,
                101,
              ),
              _number(_sets, 'Best of Sets', 1, 101, odd: true),
              DropdownButtonFormField<String>(
                key: ValueKey('checkout:$_checkout'),
                initialValue: _checkout,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Checkout'),
                items: [
                  for (final type in {
                    'double_out': 'Double Out',
                    'single_out': 'Single Out',
                    'master_out': 'Master Out',
                  }.entries)
                    DropdownMenuItem(value: type.key, child: Text(type.value)),
                ],
                onChanged: (value) => setState(() => _checkout = value!),
              ),
              SwitchListTile(
                title: const Text('Double In'),
                value: _doubleIn,
                onChanged: (value) => setState(() => _doubleIn = value),
              ),
              SwitchListTile(
                title: const Text('Zählt zur Rangliste'),
                value: _ranked,
                onChanged: (value) => setState(() => _ranked = value),
              ),
              if (_ranked)
                CommunityRankingPicker(
                  communityId: widget.communityId,
                  selectedIds: _rankingIds,
                  onChanged: (value) => setState(() => _rankingIds = value),
                ),
              const SizedBox(height: 16),
            ],
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _busy ? null : () => _save(),
                  child: const Text('Termin speichern'),
                ),
                if (_isTournament && widget.canSavePreset)
                  OutlinedButton(
                    onPressed: _busy ? null : () => _save(preset: true),
                    child: const Text('Einstellungen als Vorlage speichern'),
                  ),
              ],
            ),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    ),
  );
}
