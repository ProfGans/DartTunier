import 'package:flutter/material.dart';
import 'calendar_labels.dart';
import 'calendar_month_view.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../../communities/domain/community_permissions.dart';
import '../../notifications/presentation/push_device_menu.dart';
import '../data/community_calendar_repository.dart';
import '../domain/community_calendar.dart';
import 'calendar_event_editor.dart';

class CommunityCalendarPage extends StatefulWidget {
  const CommunityCalendarPage({
    super.key,
    required this.communityId,
    required this.communityName,
    required this.loadPermissions,
    this.createTournament,
    this.repository,
  });
  final String communityId, communityName;
  final Future<CommunityPermissions> Function() loadPermissions;
  final Widget Function(CommunityTournamentPreset settings, String title)?
  createTournament;
  final CommunityCalendarRepository? repository;
  @override
  State<CommunityCalendarPage> createState() => _CommunityCalendarPageState();
}

class _CommunityCalendarPageState extends State<CommunityCalendarPage> {
  late final _repository = widget.repository ?? CommunityCalendarRepository();
  late Future<void> _future = _load();
  List<CommunityCalendarEvent> _events = [];
  List<CalendarPreset> _presets = [];
  Map<String, int> _reminders = {};
  CommunityPermissions _rights = CommunityPermissions([]);
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;
  void _changeMonth(DateTime month) => setState(() {
    _month = month;
    _selectedDay = null;
  });
  final Set<String> _busy = {};
  Future<void> _load() async {
    final rights = await widget.loadPermissions();
    final events = await _repository.events(widget.communityId);
    final presets = await _repository.presets(widget.communityId);
    final reminders = await _repository.reminders(widget.communityId);
    _rights = rights;
    _events = events..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    _presets = presets;
    _reminders = reminders;
  }

  void _reload() => setState(() => _future = _load());
  Future<void> _edit({
    CommunityCalendarEvent? event,
    bool copy = false,
    bool isTournament = true,
  }) async {
    final saved = await Navigator.of(context).push<CommunityCalendarEvent>(
      MaterialPageRoute(
        builder: (_) => CalendarEventEditor(
          communityId: widget.communityId,
          repository: _repository,
          presets: _presets,
          event: event,
          copy: copy,
          isTournament: isTournament,
          initialDate: _selectedDay,
          canSavePreset: _rights.allows(CommunityPermission.createTournaments),
        ),
      ),
    );
    if (mounted) {
      if (saved != null) {
        _month = DateTime(saved.startsAt.year, saved.startsAt.month);
        _selectedDay = DateUtils.dateOnly(saved.startsAt);
      }
      _reload();
    }
  }

