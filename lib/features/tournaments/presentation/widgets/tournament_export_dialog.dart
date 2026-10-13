import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/tournament_export.dart';
import '../../domain/tournament_models.dart';

class TournamentExportDialog {
  static Future<void> show(BuildContext context, CreatedTournament tournament) async {
    final data = TournamentExport.encode(tournament);
    final html = TournamentExport.html(tournament);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Turnierdaten exportieren'),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            child: SelectableText(data, style: const TextStyle(fontSize: 12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Schließen')),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: data));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Turnierdaten kopiert.')));
            },
            icon: const Icon(Icons.copy), label: const Text('JSON kopieren'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: html));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('HTML-Übersicht kopiert.')));
            },
            icon: const Icon(Icons.language), label: const Text('HTML kopieren'),
          ),
        ],
      ),
    );
  }
}
