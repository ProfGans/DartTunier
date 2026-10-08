import 'package:flutter/material.dart';
import '../../data/scorer_monitor_preferences.dart';

class ScorerMonitorPreferenceTile extends StatefulWidget {
  const ScorerMonitorPreferenceTile({super.key});
  @override
  State<ScorerMonitorPreferenceTile> createState() =>
      _ScorerMonitorPreferenceTileState();
}

class _ScorerMonitorPreferenceTileState
    extends State<ScorerMonitorPreferenceTile> {
  final storage = ScorerMonitorPreferences();
  ScorerMonitorStart value = ScorerMonitorStart.off;
  bool busy = true;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final saved = await storage.load();
      if (mounted) setState(() => value = saved);
    } catch (_) {
      error = 'Monitor-Einstellung konnte nicht geladen werden.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _save(ScorerMonitorStart next) async {
    setState(() => busy = true);
    try {
      await storage.save(next);
      if (mounted) {
        setState(() {
          value = next;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Speichern fehlgeschlagen. Bitte erneut versuchen.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Spiele im Monitor-Modus starten',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Text(
          'Gilt für neu geöffnete Scorer-Spiele. Das separate Fenster lässt sich auf einen zweiten Monitor verschieben.',
        ),
        const SizedBox(height: 8),
        for (final option in const {
          ScorerMonitorStart.off: 'Aus · normale Scorer-Ansicht',
          ScorerMonitorStart.inApp: 'Punkteanzeige in der App',
          ScorerMonitorStart.window: 'Separates Anzeigefenster',
        }.entries)
          OutlinedButton.icon(
            onPressed: busy ? null : () => _save(option.key),
            icon: Icon(
              value == option.key
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            label: Text(option.value),
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
          ),
        if (error != null) Text(error!),
      ],
    ),
  );
}
