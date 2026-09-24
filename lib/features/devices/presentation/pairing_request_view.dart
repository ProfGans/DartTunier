import 'package:flutter/material.dart';
import '../data/board_display_server.dart';

class PairingRequestView extends StatelessWidget {
  const PairingRequestView({super.key, required this.receiver});
  final BoardDisplayServer receiver;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black54,
    child: Center(
      child: AlertDialog(
        title: const Text('Kopplungsanfrage'),
        content: Text(
          '${receiver.pairingName} (${receiver.pairingAddress}) möchte Spiele auf diesem Gerät anzeigen.\n\nVergleichszahl: ${receiver.pairingCode}\n\nNur koppeln, wenn auf beiden Geräten dieselbe Zahl steht. Du musst nichts eintippen.',
        ),
        actions: [
          TextButton(
            onPressed: () => receiver.answerPairing(false),
            child: const Text('Ablehnen'),
          ),
          FilledButton(
            onPressed: () => receiver.answerPairing(true),
            child: const Text('Koppeln'),
          ),
        ],
      ),
    ),
  );
}
