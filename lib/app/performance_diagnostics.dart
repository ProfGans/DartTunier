import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Opt-in, aggregate-only profile logging; never records names or game data.
class PerformanceDiagnostics {
  static bool _started = false;
  static void start() {
    if (!const bool.fromEnvironment('PERFORMANCE_LOG') || _started) return;
    _started = true;
    final startup = Stopwatch()..start();
    final build = <int>[], raster = <int>[];
    var first = true;
    SchedulerBinding.instance.addTimingsCallback((frames) {
      if (first && frames.isNotEmpty) {
        first = false;
        debugPrint(
          'PERF ${jsonEncode({'firstFrameMs': startup.elapsedMicroseconds / 1000})}',
        );
      }
      for (final frame in frames) {
        build.add(frame.buildDuration.inMicroseconds);
        raster.add(frame.rasterDuration.inMicroseconds);
      }
    });
    Timer.periodic(const Duration(seconds: 10), (_) {
      if (build.isEmpty) return;
      build.sort();
      raster.sort();
      double p95(List<int> samples) =>
          samples[((samples.length - 1) * .95).ceil()] / 1000;
      debugPrint(
        'PERF ${jsonEncode({'frames': build.length, 'buildP95Ms': p95(build), 'rasterP95Ms': p95(raster), 'buildOver16_67ms': build.where((v) => v > 16667).length, 'rasterOver16_67ms': raster.where((v) => v > 16667).length, 'rssMiB': ProcessInfo.currentRss / (1024 * 1024)})}',
      );
      build.clear();
      raster.clear();
    });
  }
}
