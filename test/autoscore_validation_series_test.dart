import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/autoscore_demo_controller.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/autoscore_validation_series.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/autoscore_diagnostic_export.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_rules.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Series persists all results and distinguishes automatic from independent checks',
    () async {
      final demo = AutoscoreDemoController();
      final series = AutoscoreValidationSeries(
        outputRoot: Directory(
          'build/autoscore_analysis/validation_series_tests',
        ),
      );
      addTearDown(demo.dispose);
      addTearDown(series.dispose);
      series.start(0, scenario: 'tightGroups', partition: 'test');
      demo.add(
        const X01Rules().createSingle(20),
        evidence: AutoscoreEvidence([], {}),
      );
      series.observe(demo.history);
      demo.reset();
      series.observe(demo.history);
      await series.flush;
      expect(series.independentlyReviewed, 0);
      expect(
        series.events.single['verificationSource'],
        'automaticUntouchedOnRemoval',
      );
      demo.confirm(0);
      series.observe(demo.history);
      await series.flush;
      expect(series.independentlyReviewed, 1);
      expect(series.independentlyCorrect, 1);
      demo.add(
        const X01Rules().createSingle(5),
        evidence: AutoscoreEvidence([], {}),
      );
      demo.review(1, const X01Rules().createSingle(20));
      series.observe(demo.history);
      await series.flush;
      expect(series.independentlyReviewed, 2);
      expect(series.independentlyCorrect, 1);
      expect(demo.history[0].evidence!.hit['datasetSplit'], 'test');
      final manifest = jsonDecode(
        File('${series.folder}/pruefserie.json').readAsStringSync(),
      );
      expect(manifest['events'], hasLength(2));
      expect(manifest['independentlyReviewed'], 2);
      expect(
        File(series.events.first['diagnosticPath'] as String).existsSync(),
        true,
      );
    },
  );
  test(
    'Missing camera evidence and unreviewed throws still persist in manifest',
    () async {
      final demo = AutoscoreDemoController();
      final series = AutoscoreValidationSeries(
        outputRoot: Directory(
          'build/autoscore_analysis/validation_series_tests',
        ),
      );
      addTearDown(demo.dispose);
      addTearDown(series.dispose);
      series.start(0, scenario: 'outerRim', partition: 'validation');
      demo.add(const X01Rules().createMiss());
      series.observe(demo.history);
      series.stop();
      await series.flush;
      final manifest = jsonDecode(
        File('${series.folder}/pruefserie.json').readAsStringSync(),
      );
      expect(manifest['events'], hasLength(1));
      expect(manifest['events'][0]['actual'], null);
      expect(manifest['events'][0]['diagnosticPath'], null);
      expect(series.independentlyReviewed, 0);
    },
  );
}
