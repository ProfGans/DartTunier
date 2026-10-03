import 'package:flutter/material.dart';
import '../../data/autoscoring_preferences.dart';

class AutoscoringPreferenceTile extends StatefulWidget {
  const AutoscoringPreferenceTile({super.key});
  @override
  State<AutoscoringPreferenceTile> createState() =>
      _AutoscoringPreferenceTileState();
}

class _AutoscoringPreferenceTileState extends State<AutoscoringPreferenceTile> {
  final _storage = AutoscoringPreferences();
  bool _enabled = false, _busy = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await _storage.load();
      if (mounted) setState(() => _enabled = value);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Einstellung konnte nicht geladen werden.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(bool value) async {
    setState(() => _busy = true);
    try {
      await _storage.save(value);
      if (mounted) {
        setState(() {
          _enabled = value;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Einstellung konnte nicht gespeichert werden.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SwitchListTile(
    title: const Text('Autoscoring automatisch starten'),
    subtitle: Text(
      _error ??
          'Beim Öffnen einer Partie automatisch verbinden, wenn mindestens drei Kameras erkannt werden. Gilt auch für Gerätepartien und fortgesetzte Spiele. Ohne Kameras bleibt die manuelle Eingabe verfügbar.',
    ),
    value: _enabled,
    onChanged: _busy ? null : _save,
  );
}
