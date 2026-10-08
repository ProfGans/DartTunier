import 'package:flutter/material.dart';
import '../../application/scorer_controller.dart';
import '../../domain/scorer_monitor_format.dart';

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
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
            final columns = constraints.maxWidth >= 600 * scale ? 2 : 1;
            final width =
                (constraints.maxWidth - 32 - (columns - 1) * 16) / columns;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: constraints.maxWidth - 32,
                    child: Text(
                      scorerMonitorFormat(controller.settings),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  for (var i = 0; i < controller.scores.length; i++)
                    SizedBox(
                      width: width,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF192B35),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            width: 3,
                            color:
                                i == controller.activePlayer &&
                                    !controller.isComplete
                                ? const Color(0xFF70E0BA)
                                : Colors.transparent,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              controller.settings.participants[i].name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                              ),
                            ),
                            Text(
                              '${i == controller.activePlayer && !controller.isComplete ? controller.remaining : controller.scores[i]}',
                              style: TextStyle(
                                color: const Color(0xFF70E0BA),
                                fontSize: width >= 500 * scale ? 110 : 64,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${controller.legs[i]} Legs · ${controller.sets[i]} Sätze',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}
