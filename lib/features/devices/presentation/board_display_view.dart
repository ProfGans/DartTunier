import 'package:flutter/material.dart';
import '../application/devices_controller.dart';
import '../application/device_scorer_settings.dart';
import 'device_scorer_session.dart';
import 'device_match_end_screen.dart';

class BoardDisplayView extends StatelessWidget {
  const BoardDisplayView({super.key, required this.controller});
  final DevicesController controller;
  @override
  Widget build(BuildContext context) {
    final assigned = controller.boardPresentation.display;
    final display =
        controller.boardPresentation.result == null &&
            assigned?.matchId != null &&
            controller.receiver.completedResult?['matchId'] == assigned?.matchId
        ? null
        : assigned;
    final result = controller.boardPresentation.result;
    if (display != null && result != null) {
      return DeviceMatchEndScreen(
        display: display,
        result: result,
        onExit: () => controller.setShowDisplay(false),
        onSkip: controller.boardPresentation.skip,
      );
    }
    String? scorerError;
    if (display?.state == 'running' &&
        display?.matchId != null &&
        display?.gameFormat != null) {
      try {
        deviceScorerSettings(display!);
        return Navigator(
          key: ValueKey(display.matchId),
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => DeviceScorerSession(
              display: display,
              receiver: controller.receiver,
              onExit: () => controller.setShowDisplay(false),
            ),
          ),
        );
      } catch (error) {
        scorerError = error.toString();
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          display == null ? 'Spielanzeige' : 'Board ${display.board}',
        ),
        actions: [
          IconButton(
            tooltip: 'Zur Verwaltung',
            onPressed: () => controller.setShowDisplay(false),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                controller.settings?.self.name ?? 'Gerät',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              if (display == null)
                const Text('Warte auf Spielzuweisung …')
              else ...[
                if (scorerError != null) Text(scorerError),
                Text(
                  display.tournamentName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                if (!controller.receiver.connected)
                  Text(
                    'Verbindung zur Turnierleitung unterbrochen – letzter Stand',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                Text(switch (display.state) {
                  'running' => 'Spiel läuft',
                  'planned' => 'Als Nächstes · Vorschau',
                  'finished' => 'Turnier abgeschlossen',
                  _ => 'Warte auf das nächste Spiel',
                }, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 32),
                if (display.home.isNotEmpty) ...[
                  Text(
                    display.home,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('gegen'),
                  ),
                  Text(
                    display.away,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 24),
                  Text(display.format, textAlign: TextAlign.center),
                  Text(display.detail, textAlign: TextAlign.center),
                  if (display.state == 'planned' && display.allowDeviceStart)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed:
                            controller.receiver.connected &&
                                !controller.receiver.startPending
                            ? controller.receiver.requestStart
                            : null,
                        child: Text(
                          controller.receiver.startPending
                              ? 'Start angefordert …'
                              : 'Partie starten',
                        ),
                      ),
                    ),
                  if (display.state == 'running')
                    Text(
                      display.score,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
