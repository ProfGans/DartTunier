import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_ranking.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_elo.dart';
import 'package:dart_tournament_manager/features/communities/presentation/widgets/ranking_rules_dialog.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'community_tournament_elo_test.dart' show eloTournament, eloMembers;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    const font = String.fromEnvironment('LAYOUT_PREVIEW_FONT');
    if (font.isNotEmpty) {
      final loader = FontLoader('Roboto')..addFont(File(font).readAsBytes().then((b) => ByteData.sublistView(b)));
      await loader.load();
    }
  });
  test('calendar cutoff clamps month end and includes boundary', () {
    expect(rankingCutoff(DateTime(2026, 5, 31), 3), DateTime(2026, 2, 28));
    final t = eloTournament(completed: true);
    final match = (t.runStages.first as GroupTournamentRunStage).groups.first.matches.first;
    match.finishedAt = DateTime(2026, 7, 8);
    CommunityEloSnapshot calculate(DateTime date) => const CommunityEloCalculator().calculate(
      members: eloMembers, tournaments: [t], currentYearOnly: false, now: date, validityMonths: 3);
    expect(calculate(DateTime(2026, 10, 8)).entries.first.rating, 1016);
    expect(calculate(DateTime(2026, 10, 9)).entries, isEmpty);
    expect(match.homeLegs, 3);
    match.finishedAt = DateTime(2025, 12, 15);
    expect(const CommunityEloCalculator().calculate(members: eloMembers, tournaments: [t], currentYearOnly: true, now: DateTime(2026, 2, 1), validityMonths: 3).entries.first.rating, 1016);
  });
  for (final size in [const Size(360,800), const Size(800,600), const Size(1440,900)]) {
    testWidgets('rules dialog at $size with large text', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(builder: (_, child) => MediaQuery(data: MediaQueryData(size: size, textScaler: TextScaler.linear(2)), child: child!), home: const Scaffold(body: RankingRulesDialog(ranking: CommunityRanking(id: 'default', name: 'Standard-Rangliste', validityMonths: 3)))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('RANKING_PREVIEWS')) {
        final boundary = tester.firstRenderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary));
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('build/ranking-rules-${size.width.toInt()}.png').writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.enterText(find.byType(TextFormField), '0');
      await tester.ensureVisible(find.text('Speichern'));
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(find.text('Bitte 1 bis 120 Monate eingeben.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
