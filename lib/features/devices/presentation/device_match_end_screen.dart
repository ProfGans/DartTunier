import 'package:flutter/material.dart';
import 'package:dart_tournament_manager/shared/widgets/adaptive_content.dart';
import '../domain/board_display.dart';

class DeviceMatchEndScreen extends StatelessWidget {
  const DeviceMatchEndScreen({
    super.key,
    required this.display,
    required this.result,
    required this.onExit,
    this.error,
    this.onRetry,
    this.onSkip,
  });
  final BoardDisplay display;
  final Map<String, dynamic> result;
  final VoidCallback onExit;
  final String? error;
  final VoidCallback? onRetry;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final statistics = result['statistics'] as Map?;
    final winner = statistics?['winner'] as int?;
    final names = [display.home, display.away];
    final legs = (result['legs'] as List).cast<int>();
    final sets = (result['sets'] as List).cast<int>();
    return Scaffold(
      appBar: AppBar(
        title: Text('Board ${display.board} · Spiel beendet'),
        leading: IconButton(
          tooltip: 'Zur Geräteverwaltung',
          onPressed: onExit,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: AdaptiveContentList(
        children: [
          const SizedBox(height: 24),
          Icon(
            winner == null
                ? Icons.handshake_outlined
                : Icons.emoji_events_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            winner == null ? 'Unentschieden!' : '${names[winner]} gewinnt!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),
          for (var i = 0; i < names.length; i++)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${names[i]}\n${legs[i]} Legs · ${sets[i]} Sets',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            error ??
                'Ergebnis und Statistiken werden an die Turnierleitung übertragen.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Die nächste Partie erscheint nach 20 Sekunden, sobald sie zugewiesen wurde.',
            textAlign: TextAlign.center,
          ),
          if (onSkip != null)
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: onSkip,
              child: const Text('Überspringen'),
            ),
          if (error != null && onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('Erneut versuchen'),
            ),
        ],
      ),
    );
  }
}
