import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/scorer/data/repositories/checkout_route_repository.dart';
import 'package:dart_tournament_manager/features/scorer/data/repositories/embedded_bot_routes.dart';

void main() {
  test('Embedded bot routes exactly match the maintained source table', () {
    expect(
      jsonDecode(embeddedBotRoutesJson),
      jsonDecode(File('assets/scorer/bot_routes_v2.json').readAsStringSync()),
    );
  });
  test(
    'Bot routes initialize without a Flutter binding or asset bundle',
    () async {
      // Intentionally no TestWidgetsFlutterBinding: platform asset loading would
      // fail here, just as it does for an unavailable runtime asset bundle.
      final repository = CheckoutRouteRepository.instance;
      await repository.initialize();
      expect(repository.isInitialized, true);
      final route = repository.bestFinishRoute(score: 170, dartsLeft: 3);
      expect(route, isNotNull);
      expect(route!.map((dart) => dart.label), ['T20', 'T20', 'BULL']);
      await repository.initialize();
      expect(
        repository.bestFinishRoute(score: 40, dartsLeft: 1)!.single.label,
        'D20',
      );
    },
  );
}
