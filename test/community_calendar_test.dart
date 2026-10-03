import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_tournament_manager/features/community_calendar/data/community_calendar_repository.dart';
import 'package:dart_tournament_manager/features/community_calendar/domain/community_calendar.dart';
import 'package:dart_tournament_manager/features/community_calendar/presentation/community_calendar_page.dart';
import 'package:dart_tournament_manager/features/community_calendar/presentation/calendar_event_editor.dart';
import 'package:dart_tournament_manager/features/community_calendar/presentation/calendar_month_view.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_permissions.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';

class CalendarTestRepository extends CommunityCalendarRepository {
  CalendarTestRepository({this.appointment = false});
  final bool appointment;
  final saved = <CommunityCalendarEvent>[];
  final savedPresets = <CalendarPreset>[];
  final remindersById = <String, int>{};
  bool? created;
  CommunityCalendarEvent get example => CommunityCalendarEvent(
    id: 'event',
    communityId: 'club',
    title: appointment
        ? 'Gemeinsames Training'
        : 'Vereinsmeisterschaft am Wochenende',
    isTournament: !appointment,
    startsAt: DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      23,
      59,
    ),
    location: 'Vereinsheim',
    notes: 'Bitte zehn Minuten vor Beginn da sein.',
    settings: const CommunityTournamentPreset(
      boardCount: 4,
      countsForRanking: false,
    ),
  );
  @override
  Future<List<CommunityCalendarEvent>> events(String id) async => [
    example,
    ...saved,
  ];
  @override
  Future<List<CalendarPreset>> presets(String id) async => savedPresets;
  @override
  Future<Map<String, int>> reminders(String id) async => remindersById;
  @override
  Future<void> setReminder(CommunityCalendarEvent event, int? minutes) async {
    if (minutes == null) {
      remindersById.remove(event.id);
    } else {
      remindersById[event.id] = minutes;
    }
  }

  @override
  Future<CommunityCalendarEvent> save(
    CommunityCalendarEvent event, {
    bool create = false,
  }) async {
    saved.add(event);
    created = create;
    return event;
  }

  @override
  Future<void> savePreset(
    String id,
    String name,
    CommunityTournamentPreset settings,
  ) async {
    savedPresets.add(
      CalendarPreset(id: 'preset', name: name, settings: settings),
    );
  }
}

class CalendarPreview extends StatelessWidget {
  const CalendarPreview({super.key});
  @override
  Widget build(BuildContext context) => CommunityCalendarPage(
    communityId: 'club',
    communityName: 'Dartverein',
    repository: CalendarTestRepository(),
    loadPermissions: () async =>
        CommunityPermissions(CommunityPermission.values.map((p) => p.key)),
  );
}