  Future<void> _remind(CommunityCalendarEvent event) async {
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Meine Erinnerung'),
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Push geht an deine registrierten Android-Geräte. Aktiviere dort den Push-Empfang.',
            ),
          ),
          for (final entry in {
            -1: 'Keine Erinnerung',
            0: 'Zum Beginn',
            15: '15 Minuten vorher',
            30: '30 Minuten vorher',
            60: '1 Stunde vorher',
            120: '2 Stunden vorher',
            1440: '1 Tag vorher',
            10080: '1 Woche vorher',
          }.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, entry.key),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(entry.value),
              ),
            ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _busy.add(event.id));
    try {
      await _repository.setReminder(event, selected < 0 ? null : selected);
      if (!mounted) return;
      setState(() {
        if (selected < 0) {
          _reminders.remove(event.id);
        } else {
          _reminders[event.id] = selected;
        }
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Erinnerung konnte nicht gespeichert werden. Bitte Verbindung prüfen.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(event.id));
    }
  }

  Future<void> _delete(CommunityCalendarEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Termin löschen?'),
        content: Text(
          '${event.title}\nZugehörige Erinnerungen werden ebenfalls entfernt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _repository.delete(event);
      if (mounted) _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Termin konnte nicht gelöscht werden.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Kalender · ${widget.communityName}')),
    body: FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return AdaptiveContentList(
            children: [
              const Text('Kalender konnte nicht geladen werden.'),
              FilledButton(
                onPressed: _reload,
                child: const Text('Erneut versuchen'),
              ),
            ],
          );
        }
        final events = _events
            .where(
              (e) =>
                  e.startsAt.year == _month.year &&
                  e.startsAt.month == _month.month,
            )
            .toList();
        final visibleEvents = _selectedDay == null
            ? events
            : events
                  .where(
                    (event) =>
                        DateUtils.isSameDay(event.startsAt, _selectedDay),
                  )
                  .toList();
        return AdaptiveContentList(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Vorheriger Monat',
                  onPressed: () =>
                      _changeMonth(DateTime(_month.year, _month.month - 1)),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  calendarMonthLabel(_month),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  tooltip: 'Nächster Monat',
                  onPressed: () =>
                      _changeMonth(DateTime(_month.year, _month.month + 1)),
                  icon: const Icon(Icons.chevron_right),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    final now = DateTime.now();
                    _month = DateTime(now.year, now.month);
                    _selectedDay = DateUtils.dateOnly(now);
                  }),
                  child: const Text('Heute'),
                ),
                IconButton(
                  tooltip: 'Kalender aktualisieren',
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (_rights.allows(CommunityPermission.createTournaments))
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => _edit(),
                    icon: const Icon(Icons.add),
                    label: const Text('Turnier eintragen'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _edit(isTournament: false),
                    icon: const Icon(Icons.event_outlined),
                    label: const Text('Termin eintragen'),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Text(
              '${_presets.length} gespeicherte Vorlagen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(
              'Beim Eintragen kannst du eine Vorlage übernehmen. Über „Kopieren“ erhält ein vorhandener Termin ein neues Datum.',
            ),
            const SizedBox(height: 16),
            CalendarMonthView(
              month: _month,
              events: events,
              selectedDay: _selectedDay,
              onDaySelected: (day) => setState(() => _selectedDay = day),
            ),
            const Text(
              'Tag auswählen, um seine Termine anzuzeigen. Die Markierung zeigt die Anzahl der Termine.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _selectedDay == null
                      ? 'Termine im Monat'
                      : 'Termine am ${_selectedDay!.day}.${_selectedDay!.month}.${_selectedDay!.year}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (_selectedDay != null)
                  TextButton(
                    onPressed: () => setState(() => _selectedDay = null),
                    child: const Text('Alle Termine im Monat'),
                  ),
              ],
            ),
            if (visibleEvents.isEmpty)
              Text(
                _selectedDay == null
                    ? 'Keine Termine in diesem Monat.'
                    : 'Keine Termine an diesem Tag.',
              ),
            for (final event in visibleEvents)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(calendarDateTimeLabel(event.startsAt)),
                      Text(event.isTournament ? 'Turnier' : 'Termin'),
                      Text(
                        event.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (event.location.isNotEmpty) Text(event.location),
                      if (event.notes.isNotEmpty) Text(event.notes),
                      if (event.isTournament)
                        Text(
                          '${event.settings.playerCount} Spieler geplant · ${event.settings.boardCount} Boards',
                        ),
                      if (event.isTournament)
                        Text(event.settings.gameFormat.label),
                      if (_reminders[event.id] case final int minutes)
                        Text(
                          'Meine Erinnerung: ${minutes == 0 ? 'zum Beginn' : '$minutes Minuten vorher'}',
                        ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (event.startsAt.isAfter(DateTime.now()))
                            TextButton.icon(
                              onPressed: _busy.contains(event.id)
                                  ? null
                                  : () => _remind(event),
                              icon: const Icon(Icons.notifications_outlined),
                              label: const Text('Erinnerung'),
                            ),
                          if (_rights.allows(
                            CommunityPermission.createTournaments,
                          ))
                            TextButton(
                              onPressed: () => _edit(event: event, copy: true),
                              child: const Text('Kopieren'),
                            ),
                          if (_rights.allows(
                            CommunityPermission.editTournaments,
                          ))
                            TextButton(
                              onPressed: () => _edit(event: event),
                              child: const Text('Bearbeiten'),
                            ),
                          if (event.isTournament &&
                              _rights.allows(
                                CommunityPermission.createTournaments,
                              ) &&
                              widget.createTournament != null)
                            TextButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => widget.createTournament!(
                                    event.settings,
                                    event.title,
                                  ),
                                ),
                              ),
                              child: const Text(
                                'Turnier aus Vorlage erstellen',
                              ),
                            ),
                          if (_rights.allows(
                            CommunityPermission.deleteTournaments,
                          ))
                            TextButton(
                              onPressed: () => _delete(event),
                              child: const Text('Löschen'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Erinnerungen werden für deinen Account gespeichert. Push-Empfang ist derzeit auf Android verfügbar; auf anderen Geräten kannst du Termine und Erinnerungen verwalten.',
            ),
            const PushDeviceMenu(),
          ],
        );
      },
    ),
  );
}
