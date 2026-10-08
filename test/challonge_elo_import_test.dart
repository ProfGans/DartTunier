import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/communities/domain/challonge_tournament.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_elo.dart';
import 'package:dart_tournament_manager/features/communities/application/challonge_import_service.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'challonge_import_test.dart' show challongeFixture, member;

void main() {
  final members = [
    member('Anna', 'a'),
    member('Ben', 'b'),
    member('Clara', 'c'),
  ];
  test('import option affects only the selected Elo ranking and persists', () {
    final source = ChallongeTournament(challongeFixture());
    final plain = source.convert('club', {'1': 'a', '2': 'b', '3': 'c'});
    final ranked = source.convert(
      'club',
      {'1': 'a', '2': 'b', '3': 'c'},
      countsForRanking: true,
      rankingIds: ['season', 'season'],
    );
    final restored = CreatedTournament.fromJson(ranked.toJson());
    expect(restored.communityRankingIds, ['season']);
    final calculator = const CommunityEloCalculator();
    expect(
      calculator
          .calculate(
            members: members,
            tournaments: [plain],
            currentYearOnly: false,
          )
          .entries,
      isEmpty,
    );
    expect(
      calculator
          .calculate(
            members: members,
            tournaments: [restored],
            currentYearOnly: false,
          )
          .entries,
      isEmpty,
    );
    final elo = calculator.calculate(
      members: members,
      tournaments: [restored, restored],
      currentYearOnly: false,
      rankingId: 'season',
    );
    expect(elo.entries.map((e) => e.rating), [1016, 984]);
    expect(elo.entries.map((e) => e.matches), [1, 1]);
  });
  test(
    'service carries Elo selection and empty selection causes no writes',
    () async {
      final saved = <CreatedTournament>[];
      var created = 0;
      final service = ChallongeImportService(
        loadMembers: () async => members,
        createMember: (name) async {
          created++;
          return member(name, 'new');
        },
        loadTournaments: () async => saved,
        saveTournament: (t) async => saved.add(t),
      );
      final sources = [ChallongeTournament(challongeFixture())];
      await expectLater(
        service.import('club', sources, countsForRanking: true),
        throwsFormatException,
      );
      expect(saved, isEmpty);
      expect(created, 0);
      await service.import(
        'club',
        sources,
        countsForRanking: true,
        rankingIds: ['default'],
      );
      expect(saved.single.countsForRanking, isTrue);
      expect(saved.single.communityRankingIds, ['default']);
      expect(
        await service.import(
          'club',
          sources,
          countsForRanking: true,
          rankingIds: ['default'],
        ),
        0,
      );
    },
  );
  test(
    'groups are replayed before knockout with stable order without match timestamps',
    () {
      final data = challongeFixture();
      final list = ChallongeTournament.unwrap(data['matches'] as List, 'match');
      list[1] = {...list[0], 'id': 100, 'group_id': 'A'};
      list[2] = {...list[0], 'id': 101, 'group_id': 'A'};
      data['matches'] = list;
      final source = ChallongeTournament(data);
      final converted = source.convert(
        'club',
        {'1': 'a', '2': 'b', '3': 'c'},
        countsForRanking: true,
        rankingIds: ['default'],
      );
      final matches = (converted.runStages.single as GroupTournamentRunStage)
          .groups
          .single
          .matches;
      expect(matches.map((m) => m.label), [
        'Challonge ${list[1]['identifier'] ?? 100}',
        'Challonge ${list[2]['identifier'] ?? 101}',
        'Challonge ${list[0]['identifier'] ?? list[0]['id']}',
      ]);
    },
  );
}