class AppointmentEditorPreview extends StatelessWidget {
  const AppointmentEditorPreview({super.key});
  @override
  Widget build(BuildContext context) => CalendarEventEditor(
    communityId: 'club',
    repository: CalendarTestRepository(),
    presets: const [],
    isTournament: false,
    initialDate: DateTime(2026, 10, 10),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'appointment metadata round trips and legacy events stay tournaments',
    () {
      final event = CalendarTestRepository(appointment: true).example;
      final json = event.toJson();
      expect((json['settings'] as Map)['playerCount'], isNull);
      final restored = CommunityCalendarEvent.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );
      expect(restored.isTournament, isFalse);
      expect(restored.notes, event.notes);
      expect(restored.startsAt, event.startsAt);
      final legacy = {
        ...json,
        'settings': const CommunityTournamentPreset().toJson(),
      };
      expect(CommunityCalendarEvent.fromJson(legacy).isTournament, isTrue);
      expect(
        () => CommunityCalendarEvent.fromJson({
          ...json,
          'settings': {'version': 1, 'calendarVersion': 99},
        }),
        throwsFormatException,
      );
    },
  );
  for (final copy in [false, true]) {
    testWidgets('appointment edit/copy preserves kind, copy=$copy', (
      tester,
    ) async {
      final repo = CalendarTestRepository(appointment: true);
      await tester.pumpWidget(
        MaterialApp(
          home: CalendarEventEditor(
            communityId: 'club',
            repository: repo,
            presets: [],
            event: repo.example,
            copy: copy,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Turniereinstellungen'), findsNothing);
      expect(find.text('Einstellungen als Vorlage speichern'), findsNothing);
      await tester.enterText(
        find.byType(TextFormField).first,
        'Vereinsbesprechung',
      );
      await tester.scrollUntilVisible(
        find.text('Termin speichern').hitTestable(),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Termin speichern'));
      await tester.pumpAndSettle();
      expect(repo.saved.single.isTournament, isFalse);
      expect(repo.saved.single.title, 'Vereinsbesprechung');
      expect(repo.created, copy);
    });
  }
  testWidgets(
    'new free appointment saves date and description without tournament settings',
    (tester) async {
      final repo = CalendarTestRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: CalendarEventEditor(
            communityId: 'club',
            repository: repo,
            presets: [],
            isTournament: false,
            initialDate: DateTime(2026, 10, 12),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Training');
      await tester.enterText(find.byType(TextFormField).at(1), 'Vereinsheim');
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'Alle sind willkommen.',
      );
      await tester.scrollUntilVisible(
        find.text('Termin speichern').hitTestable(),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Termin speichern'));
      await tester.pumpAndSettle();
      final saved = repo.saved.single;
      expect(saved.isTournament, isFalse);
      expect(saved.startsAt, DateTime(2026, 10, 12, 18));
      expect(saved.location, 'Vereinsheim');
      expect(saved.notes, 'Alle sind willkommen.');
      expect(repo.created, isTrue);
    },
  );
  testWidgets('month grid aligns weekdays and includes leap day', (
    tester,
  ) async {
    DateTime? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CalendarMonthView(
              month: DateTime(2024, 2),
              events: const [],
              selectedDay: null,
              onDaySelected: (day) => selected = day,
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('calendar-day-29')), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-day-30')), findsNothing);
    expect(
      tester.getCenter(find.text('Do')).dx,
      tester.getCenter(find.byKey(const ValueKey('calendar-day-1'))).dx,
    );
    await tester.tap(find.byKey(const ValueKey('calendar-day-29')));
    expect(selected, DateTime(2024, 2, 29));
  });
  testWidgets('day selection filters agenda and month navigation clears it', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CalendarPreview()));
    await tester.pumpAndSettle();
    final emptyDay = DateTime.now().day == 1 ? 2 : 1;
    await tester.ensureVisible(find.byKey(ValueKey('calendar-day-$emptyDay')));
    await tester.tap(find.byKey(ValueKey('calendar-day-$emptyDay')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Keine Termine an diesem Tag.'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Keine Termine an diesem Tag.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Alle Termine im Monat').hitTestable(),
      -100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alle Termine im Monat'));
    await tester.pumpAndSettle();
    expect(find.text('Keine Termine an diesem Tag.'), findsNothing);
    await tester.scrollUntilVisible(
      find.byTooltip('Nächster Monat').hitTestable(),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Nächster Monat'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CalendarMonthView>(find.byType(CalendarMonthView)).month,
      DateTime(DateTime.now().year, DateTime.now().month + 1),
    );
    expect(
      tester
          .widget<CalendarMonthView>(find.byType(CalendarMonthView))
          .selectedDay,
      isNull,
    );
  });
  test(
    'preset contains configuration but no participants, results or assignments',
    () {
      final tournament = CreatedTournament(
        name: 'Original',
        players: [
          const TournamentPlayer(
            name: 'Alice',
            profileId: 'a',
            isGenerated: false,
          ),
        ],
        stages: [
          TournamentStage(
            name: 'Finale',
            type: 'single_knockout',
            gameFormat: const TournamentGameFormat(
              x01Score: 301,
              bestOfLegs: 5,
            ),
          ),
        ],
        runStages: [],
        boardCount: 4,
        countsForRanking: true,
        communityRankingIds: ['training'],
      );
      final json = CommunityTournamentPreset.fromTournament(
        tournament,
      ).toJson();
      final copy = CommunityTournamentPreset.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );
      expect(copy.boardCount, 4);
      expect(copy.gameFormat.x01Score, 301);
      expect(copy.gameFormat.bestOfLegs, 5);
      expect(copy.rankingIds, ['training']);
      expect(json.containsKey('players'), isFalse);
      expect(json.containsKey('runStages'), isFalse);
      expect(json.containsKey('id'), isFalse);
      expect(
        () => CommunityTournamentPreset.fromJson({'version': 99}),
        throwsFormatException,
      );
    },
  );
  test('dates serialize as UTC and reminders use the correct instant', () {
    final event = CommunityCalendarEvent(
      id: 'e',
      communityId: 'c',
      title: 'Cup',
      startsAt: DateTime.parse('2026-10-25T18:30:00+01:00'),
    );
    expect(event.toJson()['starts_at'], '2026-10-25T17:30:00.000Z');
    expect(event.reminderAt(60).toUtc(), DateTime.utc(2026, 10, 25, 16, 30));
    expect(
      CommunityCalendarEvent.fromJson(event.toJson()).startsAt.toUtc(),
      event.startsAt.toUtc(),
    );
  });
  testWidgets(
    'copy saves a new date and reuses settings without modifying original',
    (tester) async {
      final repo = CalendarTestRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: CalendarEventEditor(
            communityId: 'club',
            repository: repo,
            presets: [],
            event: repo.example,
            copy: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Einstellungen als Vorlage speichern'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text('Einstellungen als Vorlage speichern')),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Einstellungen als Vorlage speichern'));
      await tester.pumpAndSettle();
      expect(repo.savedPresets.single.settings.boardCount, 4);
      await tester.tap(find.text('Termin speichern'));
      await tester.pumpAndSettle();
      expect(repo.created, isTrue);
      expect(repo.saved.single.startsAt, isNot(repo.example.startsAt));
      expect(repo.saved.single.settings.boardCount, 4);
    },
  );
  testWidgets('members may opt in to reminders without event editing rights', (
    tester,
  ) async {
    final repo = CalendarTestRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityCalendarPage(
          communityId: 'club',
          communityName: 'Club',
          repository: repo,
          loadPermissions: () async => CommunityPermissions([]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Turnier eintragen'), findsNothing);
    expect(find.text('Termin eintragen'), findsNothing);
    expect(find.text('Bearbeiten'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Erinnerung').hitTestable(),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Erinnerung'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 Stunde vorher'));
    await tester.pumpAndSettle();
    expect(repo.remindersById['event'], 60);
  });
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('calendar and editor at $size with large text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Widget app(Widget page) => MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: page,
      );
      await tester.pumpWidget(app(const CalendarPreview()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Turnier eintragen'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Termin speichern'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(app(const AppointmentEditorPreview()));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Termin speichern').hitTestable(),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
