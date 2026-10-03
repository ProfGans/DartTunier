import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/statistics/domain/bot_statistics_privacy.dart';

void main() {
  test('human visits survive and bot visits are removed without mutating input', () {
    final result = <String, dynamic>{
      'legs': [2, 1],
      'statistics': {'visits': [{'player': 0, 'points': 60}, {'player': 1, 'points': 180}]},
    };
    final clean = withoutBotStatistics(result, {1})!;
    expect((clean['statistics'] as Map)['visits'], [{'player': 0, 'points': 60}]);
    expect((result['statistics'] as Map)['visits'], hasLength(2));
    expect(withoutBotStatistics(result, {0, 1})!.containsKey('statistics'), false);
    expect(withoutBotStatistics(result, {0, 1})!['legs'], [2, 1]);
  });
}
