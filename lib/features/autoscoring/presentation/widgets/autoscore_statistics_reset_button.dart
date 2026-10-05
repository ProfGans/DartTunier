import 'package:flutter/material.dart';
import '../../data/autoscore_setup_store.dart';

class AutoscoreStatisticsResetButton extends StatelessWidget {
  const AutoscoreStatisticsResetButton({
    super.key,
    required this.store,
    this.onReset,
  });
  final AutoscoreSetupStore? store;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) => store == null
      ? _button(context)
      : ListenableBuilder(
          listenable: store!,
          builder: (context, _) => _button(context),
        );

  Widget _button(BuildContext context) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
    icon: const Icon(Icons.restart_alt),
    label: const Text('Genauigkeitsstatistik zurücksetzen'),
    onPressed: store != null && !store!.loaded
        ? null
        : () async {
            final setup = store?.active;
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                scrollable: true,
                title: const Text('Statistik zurücksetzen?'),
                content: Text(
                  'Alle Statistikzähler für „${setup?.name ?? 'Aktuelle Sitzung'}“ beginnen wieder bei 0. Die Kameraeinstellungen und gespeicherten Diagnosen bleiben erhalten.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Abbrechen'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Zurücksetzen'),
                  ),
                ],
              ),
            );
            if (!context.mounted || confirmed != true) return;
            if (setup != null) store!.resetStatistics(setup.id);
            onReset?.call();
          },
  );
}
