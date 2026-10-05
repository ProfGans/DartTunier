import 'dart:convert';

import 'embedded_bot_routes.dart';

import '../../domain/x01/checkout_planner.dart';
import '../../domain/x01/x01_models.dart';
import '../../domain/x01/x01_rules.dart';

class CheckoutRouteRepository {
  CheckoutRouteRepository._();

  static final CheckoutRouteRepository instance = CheckoutRouteRepository._();

  static const int _supportedVersion = 2;

  final Map<String, DartThrowResult> _throwsByLabel = <String, DartThrowResult>{
    for (final entry in const X01Rules().buildAllThrows()) entry.label: entry,
  };
  final Map<String, _CheckoutRouteBundle> _bundles =
      <String, _CheckoutRouteBundle>{};

  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    // Fixed routes ship with the program, including when the asset bundle of
    // an already-running installation is stale or unavailable.
    final decoded = jsonDecode(embeddedBotRoutesJson);
    if (decoded is! Map) {
      throw StateError('Checkout-Routen-Asset hat ein ungueltiges Format.');
    }
    final root = decoded.cast<String, Object?>();
    final version = (root['version'] as num?)?.toInt();
    if (version != _supportedVersion) {
      throw StateError(
        'Checkout-Routen-Asset-Version $version wird nicht unterstuetzt.',
      );
    }

    final rawBundles =
        ((root['routeBundles'] as Map?) ?? const <Object?, Object?>{})
            .cast<Object?, Object?>();
    _bundles.clear();
    for (final entry in rawBundles.entries) {
      final bundle = _readBundle(entry.value);
      if (bundle == null) {
        continue;
      }
      _bundles[entry.key.toString()] = bundle;
    }
    _initialized = true;
  }

  List<DartThrowResult>? bestFinishRoute({
    required int score,
    required int dartsLeft,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
  }) {
    final bundle = _lookupBundle(
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
    );
    if (bundle == null) {
      return null;
    }
    return _cloneRoute(
      bundle.finishRoutes[_routeKey(score: score, dartsLeft: dartsLeft)],
    );
  }

  List<DartThrowResult>? bestSetupRoute({
    required int score,
    required int dartsLeft,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
  }) {
    final bundle = _lookupBundle(
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
    );
    if (bundle == null) {
      return null;
    }
    return _cloneRoute(
      bundle.setupRoutes[_routeKey(score: score, dartsLeft: dartsLeft)],
    );
  }

  List<DartThrowResult>? bestHighScoreSetupRoute({
    required int score,
    required int dartsLeft,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
  }) {
    final bundle = _lookupBundle(
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
    );
    if (bundle == null) {
      return null;
    }
    return _cloneRoute(
      bundle.highScoreSetupRoutes[_routeKey(
        score: score,
        dartsLeft: dartsLeft,
      )],
    );
  }

  CheckoutContinuationPlan? bestContinuationPlan({
    required int score,
    required int dartsLeft,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
  }) {
    final bundle = _lookupBundle(
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
    );
    if (bundle == null) {
      return null;
    }
    final route = _cloneRoute(
      bundle.continuationRoutes[_routeKey(score: score, dartsLeft: dartsLeft)],
    );
    if (route == null || route.isEmpty) {
      return null;
    }
    final remainingScore =
        score - route.fold<int>(0, (sum, entry) => sum + entry.scoredPoints);
    return CheckoutContinuationPlan(
      throws: route,
      immediateFinish: remainingScore == 0,
      score: remainingScore,
    );
  }

  _CheckoutRouteBundle? _lookupBundle({
    required CheckoutRequirement checkoutRequirement,
    required CheckoutPlayStyle playStyle,
  }) {
    if (!_initialized) {
      return null;
    }
    return _bundles[_bundleKey(
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
    )];
  }

  _CheckoutRouteBundle? _readBundle(Object? raw) {
    final source = ((raw as Map?) ?? const <Object?, Object?>{})
        .cast<Object?, Object?>();
    final finishRoutes = _readRouteMap(source['finishRoutes']);
    final setupRoutes = _readRouteMap(source['setupRoutes']);
    final continuationRoutes = _readRouteMap(source['continuationRoutes']);
    final highScoreSetupRoutes = _readRouteMap(source['highScoreSetupRoutes']);
    if (finishRoutes.isEmpty &&
        setupRoutes.isEmpty &&
        continuationRoutes.isEmpty &&
        highScoreSetupRoutes.isEmpty) {
      return null;
    }
    return _CheckoutRouteBundle(
      finishRoutes: finishRoutes,
      setupRoutes: setupRoutes,
      continuationRoutes: continuationRoutes,
      highScoreSetupRoutes: highScoreSetupRoutes,
    );
  }

  Map<String, List<DartThrowResult>> _readRouteMap(Object? raw) {
    final source = ((raw as Map?) ?? const <Object?, Object?>{})
        .cast<Object?, Object?>();
    final mapped = <String, List<DartThrowResult>>{};
    for (final entry in source.entries) {
      final route = _deserializeRoute(entry.value);
      if (route == null || route.isEmpty) {
        continue;
      }
      mapped[entry.key.toString()] = List<DartThrowResult>.unmodifiable(route);
    }
    return mapped;
  }

  List<DartThrowResult>? _deserializeRoute(Object? raw) {
    if (raw is! List) {
      return null;
    }
    final route = <DartThrowResult>[];
    for (final item in raw) {
      final label = item?.toString();
      if (label == null || label.isEmpty) {
        return null;
      }
      final dartThrow = _throwsByLabel[label];
      if (dartThrow == null) {
        return null;
      }
      route.add(dartThrow);
    }
    return route;
  }

  List<DartThrowResult>? _cloneRoute(List<DartThrowResult>? route) {
    if (route == null) {
      return null;
    }
    return List<DartThrowResult>.unmodifiable(route);
  }

  String _routeKey({required int score, required int dartsLeft}) =>
      '$score|$dartsLeft';

  String _bundleKey({
    required CheckoutRequirement checkoutRequirement,
    required CheckoutPlayStyle playStyle,
  }) => '${checkoutRequirement.name}|${playStyle.name}';
}

class _CheckoutRouteBundle {
  const _CheckoutRouteBundle({
    required this.finishRoutes,
    required this.setupRoutes,
    required this.continuationRoutes,
    required this.highScoreSetupRoutes,
  });

  final Map<String, List<DartThrowResult>> finishRoutes;
  final Map<String, List<DartThrowResult>> setupRoutes;
  final Map<String, List<DartThrowResult>> continuationRoutes;
  final Map<String, List<DartThrowResult>> highScoreSetupRoutes;
}
