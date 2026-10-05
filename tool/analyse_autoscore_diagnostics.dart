import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/correction_analysis.dart';

/// Read-only input analysis; accepts old and new correction reports/ZIPs.
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'dart run tool/analyse_autoscore_diagnostics.dart <Ordner oder ZIP> [weitere ...] --output <JSON>',
    );
    exitCode = 64;
    return;
  }
  final outputIndex = args.indexOf('--output');
  final output = outputIndex >= 0 && outputIndex + 1 < args.length
      ? args[outputIndex + 1]
      : 'build/autoscore_analysis/correction_summary.json';
  final inputs = outputIndex >= 0 ? args.take(outputIndex) : args;
  final reports = <String, Map<dynamic, dynamic>>{};
  var unreadable = 0;
  Future<void> read(File file) async {
    try {
      String text;
      if (file.path.toLowerCase().endsWith('.zip')) {
        final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
        final report = archive.findFile('bericht.json');
        if (report == null) return;
        text = utf8.decode(report.content as List<int>);
      } else if (file.uri.pathSegments.last == 'bericht.json') {
        text = await file.readAsString();
      } else {
        return;
      }
      final report = jsonDecode(text) as Map;
      if (report['hit'] is Map &&
          report['hit']['eventType'] == 'manualRemoval') {
        return;
      }
      final key = '${report['capturedAtUtc'] ?? file.absolute.path}';
      reports[key] = report;
    } catch (_) {
      unreadable++;
    }
  }

  for (final input in inputs) {
    if (await File(input).exists()) {
      await read(File(input));
    } else if (await Directory(input).exists()) {
      final files = await Directory(input)
          .list(recursive: true, followLinks: false)
          .where((f) => f is File)
          .cast<File>()
          .toList();
      files.sort((a, b) => a.path.compareTo(b.path));
      for (final file in files) {
        await read(file);
      }
    } else {
      unreadable++;
    }
  }
  final samples = [
    for (final report in reports.values) ?correctionSampleFromReport(report),
  ];
  final summary = {
    'schemaVersion': 1,
    'reports': reports.length,
    'unreadableInputs': unreadable,
    'positionAnalysis': analysePositionCorrections(samples),
  };
  final target = File(output);
  await target.parent.create(recursive: true);
  await target.writeAsString(
    const JsonEncoder.withIndent('  ').convert(summary),
  );
  stdout.writeln(
    '${reports.length} Berichte, ${samples.length} gesetzte Positionen: ${target.absolute.path}',
  );
}
