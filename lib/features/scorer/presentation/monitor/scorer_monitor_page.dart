import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../application/scorer_controller.dart';
import '../../domain/scorer_monitor_format.dart';
import '../../application/scorer_monitor_checkouts.dart';

class ScorerMonitorPage extends StatelessWidget {
  const ScorerMonitorPage({super.key, required this.controller, this.onClose});
  final ScorerController controller;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF101A22),
    appBar: AppBar(
      title: const Text('Punkteanzeige'),
      leading: onClose == null
          ? null
          : IconButton(
              tooltip: 'Zum Scorer',
              onPressed: onClose,
              icon: const Icon(Icons.arrow_back),
            ),
    ),
    body: SafeArea(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                scorerMonitorFormat(controller.settings),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 20),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final scale =
                        MediaQuery.textScalerOf(context).scale(16) / 16;
                    final columns = constraints.maxWidth >= 600 * scale ? 2 : 1;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 12) / columns;
                    final rows = (controller.scores.length / columns).ceil();
                    final height =
                        ((constraints.maxHeight - (rows - 1) * 12) / rows)
                            .clamp(240.0, double.infinity);
                    return SingleChildScrollView(
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (var i = 0; i < controller.scores.length; i++)
                            _MonitorPlayer(
                              starter: i == controller.legStarter,
                              checkouts: monitorCheckouts(controller, i),
                              name: controller.settings.participants[i].name,
                              score:
                                  i == controller.activePlayer &&
                                      !controller.isComplete
                                  ? controller.remaining
                                  : controller.scores[i],
                              legs: controller.legs[i],
                              sets: controller.sets[i],
                              active:
                                  i == controller.activePlayer &&
                                  !controller.isComplete,
                              width: width,
                              height: height,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MonitorPlayer extends StatelessWidget {
  const _MonitorPlayer({
    required this.name,
    required this.score,
    required this.legs,
    required this.sets,
    required this.active,
    required this.width,
    required this.height,
    required this.starter,
    required this.checkouts,
  });
  final String name;
  final int score, legs, sets;
  final bool active;
  final bool starter;
  final List<String> checkouts;
  final double width, height;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final font = math
        .min(
          (width - 40) / (math.max(3, '$score'.length) * .7 * scale),
          height * (checkouts.isEmpty ? .55 : .36) / scale,
        )
        .clamp(48.0, 480.0);
    return Container(
      width: width,
      constraints: BoxConstraints(minHeight: height),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF192B35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          width: 3,
          color: active ? const Color(0xFF70E0BA) : Colors.transparent,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            children: [
              if (starter)
                const Tooltip(
                  message: 'Anwerfer dieses Legs',
                  child: Icon(Icons.circle, color: Color(0xFFFFD166), size: 18),
                ),
              Text(
                name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: width >= 600 ? 40 : 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$score',
            style: TextStyle(
              color: const Color(0xFF70E0BA),
              fontSize: font,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$legs Legs · $sets Sätze',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: width >= 600 ? 32 : 24,
            ),
          ),
          if (checkouts.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'CHECKOUT',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
            Text(
              checkouts.first,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFFFD166),
                fontSize: width >= 600 ? 44 : 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            for (final route in checkouts.skip(1))
              Text(
                route,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 22),
              ),
          ],
        ],
      ),
    );
  }
}
