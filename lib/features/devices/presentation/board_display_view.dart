import 'package:flutter/material.dart';
import '../application/devices_controller.dart';

class BoardDisplayView extends StatelessWidget {
  const BoardDisplayView({super.key, required this.controller});
  final DevicesController controller;
  @override
  Widget build(BuildContext context) {
    final display = controller.receiver.display;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          display == null ? 'Spielanzeige' : 'Board ${display.board}',
        ),
        actions: [
          TextButton(
            onPressed: () => controller.setShowDisplay(false),
            child: const Text('Zur Verwaltung'),
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
