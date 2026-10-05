import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../../application/autoscoring_controller.dart';
import '../../application/capture_general_diagnostic.dart';
import '../../data/autoscore_diagnostic_export.dart';

class GeneralDiagnosticButton extends StatefulWidget {
  const GeneralDiagnosticButton({
    super.key,
    required this.controller,
    this.setupId,
  });
  final AutoscoringController controller;
  final String? setupId;
  @override
  State<GeneralDiagnosticButton> createState() =>
      _GeneralDiagnosticButtonState();
}

class _GeneralDiagnosticButtonState extends State<GeneralDiagnosticButton> {
  bool _saving = false;
  Future<void> _report() async {
    setState(() => _saving = true);
    try {
      final evidence = captureGeneralDiagnostic(
        widget.controller,
        setupId: widget.setupId,
      );
      var note = '';
      String? description;
      description = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Allgemeine Diagnose'),
          scrollable: true,
          content: TextField(
            onChanged: (value) => note = value,
            minLines: 2,
            maxLines: 5,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Was ist passiert? (optional)',
              hintText: 'Zum Beispiel: zweiter Pfeil fehlt, Erkennung hängt …',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, note.trim()),
              child: const Text('Diagnose erstellen'),
            ),
          ],
        ),
      );
      if (description == null || !mounted) return;
      evidence.hit['userDescription'] = description;
      final path = await const AutoscoreDiagnosticExport().save(
        evidence,
        'Allgemeine Diagnose',
        'Keine Trefferkorrektur',
      );
      if (!mounted) return;
      final target = await getSaveLocation(
        suggestedName:
            'autoscore_diagnose_${evidence.capturedAt.millisecondsSinceEpoch}.zip',
        acceptedTypeGroups: [
          const XTypeGroup(label: 'Diagnose-ZIP', extensions: ['zip']),
        ],
      );
      if (target != null &&
          File(path).absolute.path != File(target.path).absolute.path) {
        await File(path).copy(target.path);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Diagnose gespeichert: ${target?.path ?? path}'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Diagnose konnte nicht exportiert werden: $error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: _saving ? null : _report,
    style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
    icon: const Icon(Icons.bug_report_outlined),
    label: Text(
      _saving ? 'Diagnose wird erstellt …' : 'Allgemeine Diagnose erstellen',
    ),
  );
}
