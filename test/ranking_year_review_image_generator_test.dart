import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/rankings/application/ranking_year_review_image_generator.dart';
import 'package:dart_tournament_manager/features/rankings/application/ranking_year_review_service.dart';
import 'package:dart_tournament_manager/features/rankings/domain/local_ranking.dart';

void main() {
  testWidgets('RankingYearReviewImageGenerator produces valid PNG bytes', (tester) async {
    const ranking = LocalRanking(id: 'r1', name: 'DC Unzenberg Test 2026');
    final stats = RankingYearPlayerStats()
      ..participations = 10
      ..tournamentWins = 3
      ..legsWon = 45
      ..bestPerformances = 5
      ..scores180 = 2;
    final review = RankingYearReview(
      2026,
      {'Max Mustermann': stats},
      [1, 2, 0, 4, 1, 0, 3, 2, 1, 0, 0, 1],
      15,
    );

    const generator = RankingYearReviewImageGenerator();
    final bytes = await tester.runAsync(
      () => generator.generatePng(ranking: ranking, review: review),
    );

    expect(bytes, isNotNull);
    expect(bytes!, isNotEmpty);
    // Check PNG signature: 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A
    expect(bytes.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    expect(bytes.length, greaterThan(1000));
  });
}
