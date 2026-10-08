import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_permissions.dart';
import 'package:dart_tournament_manager/features/communities/domain/community.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_access.dart';
import 'package:dart_tournament_manager/features/tournaments/presentation/widgets/creation/tournament_access_editor.dart';
import 'package:dart_tournament_manager/features/tournaments/presentation/widgets/run/stage_controls.dart';
import 'package:dart_tournament_manager/features/tournaments/presentation/widgets/tournament_access_gate.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'package:dart_tournament_manager/features/tournaments/presentation/widgets/run/result_entry.dart';

void main() {
  const font = String.fromEnvironment('LAYOUT_PREVIEW_FONT');
  setUpAll(() async {
    if (font.isNotEmpty) {
      await (FontLoader('Roboto')..addFont(File(font).readAsBytes().then(ByteData.sublistView))).load();
      await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  const settings = TournamentAccessSettings(creatorUserId: 'creator',
    directorUserIds: ['director'], resultEntryMode: ResultEntryMode.selected,
    resultUserIds: ['reporter']);
  TournamentAccess resolve(String? user, {bool member = true, List<String> rights = const []}) =>
    TournamentAccess.resolve(settings, user, CommunityPermissions(rights), isMember: member);
  test('creator, assigned leadership, reporter and spectator are distinct', () {
    expect(resolve('creator').canConfigure, isTrue);
    expect(resolve('creator').canLead, isTrue);
    expect(resolve('director').canLead, isTrue);
    expect(resolve('director').canConfigure, isFalse);
    expect(resolve('reporter').canEnterResults, isTrue);
    expect(resolve('reporter').canLead, isFalse);
    expect(resolve('viewer').canEnterResults, isFalse);
    expect(resolve(null).canLead, isFalse);
    expect(resolve('creator', member: false).canLead, isFalse);
    expect(resolve('director', member: false).canLead, isFalse);
    expect(resolve('role', rights: ['lead_tournaments']).canLead, isTrue);
    expect(resolve('editor', rights: ['edit_tournaments']).canLead, isFalse);
  });
  test('legacy permissions fail closed and settings round trip', () {
    final old = TournamentAccessSettings.fromJson(null);
    expect(old.resultEntryMode, ResultEntryMode.directors);
    expect(old.directorUserIds, isEmpty);
    expect(TournamentAccessSettings.fromJson(settings.toJson()).toJson(), settings.toJson());
    final all = TournamentAccessSettings.fromJson({...settings.toJson(), 'resultEntryMode': 'members'});
    expect(TournamentAccess.resolve(all, 'viewer', CommunityPermissions([]), isMember: true).canEnterResults, isTrue);
    expect(TournamentAccess.resolve(all, 'outsider', CommunityPermissions([]), isMember: false).canEnterResults, isFalse);
  });
  testWidgets('permission gate never mounts run state before authorization', (tester) async {
    final pending = Completer<TournamentAccess>();
    final tournament = CreatedTournament(name: 'Club', communityId: 'club', players: [], stages: [], runStages: []);
    var mounted = 0;
    await tester.pumpWidget(MaterialApp(home: TournamentAccessGate(tournament: tournament,
      load: () => pending.future, builder: (_, rights) {
        mounted++;
        return Text(rights.canLead ? 'Leitung' : 'Zuschauer');
      })));
    expect(mounted, 0);
    pending.complete(const TournamentAccess());
    await tester.pumpAndSettle();
    expect(find.text('Zuschauer'), findsOneWidget);
    expect(find.text('Leitung'), findsNothing);
  });
  testWidgets('reporters cannot clear or annul a game in the result dialog', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ResultDialog(
      match: GroupMatch(homePlayer: TournamentPlayer.generated(1), awayPlayer: TournamentPlayer.generated(2), round: 1),
      allowAdministration: false)));
    expect(find.textContaining('Annull'), findsNothing);
    expect(find.textContaining('zurücksetzen'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final size in [const Size(360,800), const Size(800,600), const Size(1440,900)]) {
    for (final scale in [1.0,2.0]) {
      testWidgets('access editor and spectator navigation $size/$scale', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var value = settings;
        final boundary = GlobalKey();
        await tester.pumpWidget(MaterialApp(home: MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(key: boundary, child: Scaffold(body: SingleChildScrollView(child: StatefulBuilder(builder: (context, update) => Column(children: [
            StageViewModeSwitch(selectedMode: StageViewMode.overview, canLead: false, onModeChanged: (_) {}),
            Padding(padding: const EdgeInsets.all(16), child: TournamentAccessEditor(communityId: 'club', value: value,
              onChanged: (next) => update(() => value = next),
              loadMembers: () async => [CommunityMember(userId: 'director', displayName: 'Mitglied mit einem sehr langen deutschen Namen', role: 'member', joinedAt: DateTime(2026))])),
          ]))))))));
        await tester.pumpAndSettle();
        expect(find.text('Turnierleitung'), findsNothing);
        expect(find.text('Order of Play'), findsNothing);
        expect(find.text('Turnierrechte'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (font.isNotEmpty) {
          await tester.runAsync(() async {
            final image = await (boundary.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();
            final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File('build/layout_previews/access_${size.width}_$scale.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.ensureVisible(find.text('Zusätzliche Turnierleitung'));
        await tester.tap(find.text('Zusätzliche Turnierleitung'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(CheckboxListTile).first);
        await tester.tap(find.byType(CheckboxListTile).first);
        await tester.pumpAndSettle();
        expect(value.directorUserIds, isEmpty);
        expect(value.resultUserIds, ['reporter']);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
