import 'package:flutter/material.dart';
import '../../../../devices/presentation/devices_page.dart';
import '../../../../devices/presentation/devices_scope.dart';

/// Reuses the persistent device registry without starting a tournament.
class TournamentDevicesSection extends StatelessWidget {
  const TournamentDevicesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final devices = DevicesScope.maybeOf(context);
    final count = {
      ...?devices?.settings?.savedDevices.map((device) => device.id),
      ...?devices?.accountDevices.map((device) => device.id),
    }.length;
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Geräte vorbereiten', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('Füge Geräte schon vor dem Turnierstart hinzu. '
            'Deine Turniereinstellungen bleiben dabei erhalten. '
            'Die Zuordnung zu den Boards erfolgt im angelegten Turnier.'),
        const SizedBox(height: 8),
        Text(devices == null ? 'Geräteverwaltung ist hier nicht verfügbar.'
            : '$count gespeicherte Geräte · Erreichbarkeit in der Geräteverwaltung prüfen'),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: devices == null ? null : () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => DevicesScope(
              controller: devices, child: const DevicesPage())),
          ),
          icon: const Icon(Icons.add_to_queue),
          label: const Text('Geräte hinzufügen / verwalten'),
        ),
      ]),
    ));
  }
}
