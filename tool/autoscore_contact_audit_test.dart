import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/contact_audit.dart';

void main() {
  test('Generate independent camera contact audits for old failures', () {
    for (final id in ['183', '173', '92']) {
      final root = 'build/autoscore_analysis/preupdate_183_173_92/case_$id';
      final report =
          jsonDecode(File('$root/bericht.json').readAsStringSync()) as Map;
      for (var i = 0; i < 3; i++) {
        final result = buildContactAudit(
          File('$root/kamera_${i + 1}_treffer.png').readAsBytesSync(),
          report['cameras'][i] as Map,
          report['hit'] as Map,
          report['correctionPosition'] as Map,
          emptyColor: File(
            '$root/kamera_${i + 1}_leer_farbe.jpg',
          ).readAsBytesSync(),
        );
        expect(result, isNotNull);
        File(
          '$root/kamera_${i + 1}_kontaktpruefung.png',
        ).writeAsBytesSync(result!.overlay);
        File('$root/kamera_${i + 1}_kontaktpruefung.json').writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(result.metrics),
        );
      }
    }
  });
}
