import 'package:flutter/material.dart';
import '../../tournaments/domain/tournament_models.dart';
import '../data/community_calendar_repository.dart';
import '../domain/community_calendar.dart';

class SaveCalendarPresetDialog extends StatefulWidget {
  const SaveCalendarPresetDialog({super.key, required this.tournament});
  final CreatedTournament tournament;
  @override
  State<SaveCalendarPresetDialog> createState() =>
      _SaveCalendarPresetDialogState();
}

class _SaveCalendarPresetDialogState extends State<SaveCalendarPresetDialog> {
  late final _name = TextEditingController(text: widget.tournament.name);
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Bitte einen Namen eingeben.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await CommunityCalendarRepository().savePreset(
        widget.tournament.communityId!,
        _name.text,
        CommunityTournamentPreset.fromTournament(widget.tournament),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Vorlage konnte nicht gespeichert werden. Namen, Verbindung und Rechte prüfen.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Kalender-Vorlage speichern'),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Speichert Boards, Spielerzahl, Modus und Spielformat der ersten Etappe sowie Ranglisten. Teilnehmer und Ergebnisse werden nicht kopiert.',
        ),
        TextField(
          controller: _name,
          enabled: !_busy,
          maxLength: 80,
          decoration: InputDecoration(
            labelText: 'Vorlagenname',
            errorText: _error,
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: const Text('Speichern'),
      ),
    ],
  );
}
